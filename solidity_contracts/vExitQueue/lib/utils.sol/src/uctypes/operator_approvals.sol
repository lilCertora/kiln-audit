//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./uctypes.sol";

/// @title Operator Approvals Custom Type
library LOperatorApprovalsMapping {
    function get(uctypes.OperatorApprovalsMapping position)
        internal
        pure
        returns (mapping(address => mapping(address => bool)) storage data)
    {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }
}
