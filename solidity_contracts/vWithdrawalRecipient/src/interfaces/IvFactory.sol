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

import "utils.sol/interfaces/IAdministrable.sol";
import "utils.sol/interfaces/IDepositor.sol";
import "utils.sol/interfaces/IFixable.sol";

/// @title Factory Interface
/// @author mortimr @ Kiln
/// @notice The vFactory contract is in charge of depositing validators to the consensus layer
interface IvFactory is IAdministrable, IDepositor, IFixable {
    /// @notice The provided array is empty
    error EmptyArray();

    /// @notice The provided arrays do not have matching lengths
    error InvalidArrayLengths();

    /// @notice The withdrawal attempt was made on a validator that collected no funds
    error EmptyWithdrawalRecipient();

    /// @notice The provided key concatenation is empty
    /// @param index The index of the invalid key concatenation in the calldata parameters
    error EmptyKeyPayload(uint256 index);

    /// @notice The provided validator id is invalid
    /// @param id The invalid id
    error InvalidValidatorId(uint256 id);

    /// @notice The provided key concatenation is invalid
    /// @param index The index of the invalid key concatenation in the calldata parameters
    error InvalidKeyPayload(uint256 index);

    /// @notice The provided indexes array if empty
    /// @param index The index of the invalid index array in the calldata parameters
    error EmptyIndexesArray(uint256 index);

    /// @notice The provided indexes array is unsorted
    /// @param index The index of the invalid index array in the calldata parameters
    error UnsortedIndexArray(uint256 index);

    /// @notice The withdrawal call performed on the minimal recipient reverted
    /// @param rdata The resulting error return data
    error MinimalRecipientExecutionError(bytes rdata);

    /// @notice The provided withdrawal channel is invalid
    /// @param withdrawalChannel The invalid withdrawal channel
    error InvalidWithdrawalChannel(bytes32 withdrawalChannel);

    /// @notice The provided message value in ether is invalid
    /// @param received The provided amount
    /// @param expected The expected amount
    error InvalidMessageValue(uint256 received, uint256 expected);

    /// @notice The requested validator count is too high
    /// @param requested The count of validators requested
    /// @param available The count of available validators
    error NotEnoughValidators(uint256 requested, uint256 available);

    /// @notice The provided validator index is out of bounds
    /// @param index The indexes array index in the calldata
    /// @param validatorIndex The invalid validator index
    error ValidatorIndexOutOfBounds(uint256 index, uint256 validatorIndex);

    /// @notice A funded validator removal was attempted
    /// @param index The indexes array index in the calldata
    /// @param validatorIndex The funded validator index
    error FundedValidatorRemovalAttempt(uint256 index, uint256 validatorIndex);

    /// @notice Error raised when the requested total exits on a custom channel is higher than the total funded count
    /// @param withdrawalChannel The withdrawal channel
    /// @param requestedTotal The total requested exits
    /// @param maxFundedCount The count of funded validators on the channel
    error ExitTotalTooHigh(bytes32 withdrawalChannel, uint32 requestedTotal, uint32 maxFundedCount);

    /// @notice Error raised when the requested limit on a withdrawal channel is higher than the validators count.
    /// @param withdrawalChannel The withdrawal channel
    /// @param limit The limit requested
    /// @param validatorCount The count of validators on the channel
    error LimitExceededValidatorCount(bytes32 withdrawalChannel, uint256 limit, uint256 validatorCount);

    /// @notice Emitted when the minimal recipient implementation is set
    /// @param minimalRecipientImplementation The address of the implementation
    event SetMinimalRecipientImplementation(address minimalRecipientImplementation);

    /// @notice Emitted when hatcher registry is set
    /// @param hatcherRegistry The address of the hatcher registry
    event SetHatcherRegistry(address hatcherRegistry);

    /// @notice Emitted when the operator changed
    /// @param operator The new operator address
    event ChangedOperator(address operator);

    /// @notice Emitted when the treasury changed
    /// @param treasury The new treasury address
    event ChangedTreasury(address treasury);

    /// @notice Emitted when an exit request was made
    /// @param withdrawalChannel The withdrawal channel that received the exit request
    /// @param publicKey The public key of the validator that requested the exit
    /// @param id The id of the validator that requested the exit
    event ExitValidator(bytes32 indexed withdrawalChannel, bytes publicKey, uint256 id);

    /// @notice Emitted when the owner of a validator is changed
    /// @param id The id of the validator
    /// @param owner The new owner address
    event SetValidatorOwner(uint256 indexed id, address owner);

