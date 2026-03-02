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

/// @title Pool Interface
/// @author mortimr @ Kiln
/// @notice The vPool contract is in charge of pool funds and fund validators from the vFactory
interface IvPool is IFixable {
    /// @notice Emitted at construction time when all contract addresses are set
    /// @param factory The address of the vFactory contract
    /// @param withdrawalRecipient The address of the withdrawal recipient contract
    /// @param execLayerRecipient The address of the execution layer recipient contract
    /// @param coverageRecipient The address of the coverage recipient contract
    /// @param oracleAggregator The address of the oracle aggregator contract
    /// @param exitQueue The address of the exit queue contract
    event SetContractLinks(
        address factory,
        address withdrawalRecipient,
        address execLayerRecipient,
        address coverageRecipient,
        address oracleAggregator,
        address exitQueue
    );

    /// @notice Emitted when the global validator extra data is changed
    /// @param extraData New extra data used on validator purchase
    event SetValidatorGlobalExtraData(string extraData);

    /// @notice Emitted when a depositor authorization changed
    /// @param depositor The address of the depositor
    /// @param allowed True if allowed to deposit
    event ApproveDepositor(address depositor, bool allowed);

    /// @notice Emitted when a depositor performs a deposit
    /// @param sender The transaction sender
    /// @param amount The deposit amount
    /// @param mintedShares The amount of shares created
    event Deposit(address indexed sender, uint256 amount, uint256 mintedShares);

    /// @notice Emitted when the vPool purchases validators to the vFactory
    /// @param validators The list of IDs (not BLS Public keys)
    event PurchasedValidators(uint256[] validators);

    /// @notice Emitted when new shares are created
    /// @param account The account receiving the new shares
    /// @param amount The amount of shares created
    /// @param totalSupply The new totalSupply value
    event Mint(address indexed account, uint256 amount, uint256 totalSupply);

    /// @notice Emitted when shares are burned
    /// @param burner The account burning shares
    /// @param amount The amount of burned shares
    /// @param totalSupply The new totalSupply value
    event Burn(address burner, uint256 amount, uint256 totalSupply);

    /// @notice Emitted when shares are transfered
    /// @param from The account sending the shares
    /// @param to The account receiving the shares
    /// @param value The value transfered
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when shares are approved for a spender
    /// @param owner The account approving the shares
    /// @param spender The account receiving the spending rights
    /// @param value The value of the approval. Max uint256 means infinite (will never decrease)
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when shares are voided (action of burning without redeeming anything on purpose)
    /// @param voider The account voiding the shares
    /// @param amount The amount of voided shares
    event VoidedShares(address voider, uint256 amount);

    /// @notice Emitted when ether is injected into the system (outside of the deposit flow)
    /// @param injecter The account injecting the ETH
    /// @param amount The amount of injected ETH
    event InjectedEther(address injecter, uint256 amount);

    /// @notice Emitted when the report processing is finished
    /// @param epoch The epoch number
    /// @param report The received report structure
    /// @param traces Internal traces with key figures
    event ProcessedReport(uint256 indexed epoch, ctypes.ValidatorsReport report, ReportTraces traces);

    /// @notice Emitted when rewards are distributed to the node operator
    /// @param operatorTreasury The address receiving the rewards
    /// @param sharesCount The amount of shares created to pay the rewards
    /// @param sharesValue The value in ETH of the newly minted shares
    /// @param totalSupply The updated totalSupply value
    /// @param totalUnderlyingSupply The updated totalUnderlyingSupply value
    event DistributedOperatorRewards(
        address indexed operatorTreasury, uint256 sharesCount, uint256 sharesValue, uint256 totalSupply, uint256 totalUnderlyingSupply
    );

    /// @notice Emitted when the report bounds are updated
    /// @param maxAPRUpperBound The maximum APR allowed during oracle reports
    /// @param maxAPRUpperCoverageBoost The APR boost allowed only for coverage funds
    /// @param maxRelativeLowerBound The max relative delta in underlying supply authorized during losses of funds
    event SetReportBounds(uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound);

    /// @notice Emitted when the epochs per frame value is updated
    /// @param epochsPerFrame The new epochs per frame value
    event SetEpochsPerFrame(uint256 epochsPerFrame);

    /// @notice Emitted when the consensus layer spec is updated
    /// @param consensusLayerSpec The new consensus layer spec
    event SetConsensusLayerSpec(ctypes.ConsensusLayerSpec consensusLayerSpec);

