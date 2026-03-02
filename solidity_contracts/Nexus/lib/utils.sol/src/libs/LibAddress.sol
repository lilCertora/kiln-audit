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

/// @title Lib Bytes
/// @dev This library helps manipulating addresses.
library LibAddress {
    /// @dev The base mask used to generate a bytes32 withdrawal credential from an address.
    // slither-disable-next-line too-many-digits
    uint256 constant ETH1_PREFIX = 0x0100000000000000000000000000000000000000000000000000000000000000;

    /// @dev Utility to convert an address into withdrawal credentials.
    /// @param addr The address receiving the withdrawal of the validator
    /// @return The bytes32 withdrawal credentials
    // slither-disable-next-line dead-code
    function toWithdrawalCredentials(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address(addr))) | ETH1_PREFIX);
    }

    /// @dev Utility to convert withdrawal credentials back to an address.
    /// @param withdrawalCredentials The Withdrawal Credentials to convert
    /// @return The withdrawal account
    // slither-disable-next-line dead-code
    function fromWithdrawalCredentials(bytes32 withdrawalCredentials) internal pure returns (address) {
        return address(uint160(uint256(withdrawalCredentials) & (~ETH1_PREFIX)));
    }
}
