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

library LibSignature {
    // slither-disable-next-line unused-state
    uint256 constant SIGNATURE_LENGTH = 96;

    struct Signature {
        bytes32 A;
        bytes32 B;
        bytes32 C;
    }

    // slither-disable-next-line dead-code
    function toBytes(Signature memory signature) internal pure returns (bytes memory) {
        return abi.encodePacked(signature.A, signature.B, signature.C);
    }

    // slither-disable-next-line dead-code
    function fromBytes(bytes memory signature) internal pure returns (Signature memory ret) {
        (ret) = abi.decode(signature, (Signature));
    }
}
