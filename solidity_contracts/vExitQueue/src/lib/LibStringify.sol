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
pragma solidity 0.8.17;

import "utils.sol/libs/LibUint256.sol";
import "utils.sol/libs/LibBytes.sol";
import "openzeppelin-contracts/utils/Strings.sol";

/// @title Stringify Library  - A library for converting numbers to strings with decimal support
library LibStringify {
    /// @dev Generates a string in memory with the requested count of zeroes
    /// @param count The number of zeroes to generate
    /// @return The generated string
    function generateZeroes(uint256 count) internal pure returns (string memory) {
        bytes memory zeroes = new bytes(count);
        for (uint256 idx = 0; idx < count;) {
            zeroes[idx] = "0";
            unchecked {
                ++idx;
            }
        }
        return string(zeroes);
    }

    /// @dev Converts a uint256 to a string with the requested number of decimals
    /// @param value The value to convert
    /// @param decimals The number of decimals to include
    /// @param maxIncludedDecimals The maximum number of decimals to include
    /// @return The generated string
    function uintToDecimalString(uint256 value, uint8 decimals, uint8 maxIncludedDecimals) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        bytes memory uintToString = bytes(Strings.toString(value));
        if (decimals == 0) {
            return string(uintToString);
        }
        uint256 len = uintToString.length;
        if (len > decimals) {
            if (maxIncludedDecimals == 0) {
                return string(LibBytes.slice(bytes(uintToString), 0, len - decimals));
            }
            uintToString = abi.encodePacked(
                LibBytes.slice(bytes(uintToString), 0, len - decimals),
                ".",
                LibBytes.slice(bytes(uintToString), len - decimals, LibUint256.min(decimals, maxIncludedDecimals))
            );
        } else {
            if (maxIncludedDecimals <= decimals - len) {
                return "0";
            }
            uintToString = abi.encodePacked(
                "0.",
                LibBytes.slice(
                    abi.encodePacked(generateZeroes(decimals - len), uintToString), 0, LibUint256.min(decimals, maxIncludedDecimals)
                )
            );
        }

        return string(uintToString);
    }
}
