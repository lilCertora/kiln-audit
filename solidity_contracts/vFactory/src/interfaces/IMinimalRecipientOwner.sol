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

/// @title Minimal Recipient Owner Interface
/// @author mortimr @ Kiln
/// @notice This interface defines the possible calls that the Minimal Recipient Owner contract should implement
interface IMinimalRecipientOwner {
    /// @notice Retrieve the recipient address and if auto claim is enabled
    /// @param validatorId The validator ID to retrieve the details for
    /// @return The recipient address
    /// @return True if auto claim is enabled
    function autoClaimDetails(uint256 validatorId) external view returns (address, bool);
}
