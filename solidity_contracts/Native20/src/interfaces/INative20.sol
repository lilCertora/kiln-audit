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

/// @notice Configuration parameters for the Native20 contract.
/// @param admin The address of the admin.
/// @param name ERC-20 style display name.
/// @param symbol ERC-20 style display symbol.
/// @param pools List of pool addresses.
/// @param poolFees List of fee for each pool, in basis points.
/// @param commissionRecipients List of recipients among which the withdrawn fees are shared.
/// @param commissionDistribution Share of each fee recipient, in basis points, must add up to 10 000.
/// @param poolPercentages The amount of ETH to route to each pool when staking, in basis points, must add up to 10 000.
struct Native20Configuration {
    string name;
    string symbol;
    address admin;
    address[] pools;
    uint256[] poolFees;
    address[] commissionRecipients;
    uint256[] commissionDistribution;
    uint256[] poolPercentages;
    uint256 maxCommissionBps;
    uint256 monoTicketThreshold;
}

/// @title Native20 (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract allows users to stake any amount of ETH in the vPool(s).
///         Users are given non transferable ERC-20 type shares to track their stake.
interface INative20 {
    /// @notice Initializes the contract with the given parameters.
    /// @param args The initialization arguments.
    function initialize(Native20Configuration calldata args) external;

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token, usually a shorter version of the name.
    function symbol() external view returns (string memory);

    /// @notice Returns the number of decimals used to get its user representation.
    function decimals() external view returns (uint8);

    /// @notice Returns the total amount of staking shares.
    /// @return Total amount of shares.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of ETH owned by the users in the pool(s).
    /// @return Total amount of shares.
    function totalUnderlyingSupply() external view returns (uint256);

    /// @notice Returns the amount of staking shares for an account.
    /// @param account The address of the account.
    /// @return amount of staking shares.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the ETH value of the account balance.
    /// @param account The address of the account.
    /// @return amount of ETH.
    function balanceOfUnderlying(address account) external view returns (uint256);

    /// @notice Function to stake ETH.
    function stake() external payable;
}
