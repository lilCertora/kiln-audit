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

/// @title MultiPool-20 (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract contains the internal logic for an ERC-20 token based on one or multiple pools.
interface IMultiPool20 {
    /// @notice Emitted when a stake is transferred.
    /// @param from The address sending the stake
    /// @param to The address receiving the stake
    /// @param value The transfer amount
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when an allowance is created.
    /// @param owner The owner of the shares
    /// @param spender The address that can spend
    /// @param value The allowance amount
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when some integrator shares are sold
    /// @param pSharesSold ETH amount of vPool shares sold
    /// @param id Id of the pool
    /// @param amountSold ETH amount of shares sold
    event CommissionSharesSold(uint256 pSharesSold, uint256 id, uint256 amountSold);

    /// @notice Emitted when new split is set.
    /// @param split Array of value in basis points to route to each pool
    event SetPoolPercentages(uint256[] split);

    /// @notice Thrown when a transfer is attempted but the sender does not have enough balance.
    /// @param amount The token amount.
    /// @param balance The balance of user.
    error InsufficientBalance(uint256 amount, uint256 balance);

    /// @notice Thrown when a transferFrom is attempted but the spender does not have enough allowance.
    error InsufficientAllowance(uint256 amount, uint256 allowance);

    /// @notice Thrown when trying to set a pool percentage != 0 to a deactivated pool
    error NonZeroPercentageOnDeactivatedPool(uint256 id);

    /// @notice Set the percentage of new stakes to route to each pool
    /// @notice If a pool is disabled it needs to be set to 0 in the array
    /// @param split Array of values in basis points to route to each pool
    function setPoolPercentages(uint256[] calldata split) external;

    /// @notice Burns the sender's shares and sends the exitQueue tickets to the caller.
    /// @param amount Amount of shares to add to the exit queue
    function requestExit(uint256 amount) external;

    /// @notice Returns the share to ETH conversion rate
    /// @return ETH value of a share
    function rate() external returns (uint256);

    /// @notice Allows the integrator to prevent users from depositing to a vPool.
    /// @param poolId The id of the vPool.
    /// @param status Whether the users can deposit to the pool.
    /// @param newPoolPercentages Array of value in basis points to route to each pool after the change
    function setPoolActivation(uint256 poolId, bool status, uint256[] calldata newPoolPercentages) external;
}
