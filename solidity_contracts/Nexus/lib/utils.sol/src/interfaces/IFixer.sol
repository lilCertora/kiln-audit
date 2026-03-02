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

/// @title Fixer
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The Hatcher can deploy, upgrade, fix and pause a set of instances called cubs.
///         All cubs point to the same common implementation.
interface IFixer {
    /// @notice Interface to implement on a Fixer contract.
    /// @return isFixed True if fix was properly applied
    function fix() external returns (bool isFixed);
}
