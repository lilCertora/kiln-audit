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

import "openzeppelin-contracts/proxy/Clones.sol";
import "utils.sol/Fixable.sol";
import "utils.sol/Administrable.sol";
import "utils.sol/Initializable.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/Depositor.sol";
import "utils.sol/libs/LibKey.sol";
import "utils.sol/types/bool.sol";
import "utils.sol/types/mapping.sol";

import "./interfaces/IvFactory.sol";
import "./interfaces/utils/WithdrawRecipientLike.sol";
import "./interfaces/IMinimalRecipient.sol";
import "./interfaces/IMinimalRecipientOwner.sol";
import "./ctypes/factory_depositor_mapping.sol";
import "./ctypes/deposit_mapping.sol";
import "./ctypes/withdrawal_channel_mapping.sol";
import "./ctypes/balance_mapping.sol";
import "./ctypes/metadata_struct.sol";

/// @title Factory
/// @author mortimr @ Kiln
/// @notice The vFactory contract inherits the base Depositor contract and is in charge of depositing validators to the consensus layer
// slither-disable-next-line naming-convention
contract vFactory is Depositor, Administrable, Initializable, Implementation, Fixable, IvFactory, IMinimalRecipientOwner {
    /// L for Libraries
    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;
    using LDepositMapping for ctypes.DepositMapping;
    using LWithdrawalChannelMapping for ctypes.WithdrawalChannelMapping;
    using LBalanceMapping for ctypes.BalanceMapping;
    using LMetadataStruct for ctypes.MetadataStruct;
    using LFactoryDepositorMapping for ctypes.FactoryDepositorMapping;

    /// C for Converters
    using CAddress for address;
    using CUint256 for uint256;
    using CBool for bool;

    /// @dev Unstructured Storage Pointer for vfactory.operator.
    ///      The operator in charge of managing the keys.
    /// @dev Slot: keccak256(bytes("factory.1.operator")) - 1
    types.Address internal constant $operator = types.Address.wrap(0x2f60c0db736aeffd52f4fbe926906d19bff04d2b9a6e0e4c3de0c404f9159306);

    /// @dev Unstructured Storage Pointer for vfactory.treasury.
    ///      The treasury, exposed by the contract.
    /// @dev Slot: keccak256(bytes("factory.1.treasury")) - 1
    types.Address internal constant $treasury = types.Address.wrap(0x02c77dbb697e57f3596131ed59ddceb4a0e05451fe6c52f07ecfc89c71d8c0fd);

    /// @dev Unstructured Storage Pointer for vfactory.hatcherRegistry.
    ///         The hatcher registry, used to plug new depositors.
    /// @dev Slot: keccak256(bytes("factory.1.hatcherRegistry")) - 1
    types.Address internal constant $hatcherRegistry =
        types.Address.wrap(0xa48bfa9f73021e68bfa1326bf6e29f6a98a7d7b1181c8899024549fb61a750ba);

    /// @dev Unstructured Storage Pointer for vfactory.ids.
    ///      The unique id counter.
    /// @dev Slot: keccak256(bytes("factory.1.ids")) - 1
    types.Uint256 internal constant $ids = types.Uint256.wrap(0xdf44afce51016c965a36edf8c692d8f132816933dde3838ae52ee0de1692a8b8);

    /// @dev Unstructured Storage Pointer for vfactory.depositors.
    ///      The mapping of allowed depositors.
    /// @dev Type: mapping(address => mapping(bytes32 => bool))
    /// @dev Slot: keccak256(bytes("factory.1.depositors")) - 1
    ctypes.FactoryDepositorMapping internal constant $depositors =
        ctypes.FactoryDepositorMapping.wrap(0x582302a6d084fee140e5e82bbf37f610db53bf0589b9c3c06a316cf3e8387e51);

    /// @dev Unstructured Storage Pointer for vfactory.minimalRecipientImplementation.
    ///      The address of the minimalRecipientImplementation.
    /// @dev Slot: keccak256(bytes("factory.1.minimalRecipientImplementation")) - 1
    types.Address internal constant $minimalRecipientImplementation =
        types.Address.wrap(0x2b2b1a159f590a788c5103216ce5a429d3c4a2e4a192e720a387e40748ebad21);

    /// @dev Unstructured Storage Pointer for vfactory.deposits.
    ///      The mapping of deposits.
    /// @dev Type: mapping(uint256 => ctypes.Deposit)
    /// @dev Slot: keccak256(bytes("factory.1.deposits")) - 1
    ctypes.DepositMapping internal constant $deposits =
        ctypes.DepositMapping.wrap(0x3d21a0a68bdc94f9a96726da5f50358d858d94bcff89a92c5211388fb5889261);

    /// @dev Unstructured Storage Pointer for vfactory.withdrawalChannels.
    ///      The mapping of withdrawal channels.
    /// @dev Type: mapping(bytes32 => ctypes.WithdrawalChannel)
    /// @dev Slot: keccak256(bytes("factory.1.withdrawalChannels")) - 1
    ctypes.WithdrawalChannelMapping internal constant $withdrawalChannels =
        ctypes.WithdrawalChannelMapping.wrap(0xcd286c1552b730c80a7dfd5b7600a5e250212beabb4fc0e9e2e49d110083fd22);

    /// @dev Unstructured Storage Pointer for vfactory.balances.
    ///      The mapping of balances per withdrawal channel.
    /// @dev Type: mapping(bytes32 => mapping(address => uint256))
    /// @dev Slot: keccak256(bytes("factory.1.balances")) - 1
    ctypes.BalanceMapping internal constant $balances =
        ctypes.BalanceMapping.wrap(0x68df73e3b646dd5d4cc00361743ca1b2bd3b7c03578787aafc0bc57f104418bc);

    /// @dev Unstructured Storage Pointer for vfactory.metadata
    ///      The operator public metadata
    /// @dev Slot: keccak256(bytes("factory.1.metadata")) - 1
    ctypes.MetadataStruct internal constant $metadata =
        ctypes.MetadataStruct.wrap(0x66de6835de7b7200ec1c0936575a79fef655ee027edbac32b50733fe4cc51e7b);

    /// @inheritdoc IvFactory
    function initialize(
        string calldata name,
        address depositContract,
        address admin,
        address operator_,
        address treasury_,
        address minimalRecipientImplementation,
        address hatcherRegistry
    ) external init(0) {
        LibSanitize.notZeroAddress(minimalRecipientImplementation);
        LibSanitize.notZeroAddress(hatcherRegistry);

        Depositor._setDepositContract(depositContract);
        Administrable._setAdmin(admin);
        _setOperator(operator_);
        _setTreasury(treasury_);
        $minimalRecipientImplementation.set(minimalRecipientImplementation);
        emit SetMinimalRecipientImplementation(minimalRecipientImplementation);
        $hatcherRegistry.set(hatcherRegistry);
        emit SetHatcherRegistry(hatcherRegistry);
        $ids.set(1);
        _setMetadata(name, "", "");
    }

    /// @notice Only allows the operator or the admin to perform the call
    modifier onlyOperatorOrAdmin() {
        if (msg.sender != $operator.get() && msg.sender != Administrable._getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @notice Only allows the admin or the hatcher to perform the call
    modifier onlyAdminOrHatcherRegistry() {
        if (msg.sender != Administrable._getAdmin() && msg.sender != $hatcherRegistry.get()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @notice Only allows the depositor to perform the call
    modifier onlyDepositor(bytes32 wc) {
        if (!$depositors.get()[msg.sender][wc]) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @notice Only allows the depositor, the operator or the admin
    modifier onlyDepositorOperatorOrAdmin(bytes32 wc) {
        if (!$depositors.get()[msg.sender][wc] && msg.sender != $operator.get() && msg.sender != Administrable._getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @inheritdoc IvFactory
    function operator() external view returns (address) {
        return $operator.get();
    }

    /// @inheritdoc IvFactory
    function treasury() external view returns (address) {
        return $treasury.get();
    }

    /// @inheritdoc IvFactory
    function depositors(address depositor, bytes32 wc) external view returns (bool) {
        return $depositors.get()[depositor][wc];
    }

    /// @inheritdoc IvFactory
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
        )
    {
        mapping(uint256 => ctypes.Deposit) storage dm = $deposits.get();
        ctypes.Deposit memory d = dm[id];
        if (d.index > 0) {
            found = true;
            wc = d.withdrawalChannel;
            index = d.index - 1;
            owner = d.owner;
            mapping(bytes32 => ctypes.WithdrawalChannel) storage withdrawalChannels = $withdrawalChannels.get();
            funded = withdrawalChannels[wc].funded > index;
            ctypes.Validator memory v = withdrawalChannels[wc].validators[index];
            publicKey = LibPublicKey.toBytes(v.publicKey);
            signature = LibSignature.toBytes(v.signature);
            if (wc == bytes32(0)) {
                withdrawalRecipient = _getWithdrawalAddress(publicKey);
            } else {
                withdrawalRecipient = address(uint160(uint256(wc)));
            }

            feeRecipient = v.feeRecipient;
        }
    }

    /// @inheritdoc IvFactory
    function publicKeys(uint256[] calldata ids) external view returns (bytes[] memory publicKeys_) {
        uint256 requestLength = ids.length;
        publicKeys_ = new bytes[](requestLength);

        mapping(uint256 => ctypes.Deposit) storage dm = $deposits.get();
        mapping(bytes32 => ctypes.WithdrawalChannel) storage withdrawalChannels = $withdrawalChannels.get();

        for (uint256 idx = 0; idx < requestLength;) {
            ctypes.Deposit memory d = dm[ids[idx]];
            if (d.index == 0) {
                publicKeys_[idx] = "";
            } else {
                publicKeys_[idx] = LibPublicKey.toBytes(withdrawalChannels[d.withdrawalChannel].validators[d.index - 1].publicKey);
            }

            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function key(bytes32 wc, uint256 index)
        external
        view
        returns (bool found, bytes memory publicKey, bytes memory signature, address withdrawalRecipient)
    {
        mapping(bytes32 => ctypes.WithdrawalChannel) storage withdrawalChannels = $withdrawalChannels.get();
        if (index < withdrawalChannels[wc].validators.length) {
            found = true;
            ctypes.Validator memory v = withdrawalChannels[wc].validators[index];
            publicKey = LibPublicKey.toBytes(v.publicKey);
            signature = LibSignature.toBytes(v.signature);
            if (wc == bytes32(0)) {
                withdrawalRecipient = _getWithdrawalAddress(publicKey);
            } else {
                withdrawalRecipient = address(uint160(uint256(wc)));
            }
        }
    }

    /// @inheritdoc IvFactory
    function balance(bytes32 wc, address owner) external view returns (uint256) {
        return $balances.get()[wc][owner];
    }

    /// @inheritdoc IvFactory
    function withdrawalChannel(bytes32 wc) external view returns (uint32 total, uint32 limit, uint32 funded) {
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];
        total = uint32(withdrawalChannelStruct.validators.length);
        limit = withdrawalChannelStruct.limit;
        funded = withdrawalChannelStruct.funded;
    }

    /// @inheritdoc IvFactory
    /// @dev This function is not pure because it reads the metadata from storage
    function metadata() external pure returns (string memory name, string memory url, string memory iconUrl) {
        ctypes.Metadata memory mdata = $metadata.get();
        name = mdata.name;
        url = mdata.url;
        iconUrl = mdata.iconUrl;
    }

    /// @inheritdoc IvFactory
    function withdrawalAddress(bytes calldata publicKey) external view returns (address) {
        return _getWithdrawalAddress(publicKey);
    }

    /// @inheritdoc IvFactory
    function availableValidators(bytes32 wc) external view returns (uint256) {
        return _availableValidators(wc);
    }

    /// @inheritdoc IMinimalRecipientOwner
    function autoClaimDetails(uint256 id) external view returns (address beneficiary, bool enabled) {
        // will always return enabled=false
        // the idea is to add this feature to our immutable minimal recipient, but not yet on the
        // vsuite stack.
        // This feature will probably get added by allowing depositors to set this bool for every
        // deposited validator. When setting this bool to true, we also deploy the recipient and set
        // the fee recipient to it,
        // otherwise we keep this passive deployment approach for the validators that do not want autoClaim.
        // Auto claiming is meant to increase the UX around retrieving rewards, but can come at a higher overall
        // gas cost due to to incertainty around the moment and the gas cost of the auto claim tx transactions.
        // In the case of block builders, we cannot control when our validator will propose a block and receive
        // a tx towards our minimal recipient with the execution layer rewards.
        // This approach can have increased benefits for validators that would be held by smart contracts as they
        // wouldn't need to have keepers to claim their rewards, but also for end users that have many validators
        // and don't want to go through the hassle of claiming rewards for each of them.
        enabled = false;

        mapping(uint256 => ctypes.Deposit) storage dm = $deposits.get();
        ctypes.Deposit memory d = dm[id];
        if (d.index > 0) {
            beneficiary = d.owner;
        }
    }

    /// @inheritdoc IvFactory
    function setOperator(address newOperator) external onlyAdmin {
        _setOperator(newOperator);
    }

    /// @inheritdoc IvFactory
    function setMetadata(string calldata name, string calldata url, string calldata iconUrl) external onlyAdmin {
        _setMetadata(name, url, iconUrl);
    }

    /// @inheritdoc IvFactory
    function allowDepositor(address depositor, bytes32 wc, bool allowed) external onlyAdminOrHatcherRegistry {
        $depositors.get()[depositor][wc] = allowed;
        emit ApproveDepositor(depositor, wc, allowed);
    }

    /// @inheritdoc IvFactory
    function request(bytes32 wc, uint256 amount) external onlyDepositorOperatorOrAdmin(wc) {
        ctypes.WithdrawalChannel storage withdrawalChannels = $withdrawalChannels.get()[wc];

        emit ValidatorRequest(wc, amount + LibUint256.max(withdrawalChannels.limit, withdrawalChannels.funded));
    }

    /// @inheritdoc IvFactory
    function addValidators(bytes32[] calldata withdrawalChannels, bytes[] calldata keys) external onlyOperatorOrAdmin {
        uint256 withdrawalChannelCount = withdrawalChannels.length;
        if (withdrawalChannelCount != keys.length) {
            revert InvalidArrayLengths();
        }
        if (keys.length == 0) {
            revert EmptyArray();
        }

        for (uint256 wcidx = 0; wcidx < withdrawalChannelCount;) {
            uint256 keyLength = keys[wcidx].length;
            if (keyLength % (LibKey.KEY_PAIR_LENGTH) > 0) {
                revert InvalidKeyPayload(wcidx);
            }
            if (keyLength == 0) {
                revert EmptyKeyPayload(wcidx);
            }

            _addValidatorsToWithdrawalChannel(withdrawalChannels[wcidx], keys[wcidx]);

            unchecked {
                ++wcidx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function removeValidators(bytes32[] calldata withdrawalChannels, uint256[][] calldata indexes) external onlyOperatorOrAdmin {
        uint256 withdrawalChannelCount = withdrawalChannels.length;
        if (withdrawalChannelCount != indexes.length) {
            revert InvalidArrayLengths();
        }
        if (indexes.length == 0) {
            revert EmptyArray();
        }

        for (uint256 wcidx = 0; wcidx < withdrawalChannelCount;) {
            uint256 indexesLength = indexes[wcidx].length;
            if (indexesLength == 0) {
                revert EmptyIndexesArray(wcidx);
            }

            _removeValidatorsFromWithdrawalChannel(withdrawalChannels[wcidx], indexes[wcidx], wcidx);

            unchecked {
                ++wcidx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function approve(bytes32[] calldata withdrawalChannels, uint256[] calldata limits, uint256[] calldata snapshots) external onlyAdmin {
        uint256 withdrawalChannelCount = withdrawalChannels.length;
        if (withdrawalChannelCount != limits.length || limits.length != snapshots.length) {
            revert InvalidArrayLengths();
        }
        if (withdrawalChannelCount == 0) {
            revert EmptyArray();
        }

        for (uint256 wcidx = 0; wcidx < withdrawalChannelCount;) {
            _approve(withdrawalChannels[wcidx], limits[wcidx], snapshots[wcidx]);
            unchecked {
                ++wcidx;
            }
        }
    }

    struct DepositVariables {
        ctypes.Validator v;
        uint256 lastId;
        uint256 validatorId;
        uint256[] ids;
    }

    /// @inheritdoc IvFactory
    function deposit(bytes32 wc, uint256 count, address feeRecipient, address owner, string calldata extradata)
        external
        payable
        onlyDepositor(wc)
        returns (uint256[] memory)
    {
        LibSanitize.notZeroAddress(feeRecipient);
        LibSanitize.notZeroAddress(owner);

        // slither-disable-next-line uninitialized-local
        DepositVariables memory __;

        if (count * LibConstant.DEPOSIT_SIZE != msg.value) {
            revert InvalidMessageValue(msg.value, count * LibConstant.DEPOSIT_SIZE);
        }

        {
            uint256 currentAvailableValidators = _availableValidators(wc);
            if (count > currentAvailableValidators) {
                revert NotEnoughValidators(count, currentAvailableValidators);
            }
        }

        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];
        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();

        __.lastId = $ids.get();
        __.ids = new uint256[](count);

        for (uint256 idx = 0; idx < count;) {
            __.v = withdrawalChannelStruct.validators[withdrawalChannelStruct.funded + idx];

            bytes memory publicKey = LibPublicKey.toBytes(__.v.publicKey);
            address computedWithdrawalAddress = wc == bytes32(0) ? _getWithdrawalAddress(publicKey) : address(uint160(uint256(wc)));
            _deposit(publicKey, LibSignature.toBytes(__.v.signature), computedWithdrawalAddress);

            withdrawalChannelStruct.validators[withdrawalChannelStruct.funded + idx].feeRecipient = feeRecipient;

            __.validatorId = __.lastId + idx;
            __.ids[idx] = __.validatorId;
            ds[__.validatorId] = ctypes.Deposit({index: withdrawalChannelStruct.funded + idx + 1, withdrawalChannel: wc, owner: owner});

            emit FundedValidator(wc, msg.sender, computedWithdrawalAddress, publicKey, __.validatorId, withdrawalChannelStruct.funded + idx);
            emit SetValidatorOwner(__.validatorId, owner);
            emit SetValidatorFeeRecipient(__.validatorId, feeRecipient);
            emit SetValidatorExtraData(__.validatorId, extradata);

            unchecked {
                ++idx;
            }
        }

        $balances.get()[wc][owner] += count;

        $ids.set(__.lastId + count);
        withdrawalChannelStruct.funded += uint32(count);

        return __.ids;
    }

    /// @inheritdoc IvFactory
    function setFeeRecipient(uint256[] calldata ids, address newFeeRecipient) external {
        LibSanitize.notZeroAddress(newFeeRecipient);

        if (ids.length == 0) {
            revert EmptyArray();
        }

        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();
        mapping(bytes32 => ctypes.WithdrawalChannel) storage withdrawalChannels = $withdrawalChannels.get();

        uint256 idsLength = ids.length;

        for (uint256 idx = 0; idx < idsLength;) {
            uint256 id = ids[idx];

            ctypes.Deposit storage d = ds[id];

            if (d.index == 0) {
                revert InvalidValidatorId(id);
            }

            if (d.owner != msg.sender) {
                revert LibErrors.Unauthorized(msg.sender, d.owner);
            }

            withdrawalChannels[d.withdrawalChannel].validators[d.index - 1].feeRecipient = newFeeRecipient;

            emit SetValidatorFeeRecipient(id, newFeeRecipient);

            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function setOwner(uint256[] calldata ids, address newOwner) external {
        LibSanitize.notZeroAddress(newOwner);

        uint256 idsLength = ids.length;

        if (idsLength == 0) {
            revert EmptyArray();
        }

        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();
        mapping(bytes32 => mapping(address => uint256)) storage bs = $balances.get();

        for (uint256 idx = 0; idx < idsLength;) {
            uint256 id = ids[idx];

            ctypes.Deposit memory d = ds[id];

            if (d.index == 0) {
                revert InvalidValidatorId(id);
            }

            if (d.owner != msg.sender) {
                revert LibErrors.Unauthorized(msg.sender, d.owner);
            }

            ds[id].owner = newOwner;

            emit SetValidatorOwner(id, newOwner);

            unchecked {
                bytes32 channel = d.withdrawalChannel;
                --bs[channel][msg.sender];
                ++bs[channel][newOwner];
                ++idx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function setExtraData(uint256[] calldata ids, string calldata extradata) external {
        uint256 idsLength = ids.length;

        if (idsLength == 0) {
            revert EmptyArray();
        }

        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();

        for (uint256 idx = 0; idx < idsLength;) {
            uint256 id = ids[idx];

            ctypes.Deposit memory d = ds[id];

            if (d.index == 0) {
                revert InvalidValidatorId(id);
            }

            if (d.owner != msg.sender) {
                revert LibErrors.Unauthorized(msg.sender, d.owner);
            }

            emit SetValidatorExtraData(id, extradata);

            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function exit(uint256[] calldata ids) external {
        uint256 idsLength = ids.length;

        if (idsLength == 0) {
            revert EmptyArray();
        }

        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();
        mapping(bytes32 => ctypes.WithdrawalChannel) storage wcs = $withdrawalChannels.get();

        for (uint256 idx = 0; idx < idsLength;) {
            uint256 id = ids[idx];

            ctypes.Deposit memory d = ds[id];

            if (d.index == 0) {
                revert InvalidValidatorId(id);
            }

            if (d.owner != msg.sender) {
                revert LibErrors.Unauthorized(msg.sender, d.owner);
            }

            emit ExitValidator(d.withdrawalChannel, LibPublicKey.toBytes(wcs[d.withdrawalChannel].validators[d.index - 1].publicKey), id);

            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IvFactory
    function exitTotal(uint32 totalExited) external returns (uint32) {
        LibSanitize.notNullValue(totalExited);
        bytes32 wc = LibAddress.toWithdrawalCredentials(msg.sender);
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];
        uint32 funded = withdrawalChannelStruct.funded;
        if (totalExited > funded) {
            emit ExitRequestAboveFunded(funded, totalExited);
            totalExited = funded;
        }
        emit SetExitTotal(wc, totalExited);
        return totalExited;
    }

    /// @inheritdoc IvFactory
    function withdraw(uint256[] calldata ids, address recipient) external {
        LibSanitize.notZeroAddress(recipient);

        uint256 idsLength = ids.length;

        if (idsLength == 0) {
            revert EmptyArray();
        }

        mapping(uint256 => ctypes.Deposit) storage ds = $deposits.get();

        for (uint256 idx = 0; idx < idsLength;) {
            uint256 id = ids[idx];

            _withdraw(id, ds[id], recipient);

            unchecked {
                ++idx;
            }
        }
    }

    /// @dev Sets the address of the operator
    /// @param newOperator New address for the operator
    function _setOperator(address newOperator) internal {
        LibSanitize.notZeroAddress(newOperator);
        emit ChangedOperator(newOperator);
        $operator.set(newOperator);
    }

    /// @dev Sets the address of the treasury
    /// @param newTreasury New address for the treasury
    function _setTreasury(address newTreasury) internal {
        LibSanitize.notZeroAddress(newTreasury);
        emit ChangedTreasury(newTreasury);
        $treasury.set(newTreasury);
    }

    /// @dev Sets the metadata details
    /// @param name Name of the operator
    /// @param url Optional url
    /// @param iconUrl Optional icon url
    function _setMetadata(string memory name, string memory url, string memory iconUrl) internal {
        LibSanitize.notEmptyString(name);
        ctypes.Metadata storage m = $metadata.get();
        m.name = name;
        m.url = url;
        m.iconUrl = iconUrl;
        emit SetMetadata(name, url, iconUrl);
    }

    /// @dev Internal utility to retrieve the current fundable key count on a withdrawal channel
    /// @param wc The withdrawal channel to inspect
    /// @return The count of fundable keys on the channel
    function _availableValidators(bytes32 wc) internal view returns (uint256) {
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];

        return withdrawalChannelStruct.limit - withdrawalChannelStruct.funded;
    }

    /// @dev Internal utility to perform all checks and update the staking limit of a withdrawal channel
    /// @param wc The withdrawal channel to update the staking limit of
    /// @param limit The new staking limit
    /// @param snapshot The snapshot block number to respect in case of limit increase
    function _approve(bytes32 wc, uint256 limit, uint256 snapshot) internal {
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];
        uint256 currentLimit = withdrawalChannelStruct.limit;
        if (limit == currentLimit) {
            emit UpdatedLimit(wc, limit);
        } else if (limit < currentLimit) {
            uint32 newLimit = limit < withdrawalChannelStruct.funded ? withdrawalChannelStruct.funded : uint32(limit);
            withdrawalChannelStruct.limit = newLimit;
            emit UpdatedLimit(wc, newLimit);
        } else {
            if (snapshot < withdrawalChannelStruct.lastEdit) {
                emit LastEditAfterSnapshot(wc, limit);
                return;
            }
            if (limit > withdrawalChannelStruct.validators.length) {
                revert LimitExceededValidatorCount(wc, limit, withdrawalChannelStruct.validators.length);
            }
            withdrawalChannelStruct.limit = uint32(limit);
            emit UpdatedLimit(wc, limit);
        }
    }

    /// @dev Internal utility to add several keys to a withdrawal channel
    /// @param wc The withdrawal to add keys on
    /// @param keys The key concatenation to split and add to the withdrawal channel
    function _addValidatorsToWithdrawalChannel(bytes32 wc, bytes calldata keys) internal {
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];

        uint256 keyCount = keys.length / (LibKey.KEY_PAIR_LENGTH);

        for (uint256 kidx = 0; kidx < keyCount;) {
            (LibPublicKey.PublicKey memory publicKey, LibSignature.Signature memory signature) =
                LibKey.fromBytes(LibBytes.slice(keys, kidx * LibKey.KEY_PAIR_LENGTH, LibKey.KEY_PAIR_LENGTH));
            withdrawalChannelStruct.validators.push(
                ctypes.Validator({publicKey: publicKey, signature: signature, feeRecipient: address(0)})
            );

            unchecked {
                ++kidx;
            }
        }

        emit AddedValidators(wc, keys);
        withdrawalChannelStruct.lastEdit = block.number;
    }

    /// @dev Internal utility to remove keys from a withdrawal channel
    /// @param wc The withdrawal channel to remove keys from
    /// @param indexes The list of key indexes to remove from the withdrawal channel.
    ///                Indexes are supposed to be in a decreasing order and in the range [funded, totalValidators).
    /// @param index The index of the withdrawal channel in the initial array, only used for errors.
    function _removeValidatorsFromWithdrawalChannel(bytes32 wc, uint256[] calldata indexes, uint256 index) internal {
        ctypes.WithdrawalChannel storage withdrawalChannelStruct = $withdrawalChannels.get()[wc];

        uint256 indexesCount = indexes.length;
        uint256 totalValidatorCount = withdrawalChannelStruct.validators.length;
        uint256 smallestIndex = indexes[indexesCount - 1];

        // We are assuming that the indexes are sorted in descending order.
        // The descending order is checked after (in the for loop).
        if (indexes[0] >= totalValidatorCount) revert ValidatorIndexOutOfBounds(index, indexes[0]);
        if (smallestIndex < withdrawalChannelStruct.funded) revert FundedValidatorRemovalAttempt(index, smallestIndex);

        for (uint256 idx = 0; idx < indexesCount;) {
            uint256 indexToRemove = indexes[idx];
            if (idx > 0 && indexToRemove >= indexes[idx - 1]) {
                revert UnsortedIndexArray(index);
            }

            ctypes.Validator memory removedValidator = withdrawalChannelStruct.validators[indexToRemove];

            if (indexToRemove != totalValidatorCount - 1) {
                withdrawalChannelStruct.validators[indexToRemove] = withdrawalChannelStruct.validators[totalValidatorCount - 1];
            }
            withdrawalChannelStruct.validators.pop();

            emit RemovedValidator(wc, LibPublicKey.toBytes(removedValidator.publicKey), indexToRemove);

            unchecked {
                --totalValidatorCount;
                ++idx;
            }
        }

        if (withdrawalChannelStruct.limit > smallestIndex) {
            withdrawalChannelStruct.limit = uint32(smallestIndex);
            emit UpdatedLimit(wc, smallestIndex);
        }

        withdrawalChannelStruct.lastEdit = block.number;
    }

    /// @dev Internal utility to retrieve the deterministic withdrawal address from the BLS public key
    /// @param publicKey The BLS public key
    /// @return The deterministic withdrawal address
    function _getWithdrawalAddress(bytes memory publicKey) internal view returns (address) {
        return Clones.predictDeterministicAddress($minimalRecipientImplementation.get(), keccak256(publicKey));
    }

    /// @dev Internal utility to deploy the deterministic withdrawal address from the BLS public key
    /// @param publicKey The BLS public key
    /// @return The deployed deterministic withdrawal address
    function _deployWithdrawalAddress(bytes memory publicKey) internal returns (address) {
        return Clones.cloneDeterministic($minimalRecipientImplementation.get(), keccak256(publicKey));
    }

    /// @dev Internal utility to perform a withdrawal on the deterministic withdrawal address
    /// @param id The validator id
    /// @param d The deposit to withdraw
    /// @param recipient The address receiving the funds
    // slither-disable-next-line reentrancy-events,calls-loop
    function _withdraw(uint256 id, ctypes.Deposit memory d, address recipient) internal {
        if (d.index == 0) revert InvalidValidatorId(id);

        if (d.owner != msg.sender) revert LibErrors.Unauthorized(msg.sender, d.owner);

        if (d.withdrawalChannel != bytes32(0)) revert InvalidWithdrawalChannel(d.withdrawalChannel);

        ctypes.Validator storage v = $withdrawalChannels.get()[bytes32(0)].validators[d.index - 1];

        bytes memory publicKey = LibPublicKey.toBytes(v.publicKey);

        address withdrawalRecipient = _getWithdrawalAddress(publicKey);
        uint256 recipientBalance = withdrawalRecipient.balance;

        // slither-disable-next-line incorrect-equality
        if (recipientBalance == 0) {
            revert EmptyWithdrawalRecipient();
        }

        if (withdrawalRecipient.code.length == 0) {
            _deployWithdrawalAddress(publicKey);
            IMinimalRecipient(payable(withdrawalRecipient)).init(address(this), id);
        }

        (bool success, bytes memory rdata) = IMinimalRecipient(payable(withdrawalRecipient)).exec(
            recipient, abi.encodeCall(WithdrawRecipientLike.withdrawCallback, (id, publicKey, recipientBalance)), recipientBalance
        );
        if (!success) {
            revert MinimalRecipientExecutionError(rdata);
        }
        emit Withdraw(id, recipient, recipientBalance);
    }
}
