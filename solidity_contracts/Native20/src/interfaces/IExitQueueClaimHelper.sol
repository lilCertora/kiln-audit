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

import "vsuite/interfaces/IvExitQueue.sol";

/// @title ExitQueueClaimeHelper (V1) Interface
/// @author gauthiermyr @ Kiln
interface IExitQueueClaimHelper {
    /// @notice Resolve a list of casksIds for given exitQueues and tickets
    /// @param exitQueues List of exit queues
    /// @param ticketIds List of tickets in each exit queue
    function multiResolve(address[] calldata exitQueues, uint256[][] calldata ticketIds)
        external
        view
        returns (int64[][] memory caskIdsOrErrors);

    /// @notice Claim caskIds for given tickets on each exit queue
    /// @param exitQueues List of exit queues
    /// @param ticketIds List of tickets in each exit queue
    /// @param casksIds List of caskIds to claim with each ticket
    function multiClaim(address[] calldata exitQueues, uint256[][] calldata ticketIds, uint32[][] calldata casksIds)
        external
        returns (IvExitQueue.ClaimStatus[][] memory statuse);
}
