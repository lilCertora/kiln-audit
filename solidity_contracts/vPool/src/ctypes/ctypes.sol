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

import "utils.sol/libs/LibPublicKey.sol";
import "utils.sol/libs/LibSignature.sol";

/// @title Custom Types
// slither-disable-next-line naming-convention
library ctypes {
    /// @notice Structure representing a validator in the factory
    /// @param publicKey The public key of the validator
    /// @param signature The signature used for the deposit
    /// @param feeRecipient The address receiving the exec layer fees
    struct Validator {
        LibPublicKey.PublicKey publicKey;
        LibSignature.Signature signature;
        address feeRecipient;
    }

    /// @notice Structure representing a withdrawal channel in the factory
    /// @param validators The validators in the channel
    /// @param lastEdit The last time the channel was edited (in blocks)
    /// @param limit The staking limit of the channel. Always <= validators.length
    /// @param funded The amount of funded validators in the channel
    struct WithdrawalChannel {
        Validator[] validators;
        uint256 lastEdit;
        uint32 limit;
        uint32 funded;
    }

    /// @notice Structure representing a deposit in the factory
    /// @param index The index of the deposit in the withdrawal channel
    /// @param withdrawalChannel The withdrawal channel of the validator
    /// @param owner The owner of the deposited validator
    struct Deposit {
        uint256 index;
        bytes32 withdrawalChannel;
        address owner;
    }

    /// @notice Structure representing the operator metadata in the factory
    /// @param name The name of the operator
    /// @param url The url of the operator
    /// @param iconUrl The icon url of the operator
    struct Metadata {
        string name;
        string url;
        string iconUrl;
    }

    /// @notice Structure representing the global consensus layer spec held in the global consensus layer spec holder
    /// @param genesisTimestamp The timestamp of the genesis of the consensus layer (slot 0 timestamp)
    /// @param epochsUntilFinal The number of epochs until a block is considered final by the vsuite
    /// @param slotsPerEpoch The number of slots per epoch (32 on mainnet)
    /// @param secondsPerSlot The number of seconds per slot (12 on mainnet)
    struct ConsensusLayerSpec {
        uint64 genesisTimestamp;
        uint64 epochsUntilFinal;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
    }

    /// @notice Structure representing the report bounds held in the pools
    /// @param maxAPRUpperBound The maximum APR upper bound, representing the maximum increase in underlying balance checked at each oracle report
    /// @param maxAPRUpperCoverageBoost The maximum APR upper coverage boost, representing the additional increase allowed when pulling coverage funds
    /// @param maxRelativeLowerBound The maximum relative lower bound, representing the maximum decrease in underlying balance checked at each oracle report
    struct ReportBounds {
        uint64 maxAPRUpperBound;
        uint64 maxAPRUpperCoverageBoost;
        uint64 maxRelativeLowerBound;
    }

    /// @notice Structure representing the consensus layer report submitted by oracle members
    /// @param balanceSum sum of all the balances of all validators that have been activated by the vPool
    ///        this means that as long as the validator was activated, no matter its current status, its balance is taken
    ///        into account
    /// @param exitedSum sum of all the ether that has been exited by the validators that have been activated by the vPool
    ///        to compute this value, we look for withdrawal events inside the block bodies that have happened at an epoch
    ///        that is greater or equal to the withdrawable epoch of a validator purchased by the pool
    ///        when we detect any, we take min(amount,32 eth) into account as exited balance
    /// @param skimmedSum sum of all the ether that has been skimmed by the validators that have been activated by the vPool
    ///        similar to the exitedSum, we look for withdrawal events. If the epochs is lower than the withdrawable epoch
    ///        we take into account the full withdrawal amount, otherwise we take amount - min(amount, 32 eth) into account
    /// @param slashedSum sum of all the ether that has been slashed by the validators that have been activated by the vPool
    ///        to compute this value, we look for validators that are of have been in the slashed state
    ///        then we take the balance of the validator at the epoch prior to its slashing event
    ///        we then add the delta between this old balance and the current balance (or balance just before withdrawal)
    /// @param exiting amount of currently exiting eth, that will soon hit the withdrawal recipient
    ///        this value is computed by taking the balance of any validator in the exit or slashed state or after
    /// @param maxExitable maximum amount that can get requested for exits during report processing
    ///        this value is determined by the oracle. its calculation logic can be updated but all members need to agree and reach
    ///        consensus on the new calculation logic. Its role is to control the rate at which exit requests are performed
    /// @param maxCommittable maximum amount that can get committed for deposits during report processing
    ///        positive value means commit happens before possible exit boosts, negative after
    ///        similar to the mexExitable, this value is determined by the oracle. its calculation logic can be updated but all
    ///        members need to agree and reach consensus on the new calculation logic. Its role is to control the rate at which
    ///        deposit are made. Committed funds are funds that are always a multiple of 32 eth and that cannot be used for
    ///        anything else than purchasing validator, as opposed to the deposited funds that can still be used to fuel the
    ///        exit queue in some cases.
    ///  @param epoch epoch at which the report was crafter
    ///  @param activatedCount current count of validators that have been activated by the vPool
    ///         no matter the current state of the validator, if it has been activated, it has to be accounted inside this value
    ///  @param stoppedCount current count of validators that have been stopped (being in the exit queue, exited or slashed)
    struct ValidatorsReport {
        uint128 balanceSum;
        uint128 exitedSum;
        uint128 skimmedSum;
        uint128 slashedSum;
        uint128 exiting;
        uint128 maxExitable;
        int256 maxCommittable;
        uint64 epoch;
        uint32 activatedCount;
        uint32 stoppedCount;
    }

    /// @notice Structure representing the ethers held in the pools
    /// @param deposited The amount of deposited ethers, that can either be used to boost exits or get committed
    /// @param committed The amount of committed ethers, that can only be used to purchase validators
    struct Ethers {
        uint128 deposited;
        uint128 committed;
    }

    /// @notice Structure representing a ticket in the exit queue
    /// @param position The position of the ticket in the exit queue (equal to the position + size of the previous ticket)
    /// @param size The size of the ticket in the exit queue (in pool shares)
    /// @param maxExitable The maximum amount of ethers that can be exited by the ticket owner (no more rewards in the exit queue, losses are still mutualized)
    struct Ticket {
        uint128 position;
        uint128 size;
        uint128 maxExitable;
    }

    /// @notice Structure representing a cask in the exit queue. This entity is created by the pool upon oracle reports, when exit liquidity is available to feed the exit queue
    /// @param position The position of the cask in the exit queue (equal to the position + size of the previous cask)
    /// @param size The size of the cask in the exit queue (in pool shares)
    /// @param value The value of the cask in the exit queue (in ethers)
    struct Cask {
        uint128 position;
        uint128 size;
        uint128 value;
    }

    type DepositMapping is bytes32;
    type WithdrawalChannelMapping is bytes32;
    type BalanceMapping is bytes32;
    type MetadataStruct is bytes32;
    type ConsensusLayerSpecStruct is bytes32;
    type ReportBoundsStruct is bytes32;
    type ApprovalsMapping is bytes32;
    type ValidatorsReportStruct is bytes32;
    type EthersStruct is bytes32;
    type TicketArray is bytes32;
    type CaskArray is bytes32;
    type FactoryDepositorMapping is bytes32;
}