    /// @notice Emitted when the operator fee is updated
    /// @param operatorFeeBps The new operator fee value
    event SetOperatorFee(uint256 operatorFeeBps);

    /// @notice Emitted when the deposited ether buffer is updated
    /// @param depositedEthers The new deposited ethers value
    event SetDepositedEthers(uint256 depositedEthers);

    /// @notice Emitted when the committed ether buffer is updated
    /// @param committedEthers The new committed ethers value
    event SetCommittedEthers(uint256 committedEthers);

    /// @notice Emitted when the requested exits is updated
    /// @param newRequestedExits The new requested exits count
    event SetRequestedExits(uint32 newRequestedExits);

    /// @notice The balance was too low for the requested operation
    /// @param account The account trying to perform the operation
    /// @param currentBalance The current account balance
    /// @param requiredAmount The amount that was required to perform the operation
    error BalanceTooLow(address account, uint256 currentBalance, uint256 requiredAmount);

    /// @notice The allowance was too low for the requested operation
    /// @param account The account trying to perform the operation
    /// @param operator The account triggering the operation on behalf of the account
    /// @param currentApproval The current account approval towards the operator
    /// @param requiredAmount The amount that was required to perform the operation
    error AllowanceTooLow(address account, address operator, uint256 currentApproval, uint256 requiredAmount);

    /// @notice Thrown when approval for an account and spender is already zero.
    /// @param account The account for which approval was attempted to be set to zero.
    /// @param spender The spender for which approval was attempted to be set to zero.
    error ApprovalAlreadyZero(address account, address spender);

    /// @notice Thrown when there is an error with a share receiver.
    /// @param err The error message.
    error ShareReceiverError(string err);

    /// @notice Thrown when there is no validator available to purchase.
    error NoValidatorToPurchase();

    /// @notice Thrown when the epoch of a report is too old.
    /// @param epoch The epoch of the report.
    /// @param expectEpoch The expected epoch for the operation.
    error EpochTooOld(uint256 epoch, uint256 expectEpoch);

    /// @notice Thrown when an epoch is not the first epoch of a frame.
    /// @param epoch The epoch that was not the first epoch of a frame.
    error EpochNotFrameFirst(uint256 epoch);

    /// @notice Thrown when an epoch is not final.
    /// @param epoch The epoch that was not final.
    /// @param currentTimestamp The current timestamp.
    /// @param finalTimestamp The final timestamp of the frame.
    error EpochNotFinal(uint256 epoch, uint256 currentTimestamp, uint256 finalTimestamp);

    /// @notice Thrown when the validator count is decreasing.
    /// @param previousValidatorCount The previous validator count.
    /// @param validatorCount The current validator count.
    error DecreasingValidatorCount(uint256 previousValidatorCount, uint256 validatorCount);

    /// @notice Thrown when the stopped validator count is decreasing.
    /// @param previousStoppedValidatorCount The previous stopped validator count.
    /// @param stoppedValidatorCount The current stopped validator count.
    error DecreasingStoppedValidatorCount(uint256 previousStoppedValidatorCount, uint256 stoppedValidatorCount);

    /// @notice Thrown when the slashed balance sum is decreasing.
    /// @param reportedSlashedBalanceSum The reported slashed balance sum.
    /// @param lastReportedSlashedBalanceSum The last reported slashed balance sum.
    error DecreasingSlashedBalanceSum(uint256 reportedSlashedBalanceSum, uint256 lastReportedSlashedBalanceSum);

    /// @notice Thrown when the exited balance sum is decreasing.
    /// @param reportedExitedBalanceSum The reported exited balance sum.
    /// @param lastReportedExitedBalanceSum The last reported exited balance sum.
    error DecreasingExitedBalanceSum(uint256 reportedExitedBalanceSum, uint256 lastReportedExitedBalanceSum);

    /// @notice Thrown when the skimmed balance sum is decreasing.
    /// @param reportedSkimmedBalanceSum The reported skimmed balance sum.
    /// @param lastReportedSkimmedBalanceSum The last reported skimmed balance sum.
    error DecreasingSkimmedBalanceSum(uint256 reportedSkimmedBalanceSum, uint256 lastReportedSkimmedBalanceSum);

    /// @notice Thrown when the reported validator count is higher than the total activated validators
    /// @param stoppedValidatorsCount The reported stopped validator count.
    /// @param maxStoppedValidatorsCount The maximum allowed stopped validator count.
    error StoppedValidatorCountTooHigh(uint256 stoppedValidatorsCount, uint256 maxStoppedValidatorsCount);

