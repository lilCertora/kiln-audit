// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: 2023 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// █████╔╝ ██║██║     ██╔██╗ ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity >=0.8.17;

import "./LibPublicKey.sol";
import "./LibSignature.sol";

library LibKey {
    // slither-disable-next-line unused-state
    uint256 constant KEY_PAIR_LENGTH = LibPublicKey.PUBLIC_KEY_LENGTH + LibSignature.SIGNATURE_LENGTH;

    // slither-disable-next-line dead-code
    function toBytes(LibPublicKey.PublicKey memory publicKey, LibSignature.Signature memory signature)
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(LibSignature.toBytes(signature), LibPublicKey.toBytes(publicKey));
    }

    // slither-disable-next-line dead-code
    function fromBytes(bytes memory keys)
        internal
        pure
        returns (LibPublicKey.PublicKey memory publicKey, LibSignature.Signature memory signature)
    {
        keys = bytes.concat(keys, LibPublicKey.PADDING);
        (bytes32 A, bytes32 B, bytes32 C, bytes32 D, bytes32 E_prime) =
            abi.decode(keys, (bytes32, bytes32, bytes32, bytes32, bytes32));
        bytes16 E = bytes16(uint128(uint256(E_prime) >> 128));
        signature.A = A;
        signature.B = B;
        signature.C = C;
        publicKey.A = D;
        publicKey.B = E;
    }
}
