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

/// @title Implementation
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice This contracts must be used on all implementation contracts. It ensures that the initializers are only callable through the proxy.
///         This will brick the implementation and make it unusable directly without using delegatecalls.
abstract contract Implementation {
    using LUint256 for types.Uint256;

    /// @dev The version number in storage in the initializable contract.
    /// @dev Slot: keccak256(bytes("initializable.version"))) - 1
    types.Uint256 internal constant $initializableVersion =
        types.Uint256.wrap(0xc4c7f1ccb588f39a9aa57be6cfd798d73912e27b44cfa18e1a5eba7b34e81a76);

    constructor() {
        $initializableVersion.set(type(uint256).max);
    }
}
