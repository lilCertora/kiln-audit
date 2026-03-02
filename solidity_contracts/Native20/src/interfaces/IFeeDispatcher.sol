// SPDX-License-Identifier: MIT
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

import "utils.sol/interfaces/IFixable.sol";

/// @title FeeDispatcher (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract contains functions to dispatch the ETH in a contract upon withdrawal.
interface IFeeDispatcher {
    /// @notice Emitted when the commission split is changed.
    /// @param recipients The addresses of recipients
    /// @param splits The percentage of each recipient in basis points
    event NewCommissionSplit(address[] recipients, uint256[] splits);

    /// @notice Emitted when the integrator withdraws ETH
    /// @param withdrawer address withdrawing the ETH
    /// @param amountWithdrawn amount of ETH withdrawn
    event CommissionWithdrawn(address indexed withdrawer, uint256 amountWithdrawn);

    /// @notice Thrown when functions are given lists of different length in batch arguments
    /// @param lengthA First argument length
    /// @param lengthB Second argument length
    error UnequalLengths(uint256 lengthA, uint256 lengthB);

    /// @notice Thrown when a function is called while the contract is locked
    error Reentrancy();

    /// @notice Allows the integrator to withdraw the ETH in the contract.
    function withdrawCommission() external;
}
