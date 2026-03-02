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

import "./LibErrors.sol";
import "./LibConstant.sol";

/// @title Lib Sanitize
/// @dev This library helps sanitizing inputs.
library LibSanitize {
    /// @dev Internal utility to sanitize an address and ensure its value is not 0.
    /// @param addressValue The address to verify
    // slither-disable-next-line dead-code
    function notZeroAddress(address addressValue) internal pure {
        if (addressValue == address(0)) {
            revert LibErrors.InvalidZeroAddress();
        }
    }

    /// @dev Internal utility to sanitize an uint256 value and ensure its value is not 0.
    /// @param value The value to verify
    // slither-disable-next-line dead-code
    function notNullValue(uint256 value) internal pure {
        if (value == 0) {
            revert LibErrors.InvalidNullValue();
        }
    }

    /// @dev Internal utility to sanitize a bps value and ensure it's <= 100%.
    /// @param value The bps value to verify
    // slither-disable-next-line dead-code
    function notInvalidBps(uint256 value) internal pure {
        if (value > LibConstant.BASIS_POINTS_MAX) {
            revert LibErrors.InvalidBPSValue();
        }
    }

    /// @dev Internal utility to sanitize a string value and ensure it's not empty.
    /// @param stringValue The string value to verify
    // slither-disable-next-line dead-code
    function notEmptyString(string memory stringValue) internal pure {
        if (bytes(stringValue).length == 0) {
            revert LibErrors.InvalidEmptyString();
        }
    }
}
