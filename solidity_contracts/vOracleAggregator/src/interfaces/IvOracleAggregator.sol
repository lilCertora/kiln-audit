// SPDX-License-Identifier: MIT
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

import "utils.sol/interfaces/IFixable.sol";

import "../ctypes/ctypes.sol";

/// @title Oracle Aggregator Interface
/// @author mortimr @ Kiln
/// @notice The Oracle Aggregator gathers report calldata and forwards it to the associated vPool when a quorum is met
interface IvOracleAggregator is IFixable {
    /// @notice The provided address is already a member
    /// @param member The address already a member
    error AlreadyOracleAggregatorMember(address member);

    /// @notice The provided address is not a member
    /// @param member The address already a member
    error UnknownOracleAggregatorMember(address member);

    /// @notice The provided members array was empty
    error EmptyMembersArray();

    /// @notice The maximum count of members was reached
    error TooManyMembers();

    /// @notice The Oracle Aggregator is not ready for forwarding reports
    error OracleNotReady();

    /// @notice The reported epoch is too old
    /// @param epoch The reported epoch
    /// @param highestReportedEpoch The highest reported epoch
    error EpochTooOld(uint256 epoch, uint256 highestReportedEpoch);

    /// @notice The reported epoch is invalid
    /// @param epoch The reported epoch
    error EpochInvalid(uint256 epoch);

    /// @notice The oracle member already reported for epoch
    /// @param member The oracle member address
    /// @param epoch The epoch of the report
    error AlreadyReported(address member, uint256 epoch);

    /// @notice The global member ejection status is already set to the provided value
    error StatusNotChanged();

    /// @notice Emitted when the stored Factory address is changed
    /// @param factory The new factory address
    event SetFactory(address factory);

    /// @notice Emitted when the stored Nexus address is changed
    /// @param nexus The new nexus address
    event SetNexus(address nexus);

    /// @notice Emitted when the stored Pool address is changed
    /// @param pool The new pool address
    event SetPool(address pool);

    /// @notice Emitted when the stored highest reported epoch is changed
    /// @param epoch The new highest reported epoch value
    event SetHighestReportedEpoch(uint256 epoch);

    /// @notice Emitted when a regular member voted on a report
    /// @param member The address of the member
    /// @param variant The variant of the report
    /// @param report The report data structure
    event MemberVoted(address indexed member, bytes32 indexed variant, ctypes.ValidatorsReport report);

    /// @notice Emitted when the global member voted on a report
    /// @param globalMember The address of the global member
    /// @param variant The variant of the report
    /// @param report The report data structure
    event GlobalMemberVoted(address indexed globalMember, bytes32 indexed variant, ctypes.ValidatorsReport report);

    /// @notice Emitted when a new member was added to the oracle
    /// @param member Address of the new member
    event AddedOracleAggregatorMember(address member);

    /// @notice Emitted when a member was removed from the oracle
    /// @param member Address of the removed member
    event RemovedOracleAggregatorMember(address member);

    /// @notice Emitted when the reporting data is cleared
    event ReportingCleared();

    /// @notice Emitted when the global member ejection status is changed
    /// @param status The new status
    event SetGlobalMemberEjectionStatus(bool status);

    /// @notice Emitted when a report is submitted to the vPool
    /// @param report The report data structure
    /// @param variant The variant of the report
    /// @param votes The number of votes for the report
    /// @param variantCount The number of variants that existed upon submission
    event SubmittedReport(ctypes.ValidatorsReport report, bytes32 variant, uint256 votes, uint256 variantCount);

    /// @param vpool_ The associated vPool
    /// @param vfactory_ The associated vFactory
    /// @param nexus_ The associated nexus
    function initialize(address vpool_, address vfactory_, address nexus_) external;

    /// @notice Retrieve the associated vPool
    /// @return The address of the vPool
    function pool() external view returns (address);

    /// @notice Retrieve the associated vFactory
    /// @return The address of the vFactory
    function factory() external view returns (address);

    /// @notice Retrieve the associated Nexus
    /// @return The address of the Nexus
    function nexus() external view returns (address);

    /// @notice Retrieve the oracle member list
    /// @return The list of oracle member addresses
    function members() external view returns (address[] memory);

    /// @notice Retrieve the global oracle member
    /// @return The global member address
    function globalMember() external view returns (address);

    /// @notice Retrieve the current required quorum
    /// @return The current quorum value
    function quorum() external view returns (uint256);

    /// @notice Retrieve the ready status of the Oracle
    /// @return  True if ready
    function ready() external view returns (bool);

    /// @notice Retrieve the global member ejection status.
    ///         When active AND member count >= 5, the global member is not allowed to vote and quorum is adapted accordingly.
    ///         Both conditions should be met, and even if the mode is active, if the member count is <= 4 then the global
    ///         oracle member can still vote. This ensures that the global member can participate in quorum bootstrapping,
    ///         ensuring node operators are not reporting alone initially. And it gives the opportunity to the node operator
    ///         to eject the global member is the member list grows enough.
    function globalMemberEjected() external view returns (bool);

    /// @notice Retrieve the reporting details
    /// @return reportVariants Current list of report variants
    /// @return reportVoteCount Current list of vote counts
    /// @return reportVoteTracker Tracker of the member votes
    function reportingDetails()
        external
        view
        returns (bytes32[] memory reportVariants, uint256[] memory reportVoteCount, uint256 reportVoteTracker);

    /// @notice Retrieve the highest valid reported epoch
    /// @return The current value of the highest valid reported epoch
    function highestReportedEpoch() external view returns (uint256);

    /// @notice Add an address as an oracle member
    /// @param member Address of the new member
    function addMember(address member) external;

    /// @notice Removes an address from the address list
    /// @param member Address of the member to remove
    function removeMember(address member) external;

    /// @notice Sets the global member ejection status
    /// @param status True if active
    function setGlobalMemberEjectionStatus(bool status) external;

    /// @notice Submit a report and forwards it to the vPool if quorum is met
    /// @param report The consensus layer report data structure
    function submitReport(ctypes.ValidatorsReport calldata report) external;
}
