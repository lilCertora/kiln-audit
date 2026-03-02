import requests
import json
import os
import time

addresses = [
    "0x4d893e724a0a913f6fb6ca1581644dbd81dcd5bd",
    "0xc4dcb059dd98b45b090da8982234c61d0b9e84f9",
    "0xeb4d67dba18b3be04484dfc7b7c2780e8d32a79d",
    "0xe5faa3fcc7729c3ac7b4571207bb5978e5c33e81",
    "0xba1613cf1ff0d7307315f1d98465e27877ad3f02",
    "0x9995f241c6a0d5b712281dfd3bd0e0289a5f2a98",
    "0x7d4b92522df1c7d211cbab49148d9d260b5a5e41",
    "0x61ac42269d0035cd86c52b6c5bb299daa73c7135",
    "0x5db5235b5c7e247488784986e58019fffd98fda4",
    "0x5b1c9ee05794e9667806f1bd1c6ae6d196498183",
    "0x594db36d6f3e747f2c7675659f712bf4d72a9f97",
    "0x437636e4b984eae19045626aa269a89f906cf96c",
    "0x42ecf9bde9078d659663da66b97c4823f762005e",
    "0x30a4aa1d14d44f0f5bfe887447ab6facc94a549f",
    "0x2e3956e1ee8b44ab826556770f69e3b9ca04a2a7",
    "0x2401c39d7ba9e283668a53fcc7b8f5fd9e716fdf",
    "0x18099b65842cada4d87075920986559d9216a5bf",
    "0x24a1dfebaec4e501c2152a5e4a434b236fce3d3b",
    "0xc2c48fbfec0e61683133aaff32c9c2e98fd17788",
    "0x24d6e12fa25b7f8fc6b4bba0ea77fc643d7210d3",
    "0xdac8cf86ca42185ebce7ed2dbec9bc2be1734ffc",
    "0x066b6c3fca9034395068eb9d442ee5041eac33dc",
    "0x1d6103243d0507a9d1314bac09379bf57a5cf155",
    "0x48005e62373277fbbe5584b351830b1b2ec1e3fd",
    "0xa748ae65ba11606492a9c57effa0d4b7be551ec2",
    "0xd9f56e8a1b159b1482ec3bb6ce742fa5ce084f4c",
    "0x00a0be1bbc0c99898df7e6524bf16e893c1e3bb9",
    "0xc63d9f0040d35f328274312fc8771a986fc4ba86",
    "0x99a6d933bd22040136b7ccd5dbc3acdf2c103be6",
    "0xd54ede626441ae514b15743d6a78a74c664b30a2",
    "0x4e6a0740aa4c89c7e36c430afe3dd3bec68b6aec",
    "0x8eea6cc08d824b20efb3bf7c248de694cb1f75f4",
    "0x2d5e65ff87d986d18ac224e725dc654bec3a04cd",
    "0x8a113da63f02811e63c1e38ef615df94df5d9e70",
]

API_KEY = "QDPM5ZXQ8F2P9WV7ST415W1QM1UQYTTVGX"
BASE_URL = "https://api.etherscan.io/v2/api"
OUTPUT_DIR = "solidity_contracts"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def fetch_source(address):
    params = {
        "chainid": "1",
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": API_KEY,
    }
    r = requests.get(BASE_URL, params=params, timeout=15)
    data = r.json()
    if data.get("status") != "1" or not data.get("result"):
        return None
    return data["result"][0]


def save_sources(source_code, folder):
    """Parse and save source files, preserving directory structure."""
    os.makedirs(folder, exist_ok=True)

    if source_code.startswith("{{"):
        source_code = source_code[1:-1]

    try:
        parsed = json.loads(source_code)
        sources = parsed.get("sources", parsed)
        if isinstance(sources, dict):
            for filepath, content in sources.items():
                code = content.get("content", "") if isinstance(content, dict) else content
                out_path = os.path.join(folder, filepath.replace("../", "").lstrip("/"))
                os.makedirs(os.path.dirname(out_path), exist_ok=True)
                with open(out_path, "w") as f:
                    f.write(code)
            return len(sources)
    except (json.JSONDecodeError, AttributeError):
        pass

    out_path = os.path.join(folder, "contract.sol")
    with open(out_path, "w") as f:
        f.write(source_code)
    return 1


for addr in addresses:
    print(f"Fetching {addr[:12]}...")
    result = fetch_source(addr)

    if not result:
        print(f"  -> Erreur ou pas de résultat")
        time.sleep(0.25)
        continue

    name = result.get("ContractName", "Unknown") or "Unknown"
    source = result.get("SourceCode", "")
    impl_addr = result.get("Implementation", "")
    is_proxy = result.get("Proxy") == "1" or bool(impl_addr)

    if not source:
        print(f"  -> {name}: pas de source (non vérifié)")
        time.sleep(0.25)
        continue

    if is_proxy and impl_addr:
        print(f"  -> Proxy détecté, récupération de l'implémentation {impl_addr[:12]}...")
        time.sleep(0.25)
        impl_result = fetch_source(impl_addr)
        if impl_result and impl_result.get("SourceCode"):
            impl_name = impl_result.get("ContractName", "Unknown") or "Unknown"
            folder = os.path.join(OUTPUT_DIR, impl_name)
            n = save_sources(impl_result["SourceCode"], folder)
            print(f"  -> {impl_name} ({n} fichiers)")
        else:
            folder = os.path.join(OUTPUT_DIR, name)
            n = save_sources(source, folder)
            print(f"  -> {name} ({n} fichiers, proxy sans impl vérifiée)")
    else:
        folder = os.path.join(OUTPUT_DIR, name)
        n = save_sources(source, folder)
        print(f"  -> {name} ({n} fichiers)")

    time.sleep(0.25)