    /// @notice Emitted when the metadata of the vFactory is changed
    /// @param name The operator name
    /// @param url The operator shared url
    /// @param iconUrl The operator icon
    event SetMetadata(string name, string url, string iconUrl);

    /// @notice Emitted when a depositor authorization changed
    /// @param depositor The address of the depositor
    /// @param wc The withdrawal channel
    /// @param allowed True if allowed to deposit
    event ApproveDepositor(address indexed depositor, bytes32 indexed wc, bool allowed);

    /// @notice Emitted when new keys are added to a withdrawal channel
    /// @param withdrawalChannel The withdrawal channel that received new keys
    /// @param keys The keys that were added
    event AddedValidators(bytes32 indexed withdrawalChannel, bytes keys);

    /// @notice Emitted when the staking limit has been changed for a withdrawal channel
    /// @param withdrawalChannel The withdrawal channel that had its limit updated
    /// @param limit The new staking limit of the withdrawal channel
    event UpdatedLimit(bytes32 indexed withdrawalChannel, uint256 limit);

    /// @notice Emitted when funds have been withdrawn from a validator withdrawal recipient
    /// @param id The id of the validator
    /// @param recipient The address receiving the funds
    /// @param value The value that was withdrawn
    event Withdraw(uint256 indexed id, address recipient, uint256 value);

    /// @notice Emitted when a validator extra data is changed
    /// @param id The id of the validator
    /// @param extraData The new extra data value
    event SetValidatorExtraData(uint256 indexed id, string extraData);

    /// @notice Emitted when a validator fee recipient is changed
    /// @param id The id of the validator
    /// @param feeRecipient The new fee recipient address
    event SetValidatorFeeRecipient(uint256 indexed id, address feeRecipient);

    /// @notice Emitted when keys are requested on a withdrawal channel
    /// @param withdrawalChannel The withdrawal channel where keys have been requested
    /// @param total The expect total key count of the channel
    event ValidatorRequest(bytes32 indexed withdrawalChannel, uint256 total);

    /// @notice Emitted when a channel exit request is above the funded count
    /// @param funded The count of funded validators on the channel
    /// @param requestedTotal The total requested exits
    event ExitRequestAboveFunded(uint32 funded, uint32 requestedTotal);

    /// @notice Emitted when a validator key has been removed from a withdrawal channel
    /// @param withdrawalChannel The withdrawal channel where the key has been removed
    /// @param publicKey The public key that has been removed
    /// @param validatorIndex The index of the removed validator key
    event RemovedValidator(bytes32 indexed withdrawalChannel, bytes publicKey, uint256 validatorIndex);

    /// @notice Emitted when a validator key is funded
    /// @param withdrawalChannel The withdrawal channel where the validator got funded
    /// @param depositor The address of the depositor bringing the funds for the validator
    /// @param withdrawalAddress The address of the withdrawal recipient
    /// @param publicKey The BLS Public key of the funded validator
    /// @param id The unique id of the validator
    /// @param validatorIndex The index of the funded validator in the withdrawal channel
    event FundedValidator(
        bytes32 indexed withdrawalChannel,
        address indexed depositor,
        address indexed withdrawalAddress,
        bytes publicKey,
        uint256 id,
        uint256 validatorIndex
    );

    /// @notice Emitted when the total exit for a custom withdrawal channel is changed
    /// @param withdrawalChannel The withdrawal channel where the exit count is changed
    /// @param totalExited The new total exited value
    event SetExitTotal(bytes32 indexed withdrawalChannel, uint32 totalExited);

    /// @notice Emitted when the last edit is after the snapshot (when editing the limit). The snapshot limit is staled.
    /// @param withdrawalChannel The withdrawal channel
    /// @param limit The limit requested
    event LastEditAfterSnapshot(bytes32 indexed withdrawalChannel, uint256 limit);

    /// @notice Initializes the vFactory
    /// @dev Can only be called once
    /// @param depositContract Address of the deposit contract to use
    /// @param admin Address of the contract admin
    /// @param operator_ Address of the contract operator
    /// @param treasury_ Address of the treasury
    /// @param minimalRecipientImplementation Address used by the clones as implementation for the withdrawal recipients
    /// @param hatcherRegistry Contract holding the hatcher registry
    function initialize(
        string memory name,
        address depositContract,
        address admin,
        address operator_,
        address treasury_,
        address minimalRecipientImplementation,
        address hatcherRegistry
    ) external;

