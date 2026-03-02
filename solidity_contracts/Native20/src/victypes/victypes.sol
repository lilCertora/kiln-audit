//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "utils.sol/libs/LibPublicKey.sol";
import "utils.sol/libs/LibSignature.sol";

/// @title Custom Types
// slither-disable-next-line naming-convention
library victypes {
    struct User4907 {
        address user;
        uint64 expiration;
    }

    type BalanceMapping is bytes32;
    type User4907Mapping is bytes32;
}
