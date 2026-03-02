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

library LibPublicKey {
    // slither-disable-next-line unused-state
    uint256 constant PUBLIC_KEY_LENGTH = 48;

    // slither-disable-next-line unused-state
    bytes constant PADDING = hex"00000000000000000000000000000000";

    struct PublicKey {
        bytes32 A;
        bytes16 B;
    }

    // slither-disable-next-line dead-code
    function toBytes(PublicKey memory publicKey) internal pure returns (bytes memory) {
        return abi.encodePacked(publicKey.A, publicKey.B);
    }

    // slither-disable-next-line dead-code
    function fromBytes(bytes memory publicKey) internal pure returns (PublicKey memory ret) {
        publicKey = bytes.concat(publicKey, PADDING);
        (bytes32 A, bytes32 B_prime) = abi.decode(publicKey, (bytes32, bytes32));
        bytes16 B = bytes16(uint128(uint256(B_prime) >> 128));
        ret.A = A;
        ret.B = B;
    }
}
