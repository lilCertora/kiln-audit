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

/// @title Exec Layer Recipient Interface
/// @author mortimr @ Kiln
/// @notice The Exec Layer Recipient is the recipient expected to receive rewards from block proposals
interface IvExecLayerRecipient is IFixable {
    /// @notice Emitted when ETH was supplied to the associated vPool
    /// @param amount The amount of ETH supplied
    event SuppliedEther(uint256 amount);

    /// @notice Emitted when the stored Pool address is changed
    /// @param pool The new pool address
    event SetPool(address pool);

    /// @notice Initialize the vPool (proxy pattern)
    /// @param vpool The associated vPool address
    function initialize(address vpool) external;

    /// @notice Retrieve the address of the linked vPool
    /// @return Address of the linked vPool
    function pool() external view returns (address);

    /// @notice Retrieve the funding status of the exec layer recipient
    /// @return True if the contract holds rewards
    function hasFunds() external view returns (bool);

    /// @notice Retrieve the amount of ETH available for rewards
    /// @return The total amount of ETH available for coverage
    function funds() external view returns (uint256);

    /// @notice Method called by the associated vPool to pull exec layer rewards
    /// @param max The max amount to pull as rewards
    function pull(uint256 max) external;

    /// @notice Receive handler
    receive() external payable;

    /// @notice Fallback handler
    fallback() external payable;
}
