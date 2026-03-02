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

/// @title Withdrawal Recipient Interface
/// @author mortimr @ Kiln
/// @notice Used as the withdrawal credential of the vPool validators
interface IvWithdrawalRecipient is IFixable {
    /// @notice Emitted when the stored Pool address is changed
    /// @param pool The new pool address
    event SetPool(address pool);

    /// @notice Emitted when ETH was supplied to the associated vPool
    /// @param amount The amount that was supplied
    event SuppliedEther(uint256 amount);

    /// @notice Thrown when the requested amount to pull is higher than the available balance
    /// @param requestedAmount The amount requested to pull
    /// @param availableAmount The amount available to pull
    error InvalidRequestedAmount(uint256 requestedAmount, uint256 availableAmount);

    /// @notice Initializes the WithdrawalRecipient (proxy pattern)
    /// @param vpool The address of the vPool
    function initialize(address vpool) external;

    /// @notice Retrieves the address of the associated vPool
    /// @return poolAddress The address of the vPool
    function pool() external view returns (address poolAddress);

    /// @notice Retrieves the withdrawal credential value to use on validator deposits
    /// @return computedWithdrawalCredentials The computed withdrawal credentials
    function withdrawalCredentials() external view returns (bytes32 computedWithdrawalCredentials);

    /// @notice Pull funds to vPool contract
    /// @param amount The amount of ETH to pull
    function pull(uint256 amount) external;

    /// @notice Request new total exit count for owned channel on given factory
    /// @param factory Factory to perform the call upon
    /// @param amount The total amount that should be exited
    /// @return The new total exit count
    function requestTotalExits(address factory, uint32 amount) external returns (uint32);
}
