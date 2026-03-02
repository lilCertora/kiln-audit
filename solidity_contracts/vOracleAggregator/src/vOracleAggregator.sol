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

import "utils.sol/Fixable.sol";
import "utils.sol/Initializable.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/libs/LibSanitize.sol";
import "utils.sol/types/address.sol";
import "utils.sol/types/bool.sol";
import "utils.sol/types/array.sol";
import "utils.sol/types/mapping.sol";

import "./interfaces/IvFactory.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IGlobalOracleHolder.sol";
import "./interfaces/IvOracleAggregator.sol";

/// @title Oracle Aggregator
/// @author mortimr @ Kiln
/// @notice The Oracle Aggregator gathers report calldata and forwards it to the associated vPool when a quorum is met
// slither-disable-next-line naming-convention
contract vOracleAggregator is Fixable, Initializable, Implementation, IvOracleAggregator {
    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LArray for types.Array;
    using LMapping for types.Mapping;
    using LBool for types.Bool;

    using CAddress for address;

    /// @dev Address of the associated vPool.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.pool")) - 1
    types.Address internal constant $pool = types.Address.wrap(0x761a2737c615ddb448a10d603cd26da974d493bf38c8792c10a5e43973fe4768);

    /// @dev Address of the associated vFactory.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.factory")) - 1
    types.Address internal constant $factory = types.Address.wrap(0x7d1c699613eafe8002b954568205c96523d9cab35878f60d2edab15c3dd18bf5);

    /// @dev Address of the associated Nexus.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.nexus")) - 1
    types.Address internal constant $nexus = types.Address.wrap(0x1650ea57310cc5b26ccfd9fea7f370399e3a3515bb35473fe4db358a435f1730);

    /// @dev Address of the associated Nexus.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.globalMemberEjectionStatus")) - 1
    types.Bool internal constant $globalMemberEjectionStatus =
        types.Bool.wrap(0xb437f7f8cf93c2437115db97775dfaa20557b0a78f002bfb26d1b270e4d4f8ea);

    /// @dev Vote tracker, each bit represents a member and is active after a vote.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.reportVoteTracker")) - 1
    types.Uint256 internal constant $reportVoteTracker =
        types.Uint256.wrap(0xb01eff9fee409011ae0ef0ea2ce1d6b3eac5d022db279fb24f1a04ec56fe933a);

    /// @dev The highest reported valid epoch.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.highestReportedEpoch")) - 1
    types.Uint256 internal constant $highestReportedEpoch =
        types.Uint256.wrap(0x83fd25bb4b2da2d41f145a5d44e3d0e9775a10e0290c6a7fbedf6052661f6d2f);

    /// @dev List of members allowed to submit reports.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.members")) - 1
    types.Array internal constant $members = types.Array.wrap(0x5b2e28b4804472ea289fe5335225fbc1a7730e816c34b49b72b9a25b9a884eb9);

    /// @dev Array of report variants.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.reportVariants")) - 1
    types.Array internal constant $reportVariants = types.Array.wrap(0x1debef104eed5524504dbe1be48b03db02ac2837be1c1840a28fa6f2c66f4153);

    /// @dev Array of report variants vote counts.
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.reportVoteCounts")) - 1
    types.Array internal constant $reportVoteCounts = types.Array.wrap(0xb3315062743ea24558e0a5ddf16a93cf03ff59ae2c1e25d2e696690b9ba0307d);

    /// @dev Mapping holding all the oracle members.
    /// @dev Type: mapping(address => uint256)
    /// @dev Slot: keccak256(bytes("oracleAggregator.1.memberRegistry")) - 1
    types.Mapping internal constant $memberRegistry = types.Mapping.wrap(0x18db11abf27c4431eb0f9c02477c1304511fbe94996e1a5eb80bdc8fc7d02a02);

    /// @inheritdoc IvOracleAggregator
    // slither-disable-next-line missing-zero-check
    function initialize(address vpool_, address vfactory_, address nexus_) external init(0) {
        LibSanitize.notZeroAddress(vpool_);
        LibSanitize.notZeroAddress(vfactory_);
        LibSanitize.notZeroAddress(nexus_);

        $pool.set(vpool_);
        $factory.set(vfactory_);
        $nexus.set(nexus_);
        emit SetPool(vpool_);
        emit SetFactory(vfactory_);
        emit SetNexus(nexus_);
    }

    /// @notice Only allows the admin to perform the call
    modifier onlyAdmin() {
        address admin = IvFactory($factory.get()).admin();
        if (msg.sender != admin) {
            revert LibErrors.Unauthorized(msg.sender, admin);
        }
        _;
    }

    /// @notice Only allows an oracle member to perform the call
    modifier onlyOracleMember() {
        if ($memberRegistry.get()[msg.sender.k()] == 0) {
            address globalOracleMember = _globalOracleMember();
            if (msg.sender != globalOracleMember) {
                revert LibErrors.Unauthorized(msg.sender, address(0));
            }
        }
        _;
    }

    /// @notice Only allows the call if the system is ready
    modifier oracleReady() {
        if (!_ready()) {
            revert OracleNotReady();
        }
        _;
    }

    /// @inheritdoc IvOracleAggregator
    function pool() external view returns (address) {
        return $pool.get();
    }

    /// @inheritdoc IvOracleAggregator
    function factory() external view returns (address) {
        return $factory.get();
    }

    /// @inheritdoc IvOracleAggregator
    function nexus() external view returns (address) {
        return $nexus.get();
    }

    /// @inheritdoc IvOracleAggregator
    /// @dev This method is not pure as it reads from storage
    function members() external pure returns (address[] memory) {
        return $members.toAddressA();
    }

    /// @inheritdoc IvOracleAggregator
    function globalMember() external view returns (address) {
        return _globalOracleMember();
    }

    /// @inheritdoc IvOracleAggregator
    function quorum() external view returns (uint256) {
        return _quorum();
    }

    /// @inheritdoc IvOracleAggregator
    function ready() external view returns (bool) {
        return _ready();
    }

    /// @inheritdoc IvOracleAggregator
    function globalMemberEjected() external view returns (bool) {
        return $globalMemberEjectionStatus.get();
    }

    /// @inheritdoc IvOracleAggregator
    function reportingDetails()
        external
        view
        returns (bytes32[] memory reportVariants, uint256[] memory reportVoteCount, uint256 reportVoteTracker)
    {
        return ($reportVariants.toBytes32A(), $reportVoteCounts.toUintA(), $reportVoteTracker.get());
    }

    /// @inheritdoc IvOracleAggregator
    function highestReportedEpoch() external view returns (uint256) {
        return $highestReportedEpoch.get();
    }

    /// @inheritdoc IvOracleAggregator
    function addMember(address member) external onlyAdmin {
        LibSanitize.notZeroAddress(member);
        if ($memberRegistry.get()[member.k()] != 0) {
            revert AlreadyOracleAggregatorMember(member);
        }
        uint256 membersCount = $members.toAddressA().length;
        if (membersCount == 255) {
            revert TooManyMembers();
        }
        $members.toAddressA().push(member);
        $memberRegistry.get()[member.k()] = membersCount + 1;
        emit AddedOracleAggregatorMember(member);
        _clear();
    }

    /// @inheritdoc IvOracleAggregator
    function removeMember(address member) external onlyAdmin {
        LibSanitize.notZeroAddress(member);
        uint256 memberIndex = $memberRegistry.get()[member.k()];
        if (memberIndex == 0) {
            revert UnknownOracleAggregatorMember(member);
        }
        unchecked {
            --memberIndex;
        }
        uint256 lastIndex = $members.toAddressA().length - 1;

        if (memberIndex != lastIndex) {
            address lastMemberAddress = $members.toAddressA()[lastIndex];
            $members.toAddressA()[memberIndex] = lastMemberAddress;
            $memberRegistry.get()[lastMemberAddress.k()] = memberIndex + 1;
        }
        $members.toAddressA().pop();
        delete $memberRegistry.get()[member.k()];
        emit RemovedOracleAggregatorMember(member);
        _clear();
    }

    /// @inheritdoc IvOracleAggregator
    function setGlobalMemberEjectionStatus(bool status) external onlyAdmin {
        if ($globalMemberEjectionStatus.get() == status) {
            revert StatusNotChanged();
        }
        $globalMemberEjectionStatus.set(status);
        emit SetGlobalMemberEjectionStatus(status);
    }

    /// @inheritdoc IvOracleAggregator
    function submitReport(ctypes.ValidatorsReport calldata report) external oracleReady onlyOracleMember {
        uint256 currentHighestReportedEpoch = $highestReportedEpoch.get();
        if (report.epoch < currentHighestReportedEpoch) {
            revert EpochTooOld(report.epoch, currentHighestReportedEpoch);
        }
        IvPool _pool = IvPool($pool.get());
        _pool.onlyValidEpoch(report.epoch);
        if (report.epoch > currentHighestReportedEpoch) {
            // if epoch is higher than highest and valid, we clear the reporting data of possibly old epochs and we update the expectedEpoch
            _clear();
            _setHighestReportedEpoch(report.epoch);
        }

        // if member of the registry, we get index + 1 on the array
        // otherwise we get 0.
        // due to the onlyOracleMember modifier, we can only be a member or the global member
        // if we're the global member, the index will be 0, otherwise it will be 1+
        uint256 memberIdx = $memberRegistry.get()[msg.sender.k()];
        if (memberIdx == 0 && $members.toAddressA().length >= 5 && $globalMemberEjectionStatus.get()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }

        bool isMember = memberIdx > 0;
        bool isGlobalMember = msg.sender == _globalOracleMember();

        if (_hasReported(memberIdx)) {
            revert AlreadyReported(msg.sender, report.epoch);
        }
        // member reports are registered
        _registerReport(memberIdx, isGlobalMember);

        // we retrieve the hash based on the calldata
        // inconvenient as it requires some additional data gathering off-chain to decode the calldata
        // convenient because it allows the report data format to be upgraded if needed
        bytes32 reportHash = _reportHash(report);

        int256 variantIdx = _variantIndex(reportHash);
        uint256 variantVotes;
        uint256[] storage reportVoteCounts = $reportVoteCounts.toUintA();
        bytes32[] storage reportVariants = $reportVariants.toBytes32A();
        uint256 voteCount = (isMember ? 1 : 0) + (isGlobalMember ? 1 : 0);
        if (variantIdx == -1) {
            // if the proposed variant is not found, we add it and set the vote count to 1 (or 2 if isMember && member == globalMember)
            reportVariants.push(reportHash);
            reportVoteCounts.push(voteCount);
            variantVotes = voteCount;
        } else {
            // otherwise we simply increment the vote count
            variantVotes = (reportVoteCounts[uint256(variantIdx)] += voteCount);
        }

        // both of these conditions can happen at the same time
        if (isMember) {
            emit MemberVoted(msg.sender, reportHash, report);
        }

        if (isGlobalMember) {
            emit GlobalMemberVoted(msg.sender, reportHash, report);
        }

        // we retrieve the quorum
        uint256 qrm = _quorum();
        if (variantVotes >= qrm) {
            // quorum is met ! we can push to vPool, after clearing the report
            emit SubmittedReport(report, reportHash, variantVotes, reportVariants.length);
            _clear();
            _pool.report(report);
        }
    }

    /// @dev Internal utility to retrieve the global oracle member
    /// @return The global oracle member from the nexus
    function _globalOracleMember() internal view returns (address) {
        return IGlobalOracleHolder($nexus.get()).globalOracle();
    }

    /// @dev Internal utility to compute the quorum based on the member count.
    ///      The total member count is computed from the members array + the global member.
    /// @return The quorum
    function _quorum() internal view returns (uint256) {
        uint256 memberCount = $members.toAddressA().length;
        // unless we have 5+ members AND the global member ejection status is true, we account for the global oracle member
        if (memberCount < 5 || !$globalMemberEjectionStatus.get()) {
            ++memberCount;
        }
        // quorum = (memberCount * 75%) + 1
        return ((memberCount * 3) >> 2) + 1;
    }

    /// @dev Internal utility to check contract readiness
    /// @return True if ready
    function _ready() internal view returns (bool) {
        return $members.toAddressA().length > 0;
    }

    /// @dev Retrieve the report hash from the calldata
    /// @param report The consensus layer report to hash
    /// @return The report hash
    function _reportHash(ctypes.ValidatorsReport calldata report) internal pure returns (bytes32) {
        return keccak256(abi.encode(report));
    }

    /// @dev Retrieve the vote status of a member by its index
    /// @param memberIdx The member index
    /// @return True if member voted
    function _hasReported(uint256 memberIdx) internal view returns (bool) {
        return (($reportVoteTracker.get()) >> memberIdx) & 1 == 1;
    }

    /// @dev Retrieve variant index in the stored variant array
    /// @param variant The variant to lookup
    /// @return -1 if not found, >= 0 if found
    function _variantIndex(bytes32 variant) internal view returns (int256) {
        int256 reportVariantsLength = int256($reportVariants.toBytes32A().length);
        for (int256 idx = 0; idx < reportVariantsLength;) {
            if ($reportVariants.toBytes32A()[uint256(idx)] == variant) {
                return idx;
            }
            unchecked {
                ++idx;
            }
        }
        return -1;
    }

    /// @dev Internal utility to change the highest reported epoch
    /// @param epoch The epoch to set as the highest reported epoch
    function _setHighestReportedEpoch(uint256 epoch) internal {
        $highestReportedEpoch.set(epoch);
        emit SetHighestReportedEpoch(epoch);
    }

    /// @dev Internal utility to clear all reporting data
    function _clear() internal {
        $reportVariants.del();
        $reportVoteCounts.del();
        $reportVoteTracker.del();
        emit ReportingCleared();
    }

    /// @dev Internal utility to clear all reporting data
    /// @param memberIdx The member index
    /// @param globalMemberVoted True if the global member voted
    function _registerReport(uint256 memberIdx, bool globalMemberVoted) internal {
        $reportVoteTracker.set($reportVoteTracker.get() | (1 << memberIdx) | (globalMemberVoted ? 1 : 0));
    }
}