    /// @notice Thrown when the reported exiting balance exceeds the total validator balance on the cl
    /// @param exiting The reported exiting balance.
    /// @param balance The total validator balance on the cl.
    error ExitingBalanceTooHigh(uint256 exiting, uint256 balance);

    /// @notice Thrown when the reported validator count is higher than the deposited validator count.
    /// @param reportedValidatorCount The reported validator count.
    /// @param depositedValidatorCount The deposited validator count.
    error ValidatorCountTooHigh(uint256 reportedValidatorCount, uint256 depositedValidatorCount);

    /// @notice Thrown when the coverage is higher than the loss.
    /// @param coverage The coverage.
    /// @param loss The loss.
    error CoverageHigherThanLoss(uint256 coverage, uint256 loss);

    /// @notice Thrown when the balance increase exceeds the maximum allowed balance increase.
    /// @param balanceIncrease The balance increase.
    /// @param maximumAllowedBalanceIncrease The maximum allowed balance increase.
    error UpperBoundCrossed(uint256 balanceIncrease, uint256 maximumAllowedBalanceIncrease);

    /// @notice Thrown when the balance increase exceeds the maximum allowed balance increase or maximum allowed coverage.
    /// @param balanceIncrease The balance increase.
    /// @param maximumAllowedBalanceIncrease The maximum allowed balance increase.
    /// @param maximumAllowedCoverage The maximum allowed coverage.
    error BoostedBoundCrossed(uint256 balanceIncrease, uint256 maximumAllowedBalanceIncrease, uint256 maximumAllowedCoverage);

    /// @notice Thrown when the balance decrease exceeds the maximum allowed balance decrease.
    /// @param balanceDecrease The balance decrease.
    /// @param maximumAllowedBalanceDecrease The maximum allowed balance decrease.
    error LowerBoundCrossed(uint256 balanceDecrease, uint256 maximumAllowedBalanceDecrease);

    /// @notice Thrown when the amount of shares to mint is computed to 0
    error InvalidNullMint();

    /// @notice Traces emitted at the end of the reporting process.
    /// @param preUnderlyingSupply The pre-reporting underlying supply.
    /// @param postUnderlyingSupply The post-reporting underlying supply.
    /// @param preSupply The pre-reporting supply.
    /// @param postSupply The post-reporting supply.
    /// @param newExitedEthers The new exited ethers.
    /// @param newSkimmedEthers The new skimmed ethers.
    /// @param exitBoostEthers The exit boost ethers.
    /// @param exitFedEthers The exit fed ethers.
    /// @param exitBurnedShares The exit burned shares.
    /// @param exitingProjection The exiting projection.
    /// @param baseFulfillableDemand The base fulfillable demand.
    /// @param extraFulfillableDemand The extra fulfillable demand.
    /// @param rewards The rewards. Can be negative when there is a loss, but cannot include coverage funds.
    /// @param delta The delta. Can be negative when there is a loss and include all pulled funds.
    /// @param increaseLimit The increase limit.
    /// @param coverageIncreaseLimit The coverage increase limit.
    /// @param decreaseLimit The decrease limit.
    /// @param consensusLayerDelta The consensus layer delta.
    /// @param pulledCoverageFunds The pulled coverage funds.
    /// @param pulledExecutionLayerRewards The pulled execution layer rewards.
    /// @param pulledExitQueueUnclaimedFunds The pulled exit queue unclaimed funds.
    struct ReportTraces {
        // supplied
        uint128 preUnderlyingSupply;
        uint128 postUnderlyingSupply;
        uint128 preSupply;
        uint128 postSupply;
        // new consensus layer funds
        uint128 newExitedEthers;
        uint128 newSkimmedEthers;
        // exit related funds
        uint128 exitBoostEthers;
        uint128 exitFedEthers;
        uint128 exitBurnedShares;
        uint128 exitingProjection;
        uint128 baseFulfillableDemand;
        uint128 extraFulfillableDemand;
        // rewards
        int128 rewards;
        // delta and details about sources of funds
        int128 delta;
        uint128 increaseLimit;
        uint128 coverageIncreaseLimit;
        uint128 decreaseLimit;
        int128 consensusLayerDelta;
        uint128 pulledCoverageFunds;
        uint128 pulledExecutionLayerRewards;
        uint128 pulledExitQueueUnclaimedFunds;
    }

