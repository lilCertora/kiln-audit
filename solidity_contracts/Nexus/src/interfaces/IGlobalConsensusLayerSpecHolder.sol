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
pragma solidity 0.8.17;

import "../ctypes/consensus_layer_spec_struct.sol";

/// @title Global Consensus Layer Spec Holder Interface
/// @author mortimr @ Kiln
/// @notice Contract holding and exposing a global consensus layer spec object
/// @notice This object contains all the shared consensus layer spec parameters, that are considered true for all the network
interface IGlobalConsensusLayerSpecHolder {
    /// @notice Emitted when the global consensus layer spec is updated
    /// @param genesisTimestamp The new consensus layer genesis timestamp (slot 0 timestamp)
    /// @param epochsUntilFinal The new count of epochs before one is considered final. This is a safeguard but we cannot have a 100% guarantee that the epoch is indeed final, it will just increase the probability
    /// @param slotsPerEpoch The count of slots inside one epoch
    /// @param secondsPerSlot The number of seconds inside a slot
    event SetGlobalConsensusLayerSpec(uint64 genesisTimestamp, uint64 epochsUntilFinal, uint64 slotsPerEpoch, uint64 secondsPerSlot);

    /// @notice Retrieve the global consensus layer spec structure
    /// @return The global consensus layer spec structure
    function globalConsensusLayerSpec() external view returns (ctypes.ConsensusLayerSpec memory);

    /// @notice Set the global consensus layer spec
    /// @param genesisTimestamp The timestamp of the genesis slot (slot #0)
    /// @param epochsUntilFinal The count of epochs before an epoch can be considered final
    /// @param slotsPerEpoch The count of slots inside one epoch
    /// @param secondsPerSlot The number of seconds inside a slot
    function setGlobalConsensusLayerSpec(uint64 genesisTimestamp, uint64 epochsUntilFinal, uint64 slotsPerEpoch, uint64 secondsPerSlot)
        external;
}
