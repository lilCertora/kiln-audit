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
pragma solidity >=0.8.17;

/// @title Depositor Interface
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The Depositor contract adds deposit capabilities to easily fund
///         validators and activate them on the Consensus Layer.
interface IDepositor {
    /// @notice The provided public key is not 48 bytes long.
    error InvalidPublicKeyLength();

    /// @notice The provided signature is not 96 bytes long.
    error InvalidSignatureLength();

    /// @notice The balance is too low for the deposit.
    error InvalidDepositSize();

    /// @notice An error occured during the deposit.
    error DepositError();

    /// @notice The deposit contract address has been updated.
    /// @param depositContract The new deposit contract address
    event SetDepositContract(address depositContract);

    /// @notice Retrieve the deposit contract address.
    /// @return depositContractAddress The deposit contract address
    function depositContract() external view returns (address depositContractAddress);
}