    /// @notice Retrieve the current operator address
    /// @return The operator address
    function operator() external view returns (address);

    /// @notice Retrieve the current treasury address
    /// @return The treasury address
    function treasury() external view returns (address);

    /// @notice Retrieve the depositor status
    /// @param depositor Address to verify
    /// @param wc Withdrawal channel to verify
    /// @return Status of the depositor
    function depositors(address depositor, bytes32 wc) external view returns (bool);

    /// @notice Retrieve the details of a validator by its unique id
    /// @param id ID of the validator
    /// @return found True if the ID matches a validator
    /// @return funded True if the validator is funded
    /// @return wc The withdrawal channel of the validator
    /// @return index The index of the validator in the withdrawal channel
    /// @return publicKey The BLS public key of the validator
    /// @return signature The BLS signature of the validator
    /// @return owner The address owning the validator
    /// @return withdrawalRecipient The address where the withdrawal rewards will go to
    /// @return feeRecipient The address where the execution layer fees are expected to go to
    function validator(uint256 id)
        external
        view
        returns (
            bool found,
            bool funded,
            bytes32 wc,
            uint256 index,
            bytes memory publicKey,
            bytes memory signature,
            address owner,
            address withdrawalRecipient,
            address feeRecipient
        );

    /// @notice Retrieve the details of a validator by its unique id
    /// @param ids IDs of the validators
    /// @return  Public keys of the provided IDs
    function publicKeys(uint256[] calldata ids) external view returns (bytes[] memory);

    /// @notice Retrieve the details of a key in a withdrawalChannel
    /// @param wc The withdrawal channel the key is stored in
    /// @param index The index of the key in the withdrawal channel
    /// @return found True if there's a key at the given index in the withdrawal channel
    /// @return publicKey The BLS public key of the validator
    /// @return signature The BLS signature of the validator
    /// @return withdrawalRecipient The address where the withdrawal rewards will go to
    function key(bytes32 wc, uint256 index)
        external
        view
        returns (bool found, bytes memory publicKey, bytes memory signature, address withdrawalRecipient);

    /// @notice Retrieve the number of validators owned by an account in a specific withdrawal channel
    /// @param wc The withdrawal channel to inspect
    /// @param owner The account owning the validators
    /// @return The number of owned validators in the withdrawal channel
    function balance(bytes32 wc, address owner) external view returns (uint256);

    /// @notice Retrieve the key details of the withdrawal channel
    /// @param wc The withdrawal channel to inspect
    /// @return total The total count of deposited keys
    /// @return limit The staking limit of the channel
    /// @return funded The count of funded validators
    function withdrawalChannel(bytes32 wc) external view returns (uint32 total, uint32 limit, uint32 funded);

    /// @notice Retrieve the operator public metadata
    /// @return name The operator name. Cannot be empty.
    /// @return url The operator shared url. Can be empty.
    /// @return iconUrl The operator icon url
    function metadata() external view returns (string memory name, string memory url, string memory iconUrl);

    /// @notice Retrieve the withdrawal address for the specified public key
    /// @dev This is only useful on the null withdrawal channel where the vFactory spawns
    ///      minimal clones deterministically as the withdrawal recipients of each validator.
    /// @param publicKey The BLS Public Key of the validator
    /// @return The address where the minimal clone will be deployed to retrieve the consensus layer rewards
    function withdrawalAddress(bytes calldata publicKey) external view returns (address);

    /// @notice Retrieve the count of fundable validators on a withdrawal channel
    /// @param wc The withdrawal channel to inspect
    /// @return The count of fundable validators
    function availableValidators(bytes32 wc) external view returns (uint256);

    /// @notice Changes the operator address
    /// @dev Only callable by the admin
    /// @param newOperator New operator address
    function setOperator(address newOperator) external;

    /// @notice Changes the operator public metadata
    /// @param name The operator name. Cannot be empty.
    /// @param url The operator shared url. Can be empty.
    /// @param iconUrl The operator icon url
    function setMetadata(string calldata name, string calldata url, string calldata iconUrl) external;

    /// @notice Add or remove depositor
    /// @dev Callable by the admin of the factory or the nexus
    /// @param depositor The address to add or remove
    /// @param wc The withdrawal channel to add or remove the depositor from
    /// @param allowed True to allow as depositor
    function allowDepositor(address depositor, bytes32 wc, bool allowed) external;

