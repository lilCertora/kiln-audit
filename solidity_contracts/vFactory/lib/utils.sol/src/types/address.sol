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

import "./types.sol";

/// @notice Library Address - Address slot utilities.
library LAddress {
    // slither-disable-next-line dead-code, assembly
    function get(types.Address position) internal view returns (address data) {
        // slither-disable-next-line assembly
        assembly {
            data := sload(position)
        }
    }

    // slither-disable-next-line dead-code
    function set(types.Address position, address data) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, data)
        }
    }

    // slither-disable-next-line dead-code
    function del(types.Address position) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, 0)
        }
    }
}

library CAddress {
    // slither-disable-next-line dead-code
    function toUint256(address val) internal pure returns (uint256) {
        return uint256(uint160(val));
    }

    // slither-disable-next-line dead-code
    function toBytes32(address val) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(val)));
    }

    // slither-disable-next-line dead-code
    function toBool(address val) internal pure returns (bool converted) {
        // slither-disable-next-line assembly
        assembly {
            converted := gt(val, 0)
        }
    }

    /// @notice This method should be used to convert an address to a uint256 when used as a key in a mapping.
    // slither-disable-next-line dead-code
    function k(address val) internal pure returns (uint256) {
        return toUint256(val);
    }

    /// @notice This method should be used to convert an address to a uint256 when used as a value in a mapping.
    // slither-disable-next-line dead-code
    function v(address val) internal pure returns (uint256) {
        return toUint256(val);
    }
}
