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

import "./ctypes.sol";

/// @title Consensus Layer Spec Struct Custom Type
library LConsensusLayerSpecStruct {
    // slither-disable-next-line dead-code
    function get(ctypes.ConsensusLayerSpecStruct position) internal pure returns (ctypes.ConsensusLayerSpec storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }
}