    /// @notice Emits an event signaling a request in keys on a specific withdrawal channel
    /// @param wc The withdrawal channel to perform the request on
    /// @param amount The amount of keys that should be added to the channel
    function request(bytes32 wc, uint256 amount) external;

    /// @notice Adds keys to several withdrawal channels
    /// @dev It's expected that the provided withdrawalChannels and _keys have the same length.
    ///      For each withdrawalChannel, a concatenation of [S1,P1,S2,P2...,SN,PN] is expected.
    ///      S = BLS Signature and P = BLS Public Key. Signature should come first in each pair.
    /// @param withdrawalChannels The list of withdrawal channels to add keys on
    /// @param keys The list of key concatenations to add to the withdrawal channels
    function addValidators(bytes32[] calldata withdrawalChannels, bytes[] calldata keys) external;

    /// @notice Removes keys from several withdrawal channels
    /// @dev It's expected that the provided withdrawalChannels and _indexes have the same length.
    ///      For each withdrawalChannel, an array of indexes is expected. These indexes should be sorted in descending order.
    ///      Each array should not contain any duplicate index.
    /// @param withdrawalChannels The list of withdrawal channels to add keys on
    /// @param indexes The list of lists of indexes to remove from the withdrawal channels
    function removeValidators(bytes32[] calldata withdrawalChannels, uint256[][] calldata indexes) external;

    /// @notice Modifies the staking limits of several withdrawal channels
    /// @dev It's expected that the provided withdrawalChannels, _limits and _snapshots have the same length
    ///      For each withdrawalChannel, a new limit is provided alongside a snapshot block number.
    ///      If the new limit value decreases the current one, no extra check if performed and the limit is decreased.
    ///      If the new limit value increases the current one, we check that no key modifictions have been done after
    ///      the provided snapshot block. If it's the case, we don't update the limit and we don't revert, we simply
    ///      emit an event alerting that the last key edition happened after the snapshot. Otherwise the limit is increased.
    /// @param withdrawalChannels The list of withdrawal channels to update the limits
    /// @param limits The list of new staking limits values
    /// @param snapshots The list of block snapshots to respect if the limit is increased
    function approve(bytes32[] calldata withdrawalChannels, uint256[] calldata limits, uint256[] calldata snapshots) external;

    /// @notice Deposits _count validators on the provided withdrawal channel
    /// @dev This call reverts if the count of available keys is too low on the withdrawal channel
    /// @param wc The withdrawal channel to fund keys on
    /// @param count The amount of keys to fund
    /// @param feeRecipient The fee recipient to set all the funded keys on
    /// @param owner The address owning the validators
    /// @param extradata The extra data to transmit to the node operator
    /// @return An array of unique IDs identifying the funded validators
    function deposit(bytes32 wc, uint256 count, address feeRecipient, address owner, string calldata extradata)
        external
        payable
        returns (uint256[] memory);

    /// @notice Changes the fee recipient of several validators
    /// @dev Only callable by the owner of the validators
    /// @param ids The list of validator IDs
    /// @param newFeeRecipient The new fee recipient address
    function setFeeRecipient(uint256[] calldata ids, address newFeeRecipient) external;

    /// @notice Changes the owner of several validators
    /// @dev Only callable by the owner of the validators
    /// @param ids The list of validator IDs
    /// @param newOwner The new owner address
    function setOwner(uint256[] calldata ids, address newOwner) external;

    /// @notice Changes the extradata of several validators
    /// @dev Only callable by the owner of the validators
    /// @param ids The list of validator IDs
    /// @param newExtradata The new validator extra data
    function setExtraData(uint256[] calldata ids, string calldata newExtradata) external;

    /// @notice Emits an exit request event for several validators
    /// @dev Only callable by the owner of the validators
    /// @param ids The list of validator IDs
    function exit(uint256[] calldata ids) external;

    /// @notice Perform a consensus layer withdrawal on several validators
    /// @dev Only callable by the owner of the validators and on funded validators from the null withdrawal channel
    /// @param ids The list of validator IDs
    /// @param recipient The address that should receive the funds, that implements the WithdrawRecipientLike interface
    function withdraw(uint256[] calldata ids, address recipient) external;

    /// @notice Requests a new total exited validator count for the withdrawal recipient calling the method
    /// @dev This endpoint is callable by any address, it's up to the operator to properly filter the calls
    ///      based on existing withdrawal channels only.
    /// @param totalExited The new total exited validator count for the withdrawal channel
    /// @return The new total exited validator count for the withdrawal channel
    function exitTotal(uint32 totalExited) external returns (uint32);
}
