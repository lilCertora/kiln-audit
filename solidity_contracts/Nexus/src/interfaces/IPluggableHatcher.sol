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

/// @title Pluggable Hatcher Interface
/// @author mortimr @ Kiln
/// @notice The PluggableHatcher extends the Hatcher and allows the nexus to spawn cubs
interface IPluggableHatcher {
    /// @notice Emitted when the stored Nexus address is changed
    /// @param nexus The new nexus address
    event SetNexus(address nexus);

    /// @notice Method allowing the Nexus to hatch a new cub
    /// @param cdata The calldata to provide to the hatch method
    /// @return The address of the new cub
    function plug(bytes calldata cdata) external returns (address);

    /// @notice Retrieve the configured nexus address
    /// @return The nexus address
    function nexus() external view returns (address);
}
