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

library LibConstant {
    /// @dev The basis points value representing 100%.
    uint256 internal constant BASIS_POINTS_MAX = 10_000;
    /// @dev The size of a deposit to activate a validator.
    uint256 internal constant DEPOSIT_SIZE = 32 ether;
    /// @dev The minimum freeze timeout before freeze is active.
    uint256 internal constant MINIMUM_FREEZE_TIMEOUT = 100 days;
    /// @dev Address used to represent ETH when an address is required to identify an asset.
    address internal constant ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}
