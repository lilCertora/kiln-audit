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
import "utils.sol/libs/LibUint256.sol";
import "utils.sol/libs/LibSanitize.sol";
import "utils.sol/types/address.sol";
import "utils.sol/types/string.sol";
import "utils.sol/types/bool.sol";
import "utils.sol/types/array.sol";
import "utils.sol/types/mapping.sol";

import "./ctypes/report_bounds_struct.sol";
import "./ctypes/approvals_mapping.sol";
import "./ctypes/validators_report_struct.sol";
import "./ctypes/ethers_struct.sol";
import "./ctypes/consensus_layer_spec_struct.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IvFactory.sol";
import "./interfaces/IvWithdrawalRecipient.sol";
import "./interfaces/IvExecLayerRecipient.sol";
import "./interfaces/IvCoverageRecipient.sol";
import "./interfaces/IvExitQueue.sol";

/// @title Pool
/// @author mortimr @ Kiln
/// @notice The vPool contract is in charge of pool funds and fund validators from the vFactory
// slither-disable-next-line naming-convention
contract vPool is Initializable, Implementation, Fixable, IvPool {
    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LArray for types.Array;
    using LString for types.String;
    using LMapping for types.Mapping;
    using LReportBoundsStruct for ctypes.ReportBoundsStruct;
    using LApprovalsMapping for ctypes.ApprovalsMapping;
    using LValidatorsReportStruct for ctypes.ValidatorsReportStruct;
    using LEthersStruct for ctypes.EthersStruct;
    using LConsensusLayerSpecStruct for ctypes.ConsensusLayerSpecStruct;

    using CAddress for address;
    using CUint256 for uint256;
    using CBool for bool;

    /// @dev The address of the factory contract.
    /// @dev Slot: keccak256(bytes("pool.1.factory")) - 1
    types.Address internal constant $factory = types.Address.wrap(0x6291a339792a7ba63c7494680f5520318db48cdb5f75bd777c22f5dbc7823111);

    /// @dev The address of the withdrawal recipient contract.
    /// @dev Slot: keccak256(bytes("pool.1.withdrawalRecipient")) - 1
    types.Address internal constant $withdrawalRecipient =
        types.Address.wrap(0xd38b1dea18f5d391746becd446fd4f71b974e5b528ef7e1a57d0e7d432fe55a8);

    /// @dev The address of the execution layer recipient contract.
    /// @dev Slot: keccak256(bytes("pool.1.execLayerRecipient")) - 1
    types.Address internal constant $execLayerRecipient =
        types.Address.wrap(0x7d8cc1a91feadf9f0c1d682471de3b03516cbba3e030084e389fdd08de43b49b);

    /// @dev The address of the coverage recipient contract.
    /// @dev Slot: keccak256(bytes("pool.1.coverageRecipient")) - 1
    types.Address internal constant $coverageRecipient =
        types.Address.wrap(0x14f35f245cc1d2028945376b8eb895647e61e928603b7192cff5fdd220f93c8e);

    /// @dev The address of the oracle aggregator contract.
    /// @dev Slot: keccak256(bytes("pool.1.oracleAggregator")) - 1
    types.Address internal constant $oracleAggregator =
        types.Address.wrap(0x5bc8d3f5fa692516e35ac37af2af75fa5918be8340cdf74ef176c6a30308562b);

    /// @dev The address of the exit queue contract.
    /// @dev Slot: keccak256(bytes("pool.1.exitQueue")) - 1
    types.Address internal constant $exitQueue = types.Address.wrap(0x475b8f514df48aae0c684305c33751ae728849d9045edeb31683ace230f01c41);

    /// @dev The value to use as extra data when purchasing validators.
    /// @dev Slot: keccak256(bytes("pool.1.validatorGlobalExtraData")) - 1
    types.String internal constant $validatorGlobalExtraData =
        types.String.wrap(0xe47f54aad85aaa1884b27b5945cf2cccfe806c1e36e17c27b4838920a4c81e9b);

    /// @dev Details about the ether balances of the contract.
    /// @dev Slot: keccak256(bytes("pool.1.ethers")) - 1
    ctypes.EthersStruct internal constant $ethers =
        ctypes.EthersStruct.wrap(0x6313dd8c15332e94c27940678512308c4ea59d895a189fd3b98cc211d19e99a5);

    /// @dev The last reported data.
    /// @dev Slot: keccak256(bytes("pool.1.lastReport")) - 1
    ctypes.ValidatorsReportStruct internal constant $lastReport =
        ctypes.ValidatorsReportStruct.wrap(0x3c7534b2e73933b943ebce171d930239e0eb06b6b8f91174abe27931e8a6be32);

    /// @dev Stores the last epoch of the vpool.
    /// @dev Slot: keccak256(bytes("pool.1.requestedExits")) - 1
    types.Uint256 internal constant $requestedExits = types.Uint256.wrap(0x9c2b631c00e01b44850d87ed83bc17dc3ac47564552a2041a5efed90136270bf);

    /// @dev The sum of covered slashed balances in the consensus layer.
    /// @dev Slot: keccak256(bytes("pool.1.coveredBalanceSum")) - 1
    types.Uint256 internal constant $coveredBalanceSum =
        types.Uint256.wrap(0x9ea988a990e8bb33ba380cec278407f77e425ab7847f3f16cdf0e58a18cd237b);

    /// @dev The number of epochs per frame.
    /// @dev Slot: keccak256(bytes("pool.1.epochsPerFrame")) - 1
    types.Uint256 internal constant $epochsPerFrame = types.Uint256.wrap(0xcc72d02695300c89bd94cca0db232d12866f22e6e40ec9c082dec8c41906e8f3);

    /// @dev The operator fee, in basis points.
    /// @dev Slot: keccak256(bytes("pool.1.operatorFeeBps")) - 1
    types.Uint256 internal constant $operatorFeeBps = types.Uint256.wrap(0x3705ca8d26c039a3116bef809c7a3f6dbccda279c5ae2bed0bd45cc63d46b7c5);

    /// @dev Stores the total supply of shares of the vpool.
    /// @dev Slot: keccak256(bytes("pool.1.totalSupply")) - 1
    types.Uint256 internal constant $totalSupply = types.Uint256.wrap(0x32e786e9024f22d99638b12a33ecd6f200f96f26c69da4498304451f4dbaed6a);

    /// @dev Stores the report bounds of the vpool.
    /// @dev Slot: keccak256(bytes("pool.1.reportBounds")) - 1
    ctypes.ReportBoundsStruct internal constant $reportBounds =
        ctypes.ReportBoundsStruct.wrap(0xdbbc8bc14bf323964fab933baa291de6eefbf7092435d8dde6b977533f08d8a9);

    /// @dev Stores the validators of the vpool.
    /// @dev Slot: keccak256(bytes("pool.1.validators")) - 1
    types.Array internal constant $validators = types.Array.wrap(0x658ad2f8c7fa64659babe98bd002c94832254d8e2ae8fff0ce0dfaeb5e654985);

    /// @dev Stores the depositors of the vpool.
    /// @dev Type: mapping(address => bool)
    /// @dev Slot: keccak256(bytes("pool.1.depositors")) - 1
    types.Mapping internal constant $depositors = types.Mapping.wrap(0x8be006ca42679468a8b8c20a0b9943a1b64175e3a59abf9a9c644440f2c6f3eb);

    /// @dev Stores the balances of the vpool depositors.
    /// @dev Type: mapping(address => uint256)
    /// @dev Slot: keccak256(bytes("pool.1.balances")) - 1
    types.Mapping internal constant $balances = types.Mapping.wrap(0xf63d192ff238e65853b055ea9cdca61814417984241ce7572cd7f94b259085dd);

    /// @dev Stores the approvals of the vpool depositors.
    /// @dev Type: mapping(address => mapping(address => uint256))
    /// @dev Slot: keccak256(bytes("pool.1.approvals")) - 1
    ctypes.ApprovalsMapping internal constant $approvals =
        ctypes.ApprovalsMapping.wrap(0x8de2a20c308dbb11a4ffbd4d6528a6f10f827dd4ec26d86de01f40eb80effdad);

    /// @dev The global spec for consensus layer details.
    /// @dev Slot: keccak256(bytes("pool.1.consensusLayerSpec")) - 1
    ctypes.ConsensusLayerSpecStruct internal constant $consensusLayerSpec =
        ctypes.ConsensusLayerSpecStruct.wrap(0x048aa41abc6ebe9727e0277aed47d516cf8cf00168056b11ddbb94c46eec1693);

    // Calldata indexes (constructor)
    uint8 internal constant FACTORY = 0;
    uint8 internal constant WITHDRAWAL_RECIPIENT = 1;
    uint8 internal constant EXEC_LAYER_RECIPIENT = 2;
    uint8 internal constant COVERAGE_RECIPIENT = 3;
    uint8 internal constant ORACLE_AGGREGATOR = 4;
    uint8 internal constant EXIT_QUEUE = 5;

    /// @dev The minimum amount of ether to feed the exit queue unless all demand can be fulfilled
    uint256 internal constant MINIMUM_EXIT_QUEUE_PARTIAL_FEED = 0.1 ether;

    /// @notice The threshold in underlying balance before which shares are minted 1:1
    /// @notice This ensures a minimum amount of shares before performing mulDivs
    uint256 internal constant INITIAL_MINT_THRESHOLD = 0.1 ether;

    /// @inheritdoc IvPool
    // slither-disable-next-line reentrancy-benign,reentrancy-events
    function initialize(
        address[6] calldata addrs,
        uint256 epochsPerFrame_,
        ctypes.ConsensusLayerSpec calldata consensusLayerSpec_,
        uint64[3] calldata bounds_,
        uint256 operatorFeeBps_,
        string calldata extraData_
    ) external init(0) {
        LibSanitize.notZeroAddress(addrs[FACTORY]);
        LibSanitize.notZeroAddress(addrs[WITHDRAWAL_RECIPIENT]);
        LibSanitize.notZeroAddress(addrs[EXEC_LAYER_RECIPIENT]);
        LibSanitize.notZeroAddress(addrs[COVERAGE_RECIPIENT]);
        LibSanitize.notZeroAddress(addrs[ORACLE_AGGREGATOR]);
        LibSanitize.notZeroAddress(addrs[EXIT_QUEUE]);
        _setEpochsPerFrame(epochsPerFrame_);
        _setConsensusLayerSpec(consensusLayerSpec_);
        _setReportBounds(bounds_[0], bounds_[1], bounds_[2]);
        _setOperatorFee(operatorFeeBps_);
        _setValidatorGlobalExtraData(extraData_);

        $factory.set(addrs[FACTORY]);
        $withdrawalRecipient.set(addrs[WITHDRAWAL_RECIPIENT]);
        $execLayerRecipient.set(addrs[EXEC_LAYER_RECIPIENT]);
        $coverageRecipient.set(addrs[COVERAGE_RECIPIENT]);
        $oracleAggregator.set(addrs[ORACLE_AGGREGATOR]);
        $exitQueue.set(addrs[EXIT_QUEUE]);

        emit SetContractLinks(
            addrs[FACTORY],
            addrs[WITHDRAWAL_RECIPIENT],
            addrs[EXEC_LAYER_RECIPIENT],
            addrs[COVERAGE_RECIPIENT],
            addrs[ORACLE_AGGREGATOR],
            addrs[EXIT_QUEUE]
        );
    }

    /// @notice Only allows the admin to perform the call
    modifier onlyAdmin() {
        {
            address admin = IvFactory($factory.get()).admin();
            if (msg.sender != admin) {
                revert LibErrors.Unauthorized(msg.sender, admin);
            }
        }
        _;
    }

    /// @notice Only allows the oracle aggregator to perform the call
    modifier onlyOracleAggregator() {
        {
            address oracleAggregatorAddr = $oracleAggregator.get();
            if (msg.sender != oracleAggregatorAddr) {
                revert LibErrors.Unauthorized(msg.sender, oracleAggregatorAddr);
            }
        }
        _;
    }

    /// @notice Only allows the depositor to perform the call
    modifier onlyDepositor() {
        if (!$depositors.get()[msg.sender.k()].toBool()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @inheritdoc IvPool
    function factory() external view returns (address) {
        return $factory.get();
    }

    /// @inheritdoc IvPool
    function execLayerRecipient() external view returns (address) {
        return $execLayerRecipient.get();
    }

    /// @inheritdoc IvPool
    function coverageRecipient() external view returns (address) {
        return $coverageRecipient.get();
    }

    /// @inheritdoc IvPool
    function withdrawalRecipient() external view returns (address) {
        return $withdrawalRecipient.get();
    }

    /// @inheritdoc IvPool
    function oracleAggregator() external view returns (address) {
        return $oracleAggregator.get();
    }

    /// @inheritdoc IvPool
    function exitQueue() external view returns (address) {
        return $exitQueue.get();
    }

    /// @inheritdoc IvPool
    function validatorGlobalExtraData() external view returns (string memory) {
        return $validatorGlobalExtraData.get();
    }

    /// @inheritdoc IvPool
    function depositors(address depositorAddress) external view returns (bool) {
        return $depositors.get()[depositorAddress.k()].toBool();
    }

    /// @inheritdoc IvPool
    function totalSupply() external view returns (uint256) {
        return _totalSupply();
    }

    /// @inheritdoc IvPool
    function name() external view returns (string memory) {
        if ($version.get() == 0) {
            return "";
        }
        // slither-disable-next-line unused-return
        (string memory name_,,) = IvFactory($factory.get()).metadata();
        return string.concat(name_, " vPool Shares");
    }

    /// @inheritdoc IvPool
    function symbol() external view returns (string memory) {
        if ($version.get() == 0) {
            return "";
        }
        return "VPS";
    }

    /// @inheritdoc IvPool
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @inheritdoc IvPool
    function totalUnderlyingSupply() external view returns (uint256) {
        return _totalUnderlyingSupply();
    }

    /// @inheritdoc IvPool
    function rate() external view returns (uint256) {
        uint256 currentTotalSupply = _totalSupply();
        return currentTotalSupply > 0 ? LibUint256.mulDiv(_totalUnderlyingSupply(), 1e18, currentTotalSupply) : 1e18;
    }

    /// @inheritdoc IvPool
    function requestedExits() external view returns (uint32) {
        return uint32($requestedExits.get());
    }

    /// @inheritdoc IvPool
    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf(account);
    }

    function _balanceOf(address account) internal view returns (uint256) {
        return $balances.get()[account.k()];
    }

    /// @inheritdoc IvPool
    function allowance(address owner, address spender) external view returns (uint256) {
        return $approvals.get()[owner][spender];
    }

    /// @inheritdoc IvPool
    /// @dev This function is not pure because it reads `ethers` from storage
    function ethers() external pure returns (ctypes.Ethers memory) {
        return $ethers.get();
    }

    /// @inheritdoc IvPool
    /// @dev This function is not pure because it reads `validators` from storage
    function purchasedValidators() external pure returns (uint256[] memory) {
        return $validators.toUintA();
    }

    /// @inheritdoc IvPool
    function purchasedValidatorAtIndex(uint256 idx) external view returns (uint256) {
        return $validators.toUintA()[idx];
    }

    /// @inheritdoc IvPool
    function purchasedValidatorCount() external view returns (uint256) {
        return $validators.toUintA().length;
    }

    /// @inheritdoc IvPool
    function lastEpoch() external view returns (uint256) {
        return $lastReport.get().epoch;
    }

    /// @inheritdoc IvPool
    function lastReport() external view returns (ctypes.ValidatorsReport memory) {
        return $lastReport.get();
    }

    /// @inheritdoc IvPool
    function totalCovered() external view returns (uint256) {
        return $coveredBalanceSum.get();
    }

    /// @inheritdoc IvPool
    function epochsPerFrame() external view returns (uint256) {
        return $epochsPerFrame.get();
    }

    /// @inheritdoc IvPool
    function consensusLayerSpec() external pure returns (ctypes.ConsensusLayerSpec memory) {
        return $consensusLayerSpec.get();
    }

    /// @inheritdoc IvPool
    function reportBounds()
        external
        view
        returns (uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound)
    {
        ctypes.ReportBounds storage rbs = $reportBounds.get();
        return (rbs.maxAPRUpperBound, rbs.maxAPRUpperCoverageBoost, rbs.maxRelativeLowerBound);
    }

    /// @inheritdoc IvPool
    function operatorFee() external view returns (uint256) {
        return $operatorFeeBps.get();
    }

    /// @inheritdoc IvPool
    function isValidEpoch(uint256 epoch) external view returns (bool) {
        return _isValidEpoch(epoch);
    }

    /// @inheritdoc IvPool
    function onlyValidEpoch(uint256 epoch) external view {
        ctypes.ConsensusLayerSpec memory cls = $consensusLayerSpec.get();

        _onlyValidEpoch(cls, epoch);
    }

    /// @inheritdoc IvPool
    function allowDepositor(address depositorAddress, bool allowed) external onlyAdmin {
        LibSanitize.notZeroAddress(depositorAddress);
        $depositors.get()[depositorAddress.k()] = allowed.v();
        emit ApproveDepositor(depositorAddress, allowed);
    }

    /// @inheritdoc IvPool
    function transferShares(address to, uint256 amount, bytes calldata data) external returns (bool) {
        LibSanitize.notZeroAddress(to);
        LibSanitize.notNullValue(amount);
        return _transfer(msg.sender, msg.sender, to, amount, data);
    }

    /// @inheritdoc IvPool
    function increaseAllowance(address spender, uint256 amount) external returns (bool) {
        LibSanitize.notZeroAddress(spender);
        LibSanitize.notNullValue(amount);
        uint256 approval = $approvals.get()[msg.sender][spender];
        uint256 newApproval = approval + amount;
        $approvals.get()[msg.sender][spender] = newApproval;
        emit Approval(msg.sender, spender, newApproval);
        return true;
    }

    /// @inheritdoc IvPool
    function decreaseAllowance(address spender, uint256 amount) external returns (bool) {
        LibSanitize.notZeroAddress(spender);
        LibSanitize.notNullValue(amount);
        uint256 approval = $approvals.get()[msg.sender][spender];
        if (approval < amount) {
            revert AllowanceTooLow(msg.sender, spender, approval, amount);
        }
        unchecked {
            uint256 newApproval = approval - amount;
            $approvals.get()[msg.sender][spender] = newApproval;
            emit Approval(msg.sender, spender, newApproval);
        }
        return true;
    }

    /// @inheritdoc IvPool
    function voidAllowance(address spender) external returns (bool) {
        LibSanitize.notZeroAddress(spender);
        uint256 approval = $approvals.get()[msg.sender][spender];
        if (approval == 0) {
            revert ApprovalAlreadyZero(msg.sender, spender);
        }
        delete $approvals.get()[msg.sender][spender];
        emit Approval(msg.sender, spender, 0);
        return true;
    }

    /// @inheritdoc IvPool
    function transferSharesFrom(address from, address to, uint256 amount, bytes calldata data) external returns (bool) {
        LibSanitize.notZeroAddress(from);
        LibSanitize.notZeroAddress(to);
        LibSanitize.notNullValue(amount);

        _consumeApproval(from, msg.sender, amount);
        return _transfer(msg.sender, from, to, amount, data);
    }

    /// @inheritdoc IvPool
    // slither-disable-next-line reentrancy-events
    function deposit() external payable onlyDepositor returns (uint256) {
        LibSanitize.notNullValue(msg.value);

        uint256 currentTotalSupply = _totalSupply();
        uint256 currentTotalUnderlyingBalance = _totalUnderlyingSupply();

        _setDepositedEthers($ethers.get().deposited + uint128(msg.value));
        uint256 amountToMint = 0;
        uint256 remainingEth = msg.value;

        if (currentTotalUnderlyingBalance < INITIAL_MINT_THRESHOLD) {
            amountToMint = LibUint256.min(INITIAL_MINT_THRESHOLD - currentTotalUnderlyingBalance, remainingEth);
            remainingEth -= amountToMint;
        }

        if (remainingEth > 0) {
            amountToMint += LibUint256.mulDiv(remainingEth, currentTotalSupply + amountToMint, currentTotalUnderlyingBalance + amountToMint);
        }

        if (amountToMint == 0) {
            revert InvalidNullMint();
        }

        _mint(amountToMint, currentTotalSupply, msg.sender);
        emit Deposit(msg.sender, msg.value, amountToMint);

        return amountToMint;
    }

    /// @inheritdoc IvPool
    // slither-disable-next-line reentrancy-events,reentrancy-benign
    function purchaseValidators(uint256 max) external {
        uint128 committedEthers = $ethers.get().committed;
        uint256 maxPurchaseAmount = LibUint256.min(max, committedEthers / LibConstant.DEPOSIT_SIZE);

        if (maxPurchaseAmount == 0) {
            revert NoValidatorToPurchase();
        }

        bytes32 withdrawalChannel = IvWithdrawalRecipient($withdrawalRecipient.get()).withdrawalCredentials();
        IvFactory vfactory = IvFactory($factory.get());
        uint256 purchasableValidatorCount = LibUint256.min(vfactory.availableValidators(withdrawalChannel), maxPurchaseAmount);

        _setCommittedEthers(committedEthers - uint128(LibConstant.DEPOSIT_SIZE * purchasableValidatorCount));

        uint256[] memory purchasedValidatorsIds = vfactory.deposit{value: LibConstant.DEPOSIT_SIZE * purchasableValidatorCount}(
            withdrawalChannel, purchasableValidatorCount, $execLayerRecipient.get(), address(this), $validatorGlobalExtraData.get()
        );

        uint256 purchasedValidatorsIdsLength = purchasedValidatorsIds.length;

        for (uint256 idx = 0; idx < purchasedValidatorsIdsLength;) {
            $validators.toUintA().push(purchasedValidatorsIds[idx]);
            unchecked {
                ++idx;
            }
        }

        emit PurchasedValidators(purchasedValidatorsIds);
        if (purchasableValidatorCount < maxPurchaseAmount) {
            IvFactory($factory.get()).request(withdrawalChannel, maxPurchaseAmount - purchasableValidatorCount);
        }
    }

    /// @inheritdoc IvPool
    function setOperatorFee(uint256 operatorFeeBps) external onlyAdmin {
        _setOperatorFee(operatorFeeBps);
    }

    /// @inheritdoc IvPool
    function setEpochsPerFrame(uint256 newEpochsPerFrame) external onlyAdmin {
        _setEpochsPerFrame(newEpochsPerFrame);
    }

    /// @inheritdoc IvPool
    function setConsensusLayerSpec(ctypes.ConsensusLayerSpec calldata consensusLayerSpec_) external onlyAdmin {
        _setConsensusLayerSpec(consensusLayerSpec_);
    }

    /// @inheritdoc IvPool
    function setReportBounds(uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound) external onlyAdmin {
        _setReportBounds(maxAPRUpperBound, maxAPRUpperCoverageBoost, maxRelativeLowerBound);
    }

    /// @inheritdoc IvPool
    function setValidatorGlobalExtraData(string calldata extraData) external onlyAdmin {
        _setValidatorGlobalExtraData(extraData);
    }

    /// @inheritdoc IvPool
    function injectEther() external payable {
        LibSanitize.notNullValue(msg.value);
        if (
            msg.sender != $execLayerRecipient.get() && msg.sender != $coverageRecipient.get() && msg.sender != $withdrawalRecipient.get()
                && msg.sender != $exitQueue.get()
        ) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _setDepositedEthers($ethers.get().deposited + uint128(msg.value));
        emit InjectedEther(msg.sender, msg.value);
    }

    /// @inheritdoc IvPool
    function voidShares(uint256 amount) external {
        LibSanitize.notNullValue(amount);
        if (msg.sender != $coverageRecipient.get()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _burn(amount, msg.sender);
        emit VoidedShares(msg.sender, amount);
    }

    /// @dev Internal variable structure for the report processing function
    /// @param traces The traces of the report, key metrics and values that are emitted via an event at the end of the report
    /// @param preValidatorCount The number of validators before the new report is applied
    /// @param preHistoricalVolume The historical volume of the consensus layer (all eth that went in and out) before the new report is applied
    /// @param increaseCredit The amount of funds we can pull from the various recipients
    /// @param exitDemand The exit demand from the exit queue
    struct ReportInternalVariables {
        ReportTraces traces;
        uint256 preValidatorCount;
        uint256 preHistoricalVolume;
        uint256 increaseCredit;
        uint256 exitDemand;
    }

    /// @inheritdoc IvPool
    // slither-disable-next-line reentrancy-events,reentrancy-no-eth,incorrect-equality,cyclomatic-complexity
    function report(ctypes.ValidatorsReport calldata rprt) external onlyOracleAggregator {
        //                                                               _   _                                                         //
        //                                                              | | (_)                                                        //
        //                                     _ __ ___ _ __   ___  _ __| |_ _ _ __   __ _                                             //
        //                                    | '__/ _ \ '_ \ / _ \| '__| __| | '_ \ / _` |                                            //
        //                                    | | |  __/ |_) | (_) | |  | |_| | | | | (_| |                                            //
        //                                    |_|  \___| .__/ \___/|_|   \__|_|_| |_|\__, |                                            //
        //                                             | |                            __/ |                                            //
        //                                             |_|                           |___/                                             //
        //                                                                                                                             //
        //  Reporting is the heart of the vPool, powering all the features of the pool in one atomic                                   //
        //  action. This method is HEAVY, it does a lot of work atomically and powers all the pooling on top of the vFactory           //
        //  The vPool assumes that the report cannot be trusted and will perform all the possible sanity                               //
        //  checks to ensure that the new values are indeed valid                                                                      //
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Report Format---------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  uint128 balanceSum;                                                                                                        //
        //      sum of all the balances of all validators that have been activated by the vPool                                        //
        //      this means that as long as the validator was activated, no matter its current status, its balance is taken             //
        //      into account                                                                                                           //
        //  uint128 exitedSum;                                                                                                         //
        //      sum of all the ether that has been exited by the validators that have been activated by the vPool                      //
        //      to compute this value, we look for withdrawal events inside the block bodies that have happened at an epoch            //
        //      that is greater or equal to the withdrawable epoch of a validator purchased by the pool                                //
        //      when we detect any, we take min(amount,32 eth) into account as exited balance                                          //
        //  uint128 skimmedSum;                                                                                                        //
        //      sum of all the ether that has been skimmed by the validators that have been activated by the vPool                     //
        //      similar to the exitedSum, we look for withdrawal events. If the epochs is lower than the withdrawable epoch            //
        //      we take into account the full withdrawal amount, otherwise we take amount - min(amount, 32 eth) into account            //
        //  uint128 slashedSum;                                                                                                        //
        //      sum of all the ether that has been slashed by the validators that have been activated by the vPool                     //
        //      to compute this value, we look for validators that are of have been in the slashed state                               //
        //      then we take the balance of the validator at the epoch prior to its slashing event                                     //
        //      we then add the delta between this old balance and the current balance (or balance just before withdrawal)             //
        //  uint128 exiting;                                                                                                           //
        //      amount of currently exiting eth, that will soon hit the withdrawal recipient                                           //
        //      this value is computed by taking the balance of any validator in the exit or slashed state or after                    //
        //  uint128 maxExitable;                                                                                                       //
        //      maximum amount that can get requested for exits during report processing                                               //
        //      this value is determined by the oracle. its calculation logic can be updated but all members need to agree and reach   //
        //      consensus on the new calculation logic. Its role is to control the rate at which exit requests are performed           //
        //  int256 maxCommittable;                                                                                                     //
        //      maximum amount that can get committed for deposits during report processing                                            //
        //      positive value means commit happens before possible exit boosts, negative after                                        //
        //      similar to the maxExitable, this value is determined by the oracle. its calculation logic can be updated but all       //
        //      members need to agree and reach consensus on the new calculation logic. Its role is to control the rate at which       //
        //      deposita are made. Committed funds are funds that are always a multiple of 32 eth and that cannot be used for          //
        //      anything else than purchasing validator, as opposed to the deposited funds that can still be used to fuel the          //
        //      exit queue in some cases.                                                                                              //
        //  uint64 epoch;                                                                                                              //
        //      epoch at which the report was crafted                                                                                  //
        //  uint32 activatedCount;                                                                                                     //
        //      current count of validators that have been activated by the vPool                                                      //
        //      no matter the current state of the validator, if it has been activated, it has to be accounted inside this value       //
        //  uint32 stoppedCount;                                                                                                       //
        //      current count of validators that have been stopped (being in the exit queue, exited or slashed)                        //
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Initialization--------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  We start the reporting process by preparing variables used across all the process. The core variable, named __, holds all  //
        //  the internal variables required during the reporting process, alongside a tracing structure that will be emitted at the    //
        //  end of the reporting process, providing great insights to off-chain indexers about what happened during the reporting      //
        //                                                                                                                             //
        ctypes.ConsensusLayerSpec memory cls = $consensusLayerSpec.get();
        ctypes.ValidatorsReport storage lastRprt = $lastReport.get();
        // slither-disable-next-line uninitialized-local                                                                               //
        ReportInternalVariables memory __;
        _onlyValidEpoch(cls, rprt.epoch);
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Sanitization----------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  Some inputs can directly get sanitized by comparing with internal values or previously reported data. Some assertions that //
        //  we are going to verify are:                                                                                                //
        //                                                                                                                             //
        //  ----- The activated validator count is not decreasing                                                                      //
        __.preValidatorCount = lastRprt.activatedCount;

        if (rprt.activatedCount < __.preValidatorCount) {
            revert DecreasingValidatorCount(__.preValidatorCount, rprt.activatedCount);
        }
        //                                                                                                                             //
        //  ----- The stopped validator count is not decreasing                                                                        //
        if (rprt.stoppedCount < lastRprt.stoppedCount) {
            revert DecreasingStoppedValidatorCount(lastRprt.stoppedCount, rprt.stoppedCount);
        }
        //                                                                                                                             //
        //  ----- The activated validator count is not higher than the number of deposits                                              //
        {
            uint256 depositedValidatorCount = $validators.toUintA().length;

            if (rprt.activatedCount > depositedValidatorCount) {
                revert ValidatorCountTooHigh(rprt.activatedCount, depositedValidatorCount);
            }

            if (rprt.stoppedCount > rprt.activatedCount) {
                revert StoppedValidatorCountTooHigh(rprt.stoppedCount, rprt.activatedCount);
            }
        }
        //                                                                                                                             //
        //  ----- The slashed balance sum is not decreasing                                                                            //
        if (rprt.slashedSum < lastRprt.slashedSum) {
            revert DecreasingSlashedBalanceSum(rprt.slashedSum, lastRprt.slashedSum);
        }
        //                                                                                                                             //
        //  ----- The exited balance sum is not decreasing                                                                             //
        if (rprt.exitedSum < lastRprt.exitedSum) {
            revert DecreasingExitedBalanceSum(rprt.exitedSum, lastRprt.exitedSum);
        }
        //                                                                                                                             //
        //  ----- The skimmed balance sum is not decreasing                                                                            //
        if (rprt.skimmedSum < lastRprt.skimmedSum) {
            revert DecreasingSkimmedBalanceSum(rprt.skimmedSum, lastRprt.skimmedSum);
        }
        //                                                                                                                             //
        //  ----- The exiting balance does not exceed the balance                                                                      //
        if (rprt.exiting > rprt.balanceSum) {
            revert ExitingBalanceTooHigh(rprt.exiting, rprt.balanceSum);
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Snapshot--------------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  The last step before starting to process the report is to save key values as they are before the report is made            //
        //  These values will be used along the reporting process to ensure some additional invariants are not broken                  //
        //                                                                                                                             //
        //  ----- The previous historical volume is computed and saved. This value represents all the volume that went in and out      //
        //        of the consensus layer. This value will allow us to accurately compute what is the current delta in the consesnsus   //
        //        layer balance                                                                                                        //
        __.preHistoricalVolume = lastRprt.balanceSum + lastRprt.exitedSum + lastRprt.skimmedSum;
        //                                                                                                                             //
        //  ----- The volume is adapted if the number of activated validator has increased                                             //
        if (rprt.activatedCount > __.preValidatorCount) {
            __.preHistoricalVolume += (rprt.activatedCount - __.preValidatorCount) * LibConstant.DEPOSIT_SIZE;
        }
        //                                                                                                                             //
        //  ----- The total underlying supply and total supply are saved                                                               //
        __.traces.preUnderlyingSupply = uint128(_totalUnderlyingSupply());
        __.traces.preSupply = uint128(_totalSupply());
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Computing margin------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  Now that we have stored most of the values that we needed, we can start computing the margins in which we should operate.  //
        //  The vPool holds values called the reporting bounds. These bounds will dictate how the conversion rate is allowed to        //
        //  increase or decrease. We're starting the reporting process by computing our upper margin, this will allow us to verify     //
        //  that this upper margin is not crossed, and help us compute the amounts we're allowed to pull from the various recipients   //
        //  holding funds for the vPool.                                                                                               //
        //                                                                                                                             //
        //  ----- The period is computed by computing the timestamps from the epoch values                                             //
        uint256 period = _epochTimestamp(cls, rprt.epoch) - _epochTimestamp(cls, lastRprt.epoch);
        //                                                                                                                             //
        //  ----- The maximum allowed balance increase is now computed                                                                 //
        __.traces.increaseLimit = uint128(_maxAllowedBalanceIncrease(__.traces.preUnderlyingSupply, period));
        __.increaseCredit = __.traces.increaseLimit;
        //                                                                                                                             //
        //  ----- The current historical volume is computed                                                                            //
        uint256 historicalVolume = rprt.balanceSum + rprt.skimmedSum + rprt.exitedSum;
        __.traces.rewards = int128(uint128(historicalVolume)) - int128(uint128(__.preHistoricalVolume));
        //                                                                                                                             //
        //  ----- Based only on reported information, we check how the margin should be updated,                                       //
        if (__.traces.rewards < 0) {
            //    if the balance has decreased, we increase                                                          //
            //    our margin and capacity of eth to pull into the system                                                          //
            __.increaseCredit += uint256(-int256(__.traces.rewards));
        } else if (__.traces.rewards <= int128(uint128(__.increaseCredit))) {
            //    if the balance has increased, while staying under the upper bound limit, we update the margin                     //
            //    by reducing its capacity                                                                                          //
            __.increaseCredit -= uint256(int256(__.traces.rewards));
        } else {
            //    otherwise, it means that the balance increased outside of the allowed upper bound                                    //
            revert UpperBoundCrossed(historicalVolume - __.preHistoricalVolume, __.traces.increaseLimit);
        }

        __.traces.consensusLayerDelta = __.traces.rewards;
        __.traces.delta = __.traces.rewards;
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Pulling Exits and Skimmings-------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  While the system is live, funds will accrue inside the withdrawal recipient. Two actions will drive this flow of funds     //
        //                                                                                                                             //
        //  ----- Exits: validators are stopped and their effective balance is sent back to the execution layer                        //
        __.traces.newExitedEthers = rprt.exitedSum - lastRprt.exitedSum;
        //  ----- Skimmings: validators are generating rewards that are periodically sent to the execution layer                       //
        __.traces.newSkimmedEthers = rprt.skimmedSum - lastRprt.skimmedSum;
        //                                                                                                                             //
        //  ----- Once we know how much was exited and skimmed since last report, we know how much money we can ask the                //
        //        withdrawal recipient                                                                                                 //
        if (__.traces.newSkimmedEthers + __.traces.newExitedEthers > 0) {
            IvWithdrawalRecipient($withdrawalRecipient.get()).pull(__.traces.newSkimmedEthers + __.traces.newExitedEthers);
            //  In the case of exits, we're removing them from the deposited balance for now                                           //
            if (__.traces.newExitedEthers > 0) {
                //  As the pull method puts all the pulled eth into the deposited storage value, we need to remove the exited ethers   //
                //  as its state is "uncertain" and will be clarified during report based on possible exit requests we will fulfill    //
                _setDepositedEthers($ethers.get().deposited - uint128(__.traces.newExitedEthers));
            }
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Execution Layer Fees--------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  Every time a validator is selected to propose a block, gas tips and mev bribes are sent to its execution layer recipient   //
        //  address. This is a different address than the withdrawal recipient. Every time validators activated by the vPool are       //
        //  proposing a block, we will receive funds inside the execution layer recipient, which is configured to be the same for      //
        //  all the validators. Based on the margin we computed and updated earlier, we will attempt to pull funds from the            //
        //  execution layer recipient, up to the margin.                                                                               //
        //  The execution layer recipient will then provide at maximum the value requested.                                            //
        //                                                                                                                             //
        if (__.increaseCredit > 0) {
            //  ----- Amount pulled is the current allowed margin                                                                      //
            uint256 pulledAmount = _pullExecLayerFees(__.increaseCredit);
            //  ----- The current allowed margin is decreased accordingly                                                              //
            __.increaseCredit -= pulledAmount;
            //  ----- Traces are updated aswell                                                                                        //
            __.traces.pulledExecutionLayerRewards = uint128(pulledAmount);
            __.traces.rewards += int128(uint128(pulledAmount));
            __.traces.delta += int128(uint128(pulledAmount));
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Exit Queue Unclaimed Funds--------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  When users are creating exit tickets, a maximum redeemable amount in eth is computed based on the current rate. If the     //
        //  rate at which the user burns its ticket is higher, then the difference is stored inside an unclaimed fund buffer. These    //
        //  funds are then pulled back into the system. No fee is taken upon these funds                                               //
        //                                                                                                                             //
        if (__.increaseCredit > 0) {
            //  ----- Amount pulled is the current allowed margin                                                                      //
            uint256 pulledAmount = _pullExitQueueUnclaimedFunds(__.increaseCredit);
            //  ----- The current allowed margin is decreased accordingly                                                              //
            __.increaseCredit -= pulledAmount;
            //  ----- Traces are updated aswell                                                                                        //
            __.traces.pulledExitQueueUnclaimedFunds = uint128(pulledAmount);
            __.traces.rewards += int128(uint128(pulledAmount));
            __.traces.delta += int128(uint128(pulledAmount));
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Coverage--------------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  It can happen in some rare situations that a validator misbehaves and gets punished. Slashing will reduce the balance      //
        //  of the validator, creating possible losses for the pool holders. The report includes the slashed balance sum to            //
        //  accurately track the amount that was lost due to such events. It's then up to the coverage recipient to fill the hole      //
        //  created by the penalties.                                                                                                  //
        //  Some things to note:                                                                                                       //
        //                                                                                                                             //
        //    - The coverage recipient might not hold enough funds to cover for the loss. If the loss is sending the balance under     //
        //      the lower bound, the report will fail, giving more time for operators and donors to provide funds to the coverage      //
        //      recipient, and rewards to accrues.                                                                                     //
        //    - The coverage recipient can hold ether and shares of the vPool. In case of a coverage request, the coverage fund        //
        //      will start by trying to provide ether up to the requested amount, and then will try to burn vPool shares               //
        //      worth the remaining amount of ether (based on the conversion rate after burn)                                          //
        //    - The covered amount is also requested to be under the upper bound margin but there is an addition "boost" margin        //
        //      that helps pull coverage funds faster. You can see that the margin for this specific operation is increased.           //
        //                                                                                                                             //
        uint256 _coveredBalanceSum = $coveredBalanceSum.get();
        __.traces.coverageIncreaseLimit = uint128(_maxCoverageBalanceIncrease(__.traces.preUnderlyingSupply, period));
        {
            //  ----- We increase the allowed margin for coverage                                                                      //
            uint256 maxPullableCoverage = __.increaseCredit + __.traces.coverageIncreaseLimit;
            //  ----- We only pull funds if there is a difference with the reported slashed balance and the amount covered by          //
            //        the vPool                                                                                                        //
            if (maxPullableCoverage > 0 && _coveredBalanceSum < rprt.slashedSum) {
                uint256 maxCoverableAmount = LibUint256.min(rprt.slashedSum - _coveredBalanceSum, maxPullableCoverage);
                __.traces.pulledCoverageFunds = uint128(_pullCoverage(maxCoverableAmount));
                __.traces.delta += int128(__.traces.pulledCoverageFunds);
            }
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Storage---------------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  ----- The last report is saved and exposed via external view methods                                                       //
        $lastReport.update(rprt);
        //                                                                                                                             //
        //  ----- Now that funds and internal buffers are updated, we retrieve the final total underlying supply and total supply      //
        __.traces.postUnderlyingSupply = uint128(_totalUnderlyingSupply());
        __.traces.postSupply = uint128(_totalSupply());
        __.traces.decreaseLimit = uint128(_maxAllowedBalanceDecrease(__.traces.preUnderlyingSupply));
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Delta Checks----------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  ----- We ensure that we're not crossing the bounds after pulling everything we had to pull                                 //
        if (__.traces.delta > 0) {
            //  ----- As delta is positive, we check for upper bound crossing                                                          //
            if (__.traces.pulledCoverageFunds > 0) {
                // ----- If we pulled coverage funds, we check for boosted upper bound crossing                                        //
                if (uint256(int256(__.traces.delta)) > __.traces.increaseLimit + __.traces.coverageIncreaseLimit) {
                    revert BoostedBoundCrossed(uint256(int256(__.traces.delta)), __.traces.increaseLimit, __.traces.coverageIncreaseLimit);
                }
            } else {
                // ----- If we didn't pull coverage funds, we check for normal upper bound crossing                                    //
                if (uint256(int256(__.traces.delta)) > __.traces.increaseLimit) {
                    revert UpperBoundCrossed(uint256(int256(__.traces.delta)), __.traces.increaseLimit);
                }
            }
        } else {
            //  ----- As delta is negative, we check for lower bound crossing                                                          //
            if (uint256(-int256(__.traces.delta)) > __.traces.decreaseLimit) {
                revert LowerBoundCrossed(uint256(-int256(__.traces.delta)), __.traces.decreaseLimit);
            }
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Exit Queue Funding & Deposit Commitments------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  Based on the total deposited amount and the reported maximum committable amount, we commit an amount of eth that is a      //
        //  multiple of 32 eth. This prevents eth from being stuck while it could be used for exits                                    //
        //  Then if we have funds left uncommitted, we add them to the exit boost buffer, extra funds that can be used for feeding     //
        //  the exit queue                                                                                                             //
        //                                                                                                                             //
        //  ----- We compute the amount committable and the exit boost buffer size                                                     //
        //        The committed amount is 0 if max committable is negative                                                             //
        uint256 deposited = $ethers.get().deposited;
        if (deposited > 0) {
            uint256 commitment = LibUint256.min(deposited, rprt.maxCommittable > 0 ? uint256(rprt.maxCommittable) : 0);
            commitment -= commitment % LibConstant.DEPOSIT_SIZE;

            if (commitment > 0) {
                _setCommittedEthers(uint128($ethers.get().committed + commitment));
            }

            //  We take everything except the committed eth into account into the exit boost buffer. This buffer contains deposit eth  //
            //  take can be used to pay for user tickets in the exit queue.                                                            //
            __.traces.exitBoostEthers = uint128(deposited - commitment);
            __.traces.postUnderlyingSupply -= __.traces.exitBoostEthers;
            //  Now that all the eth have been moved to the exit boost buffer, we can reset the deposited amount to 0                  //
            _setDepositedEthers(0);
            deposited = 0;
        }
        //                                                                                                                             //
        //  ----- If funds are available to feed the exit queue, we compute the appropriate amount of shares to fill and burn based on //
        //        total demand and fund availability                                                                                   //
        address _exitQueue = $exitQueue.get();
        uint256 exitQueueBalance = _balanceOf(_exitQueue);
        //                                                                                                                             //
        //  ----- We compute the exiting projection, which is the amount of ethers that is expected to be exited soon                  //
        //        This amount is based on the exiting amount, which is the amount of eth detected in the exit flow of the              //
        //        consensus layer, and the amount of unfulfilled exit requests that are expected to be triggered by the                //
        //        operator soon                                                                                                        //
        __.traces.exitingProjection = rprt.exiting;
        uint256 currentRequestedExits = $requestedExits.get();
        if (currentRequestedExits > rprt.stoppedCount) {
            __.traces.exitingProjection += uint128((currentRequestedExits - rprt.stoppedCount) * LibConstant.DEPOSIT_SIZE);
        }
        if (exitQueueBalance > 0) {
            //                                                                                                                         //
            //  ----- We retrieve temporary supply values, needed to compute the exit queue demand and capacity                        //
            //        We are adding both newExitedEthers and exitBoostEthers to the total underlying supply because                    //
            //        both are not accounted anywhere in the storage values tracking the underlying supply yet.                        //
            uint256 postUnderlyingSupplyIncludingExitAllocation =
                uint128(__.traces.postUnderlyingSupply + __.traces.newExitedEthers + __.traces.exitBoostEthers);
            __.exitDemand = LibUint256.mulDiv(exitQueueBalance, postUnderlyingSupplyIncludingExitAllocation, __.traces.postSupply);
            if (__.traces.newExitedEthers + __.traces.exitBoostEthers > 0) {
                __.traces.exitBurnedShares = uint128(exitQueueBalance);
                //                                                                                                                     //
                //  ----- We compute the base fulfillable amount, which is constrained by the new exited ethers, funds dedicated to    //
                //        feeding the exit queue                                                                                       //
                __.traces.baseFulfillableDemand = uint128(LibUint256.min(__.exitDemand, __.traces.newExitedEthers));
                //                                                                                                                     //
                //  ----- We compute the extra demand as the demand exceeding the base fulfillable demand                              //
                uint256 extraDemand = LibUint256.max(__.exitDemand, __.traces.newExitedEthers) - __.traces.newExitedEthers;
                //  ----- This value is the maxiumum theoretical amount of exit demand we can fulfill based on the eth that is         //
                //        currently expected to arrive to the contract.                                                                //
                uint256 totalFulfillableDemand = extraDemand - LibUint256.min(extraDemand, __.traces.exitingProjection);
                //                                                                                                                     //
                //  ----- We then compute the extra fulfillable amount by taking into account the exiting projection, in order to      //
                //        maximize the deposit volume. The goal is to not use deposit funds if the exiting projection is already       //
                //        covering the demand. We will only be able to cover what is exceeding the exiting projection                  //
                __.traces.extraFulfillableDemand = uint128(LibUint256.min(totalFulfillableDemand, __.traces.exitBoostEthers));
                //                                                                                                                     //
                //  ----- The ether amount we can feed is then computed by summing the base fulfillable demand and the extra           //
                __.traces.exitFedEthers = __.traces.baseFulfillableDemand + __.traces.extraFulfillableDemand;
                //                                                                                                                     //
                //  ----- We prevent feeding the queue if we're not filling all the demand and not above the minimum threshold         //
                //                                                                                                                     //
                if (__.traces.exitFedEthers < __.exitDemand) {
                    if (__.traces.exitFedEthers < MINIMUM_EXIT_QUEUE_PARTIAL_FEED) {
                        __.traces.exitFedEthers = 0;
                        __.traces.exitBurnedShares = 0;
                    } else {
                        __.traces.exitBurnedShares = uint128(
                            LibUint256.mulDiv(__.traces.exitFedEthers, __.traces.postSupply, postUnderlyingSupplyIncludingExitAllocation)
                        );
                    }
                }
                //                                                                                                                     //
                if (__.traces.exitBurnedShares > 0) {
                    //                                                                                                                 //
                    //  ----- The shares are burned                                                                                    //
                    _burn(__.traces.exitBurnedShares, _exitQueue);
                    //                                                                                                                 //
                    //  ----- We send the funds to the exit queue, with their associated shares value                                  //
                    IvExitQueue(_exitQueue).feed{value: __.traces.exitFedEthers}(__.traces.exitBurnedShares);
                    //                                                                                                                 //
                    //  ----- We update the supply value in the traces                                                                 //
                    __.traces.postSupply -= __.traces.exitBurnedShares;
                    //                                                                                                                 //
                    //  ----- We update the exit demand by subtracting the amount of eth provided to the exit queue                    //
                    __.exitDemand -= __.traces.exitFedEthers;
                } else {
                    //                                                                                                                 //
                    //  ----- In the very rare case where we end up here, we reset the exit queue feed values to not interfere with    //
                    //        the next accounting logics                                                                               //
                    __.traces.exitFedEthers = 0;
                    __.traces.exitBurnedShares = 0;
                }
            }
        }
        //                                                                                                                             //
        //  ----- If there is some exit ethers that wasn't used to feed the exit queue, we move these funds back into the deposited    //
        //        eth buffer.                                                                                                          //
        //        At this point, we are sure deposited == 0, this is why we override and not increment the cached value.               //
        if (__.traces.exitFedEthers < __.traces.newExitedEthers + __.traces.exitBoostEthers) {
            deposited = uint128((__.traces.newExitedEthers + __.traces.exitBoostEthers) - __.traces.exitFedEthers);
            __.traces.postUnderlyingSupply += uint128(deposited);
            _setDepositedEthers(uint128(deposited));
        }
        //                                                                                                                             //
        //  ----- We compute the amount committable after the exit queue was fed and only if maxCommitable is negative                 //
        if (deposited > 0 && rprt.maxCommittable < 0) {
            uint256 commitment = LibUint256.min(deposited, uint256(-rprt.maxCommittable));
            commitment -= commitment % LibConstant.DEPOSIT_SIZE;
            if (commitment > 0) {
                _setDepositedEthers(uint128(deposited - commitment));
                _setCommittedEthers(uint128($ethers.get().committed + commitment));
            }
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Commissions-----------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  Now that we have pulled all required funds, we have been able to compute the delta in balance, and the amount of rewards   //
        //  gathered by the protocol. This amount only includes rewards from skimming and from the execution layer recipient. Funds    //
        //  from the coverage recipient are not accounted as rewards.                                                                  //
        //  From this information, we can then distribute the rewards to the operator treasury.                                        //
        //                                                                                                                             //
        if (__.traces.rewards > 0) {
            __.traces.postSupply += uint128(_distributeRewards(uint256(int256(__.traces.rewards))));
        }
        //                                                                                                                             //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Finalize--------------------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  ----- The tracked covered amount is updated                                                                                //
        if (__.traces.pulledCoverageFunds > 0) {
            _coveredBalanceSum += __.traces.pulledCoverageFunds;
            $coveredBalanceSum.set(_coveredBalanceSum);
        }
        //                                                                                                                             //
        //  ----- And if we covered more than the slashing balance sum, we revert                                                      //
        if (_coveredBalanceSum > rprt.slashedSum) {
            revert CoverageHigherThanLoss(_coveredBalanceSum, rprt.slashedSum);
        }
        //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //  ---Post-Report actions---------------------------------------------------------------------------------------------------  //
        //  -------------------------------------------------------------------------------------------------------------------------  //
        //                                                                                                                             //
        //  After the checks, we can now perform async actions meant for the next reporting round. Here we will analyze the exit       //
        //  demand from the exit queue and request the appropriate amount of validator to exit to cover the demand in ethers           //
        //                                                                                                                             //
        //  ----- If exit demand is not null, we compute the amount of validator we should exit and forward the info to the factory    //
        {
            uint256 initialRequestedExits = currentRequestedExits;
            currentRequestedExits = LibUint256.max(currentRequestedExits, rprt.stoppedCount);
            if (__.exitDemand > __.traces.exitingProjection) {
                uint256 newExitRequests =
                    LibUint256.ceil(LibUint256.min(__.exitDemand - __.traces.exitingProjection, rprt.maxExitable), LibConstant.DEPOSIT_SIZE);
                if (newExitRequests > 0) {
                    currentRequestedExits = IvWithdrawalRecipient($withdrawalRecipient.get()).requestTotalExits(
                        $factory.get(), uint32(currentRequestedExits + newExitRequests)
                    );
                }
            }
            if (currentRequestedExits != initialRequestedExits) {
                _setRequestedExits(uint32(currentRequestedExits));
            }
        }
        //                                                    _                    _                                                   //
        //                                                   | |                  | |                                                  //
        //                                                 __| | ___  _ __   ___  | |                                                  //
        //                                                / _` |/ _ \| '_ \ / _ \ | |                                                  //
        //                                               | (_| | (_) | | | |  __/ |_|                                                  //
        //                                                \__,_|\___/|_| |_|\___| (_)                                                  //
        //                                                                                                                             //
        emit ProcessedReport(rprt.epoch, rprt, __.traces);
    }

    /// @dev Internal utility to set the current requested exit count and emit and event
    /// @param newValue The new requested exits value
    function _setRequestedExits(uint32 newValue) internal {
        $requestedExits.set(newValue);
        emit SetRequestedExits(newValue);
    }

    /// @dev Internal utility to set the current deposited ether value and emit an event
    /// @param newValue new deposited ether value
    function _setDepositedEthers(uint128 newValue) internal {
        $ethers.get().deposited = newValue;
        emit SetDepositedEthers(newValue);
    }

    /// @dev Internal utility to set the current committed ether value and emit an event
    /// @param newValue new committed ether value
    // slither-disable-next-line dead-code
    function _setCommittedEthers(uint128 newValue) internal {
        $ethers.get().committed = newValue;
        emit SetCommittedEthers(newValue);
    }

    /// @dev Internal utility to retrieve the current total supply of shares
    /// @return The current total supply of shares
    function _totalSupply() internal view returns (uint256) {
        return $totalSupply.get();
    }

    /// @dev Internal utility to retrieve the current total underlying supply of ETH
    /// @return total The current total underlying supply of ETH
    function _totalUnderlyingSupply() internal view returns (uint256 total) {
        ctypes.ValidatorsReport storage lastRprt = $lastReport.get();
        total = $ethers.get().deposited + $ethers.get().committed + lastRprt.balanceSum;

        uint256 consensusLayerValidatorCount = lastRprt.activatedCount;
        uint256 executionLayerPurchasedValidatorCount = $validators.toUintA().length;
        if (consensusLayerValidatorCount < executionLayerPurchasedValidatorCount) {
            total += (executionLayerPurchasedValidatorCount - consensusLayerValidatorCount) * LibConstant.DEPOSIT_SIZE;
        }
    }

    /// @dev Internal utility to check if an epoch is the first of its frame
    /// @param epoch The epoch to verify
    /// @return True if frame first epoch
    function _isFrameFirstEpochId(uint256 epoch) internal view returns (bool) {
        return (epoch % $epochsPerFrame.get()) == 0;
    }

    /// @dev Internal utility to retrieve the timestamp of an epoch
    /// @param cls The global consensus layer specification
    /// @param epoch The epoch to convert
    /// @return The timestamp of the given epoch
    function _epochTimestamp(ctypes.ConsensusLayerSpec memory cls, uint256 epoch) internal pure returns (uint256) {
        return cls.genesisTimestamp + (epoch * cls.slotsPerEpoch * cls.secondsPerSlot);
    }

    /// @dev Internal utility to retrieve the timestamp where the epoch would be finalized
    /// @param cls The global consensus layer specification
    /// @param epoch The epoch to convert
    /// @return The timestamp when the given epoch is finalized
    function _finalized(ctypes.ConsensusLayerSpec memory cls, uint256 epoch) internal pure returns (uint256) {
        uint256 epochTimestamp = _epochTimestamp(cls, epoch);
        return epochTimestamp + (cls.epochsUntilFinal * cls.slotsPerEpoch * cls.secondsPerSlot);
    }

    /// @dev Internal utility to verify if an epoch is valid for a report
    /// @param epoch The epoch to verify
    /// @return True if epoch is valid
    // slither-disable-next-line timestamp
    function _isValidEpoch(uint256 epoch) internal view returns (bool) {
        uint256 expectedEpoch = ($lastReport.get().epoch + $epochsPerFrame.get());
        if (epoch < expectedEpoch) {
            return false;
        }
        ctypes.ConsensusLayerSpec memory cls = $consensusLayerSpec.get();
        uint256 finalizedTimestamp = _finalized(cls, epoch);
        return !(block.timestamp < finalizedTimestamp) && _isFrameFirstEpochId(epoch);
    }

    /// @dev Internal utility that reverts if epoch is invalid
    /// @param cls The global consensus layer specification
    /// @param epoch The epoch to verify
    // slither-disable-next-line timestamp
    function _onlyValidEpoch(ctypes.ConsensusLayerSpec memory cls, uint256 epoch) internal view {
        uint256 expectedEpoch = ($lastReport.get().epoch + $epochsPerFrame.get());
        if (epoch < expectedEpoch) {
            revert EpochTooOld(epoch, expectedEpoch);
        }
        uint256 finalizedTimestamp = _finalized(cls, epoch);
        if (block.timestamp < finalizedTimestamp) {
            revert EpochNotFinal(epoch, block.timestamp, finalizedTimestamp);
        }
        if (!_isFrameFirstEpochId(epoch)) {
            revert EpochNotFrameFirst(epoch);
        }
    }

    /// @dev Internal utility to compute the maximum allowed balance increase in the given period of time
    /// @param balance The total balance of the vPool in ETH
    /// @param period The period to use in seconds
    /// @return The maximum increase in balance for the given period
    function _maxAllowedBalanceIncrease(uint256 balance, uint256 period) internal view returns (uint256) {
        return (balance * $reportBounds.get().maxAPRUpperBound * period) / (LibConstant.BASIS_POINTS_MAX * 365 days);
    }

    /// @dev Internal utility to compute the maximum allowed extra coverage.
    ///      This is an extra upper bound that is only usable when covering funds.
    /// @param balance The total balance of the vPool in ETH
    /// @param period The period to use in seconds
    /// @return The maximum coverage increase in balance above the regular upper bound
    function _maxCoverageBalanceIncrease(uint256 balance, uint256 period) internal view returns (uint256) {
        return (balance * $reportBounds.get().maxAPRUpperCoverageBoost * period) / (LibConstant.BASIS_POINTS_MAX * 365 days);
    }

    /// @dev Internal utility to compute the maximum allowed balance decrease
    /// @param balance The total balance of the vPool in ETH
    /// @return The maximum allowed balance decrease
    function _maxAllowedBalanceDecrease(uint256 balance) internal view returns (uint256) {
        return (balance * $reportBounds.get().maxRelativeLowerBound) / LibConstant.BASIS_POINTS_MAX;
    }

    /// @dev Internal utility to mint new shares of the vPool
    /// @param amount The amount of shares to mint
    /// @param currentTotalSupply The current total supply
    /// @param owner The address receiving the shares
    function _mint(uint256 amount, uint256 currentTotalSupply, address owner) internal {
        $balances.get()[owner.k()] += amount;
        currentTotalSupply += amount;
        $totalSupply.set(currentTotalSupply);
        emit Mint(owner, amount, currentTotalSupply);
        emit Transfer(address(0), owner, amount);
        _acceptanceChecks(address(this), address(0), owner, amount, "");
    }

    /// @dev Internal utility to burns shares of the vPool
    /// @param amount The amount of shares to burn
    /// @param owner The address burning the shares
    function _burn(uint256 amount, address owner) internal {
        $balances.get()[owner.k()] -= amount;
        uint256 newTotalSupply = $totalSupply.get() - amount;
        $totalSupply.set(newTotalSupply);
        emit Transfer(owner, address(0), amount);
        emit Burn(owner, amount, newTotalSupply);
    }

    /// @dev Internal utility to transfer shares of the vPool
    /// @param operator The address of the operator of the transfer
    /// @param from The address sending the shares
    /// @param to The address receiving the shares
    /// @param amount The amount of shares transfered
    /// @param data The attached extra data
    function _transfer(address operator, address from, address to, uint256 amount, bytes memory data) internal returns (bool) {
        uint256 balance = $balances.get()[from.k()];
        if (balance < amount) {
            revert BalanceTooLow(from, balance, amount);
        }

        emit Transfer(from, to, amount);

        unchecked {
            $balances.get()[from.k()] = balance - amount;
        }
        $balances.get()[to.k()] += amount;

        _acceptanceChecks(operator, from, to, amount, data);

        return true;
    }

    /// @dev Internal utility to consume approval from an operator.
    ///      If the approval was the max uint256 value, no change is done.
    /// @param owner The owner of the shares
    /// @param operator The approved operator
    /// @param amount The amount of approval to consume
    function _consumeApproval(address owner, address operator, uint256 amount) internal {
        uint256 approval = $approvals.get()[owner][operator];
        if (approval < amount) {
            revert AllowanceTooLow(owner, operator, approval, amount);
        }
        if (approval != type(uint256).max) {
            unchecked {
                approval -= amount;
            }
            $approvals.get()[owner][operator] = approval;
            emit Approval(owner, operator, approval);
        }
    }

    /// @dev Internal utility to perform transfer checks when sending shares to a contract.
    ///      It is expected that receiving contracts implement the IvPoolSharesReceiver interface.
    /// @param operator The address of the operator of the transfer
    /// @param from The address sending the shares
    /// @param to The address receiving the shares
    /// @param amount The amount of shares being transfered
    /// @param data The attached extra data to forward to the contract
    // slither-disable-next-line variable-scope,unused-return
    function _acceptanceChecks(address operator, address from, address to, uint256 amount, bytes memory data) internal {
        if (to.code.length > 0) {
            // slither-disable-next-line uninitialized-local
            try IvPoolSharesReceiver(to).onvPoolSharesReceived(operator, from, amount, data) returns (bytes4 response) {
                if (response != IvPoolSharesReceiver.onvPoolSharesReceived.selector) {
                    revert ShareReceiverError("vPoolSharesReceiver rejected tokens");
                }
                // slither-disable-next-line uninitialized-local
            } catch Error(string memory reason) {
                revert ShareReceiverError(reason);
            } catch {
                revert ShareReceiverError("receiver paniced or is not vPoolSharesReceiver");
            }
        }
    }

    /// @dev Internal utility to set the global validator extra data
    /// @param newExtraData New extra data value to use
    function _setValidatorGlobalExtraData(string calldata newExtraData) internal {
        $validatorGlobalExtraData.set(newExtraData);
        emit SetValidatorGlobalExtraData(newExtraData);
    }

    /// @dev Internal utility to set the operator fee value
    /// @param operatorFeeBps The new operator fee in bps
    function _setOperatorFee(uint256 operatorFeeBps) internal {
        LibSanitize.notInvalidBps(operatorFeeBps);
        $operatorFeeBps.set(operatorFeeBps);
        emit SetOperatorFee(operatorFeeBps);
    }

    /// @dev Internal utility to set the size of a frame in epochs
    /// @param newEpochsPerFrame New count of epochs inside a frame
    function _setEpochsPerFrame(uint256 newEpochsPerFrame) internal {
        $epochsPerFrame.set(newEpochsPerFrame);
        emit SetEpochsPerFrame(newEpochsPerFrame);
    }

    /// @dev Internal utility to set the consensus layer spec
    /// @param consensusLayerSpec_ The new consensus layer spec
    function _setConsensusLayerSpec(ctypes.ConsensusLayerSpec memory consensusLayerSpec_) internal {
        ctypes.ConsensusLayerSpec storage cls = $consensusLayerSpec.get();
        cls.genesisTimestamp = consensusLayerSpec_.genesisTimestamp;
        cls.epochsUntilFinal = consensusLayerSpec_.epochsUntilFinal;
        cls.slotsPerEpoch = consensusLayerSpec_.slotsPerEpoch;
        cls.secondsPerSlot = consensusLayerSpec_.secondsPerSlot;
        emit SetConsensusLayerSpec(consensusLayerSpec_);
    }

    /// @dev Internal utility to set the reporting bounds
    /// @param maxAPRUpperBound The new max allowed upper bound APR
    /// @param maxAPRUpperCoverageBoost The new max increase in the upper bound for coverage funds
    /// @param maxRelativeLowerBound The new max decrease allowed
    function _setReportBounds(uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound) internal {
        ctypes.ReportBounds storage rbs = $reportBounds.get();
        rbs.maxAPRUpperBound = maxAPRUpperBound;
        rbs.maxAPRUpperCoverageBoost = maxAPRUpperCoverageBoost;
        rbs.maxRelativeLowerBound = maxRelativeLowerBound;
        emit SetReportBounds(maxAPRUpperBound, maxAPRUpperCoverageBoost, maxRelativeLowerBound);
    }

    /// @dev Internal utility to distribute rewards to operator
    /// @param rewards Amount of ETH generated as rewards on the consensus layer
    function _distributeRewards(uint256 rewards) internal returns (uint256 sharesToMint) {
        uint256 currentTotalSupply = _totalSupply();
        uint256 currentTotalUnderlyingSupply = _totalUnderlyingSupply();
        uint256 operatorFeeBps = $operatorFeeBps.get();

        uint256 numerator = rewards * currentTotalSupply * operatorFeeBps;
        uint256 denominator = (currentTotalUnderlyingSupply * LibConstant.BASIS_POINTS_MAX) - (rewards * operatorFeeBps);

        if (denominator != 0) {
            sharesToMint = numerator / denominator;
            if (sharesToMint > 0) {
                address operatorTreasury = IvFactory($factory.get()).treasury();
                currentTotalSupply += sharesToMint;
                emit DistributedOperatorRewards(
                    operatorTreasury,
                    sharesToMint,
                    LibUint256.mulDiv(sharesToMint, currentTotalUnderlyingSupply, currentTotalSupply),
                    currentTotalSupply,
                    currentTotalUnderlyingSupply
                );
                _mint(sharesToMint, currentTotalSupply - sharesToMint, operatorTreasury);
            }
        }
    }

    /// @dev Internal utility to pull exec layer fees from the exec layer recipient
    /// @param max The maximum allowed amount of ETH to pull
    /// @return The actual value pulled into the system
    function _pullExecLayerFees(uint256 max) internal returns (uint256) {
        IvExecLayerRecipient elr = IvExecLayerRecipient(payable($execLayerRecipient.get()));
        if (!elr.hasFunds()) {
            return 0;
        }
        uint256 currentBalance = address(this).balance;
        elr.pull(max);
        return address(this).balance - currentBalance;
    }

    /// @dev Internal utility to pull exec layer fees from the exec layer recipient
    /// @param max The maximum allowed amount of ETH to pull
    /// @return The actual value pulled into the system
    function _pullExitQueueUnclaimedFunds(uint256 max) internal returns (uint256) {
        IvExitQueue eq = IvExitQueue(payable($exitQueue.get()));
        uint256 currentBalance = address(this).balance;
        eq.pull(max);
        return address(this).balance - currentBalance;
    }

    /// @dev Internal utility to pull coverage funds from the coverage recipient.
    ///      The coverage recipient can fulfill this task by injecting ETH or voiding vPool shares.
    /// @param max The maximum allowed amount of ETH to pull
    /// @return The actual value pulled into the system
    function _pullCoverage(uint256 max) internal returns (uint256) {
        IvCoverageRecipient cr = IvCoverageRecipient(payable($coverageRecipient.get()));
        if (!cr.hasFunds()) {
            return 0;
        }
        uint256 preTotalSupply = _totalSupply();
        uint256 preTotalUnderlyingSupply = _totalUnderlyingSupply();
        cr.cover(max);
        uint256 postTotalSupply = _totalSupply();
        uint256 postTotalUnderlyingSupply = _totalUnderlyingSupply();

        return LibUint256.mulDiv(postTotalUnderlyingSupply, preTotalSupply, postTotalSupply) - preTotalUnderlyingSupply;
    }
}
