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

import "./interfaces/IHatcher.sol";

import "./Cub.sol";
import "./Administrable.sol";
import "./Freezable.sol";

import "./libs/LibUint256.sol";

import "./libs/LibSanitize.sol";
import "./types/address.sol";
import "./types/uint256.sol";
import "./types/mapping.sol";
import "./types/array.sol";
import "./types/bool.sol";

/// @title Administrable
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly.
/// @dev In general, regarding the fixes, try to always perform atomic actions to apply them.
/// @dev When using regular fixes, it's already the case.
/// @dev When using global fixes, try to wrap multiple actions in one tx/bundle to create the global fix and apply it on required instances.
/// @dev When removing a global fix, keep in mind that the action can be front runned and the fix that should be removed would be applied.
/// @dev The hatcher can be frozen by the admin. Once frozen, no more upgrade, pausing or fixing is allowed.
/// @dev If frozen and paused, a cub will be unpaused.
/// @dev If frozen and pending fixes are still there, they will be applied to cubs that haven't applied them.
/// @dev If frozen, pending fixes cannot be removed.
/// @dev Initial progress and cub progress can get updated by the admin. This means a fix can be applied twice if progress is decreased.
/// @notice This contract provides all the utilities to handle the administration and its transfer
abstract contract Hatcher is Administrable, Freezable, IHatcher {
    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;
    using LArray for types.Array;
    using LBool for types.Bool;

    using CAddress for address;
    using CUint256 for uint256;
    using CBool for bool;

    /// @dev Unstructured Storage Helper for hatcher.pauser.
    /// @dev Holds the pauser address.
    /// @dev Slot: keccak256(bytes("hatcher.pauser")) - 1
    types.Address internal constant $pauser =
        types.Address.wrap(0x67ad2ba345683ea58e6dcc49f12611548bc3a5b2c8c753edc1878aa0a76c3ce2);
    /// @dev Unstructured Storage Helper for hatcher.implementation.
    /// @dev Holds the common implementation used by all the cubs.
    /// @dev Slot: keccak256(bytes("hatcher.implementation")) - 1
    types.Address internal constant $implementation =
        types.Address.wrap(0x5822215992e9fc50486d8256024d96ad28d5ca5cb787840aef51159121dccd9d);
    /// @dev Unstructured Storage Helper for hatcher.initialProgress.
    /// @dev Holds the initial progress value given to all new cubs.
    /// @dev Supersedes the progress of old cubs if the value is higher than their progress.
    /// @dev Slot: keccak256(bytes("hatcher.initialProgress")) - 1
    types.Uint256 internal constant $initialProgress =
        types.Uint256.wrap(0x4a267ea82c1f4624b3dc08ad19614228bbdeee20d07eb9966d67c16d39550d77);
    /// @dev Unstructured Storage Helper for hatcher.fixProgresses.
    /// @dev Holds the value of the fix progress of every cub.
    /// @dev Type: mapping (address => uint256)
    /// @dev Slot: keccak256(bytes("hatcher.fixProgresses")) - 1
    types.Mapping internal constant $fixProgresses =
        types.Mapping.wrap(0xa7208bf4db7440ac9388b234d45a5b207976f0fc12d31bf9eaa80e4e2fc0d57c);
    /// @dev Unstructured Storage Helper for hatcher.pauseStatus.
    /// @dev Holds the pause status of every cub.
    /// @dev Type: mapping (address => bool)
    /// @dev Slot: keccak256(bytes("hatcher.pauseStatus")) - 1
    types.Mapping internal constant $pauseStatus =
        types.Mapping.wrap(0xd0ad769ee84b03ff353d2cb4c134ab25db1f330b56357f28eadc5b28c2f88991);
    /// @dev Unstructured Storage Helper for hatcher.globalPauseStatus.
    /// @dev Holds the global pause status.
    /// @dev Slot: keccak256(bytes("hatcher.globalPauseStatus")) - 1
    types.Bool internal constant $globalPauseStatus =
        types.Bool.wrap(0x798f8d9ad9ed68e65653cd13b4f27162f01222155b56622ae81337e4888e20c0);
    /// @dev Unstructured Storage Helper for hatcher.fixes.
    /// @dev Holds the array of global fixes.
    /// @dev Slot: keccak256(bytes("hatcher.fixes")) - 1
    types.Array internal constant $fixes =
        types.Array.wrap(0xa8612761e880b1989e2ad0bb2c51004fad089f897b1cd8dc3dbfeae33493df55);
    /// @dev Unstructured Storage Helper for hatcher.initialProgress.
    /// @dev Holds the create2 salt.
    /// @dev Slot: keccak256(bytes("hatcher.creationSalt")) - 1
    types.Uint256 internal constant $creationSalt =
        types.Uint256.wrap(0x7b4670a3a88a40c4de314967df154b504cc215cbd280a064c677342c49c2759d);

    /// @dev Only allows admin or pauser to perform the call.
    modifier onlyAdminOrPauser() {
        if (msg.sender != _getAdmin() && msg.sender != $pauser.get()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @inheritdoc IHatcher
    function implementation() external view returns (address) {
        return $implementation.get();
    }

    /// @inheritdoc IHatcher
    // slither-disable-next-line timestamp
    function status(address cub) external view returns (address, bool, bool) {
        return (
            $implementation.get(),
            $fixProgresses.get()[cub.k()] < $fixes.toAddressA().length,
            ($globalPauseStatus.get() || $pauseStatus.get()[cub.k()].toBool()) && !_isFrozen()
        );
    }

    /// @inheritdoc IHatcher
    function initialProgress() external view returns (uint256) {
        return $initialProgress.get();
    }

    /// @inheritdoc IHatcher
    function progress(address cub) external view returns (uint256) {
        return $fixProgresses.get()[cub.k()];
    }

    /// @inheritdoc IHatcher
    function globalPaused() external view returns (bool) {
        return $globalPauseStatus.get();
    }

    /// @inheritdoc IHatcher
    function paused(address cub) external view returns (bool) {
        return $pauseStatus.get()[cub.k()].toBool();
    }

    /// @inheritdoc IHatcher
    function pauser() external view returns (address) {
        return $pauser.get();
    }

    /// @inheritdoc IHatcher
    function fixes(address cub) external view returns (address[] memory) {
        uint256 currentProgress = $fixProgresses.get()[cub.k()];
        uint256 rawFixCount = $fixes.toAddressA().length;
        uint256 fixCount = rawFixCount - LibUint256.min(currentProgress, rawFixCount);
        address[] memory forwardedFixes = new address[](fixCount);

        for (uint256 idx = 0; idx < fixCount;) {
            forwardedFixes[idx] = $fixes.toAddressA()[idx + currentProgress];
            unchecked {
                ++idx;
            }
        }

        return forwardedFixes;
    }

    /// @inheritdoc IHatcher
    /// @dev This method is not view because it reads the fixes from storage.
    function globalFixes() external pure returns (address[] memory) {
        return $fixes.toAddressA();
    }

    /// @inheritdoc IHatcher
    function nextHatch() external view returns (address) {
        return _nextHatch();
    }

    /// @inheritdoc IHatcher
    function frozen() external view returns (bool) {
        return _isFrozen();
    }

    /// @inheritdoc IHatcher
    function freezeTime() external view returns (uint256) {
        return _freezeTime();
    }

    /// @inheritdoc IHatcher
    function hatch(bytes calldata cdata) external virtual onlyAdmin returns (address) {
        return _hatch(cdata);
    }

    /// @inheritdoc IHatcher
    function hatch() external virtual onlyAdmin returns (address) {
        return _hatch("");
    }

    /// @inheritdoc IHatcher
    function commitFixes() external {
        address cub = msg.sender;
        uint256 newProgress = $fixes.toAddressA().length;
        $fixProgresses.get()[cub.k()] = newProgress;
        emit CommittedFixes(cub, newProgress);
    }

    /// @inheritdoc IHatcher
    function setPauser(address newPauser) external onlyAdmin {
        _setPauser(newPauser);
    }

    /// @inheritdoc IHatcher
    // slither-disable-next-line reentrancy-events,calls-loop
    function applyFixToCubs(address fixer, address[] calldata cubs) external notFrozen onlyAdmin {
        LibSanitize.notZeroAddress(fixer);
        uint256 cubCount = cubs.length;
        for (uint256 idx = 0; idx < cubCount;) {
            LibSanitize.notZeroAddress(cubs[idx]);
            Cub(payable(cubs[idx])).applyFix(fixer);
            emit AppliedFix(cubs[idx], fixer);
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IHatcher
    // slither-disable-next-line reentrancy-events,calls-loop
    function applyFixesToCub(address cub, address[] calldata fixers) external notFrozen onlyAdmin {
        LibSanitize.notZeroAddress(cub);
        uint256 fixCount = fixers.length;
        for (uint256 idx = 0; idx < fixCount;) {
            LibSanitize.notZeroAddress(fixers[idx]);
            Cub(payable(cub)).applyFix(fixers[idx]);
            emit AppliedFix(cub, fixers[idx]);
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IHatcher
    function registerGlobalFix(address fixer) external notFrozen onlyAdmin {
        LibSanitize.notZeroAddress(fixer);
        $fixes.toAddressA().push(fixer);
        emit RegisteredGlobalFix(fixer, $fixes.toAddressA().length - 1);
    }

    /// @inheritdoc IHatcher
    function deleteGlobalFix(uint256 index) external notFrozen onlyAdmin {
        $fixes.toAddressA()[index] = address(0);
        emit DeletedGlobalFix(index);
    }

    /// @inheritdoc IHatcher
    function upgradeTo(address newImplementation) external notFrozen onlyAdmin {
        _setImplementation(newImplementation);
    }

    /// @inheritdoc IHatcher
    function upgradeToAndChangeInitialProgress(address newImplementation, uint256 initialProgress_)
        external
        notFrozen
        onlyAdmin
    {
        _setInitialProgress(initialProgress_);
        _setImplementation(newImplementation);
    }

    /// @inheritdoc IHatcher
    function setInitialProgress(uint256 initialProgress_) external notFrozen onlyAdmin {
        _setInitialProgress(initialProgress_);
    }

    /// @inheritdoc IHatcher
    function setCubProgress(address cub, uint256 newProgress) external notFrozen onlyAdmin {
        $fixProgresses.get()[cub.k()] = newProgress;
        emit CommittedFixes(cub, newProgress);
    }

    /// @inheritdoc IHatcher
    function pauseCubs(address[] calldata cubs) external notFrozen onlyAdminOrPauser {
        for (uint256 idx = 0; idx < cubs.length;) {
            LibSanitize.notZeroAddress(cubs[idx]);
            _pause(cubs[idx]);
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IHatcher
    function unpauseCubs(address[] calldata cubs) external notFrozen onlyAdmin {
        for (uint256 idx = 0; idx < cubs.length;) {
            LibSanitize.notZeroAddress(cubs[idx]);
            _unpause(cubs[idx]);
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IHatcher
    function globalPause() external notFrozen onlyAdminOrPauser {
        $globalPauseStatus.set(true);
        emit GlobalPause();
    }

    /// @inheritdoc IHatcher
    function globalUnpause() external notFrozen onlyAdmin {
        $globalPauseStatus.set(false);
        emit GlobalUnpause();
    }

    /// @inheritdoc IHatcher
    function freeze(uint256 freezeTimeout) external {
        _freeze(freezeTimeout);
    }

    /// @inheritdoc IHatcher
    function cancelFreeze() external {
        _cancelFreeze();
    }

    /// @dev Internal utility to set the pauser address.
    /// @param newPauser Address of the new pauser
    function _setPauser(address newPauser) internal {
        $pauser.set(newPauser);
        emit SetPauser(newPauser);
    }

    /// @dev Internal utility to change the common implementation.
    /// @dev Reverts if the new implementation is not a contract.
    /// @param newImplementation Address of the new implementation
    function _setImplementation(address newImplementation) internal {
        LibSanitize.notZeroAddress(newImplementation);
        if (newImplementation.code.length == 0) {
            revert ImplementationNotAContract(newImplementation);
        }
        $implementation.set(newImplementation);
        emit Upgraded(newImplementation);
    }

    /// @dev Internal utility to retrieve the address of the next deployed Cub.
    /// @return Address of the next cub
    // slither-disable-next-line too-many-digits
    function _nextHatch() internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", address(this), bytes32($creationSalt.get()), keccak256(type(Cub).creationCode)
                        )
                    )
                )
            )
        );
    }

    /// @dev Internal utility to create a new Cub.
    /// @dev The provided cdata is used to perform an atomic call upon contract creation.
    /// @param cdata The calldata to use for the atomic creation call
    // slither-disable-next-line reentrancy-events
    function _hatch(bytes memory cdata) internal returns (address cub) {
        uint256 salt = $creationSalt.get();
        $creationSalt.set(salt + 1);
        cub = address((new Cub){salt: bytes32(salt)}());

        uint256 currentInitialProgress = $initialProgress.get();
        if (currentInitialProgress > 0) {
            $fixProgresses.get()[cub.k()] = currentInitialProgress;
        }

        Cub(payable(cub)).___initializeCub(address(this), cdata);
        emit Hatched(cub, cdata);
    }

    /// @dev Internal utility to pause a cub.
    /// @param cub The cub to pause
    function _pause(address cub) internal {
        $pauseStatus.get()[cub.k()] = true.v();
        emit Pause(cub);
    }

    /// @dev Internal utility to unpause a cub.
    /// @param cub The cub to unpause
    function _unpause(address cub) internal {
        $pauseStatus.get()[cub.k()] = false.v();
        emit Unpause(cub);
    }

    /// @dev Internal utility to set the initial cub progress.
    /// @dev This value defines where the new cubs should start applying fixes from the global fix array.
    /// @dev This value supersedes existing cub progresses if the progress is lower than this value.
    /// @param initialProgress_ New initial progress
    function _setInitialProgress(uint256 initialProgress_) internal {
        $initialProgress.set(initialProgress_);
        emit SetInitialProgress(initialProgress_);
    }

    /// @dev Internal utility to retrieve the address of the freezer.
    /// @return Address of the freezer
    function _getFreezer() internal view override returns (address) {
        return _getAdmin();
    }
}
