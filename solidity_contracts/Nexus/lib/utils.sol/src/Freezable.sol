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
pragma solidity >=0.8.17;

// For some unexplainable and mysterious reason, adding this line would make slither crash
// This is the reason why we are not using our own unstructured storage libs in this contract
// (while the libs work properly in a lot of contracts without slither having any issue with it)
// import "./types/uint256.sol";

import "./libs/LibErrors.sol";
import "./libs/LibConstant.sol";
import "openzeppelin-contracts/utils/StorageSlot.sol";

/// @title Freezable
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The Freezable contract is used to add a freezing capability to admin related actions.
///         The goal would be to ossify an implementation after a certain amount of time.
// slither-disable-next-line unimplemented-functions
abstract contract Freezable {
    /// @notice Thrown when a call happened while it was forbidden when frozen.
    error Frozen();

    /// @notice Thrown when the provided timeout value is lower than 100 days.
    /// @param providedValue The user provided value
    /// @param minimumValue The minimum allowed value
    error FreezeTimeoutTooLow(uint256 providedValue, uint256 minimumValue);

    /// @notice Emitted when the freeze timeout is changed.
    /// @param freezeTime The timestamp after which the contract will be frozen
    event SetFreezeTime(uint256 freezeTime);

    /// @dev This is the keccak-256 hash of "freezable.freeze_timestamp" subtracted by 1.
    bytes32 private constant _FREEZE_TIMESTAMP_SLOT = 0x04b06dd5becaad633b58f99e01f1e05103eff5a573d10d18c9baf1bc4e6bfd3a;

    /// @dev Only callable by the freezer account.
    modifier onlyFreezer() {
        _onlyFreezer();
        _;
    }

    /// @dev Only callable when not frozen.
    modifier notFrozen() {
        _notFrozen();
        _;
    }

    /// @dev Override and set it to return the address to consider as the freezer.
    /// @return The freezer address
    // slither-disable-next-line dead-code
    function _getFreezer() internal view virtual returns (address);

    /// @dev Retrieve the freeze status.
    /// @return True if contract is frozen
    // slither-disable-next-line dead-code,timestamp
    function _isFrozen() internal view returns (bool) {
        uint256 freezeTime_ = _freezeTime();
        return (freezeTime_ > 0 && block.timestamp >= freezeTime_);
    }

    /// @dev Retrieve the freeze timestamp.
    /// @return The freeze timestamp
    // slither-disable-next-line dead-code
    function _freezeTime() internal view returns (uint256) {
        return StorageSlot.getUint256Slot(_FREEZE_TIMESTAMP_SLOT).value;
    }

    /// @dev Internal utility to set the freeze timestamp.
    /// @param freezeTime The new freeze timestamp
    // slither-disable-next-line dead-code
    function _setFreezeTime(uint256 freezeTime) internal {
        StorageSlot.getUint256Slot(_FREEZE_TIMESTAMP_SLOT).value = freezeTime;
        emit SetFreezeTime(freezeTime);
    }

    /// @dev Internal utility to revert if caller is not freezer.
    // slither-disable-next-line dead-code
    function _onlyFreezer() internal view {
        if (msg.sender != _getFreezer()) {
            revert LibErrors.Unauthorized(msg.sender, _getFreezer());
        }
    }

    /// @dev Internal utility to revert if contract is frozen.
    // slither-disable-next-line dead-code
    function _notFrozen() internal view {
        if (_isFrozen()) {
            revert Frozen();
        }
    }

    /// @dev Internal utility to start the freezing procedure.
    /// @param freezeTimeout Timeout to add to current timestamp to define freeze timestamp
    // slither-disable-next-line dead-code
    function _freeze(uint256 freezeTimeout) internal {
        _notFrozen();
        _onlyFreezer();
        if (freezeTimeout < LibConstant.MINIMUM_FREEZE_TIMEOUT) {
            revert FreezeTimeoutTooLow(freezeTimeout, LibConstant.MINIMUM_FREEZE_TIMEOUT);
        }

        // overflow would revert
        uint256 now_ = block.timestamp;
        uint256 freezeTime_ = now_ + freezeTimeout;

        _setFreezeTime(freezeTime_);
    }

    /// @dev Internal utility to cancel the freezing procedure.
    // slither-disable-next-line dead-code
    function _cancelFreeze() internal {
        _notFrozen();
        _onlyFreezer();
        _setFreezeTime(0);
    }
}
