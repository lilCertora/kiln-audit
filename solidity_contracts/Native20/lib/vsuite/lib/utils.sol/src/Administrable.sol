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

import "./libs/LibSanitize.sol";
import "./types/address.sol";
import "./interfaces/IAdministrable.sol";

/// @title Administrable
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice This contract provides all the utilities to handle the administration and its transfer.
abstract contract Administrable is IAdministrable {
    using LAddress for types.Address;

    /// @dev The admin address in storage.
    /// @dev Slot: keccak256(bytes("administrable.admin")) - 1
    types.Address internal constant $admin =
        types.Address.wrap(0x927a17e5ea75d9461748062a2652f4d3698a628896c9832f8488fa0d2846af09);
    /// @dev The pending admin address in storage.
    /// @dev Slot: keccak256(bytes("administrable.pendingAdmin")) - 1
    types.Address internal constant $pendingAdmin =
        types.Address.wrap(0x3c1eebcc225c6cc7f5f8765767af6eff617b4139dc3624923a2db67dbca7b68e);

    /// @dev This modifier ensures that only the admin is able to call the method.
    modifier onlyAdmin() {
        if (msg.sender != _getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender, _getAdmin());
        }
        _;
    }

    /// @dev This modifier ensures that only the pending admin is able to call the method.
    modifier onlyPendingAdmin() {
        if (msg.sender != _getPendingAdmin()) {
            revert LibErrors.Unauthorized(msg.sender, _getPendingAdmin());
        }
        _;
    }

    /// @inheritdoc IAdministrable
    function admin() external view returns (address) {
        return _getAdmin();
    }

    /// @inheritdoc IAdministrable
    function pendingAdmin() external view returns (address) {
        return _getPendingAdmin();
    }

    /// @notice Propose a new admin.
    /// @dev Only callable by the admin.
    /// @param newAdmin The new admin to propose
    function transferAdmin(address newAdmin) external onlyAdmin {
        _setPendingAdmin(newAdmin);
    }

    /// @notice Accept an admin transfer.
    /// @dev Only callable by the pending admin.
    function acceptAdmin() external onlyPendingAdmin {
        _setAdmin(msg.sender);
        _setPendingAdmin(address(0));
    }

    /// @dev Retrieve the admin address.
    /// @return The admin address
    function _getAdmin() internal view returns (address) {
        return $admin.get();
    }

    /// @dev Change the admin address.
    /// @param newAdmin The new admin address
    function _setAdmin(address newAdmin) internal {
        LibSanitize.notZeroAddress(newAdmin);
        emit SetAdmin(newAdmin);
        $admin.set(newAdmin);
    }

    /// @dev Retrieve the pending admin address.
    /// @return The pending admin address
    function _getPendingAdmin() internal view returns (address) {
        return $pendingAdmin.get();
    }

    /// @dev Change the pending admin address.
    /// @param newPendingAdmin The new pending admin address
    function _setPendingAdmin(address newPendingAdmin) internal {
        emit SetPendingAdmin(newPendingAdmin);
        $pendingAdmin.set(newPendingAdmin);
    }
}
