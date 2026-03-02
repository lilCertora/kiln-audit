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

/// @title Cub
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The cub is controlled by a Hatcher in charge of providing its status details and implementation address.
interface ICub {
    /// @notice An error occured when performing the delegatecall to the fix.
    /// @param fixer Address implementing the fix
    /// @param err The return data from the call error
    error FixDelegateCallError(address fixer, bytes err);

    /// @notice The fix method failed by returning false.
    /// @param fixer Added implementing the fix
    error FixCallError(address fixer);

    /// @notice A call was made while the cub was paused.
    /// @param caller The address that performed the call
    error CalledWhenPaused(address caller);

    error CubAlreadyInitialized();

    /// @notice Emitted when several fixes have been applied.
    /// @param fixes List of fixes to apply
    event AppliedFixes(address[] fixes);

    /// @notice Public method that emits the AppliedFixes event.
    /// @dev Transparent to all callers except the cub itself
    /// @dev Only callable by the cub itself as a regular call
    /// @dev This method is used to detect the execution context (view/non-view)
    /// @param _fixers List of applied fixes
    function appliedFixes(address[] memory _fixers) external;

    /// @notice Applies the provided fix.
    /// @dev Transparent to all callers except the hatcher
    /// @param _fixer The address of the contract implementing the fix to apply
    function applyFix(address _fixer) external;
}
