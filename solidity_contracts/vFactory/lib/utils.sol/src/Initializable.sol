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

import "./types/uint256.sol";

/// @title Initializable
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice This contracts helps upgradeable contracts handle an internal
///         version value to prevent initializer replays.
abstract contract Initializable {
    using LUint256 for types.Uint256;

    /// @notice The version has been initialized.
    /// @param version The version number initialized
    /// @param cdata The calldata used for the call
    event Initialized(uint256 version, bytes cdata);

    /// @notice The init modifier has already been called on the given version number.
    /// @param version The provided version number
    /// @param currentVersion The stored version number
    error AlreadyInitialized(uint256 version, uint256 currentVersion);

    /// @dev The version number in storage.
    /// @dev Slot: keccak256(bytes("initializable.version"))) - 1
    types.Uint256 internal constant $version =
        types.Uint256.wrap(0xc4c7f1ccb588f39a9aa57be6cfd798d73912e27b44cfa18e1a5eba7b34e81a76);

    /// @dev The modifier to use on initializers.
    /// @dev Do not provide _version dynamically, make sure the value is hard-coded each
    ///      time the modifier is used.
    /// @param _version The version to initialize
    // slither-disable-next-line incorrect-modifier
    modifier init(uint256 _version) {
        if (_version == $version.get()) {
            $version.set(_version + 1);
            emit Initialized(_version, msg.data);
            _;
        } else {
            revert AlreadyInitialized(_version, $version.get());
        }
    }
}
