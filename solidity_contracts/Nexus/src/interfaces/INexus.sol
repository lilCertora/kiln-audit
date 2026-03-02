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

import "./IGlobalRecipientHolder.sol";
import "./IGlobalOracleHolder.sol";
import "./IGlobalConsensusLayerSpecHolder.sol";

/// @title Nexus Interface
/// @author mortimr @ Kiln
/// @notice The Nexus is in charge of spawning the validator suites
interface INexus is IGlobalRecipientHolder, IGlobalOracleHolder, IGlobalConsensusLayerSpecHolder {
    /// @notice Input parameters for the spawnFactory call
    /// @param treasuryFee The initial treasury fee in BPS for the vTreasury
    /// @param admin The admin address of the vFactory
    /// @param operator The operator address of the vFactory
    /// @param operatorName The operator name metadata
    struct FactoryConstructionArguments {
        uint256 treasuryFee;
        address admin;
        address operator;
        string operatorName;
    }

    /// @notice Input parameters for the spawnPool call
    /// @param epochsPerFrame The number of epochs inside a reporting frame (225 = 24 hours)
    /// @param operatorFeeBps The operator fee in bps, received as shares upon oracle reports
    /// @param factory The address of the linked vFactory
    /// @param reportBounds The oracle report bounds ([upperBound, coverageUpperBound, lowerBound])
    /// @param initialExtraData The initial extra data to use when depositing validators
    /// @param exitQueueImageUrl The URL of the image to use for the exit queue ERC721
    struct PoolConstructionArguments {
        uint256 epochsPerFrame;
        uint256 operatorFeeBps;
        address factory;
        uint64[3] reportBounds;
        string initialExtraData;
        string exitQueueImageUrl;
    }

    /// @notice The minimal recipient implementation address was changed
    /// @param minimalRecipientImplementationAddress The new address of the minimal recipient implementation
    event SetMinimalRecipientImplementation(address minimalRecipientImplementationAddress);

    /// @notice The deposit contract address was set
    /// @param depositContractAddress The deposit contract address
    event SetDepositContract(address depositContractAddress);

    /// @notice A factory was spawned with its treasury
    /// @param factory The address of the factory contract
    /// @param treasury The address of its treasury contract
    event SpawnedFactory(address indexed factory, address treasury);

    /// @notice A pool was spawned with all its contracts
    /// @param factory The factory upon which the pool was spawned
    /// @param pool The address of the spawned pool
    /// @param withdrawalRecipient The address of its withdrawal recipient contract
    /// @param execLayerRecipient The address of its exec layer recipient contract
    /// @param coverageRecipient The address of its coverage recipient contract
    /// @param oracleAggregator The address of its oracle aggregator contract
    /// @param exitQueue The address of its exit queue contract
    event SpawnedPool(
        address indexed factory,
        address pool,
        address withdrawalRecipient,
        address execLayerRecipient,
        address coverageRecipient,
        address oracleAggregator,
        address exitQueue
    );

    /// @notice The core hatchers have been changed
    /// @param factory The address of the vFactory Hatcher
    /// @param pool The address of the vPool Hatcher
    /// @param treasury The address of the vTreasury Hatcher
    /// @param withdrawalRecipient The address of the vWithdrawalRecipient Hatcher
    /// @param execLayerRecipient The address of the vExecLayerRecipient Hatcher
    /// @param coverageRecipient The address of the vCoverageRecipient Hatcher
    /// @param oracleAggregator The address of the vOracleAggregator Hatcher
    /// @param exitQueue The address of the vExitQueue Hatcher
    event SetCoreHatchers(
        address factory,
        address pool,
        address treasury,
        address withdrawalRecipient,
        address execLayerRecipient,
        address coverageRecipient,
        address oracleAggregator,
        address exitQueue
    );

    /// @notice Thrown when a spawn action was attempted on a contract that wasn't a spawned factory
    /// @param caller The address of the caller
    /// @param invalidFactory The address of the factory that is not registered as spawned
    error NotSpawnedFactory(address caller, address invalidFactory);

    /// @notice Thrown when the provided pluggable hatcher is not configured to point on this Nexus
    /// @param pluggableHatcher The address of the pluggable hatcher
    /// @param configuredNexus The address of the configured nexus
    error InvalidPluggableHatcherConfiguration(address pluggableHatcher, address configuredNexus);

    /// @notice Initialize the Nexus (proxy pattern)
    /// @param admin The admin of the Nexus
    /// @param pluggableHatcherList The initial list of allowed pluggable hatchers
    /// @param depositContract_ The deposit contract address
    /// @param minimalRecipientImplementation_ The address of the minimal recipient implementation
    /// @param globalRecipient_ The initial global recipient address
    /// @param globalOracle_ The initial global oracle address
    /// @param genesisTimestamp_ The timestamp of the genesis slot (slot #0)
    /// @param epochsUntilFinal_ The count of epochs before an epoch can be considered final
    /// @param slotsPerEpoch_ The count of slots inside one epoch
    /// @param secondsPerSlot_ The number of seconds inside a slot
    function initialize(
        address admin,
        address[8] calldata pluggableHatcherList,
        address depositContract_,
        address minimalRecipientImplementation_,
        address globalRecipient_,
        address globalOracle_,
        uint64 genesisTimestamp_,
        uint64 epochsUntilFinal_,
        uint64 slotsPerEpoch_,
        uint64 secondsPerSlot_
    ) external;

    /// @notice Retrieve the deposit contract address used when configuring vFactory instances
    /// @return The deposit contract address
    function depositContract() external view returns (address);

    /// @notice Retrieve the minimal recipient implementation address used when configuring vFactory instances
    /// @return The minimal recipient implementation address
    function minimalRecipientImplementation() external view returns (address);

    /// @notice Retrieve the list of the core hatchers
    /// @return The list of the core hatchers
    function coreHatchers() external view returns (address[] memory);

    /// @notice Check to see if an address is a spawned factory
    /// @param factory The address to verify
    /// @return True if spawned
    function spawnedFactory(address factory) external view returns (bool);

    /// @notice Utility to replace the core hatchers
    /// @param coreHatchers_ The list of core hatchers in the following order: vFactory, vPool, vTreasury, vWithdrawalRecipient, vExecLayerRecipient, vCoverageRecipient, vOracleAggregator
    function replaceCoreHatchers(address[8] calldata coreHatchers_) external;

    /// @notice Utility to spawn a factory and its treasury
    /// @param fca Structure holding all the arguments required to spawn a factory. [FactoryConstructionArguments details](../interfaces/INexus.1.sol/contract.INexus.md#factoryconstructionarguments).
    /// @return spawned The addresses of the spawned contracts: [vFactory, vTreasury]
    function spawnFactory(FactoryConstructionArguments calldata fca) external returns (address[2] memory spawned);

    /// @notice Utility to spawn a pool and all its contracts and register it as a depositor on a factory
    /// @param pca Structure holding all the arguments required to spawn a pool. [PoolConstructionArguments details](../interfaces/INexus.1.sol/contract.INexus.md#poolconstructionarguments).
    /// @return spawned The addresses of the spawned contracts: [vPool, vWithdrawalRecipient, vExecLayerRecipient, vCoverageRecipient, vOracleAggregator, vExitQueue]
    function spawnPool(PoolConstructionArguments calldata pca) external returns (address[6] memory spawned);
}