    /// @notice Initializes the contract with the given parameters.
    /// @param addrs The addresses of the dependencies (factory, withdrawal recipient, exec layer recipient,
    ///              coverage recipient, oracle aggregator, exit queue).
    /// @param epochsPerFrame_ The number of epochs per frame.
    /// @param consensusLayerSpec_ The consensus layer spec.
    /// @param bounds_ The bounds for reporting.
    /// @param operatorFeeBps_ The operator fee in basis points.
    /// @param extraData_ The initial extra data that will be provided on each deposit
    function initialize(
        address[6] calldata addrs,
        uint256 epochsPerFrame_,
        ctypes.ConsensusLayerSpec calldata consensusLayerSpec_,
        uint64[3] calldata bounds_,
        uint256 operatorFeeBps_,
        string calldata extraData_
    ) external;

    /// @notice Returns the address of the factory contract.
    /// @return The address of the factory contract.
    function factory() external view returns (address);

    /// @notice Returns the address of the execution layer recipient contract.
    /// @return The address of the execution layer recipient contract.
    function execLayerRecipient() external view returns (address);

    /// @notice Returns the address of the coverage recipient contract.
    /// @return The address of the coverage recipient contract.
    function coverageRecipient() external view returns (address);

    /// @notice Returns the address of the withdrawal recipient contract.
    /// @return The address of the withdrawal recipient contract.
    function withdrawalRecipient() external view returns (address);

    /// @notice Returns the address of the oracle aggregator contract.
    /// @return The address of the oracle aggregator contract.
    function oracleAggregator() external view returns (address);

    /// @notice Returns the address of the exit queue contract
    /// @return The address of the exit queue contract
    function exitQueue() external view returns (address);

    /// @notice Returns the current validator global extra data
    /// @return The validator global extra data value
    function validatorGlobalExtraData() external view returns (string memory);

    /// @notice Returns whether the given address is a depositor.
    /// @param depositorAddress The address to check.
    /// @return Whether the given address is a depositor.
    function depositors(address depositorAddress) external view returns (bool);

    /// @notice Returns the total supply of tokens.
    /// @return The total supply of tokens.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the name of the vPool
    /// @return The name of the vPool
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the vPool
    /// @return The symbol of the vPool
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals of the vPool shares
    /// @return The decimal count
    function decimals() external pure returns (uint8);

    /// @notice Returns the total underlying supply of tokens.
    /// @return The total underlying supply of tokens.
    function totalUnderlyingSupply() external view returns (uint256);

    /// @notice Returns the current ETH/SHARES rate based on the total underlying supply and total supply.
    /// @return The current rate
    function rate() external view returns (uint256);

    /// @notice Returns the current requested exit count
    /// @return The current requested exit count
    function requestedExits() external view returns (uint32);

    /// @notice Returns the balance of the given account.
    /// @param account The address of the account to check.
    /// @return The balance of the given account.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the allowance of the given spender for the given owner.
    /// @param owner The owner of the allowance.
    /// @param spender The spender of the allowance.
    /// @return The allowance of the given spender for the given owner.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Returns the details about the held ethers
    /// @return The structure of ethers inside the contract
    function ethers() external view returns (ctypes.Ethers memory);

    /// @notice Returns an array of the IDs of purchased validators.
    /// @return An array of the IDs of purchased validators.
    function purchasedValidators() external view returns (uint256[] memory);

    /// @notice Returns the ID of the purchased validator at the given index.
    /// @param idx The index of the validator.
    /// @return The ID of the purchased validator at the given index.
    function purchasedValidatorAtIndex(uint256 idx) external view returns (uint256);

    /// @notice Returns the total number of purchased validators.
    /// @return The total number of purchased validators.
    function purchasedValidatorCount() external view returns (uint256);

    /// @notice Returns the last epoch.
    /// @return The last epoch.
    function lastEpoch() external view returns (uint256);

    /// @notice Returns the last validator report that was processed
    /// @return The last report structure.
    function lastReport() external view returns (ctypes.ValidatorsReport memory);

    /// @notice Returns the total amount in ETH covered by the contract.
    /// @return The total amount in ETH covered by the contract.
    function totalCovered() external view returns (uint256);

    /// @notice Returns the number of epochs per frame.
    /// @return  The number of epochs per frame.
    function epochsPerFrame() external view returns (uint256);

    /// @notice Returns the consensus layer spec.
    /// @return The consensus layer spec.
    function consensusLayerSpec() external pure returns (ctypes.ConsensusLayerSpec memory);

