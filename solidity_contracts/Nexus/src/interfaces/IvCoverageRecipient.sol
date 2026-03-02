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
pragma solidity 0.8.17;

import "utils.sol/interfaces/IFixable.sol";

import "./IvPoolSharesReceiver.sol";

/// @title Coverage Recipient Interface
/// @author mortimr @ Kiln
/// @notice The Coverage Recipient can hold ETH or vPool shares to repay losses due to slashing
interface IvCoverageRecipient is IFixable, IvPoolSharesReceiver {
    /// @notice Emitted when the stored Pool address is changed
    /// @param pool The new pool address
    event SetPool(address pool);

    /// @notice Emitted when a new donor address has been authorized
    /// @param donorAddress Address of the new donor
    /// @param allowed True if authorized to donate
    event AllowedDonor(address donorAddress, bool allowed);

    /// @notice Emitted when ETH was donated to the recipient
    /// @param amount The amount of ETH donated
    event UpdatedEtherForCoverage(uint256 amount);

    /// @notice Emitted when vPool shares were donated to the recipient
    /// @param amount The amount of vPool shares donated
    event UpdatedSharesForCoverage(uint256 amount);

    /// @notice Emitted when the coverage recipient supplies ETH to its vPool
    /// @param amount Amount of supplied ETH
    event SuppliedEther(uint256 amount);

    /// @notice Emitted when the coverage recipient voids vPool shares
    /// @param amount Amount of voided vPool shares
    event VoidedShares(uint256 amount);

    /// @notice Thrown when the requested amount to remove exceeds coverage recipient balance
    /// @param requestedAmount The amount that was requested for removal
    /// @param availableAmount The amount that was available
    error RemovedAmountTooHigh(uint256 requestedAmount, uint256 availableAmount);

    /// @notice Thrown when the transfer of shares upon removal failed
    /// @param recipient The recipient for the shares transfer
    /// @param amount The amount to remove
    /// @param cdata The provided extra data
    error SharesTransferError(address recipient, uint256 amount, bytes cdata);

    /// @notice Initialize the CoverageRecipient (proxy pattern)
    /// @param vpool The address of the linked vPool
    function initialize(address vpool) external;

    /// @notice Retrieve the address of the linked vPool
    /// @return Address of the linked vPool
    function pool() external view returns (address);

    /// @notice Retrieve the authorization status of a donor
    /// @param donorAddress Address of the donor to inspect
    /// @return True if authorized to donate
    function donor(address donorAddress) external view returns (bool);

    /// @notice Retrieve the funding status of the coverage recipient
    /// @return True if the contract holds funds for coverage
    function hasFunds() external view returns (bool);

    /// @notice Retrieve the amount of ETH available for coverage
    /// @return The total amount of ETH available for coverage
    function etherFunds() external view returns (uint256);

    /// @notice Retrieve the amount of vPool shares available for coverage
    /// @return The total amount of vPool shares available for coverage
    function sharesFunds() external view returns (uint256);

    /// @notice Method called by the associated vPool to ask for coverage. The Coverage Recipient will
    ///         attempt to cover up to the maximum requested amount.
    /// @dev Only callable by the associated vPool
    /// @param max The maximum amount to cover in ETH
    function cover(uint256 max) external;

    /// @notice Change the authorization status of a donor
    /// @param donorAddress The address of the donor
    /// @param allowed True if the address should be allowed to donate
    function allowDonor(address donorAddress, bool allowed) external;

    /// @notice Method to add ETH for coverage
    /// @dev Only callable by an authorized donor
    function fundWithEther() external payable;

    /// @notice Method to remove ETH from the coverage recipient
    /// @dev Only callable by the admin
    /// @param recipient The address to send the funds to
    /// @param amount The amount of ETH to remove
    function removeEther(address recipient, uint256 amount) external;

    /// @notice Method to remove vPool Shares from the coverage recipient
    /// @dev Only callable by the admin
    /// @param recipient The address to send the funds to
    /// @param amount The amount of vPool Shares to remove
    function removeShares(address recipient, uint256 amount) external;
}
