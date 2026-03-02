//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./victypes.sol";

/// @title Balance mappings Custom Type
library LBalance {
    // slither-disable-next-line dead-code
    function get(victypes.BalanceMapping position) internal pure returns (mapping(address => uint256) storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }
}
