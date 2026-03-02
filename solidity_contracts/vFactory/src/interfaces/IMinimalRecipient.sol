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

/// @title Minimal Recipient Interface
/// @author mortimr @ Kiln
/// @notice This contract is meant to be deployed to hold funds and to be controlled by another contract.
///         The main use case behind this is to determinstically deploy clones of this contract to addresses
///         used as withdrawal credentials for validators.
interface IMinimalRecipient {
    /// @notice The minimal recipient has already been initialized
    error AlreadyInitialized();

    /// @notice The balance is insufficient for the requested value
    /// @param balance The current balance
    /// @param value The requested value
    error InsufficientBalance(uint256 balance, uint256 value);

    /// @notice The auto claim failed
    /// @param validatorId The validator ID
    /// @param recipient The recipient address
    /// @param claimAmount The amount to claim
    /// @param rdata The revert data
    event AutoClaimFailure(uint256 indexed validatorId, address indexed recipient, uint256 claimAmount, bytes rdata);

    /// @notice Initializer
    /// @param owner The address able to perform exec
    /// @param id The validator ID that this contract is associated with
    function init(address owner, uint256 id) external;

    /// @notice Executes an arbitrary call to a target contract
    /// @param target The address to call
    /// @param cdata The calldata to use
    /// @param value The value in ETH to use
    /// @return True if the call was successful
    /// @return The returndata of the call
    function exec(address target, bytes calldata cdata, uint256 value) external returns (bool, bytes memory);

    /// @notice Claims the validator's rewards
    /// @dev Required when we want to claim using the autoClaim flow, without having to send ETH
    function forceClaim() external;

    /// @notice Explicit ETH receiver
    receive() external payable;

    /// @notice Explicit Fallback
    fallback() external payable;
}
