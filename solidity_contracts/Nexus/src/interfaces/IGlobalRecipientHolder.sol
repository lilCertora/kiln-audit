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

/// @title Global Recipient Holder Interface
/// @author mortimr @ Kiln
/// @notice Contract holding and exposing a global recipient address
interface IGlobalRecipientHolder {
    /// @notice Emitted when the global recipient has been changed
    /// @param globalRecipient The new global recipient address
    event SetGlobalRecipient(address globalRecipient);

    /// @notice Retrieve the global recipient address
    /// @return The global recipient address
    function globalRecipient() external view returns (address);

    /// @notice Set the global recipient value
    /// @param newGlobalRecipient The new address for the global recipient
    function setGlobalRecipient(address newGlobalRecipient) external;
}
