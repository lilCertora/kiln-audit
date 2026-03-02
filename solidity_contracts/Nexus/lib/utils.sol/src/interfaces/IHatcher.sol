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

import "openzeppelin-contracts/proxy/beacon/IBeacon.sol";

/// @title Hatcher Interface
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The Hatcher can deploy, upgrade, fix and pause a set of instances called cubs.
///         All cubs point to the same coomon implementation.
interface IHatcher is IBeacon {
    /// @notice Emitted when the system is globally paused.
    event GlobalPause();

    /// @notice Emitted when the system is globally unpaused.
    event GlobalUnpause();

    /// @notice Emitted when a specific cub is paused.
    /// @param cub Address of the cub being paused
    event Pause(address cub);

    /// @notice Emitted when a specific cub is unpaused.
    /// @param cub Address of the cub being unpaused
    event Unpause(address cub);

    /// @notice Emitted when a global fix is removed.
    /// @param index Index of the global fix being removed
    event DeletedGlobalFix(uint256 index);

    /// @notice Emitted when a cub has properly applied a fix.
    /// @param cub Address of the cub that applied the fix
    /// @param fix Address of the fix was applied
    event AppliedFix(address cub, address fix);

    /// @notice Emitted the common implementation is updated.
    /// @param implementation New common implementation address
    event Upgraded(address indexed implementation);

    /// @notice Emitted a new cub is hatched.
    /// @param cub Address of the new instance
    /// @param cdata Calldata used to perform the atomic first call
    event Hatched(address indexed cub, bytes cdata);

    /// @notice Emitted a the initial progress has been changed.
    /// @param initialProgress New initial progress value
    event SetInitialProgress(uint256 initialProgress);

    /// @notice Emitted a new pauser is set.
    /// @param pauser Address of the new pauser
    event SetPauser(address pauser);

    /// @notice Emitted a cub committed some global fixes.
    /// @param cub Address of the cub that applied the global fixes
    /// @param progress New cub progress
    event CommittedFixes(address cub, uint256 progress);

    /// @notice Emitted a global fix is registered.
    /// @param fix Address of the new global fix
    /// @param index Index of the new global fix in the global fix array
    event RegisteredGlobalFix(address fix, uint256 index);

    /// @notice The provided implementation is not a smart contract.
    /// @param implementation The provided implementation
    error ImplementationNotAContract(address implementation);

    /// @notice Retrieve the common implementation.
    /// @return implementationAddress Address of the common implementation
    function implementation() external view returns (address implementationAddress);

    /// @notice Retrieve cub status details.
    /// @param cub The address of the cub to fetch the status of
    /// @return implementationAddress The current implementation address to use
    /// @return hasFixes True if there are fixes to apply
    /// @return isPaused True if the system is paused globally or the calling cub is paused
    function status(address cub) external view returns (address implementationAddress, bool hasFixes, bool isPaused);

    /// @notice Retrieve the initial progress.
    /// @dev This value is the starting progress value for all new cubs
    /// @return currentInitialProgress The initial progress
    function initialProgress() external view returns (uint256 currentInitialProgress);

    /// @notice Retrieve the current progress of a specific cub.
    /// @param cub Address of the cub
    /// @return currentProgress The current progress of the cub
    function progress(address cub) external view returns (uint256 currentProgress);

    /// @notice Retrieve the global pause status.
    /// @return isGlobalPaused True if globally paused
    function globalPaused() external view returns (bool isGlobalPaused);

    /// @notice Retrieve a cub pause status.
    /// @param cub Address of the cub
    /// @return isPaused True if paused
    function paused(address cub) external view returns (bool isPaused);

    /// @notice Retrieve the address of the pauser.
    function pauser() external view returns (address);

    /// @notice Retrieve a cub's global fixes that need to be applied, taking its progress into account.
    /// @param cub Address of the cub
    /// @return fixesAddresses An array of addresses that implement fixes
    function fixes(address cub) external view returns (address[] memory fixesAddresses);

    /// @notice Retrieve the raw list of global fixes.
    /// @return globalFixesAddresses An array of addresses that implement the global fixes
    function globalFixes() external view returns (address[] memory globalFixesAddresses);

    /// @notice Retrieve the address of the next hatched cub.
    /// @return nextHatchedCub The address of the next cub
    function nextHatch() external view returns (address nextHatchedCub);

    /// @notice Retrieve the freeze status.
    /// @return True if frozen
    function frozen() external view returns (bool);

    /// @notice Retrieve the timestamp when the freeze happens.
    /// @return The freeze timestamp
    function freezeTime() external view returns (uint256);

    /// @notice Creates a new cub.
    /// @param cdata The calldata to use for the initial atomic call
    /// @return cubAddress The address of the new cub
    function hatch(bytes calldata cdata) external returns (address cubAddress);

    /// @notice Creates a new cub, without calldata.
    /// @return cubAddress The address of the new cub
    function hatch() external returns (address cubAddress);

    /// @notice Sets the progress of the caller to the current global fixes array length.
    function commitFixes() external;

    /// @notice Sets the address of the pauser.
    /// @param newPauser Address of the new pauser
    function setPauser(address newPauser) external;

    /// @notice Apply a fix to several cubs.
    /// @param fixer Fixer contract implementing the fix
    /// @param cubs List of cubs to apply the fix on
    function applyFixToCubs(address fixer, address[] calldata cubs) external;

    /// @notice Apply several fixes to one cub.
    /// @param cub The cub to apply the fixes on
    /// @param fixers List of fixer contracts implementing the fixes
    function applyFixesToCub(address cub, address[] calldata fixers) external;

    /// @notice Register a new global fix for cubs to call asynchronously.
    /// @param fixer Address of the fixer implementing the fix
    function registerGlobalFix(address fixer) external;

    /// @notice Deletes a global fix from the array.
    /// @param index Index of the global fix to remove
    function deleteGlobalFix(uint256 index) external;

    /// @notice Upgrades the common implementation address.
    /// @param newImplementation Address of the new common implementation
    function upgradeTo(address newImplementation) external;

    /// @notice Upgrades the common implementation address and the initial progress value.
    /// @param newImplementation Address of the new common implementation
    /// @param initialProgress_ The new initial progress value
    function upgradeToAndChangeInitialProgress(address newImplementation, uint256 initialProgress_) external;

    /// @notice Sets the initial progress value.
    /// @param initialProgress_ The new initial progress value
    function setInitialProgress(uint256 initialProgress_) external;

    /// @notice Sets the progress of a cub.
    /// @param cub Address of the cub
    /// @param newProgress New progress value
    function setCubProgress(address cub, uint256 newProgress) external;

    /// @notice Pauses a set of cubs.
    /// @param cubs List of cubs to pause
    function pauseCubs(address[] calldata cubs) external;

    /// @notice Unpauses a set of cubs.
    /// @param cubs List of cubs to unpause
    function unpauseCubs(address[] calldata cubs) external;

    /// @notice Pauses all the cubs of the system.
    function globalPause() external;

    /// @notice Unpauses all the cubs of the system.
    /// @dev If a cub was specifically paused, this method won't unpause it
    function globalUnpause() external;

    /// @notice Sets the freeze timestamp.
    /// @param freezeTimeout The timeout to add to current timestamp before freeze happens
    function freeze(uint256 freezeTimeout) external;

    /// @notice Cancels the freezing procedure.
    function cancelFreeze() external;
}