    /// @notice Returns the report bounds.
    /// @return maxAPRUpperBound The maximum APR for the upper bound.
    /// @return maxAPRUpperCoverageBoost The maximum APR for the upper bound with coverage boost.
    /// @return maxRelativeLowerBound The maximum relative lower bound.
    function reportBounds()
        external
        view
        returns (uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound);

    /// @notice Returns the operator fee.
    /// @return  The operator fee.
    function operatorFee() external view returns (uint256);

    /// @notice Returns whether the given epoch is valid.
    /// @param epoch The epoch to check.
    /// @return Whether the given epoch is valid.
    function isValidEpoch(uint256 epoch) external view returns (bool);

    /// @notice Reverts if given epoch is invalid, with an explicit custom error based on the issue
    /// @param epoch The epoch to check.
    function onlyValidEpoch(uint256 epoch) external view;

    /// @notice Allows or disallows the given depositor to deposit.
    /// @param depositorAddress The address of the depositor.
    /// @param allowed Whether the depositor is allowed to deposit.
    function allowDepositor(address depositorAddress, bool allowed) external;

    /// @notice Transfers the given amount of shares to the given address.
    /// @param to The address to transfer the shares to.
    /// @param amount The amount of shares to transfer.
    /// @param data Additional data for the transfer.
    /// @return Whether the transfer was successful.
    function transferShares(address to, uint256 amount, bytes calldata data) external returns (bool);

    /// @notice Increases the allowance for the given spender by the given amount.
    /// @param spender The spender to increase the allowance for.
    /// @param amount The amount to increase the allowance by.
    /// @return Whether the increase was successful.
    function increaseAllowance(address spender, uint256 amount) external returns (bool);

    /// @notice Decreases the allowance of a spender by the given amount.
    /// @param spender The address of the spender.
    /// @param amount The amount to decrease the allowance by.
    /// @return Whether the allowance was successfully decreased.
    function decreaseAllowance(address spender, uint256 amount) external returns (bool);

    /// @notice Voids the allowance of a spender.
    /// @param spender The address of the spender.
    /// @return Whether the allowance was successfully voided.
    function voidAllowance(address spender) external returns (bool);

    /// @notice Transfers shares from one account to another.
    /// @param from The address of the account to transfer shares from.
    /// @param to The address of the account to transfer shares to.
    /// @param amount The amount of shares to transfer.
    /// @param data Optional data to include with the transaction.
    /// @return  Whether the transfer was successful.
    function transferSharesFrom(address from, address to, uint256 amount, bytes calldata data) external returns (bool);

    /// @notice Deposits ether into the contract.
    /// @return  The number of shares minted on deposit
    function deposit() external payable returns (uint256);

    /// @notice Purchases the maximum number of validators allowed.
    /// @param max The maximum number of validators to purchase.
    function purchaseValidators(uint256 max) external;

    /// @notice Sets the operator fee.
    /// @param operatorFeeBps The new operator fee, in basis points.
    function setOperatorFee(uint256 operatorFeeBps) external;

    /// @notice Sets the number of epochs per frame.
    /// @param newEpochsPerFrame The new number of epochs per frame.
    function setEpochsPerFrame(uint256 newEpochsPerFrame) external;

    /// @notice Sets the consensus layer spec.
    /// @param consensusLayerSpec_ The new consensus layer spec.
    function setConsensusLayerSpec(ctypes.ConsensusLayerSpec calldata consensusLayerSpec_) external;

    /// @notice Sets the global validator extra data
    /// @param extraData The new extra data to use
    function setValidatorGlobalExtraData(string calldata extraData) external;

    /// @notice Sets the bounds for reporting.
    /// @param maxAPRUpperBound The maximum APR for the upper bound.
    /// @param maxAPRUpperCoverageBoost The maximum APR for the upper coverage boost.
    /// @param maxRelativeLowerBound The maximum relative value for the lower bound.
    function setReportBounds(uint64 maxAPRUpperBound, uint64 maxAPRUpperCoverageBoost, uint64 maxRelativeLowerBound) external;

    /// @notice Injects ether into the contract.
    function injectEther() external payable;

    /// @notice Voids the given amount of shares.
    /// @param amount The amount of shares to void.
    function voidShares(uint256 amount) external;

    /// @notice Reports the validator data for the given epoch.
    /// @param rprt The consensus layer report to process
    function report(ctypes.ValidatorsReport calldata rprt) external;
}
