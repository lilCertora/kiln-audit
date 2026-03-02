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

import "prb-math/PRBMath.sol";

library LibUint256 {
    // slither-disable-next-line dead-code
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        // slither-disable-next-line assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /// @custom:author Vectorized/solady#58681e79de23082fd3881a76022e0842f5c08db8
    // slither-disable-next-line dead-code
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        // slither-disable-next-line assembly
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    // slither-disable-next-line dead-code
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return PRBMath.mulDiv(a, b, c);
    }

    // slither-disable-next-line dead-code
    function ceil(uint256 num, uint256 den) internal pure returns (uint256) {
        return (num / den) + (num % den > 0 ? 1 : 0);
    }
}
