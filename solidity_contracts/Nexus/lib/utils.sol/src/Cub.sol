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

import "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";
import "./interfaces/IFixer.sol";
import "./interfaces/IHatcher.sol";
import "./interfaces/ICub.sol";

/// @title Cub
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The cub is controlled by a Hatcher in charge of providing its status details and implementation address.
contract Cub is Proxy, ERC1967Upgrade, ICub {
    /// @notice Initializer to not rely on the constructor.
    /// @param beacon The address of the beacon to pull its info from
    /// @param data The calldata to add to the initial call, if any
    // slither-disable-next-line naming-convention
    function ___initializeCub(address beacon, bytes memory data) external {
        if (_getBeacon() != address(0)) {
            revert CubAlreadyInitialized();
        }
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    /// @dev Internal utility to retrieve the implementation from the beacon.
    /// @return The implementation address
    // slither-disable-next-line dead-code
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /// @dev Prevents unauthorized calls.
    /// @dev This will make the method transparent, forcing unauthorized callers into the fallback.
    modifier onlyBeacon() {
        if (msg.sender != _getBeacon()) {
            _fallback();
        } else {
            _;
        }
    }

    /// @dev Prevents unauthorized calls.
    /// @dev This will make the method transparent, forcing unauthorized callers into the fallback.
    modifier onlyMe() {
        if (msg.sender != address(this)) {
            _fallback();
        } else {
            _;
        }
    }

    /// @inheritdoc ICub
    // slither-disable-next-line reentrancy-events
    function appliedFixes(address[] memory fixers) public onlyMe {
        emit AppliedFixes(fixers);
    }

    /// @inheritdoc ICub
    function applyFix(address fixer) external onlyBeacon {
        _applyFix(fixer);
    }

    /// @dev Retrieve the list of fixes for this cub from the hatcher.
    /// @param beacon Address of the hatcher acting as a beacon
    /// @return List of fixes to apply
    function _fixes(address beacon) internal view returns (address[] memory) {
        return IHatcher(beacon).fixes(address(this));
    }

    /// @dev Retrieve the status for this cub from the hatcher.
    /// @param beacon Address of the hatcher acting as a beacon
    /// @return First value is true if fixes are pending, second value is true if cub is paused
    function _status(address beacon) internal view returns (address, bool, bool) {
        return IHatcher(beacon).status(address(this));
    }

    /// @dev Commits fixes to the hatcher.
    /// @param beacon Address of the hatcher acting as a beacon
    function _commit(address beacon) internal {
        IHatcher(beacon).commitFixes();
    }

    /// @dev Fetches the current cub status and acts accordingly.
    /// @param beacon Address of the hatcher acting as a beacon
    function _fix(address beacon) internal returns (address) {
        (address implementation, bool hasFixes, bool isPaused) = _status(beacon);
        if (isPaused && msg.sender != address(0)) {
            revert CalledWhenPaused(msg.sender);
        }
        if (hasFixes) {
            bool isStaticCall = false;
            address[] memory fixes = _fixes(beacon);
            // This is a trick to check if the current execution context
            // allows state modifications
            try this.appliedFixes(fixes) {}
            catch {
                isStaticCall = true;
            }
            // if we properly emitted AppliedFixes, we are not in a view or pure call
            // we can then apply fixes
            if (!isStaticCall) {
                for (uint256 idx = 0; idx < fixes.length;) {
                    if (fixes[idx] != address(0)) {
                        _applyFix(fixes[idx]);
                    }

                    unchecked {
                        ++idx;
                    }
                }
                _commit(beacon);
            }
        }
        return implementation;
    }

    /// @dev Applies the given fix, and reverts in case of error.
    /// @param fixer Address that implements the fix
    // slither-disable-next-line controlled-delegatecall,delegatecall-loop,low-level-calls
    function _applyFix(address fixer) internal {
        (bool success, bytes memory rdata) = fixer.delegatecall(abi.encodeCall(IFixer.fix, ()));
        if (!success) {
            revert FixDelegateCallError(fixer, rdata);
        }
        (success) = abi.decode(rdata, (bool));
        if (!success) {
            revert FixCallError(fixer);
        }
    }

    /// @dev Fallback method that ends up forwarding calls as delegatecalls to the implementation.
    function _fallback() internal override(Proxy) {
        _beforeFallback();
        address beacon = _getBeacon();
        address implementation = _fix(beacon);
        _delegate(implementation);
    }
}
