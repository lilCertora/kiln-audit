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

import "utils.sol/Hatcher.sol";
import "utils.sol/Initializable.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/libs/LibAddress.sol";

import "./interfaces/IPluggableHatcher.sol";
import "./interfaces/INexus.sol";
import "./interfaces/IvTreasury.sol";
import "./interfaces/IvFactory.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IvWithdrawalRecipient.sol";
import "./interfaces/IvExecLayerRecipient.sol";
import "./interfaces/IvCoverageRecipient.sol";
import "./interfaces/IvOracleAggregator.sol";
import "./interfaces/IvExitQueue.sol";

/// @title Nexus
/// @author mortimr @ Kiln
/// @notice The Nexus is in charge of spawning the validator suites, and handles the pluggable hatcher registry
contract Nexus is Initializable, Implementation, Administrable, INexus {
    using LMapping for types.Mapping;
    using LAddress for types.Address;
    using LConsensusLayerSpecStruct for ctypes.ConsensusLayerSpecStruct;
    using LArray for types.Array;

    using CAddress for address;
    using CBool for bool;
    using CUint256 for uint256;

    /// @dev The deposit contract address used to configure vFactory instances.
    /// @dev Slot: keccak256(bytes("nexus.1.depositContract")) - 1
    types.Address internal constant $depositContract =
        types.Address.wrap(0x1887dbff9d7375c97f32aee0033d3c42983f0c35dbface9cb557931d12c45c11);

    /// @dev The minimal recipient implementation address used to configure vFactory instances.
    /// @dev Slot: keccak256(bytes("nexus.1.minimalRecipientImplementation")) - 1
    types.Address internal constant $minimalRecipientImplementation =
        types.Address.wrap(0x898d0c94807e0166707ddb91f15c9290a0558b913c7bf6445c92bae52ea1dcc9);

    /// @dev The global recipient on the deployed treasuries.
    /// @dev Slot: keccak256(bytes("nexus.1.globalRecipient")) - 1
    types.Address internal constant $globalRecipient =
        types.Address.wrap(0x48455c9d54a35c3e71e4029cce3c34703248f49ef4db1f67706bb9ec9390c439);

    /// @dev The global mandatory oracle on all vPools.
    /// @dev Slot: keccak256(bytes("nexus.1.globalOracle")) - 1
    types.Address internal constant $globalOracle = types.Address.wrap(0x258dbea082092e1ff5bd559c7567e319e407e4110a23e02c4335ad5ea15f02a5);

    /// @dev The global spec for consensus layer details.
    /// @dev Slot: keccak256(bytes("nexus.1.globalConsensusLayerSpec")) - 1
    ctypes.ConsensusLayerSpecStruct internal constant $globalConsensusLayerSpec =
        ctypes.ConsensusLayerSpecStruct.wrap(0xd2b643ff25531d9c19adf886daafaf67ec76b779f42846be315007e0468fee00);

    /// @dev The list of core hatchers.
    /// @dev Slot: keccak256(bytes("nexus.1.coreHatchers")) - 1
    types.Array internal constant $coreHatchers = types.Array.wrap(0x80119f3220af1fe1cb40093f5c14a16b36620d29be3853a6f75feda0b02352dc);

    /// @dev The mapping keeping track of spawned factories.
    /// @dev Type: mapping(address => bool)
    /// @dev Slot: keccak256(bytes("nexus.1.spawnedFactories")) - 1
    types.Mapping internal constant $spawnedFactories =
        types.Mapping.wrap(0xfc5007dccb37bee4567627789bd7f589c4edb78dc700df046b3425ce34a8586b);

    /// Hatcher indexes
    uint8 internal constant FACTORY = 0;
    uint8 internal constant POOL = 1;
    uint8 internal constant TREASURY = 2;
    uint8 internal constant WITHDRAWAL_RECIPIENT = 3;
    uint8 internal constant EXEC_LAYER_RECIPIENT = 4;
    uint8 internal constant COVERAGE_RECIPIENT = 5;
    uint8 internal constant ORACLE_AGGREGATOR = 6;
    uint8 internal constant EXIT_QUEUE = 7;

    /// @inheritdoc INexus
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
    ) external init(0) {
        LibSanitize.notZeroAddress(depositContract_);
        LibSanitize.notZeroAddress(minimalRecipientImplementation_);
        LibSanitize.notZeroAddress(globalRecipient_);
        LibSanitize.notZeroAddress(globalOracle_);

        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[FACTORY]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[POOL]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[TREASURY]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[WITHDRAWAL_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[EXEC_LAYER_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[COVERAGE_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[ORACLE_AGGREGATOR]));
        _checkPluggableHatcher(IPluggableHatcher(pluggableHatcherList[EXIT_QUEUE]));

        _setAdmin(admin);

        address[] storage chs = $coreHatchers.toAddressA();
        chs.push(pluggableHatcherList[FACTORY]);
        chs.push(pluggableHatcherList[POOL]);
        chs.push(pluggableHatcherList[TREASURY]);
        chs.push(pluggableHatcherList[WITHDRAWAL_RECIPIENT]);
        chs.push(pluggableHatcherList[EXEC_LAYER_RECIPIENT]);
        chs.push(pluggableHatcherList[COVERAGE_RECIPIENT]);
        chs.push(pluggableHatcherList[ORACLE_AGGREGATOR]);
        chs.push(pluggableHatcherList[EXIT_QUEUE]);
        _emitSetCoreHatchersEvent(pluggableHatcherList);

        $depositContract.set(depositContract_);
        emit SetDepositContract(depositContract_);
        $minimalRecipientImplementation.set(minimalRecipientImplementation_);
        emit SetMinimalRecipientImplementation(minimalRecipientImplementation_);
        _setGlobalRecipient(globalRecipient_);
        _setGlobalOracle(globalOracle_);
        _setGlobalConsensusLayerSpec(genesisTimestamp_, epochsUntilFinal_, slotsPerEpoch_, secondsPerSlot_);
    }

    modifier onlyFactoryAdmin(address factory) {
        {
            address factoryAdmin = IvFactory(factory).admin();
            if (msg.sender != factoryAdmin) {
                revert LibErrors.Unauthorized(msg.sender, factoryAdmin);
            }
        }
        _;
    }

    modifier onlySpawnedFactory(address factory) {
        if (!$spawnedFactories.get()[factory.k()].toBool()) {
            revert NotSpawnedFactory(msg.sender, factory);
        }
        _;
    }

    /// @inheritdoc IGlobalRecipientHolder
    function globalRecipient() external view returns (address) {
        return $globalRecipient.get();
    }

    /// @inheritdoc IGlobalOracleHolder
    function globalOracle() external view returns (address) {
        return $globalOracle.get();
    }

    /// @inheritdoc IGlobalConsensusLayerSpecHolder
    /// @dev This function is not pure because it retrieves the struct from storage.
    function globalConsensusLayerSpec() external pure returns (ctypes.ConsensusLayerSpec memory) {
        return $globalConsensusLayerSpec.get();
    }

    /// @inheritdoc INexus
    function depositContract() external view returns (address) {
        return $depositContract.get();
    }

    /// @inheritdoc INexus
    function minimalRecipientImplementation() external view returns (address) {
        return $minimalRecipientImplementation.get();
    }

    /// @inheritdoc INexus
    /// @dev This function is not pure because it retrieves the array from storage.
    function coreHatchers() external pure returns (address[] memory) {
        return $coreHatchers.toAddressA();
    }

    /// @inheritdoc INexus
    function spawnedFactory(address factory) external view returns (bool) {
        return $spawnedFactories.get()[factory.k()].toBool();
    }

    /// @inheritdoc INexus
    function replaceCoreHatchers(address[8] calldata coreHatchers_) external onlyAdmin {
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[FACTORY]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[POOL]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[TREASURY]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[WITHDRAWAL_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[EXEC_LAYER_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[COVERAGE_RECIPIENT]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[ORACLE_AGGREGATOR]));
        _checkPluggableHatcher(IPluggableHatcher(coreHatchers_[EXIT_QUEUE]));
        address[] storage chs = $coreHatchers.toAddressA();
        chs[FACTORY] = coreHatchers_[FACTORY];
        chs[POOL] = coreHatchers_[POOL];
        chs[TREASURY] = coreHatchers_[TREASURY];
        chs[WITHDRAWAL_RECIPIENT] = coreHatchers_[WITHDRAWAL_RECIPIENT];
        chs[EXEC_LAYER_RECIPIENT] = coreHatchers_[EXEC_LAYER_RECIPIENT];
        chs[COVERAGE_RECIPIENT] = coreHatchers_[COVERAGE_RECIPIENT];
        chs[ORACLE_AGGREGATOR] = coreHatchers_[ORACLE_AGGREGATOR];
        chs[EXIT_QUEUE] = coreHatchers_[EXIT_QUEUE];
        _emitSetCoreHatchersEvent(coreHatchers_);
    }

    /// @inheritdoc INexus
    // slither-disable-next-line reentrancy-events
    function spawnFactory(INexus.FactoryConstructionArguments calldata fca) external onlyAdmin returns (address[2] memory spawned) {
        address[] storage chs = $coreHatchers.toAddressA();

        spawned[1] =
            IPluggableHatcher(chs[TREASURY]).plug(abi.encodeCall(IvTreasury.initialize, (fca.admin, address(this), fca.treasuryFee)));

        // Deploy new vFactory instance
        spawned[0] = IPluggableHatcher(chs[FACTORY]).plug(
            abi.encodeCall(
                IvFactory.initialize,
                (
                    fca.operatorName,
                    $depositContract.get(),
                    fca.admin,
                    fca.operator,
                    spawned[1],
                    $minimalRecipientImplementation.get(),
                    address(this)
                )
            )
        );

        $spawnedFactories.get()[spawned[0].k()] = true.v();
        emit SpawnedFactory(spawned[0], spawned[1]);
    }

    /// @inheritdoc INexus
    // slither-disable-next-line reentrancy-events
    function spawnPool(INexus.PoolConstructionArguments calldata pca)
        external
        onlySpawnedFactory(pca.factory)
        onlyFactoryAdmin(pca.factory)
        returns (address[6] memory spawned)
    {
        address[] storage chs = $coreHatchers.toAddressA();

        spawned[0] = IHatcher(chs[POOL]).nextHatch();

        spawned[1] = IPluggableHatcher(chs[WITHDRAWAL_RECIPIENT]).plug(abi.encodeCall(IvWithdrawalRecipient.initialize, (spawned[0])));

        spawned[2] = IPluggableHatcher(chs[EXEC_LAYER_RECIPIENT]).plug(abi.encodeCall(IvExecLayerRecipient.initialize, (spawned[0])));

        spawned[3] = IPluggableHatcher(chs[COVERAGE_RECIPIENT]).plug(abi.encodeCall(IvCoverageRecipient.initialize, (spawned[0])));

        spawned[4] = IPluggableHatcher(chs[ORACLE_AGGREGATOR]).plug(
            abi.encodeCall(IvOracleAggregator.initialize, (spawned[0], pca.factory, address(this)))
        );

        spawned[5] = IPluggableHatcher(chs[EXIT_QUEUE]).plug(abi.encodeCall(IvExitQueue.initialize, (spawned[0], pca.exitQueueImageUrl)));

        bytes memory call = _generatePoolCalldata(pca, spawned);

        // Deploy and plug new vPool instance to vFactory
        assert(IPluggableHatcher(chs[POOL]).plug(call) == spawned[0]);

        IvFactory(pca.factory).allowDepositor(spawned[0], LibAddress.toWithdrawalCredentials(spawned[1]), true);

        emit SpawnedPool(pca.factory, spawned[0], spawned[1], spawned[2], spawned[3], spawned[4], spawned[5]);
    }

    /// @inheritdoc IGlobalRecipientHolder
    function setGlobalRecipient(address newGlobalRecipient) external onlyAdmin {
        _setGlobalRecipient(newGlobalRecipient);
    }

    /// @inheritdoc IGlobalOracleHolder
    function setGlobalOracle(address newGlobalOracle) external onlyAdmin {
        _setGlobalOracle(newGlobalOracle);
    }

    /// @inheritdoc IGlobalConsensusLayerSpecHolder
    function setGlobalConsensusLayerSpec(uint64 genesisTimestamp, uint64 epochsUntilFinal, uint64 slotsPerEpoch, uint64 secondsPerSlot)
        external
        onlyAdmin
    {
        _setGlobalConsensusLayerSpec(genesisTimestamp, epochsUntilFinal, slotsPerEpoch, secondsPerSlot);
    }

    function _checkPluggableHatcher(IPluggableHatcher ph) internal view {
        LibSanitize.notZeroAddress(address(ph));
        if (ph.nexus() != address(this)) {
            revert InvalidPluggableHatcherConfiguration(address(ph), ph.nexus());
        }
    }

    function _generatePoolCalldata(INexus.PoolConstructionArguments calldata pca, address[6] memory spawned)
        internal
        pure
        returns (bytes memory call)
    {
        address[6] memory addrs;
        addrs[0] = pca.factory;
        addrs[1] = spawned[1];
        addrs[2] = spawned[2];
        addrs[3] = spawned[3];
        addrs[4] = spawned[4];
        addrs[5] = spawned[5];
        call = abi.encodeCall(
            IvPool.initialize,
            (addrs, pca.epochsPerFrame, $globalConsensusLayerSpec.get(), pca.reportBounds, pca.operatorFeeBps, pca.initialExtraData)
        );
    }

    function _emitSetCoreHatchersEvent(address[8] calldata pluggableHatcherList) internal {
        emit SetCoreHatchers(
            pluggableHatcherList[FACTORY],
            pluggableHatcherList[POOL],
            pluggableHatcherList[TREASURY],
            pluggableHatcherList[WITHDRAWAL_RECIPIENT],
            pluggableHatcherList[EXEC_LAYER_RECIPIENT],
            pluggableHatcherList[COVERAGE_RECIPIENT],
            pluggableHatcherList[ORACLE_AGGREGATOR],
            pluggableHatcherList[EXIT_QUEUE]
        );
    }

    function _setGlobalRecipient(address newGlobalRecipient) internal {
        LibSanitize.notZeroAddress(newGlobalRecipient);
        $globalRecipient.set(newGlobalRecipient);
        emit SetGlobalRecipient(newGlobalRecipient);
    }

    function _setGlobalOracle(address newGlobalOracle) internal {
        LibSanitize.notZeroAddress(newGlobalOracle);
        $globalOracle.set(newGlobalOracle);
        emit SetGlobalOracle(newGlobalOracle);
    }

    function _setGlobalConsensusLayerSpec(uint64 genesisTimestamp, uint64 epochsUntilFinal, uint64 slotsPerEpoch, uint64 secondsPerSlot)
        internal
    {
        ctypes.ConsensusLayerSpec storage gclss = $globalConsensusLayerSpec.get();
        gclss.genesisTimestamp = genesisTimestamp;
        gclss.epochsUntilFinal = epochsUntilFinal;
        gclss.slotsPerEpoch = slotsPerEpoch;
        gclss.secondsPerSlot = secondsPerSlot;
        emit SetGlobalConsensusLayerSpec(genesisTimestamp, epochsUntilFinal, slotsPerEpoch, secondsPerSlot);
    }
}
