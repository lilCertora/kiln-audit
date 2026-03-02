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

import "utils.sol/libs/LibErrors.sol";
import "utils.sol/libs/LibUint256.sol";
import "utils.sol/libs/LibConstant.sol";
import "./interfaces/IExitQueueClaimHelper.sol";
import "./interfaces/IFeeDispatcher.sol";

/// @title ExitQueueClaimeHelper (V1) Contract
/// @author gauthiermyr @ Kiln
/// @notice This contract contains functions to resolve and claim casks on several exit queues.
contract ExitQueueClaimHelper is IExitQueueClaimHelper {
    /// @inheritdoc IExitQueueClaimHelper
    function multiResolve(address[] calldata exitQueues, uint256[][] calldata ticketIds)
        external
        view
        override
        returns (int64[][] memory caskIdsOrErrors)
    {
        if (exitQueues.length != ticketIds.length) {
            revert IFeeDispatcher.UnequalLengths(exitQueues.length, ticketIds.length);
        }

        caskIdsOrErrors = new int64[][](exitQueues.length);

        for (uint256 i = 0; i < exitQueues.length;) {
            IvExitQueue exitQueue = IvExitQueue(exitQueues[i]);
            // slither-disable-next-line calls-loop
            caskIdsOrErrors[i] = exitQueue.resolve(ticketIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IExitQueueClaimHelper
    function multiClaim(address[] calldata exitQueues, uint256[][] calldata ticketIds, uint32[][] calldata casksIds)
        external
        override
        returns (IvExitQueue.ClaimStatus[][] memory statuses)
    {
        if (exitQueues.length != ticketIds.length) {
            revert IFeeDispatcher.UnequalLengths(exitQueues.length, ticketIds.length);
        }
        if (exitQueues.length != casksIds.length) {
            revert IFeeDispatcher.UnequalLengths(exitQueues.length, casksIds.length);
        }

        statuses = new IvExitQueue.ClaimStatus[][](exitQueues.length);

        for (uint256 i = 0; i < exitQueues.length;) {
            IvExitQueue exitQueue = IvExitQueue(exitQueues[i]);
            // slither-disable-next-line calls-loop
            statuses[i] = exitQueue.claim(ticketIds[i], casksIds[i], type(uint16).max);

            unchecked {
                ++i;
            }
        }
    }
}
