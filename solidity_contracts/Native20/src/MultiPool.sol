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

import "utils.sol/Administrable.sol";
import "utils.sol/types/mapping.sol";
import "utils.sol/types/uint256.sol";
import "utils.sol/types/bool.sol";
import "utils.sol/types/address.sol";

import "vsuite/interfaces/IvPool.sol";
import "./interfaces/IMultiPool.sol";
import "./FeeDispatcher.sol";
import "./ExitQueueClaimHelper.sol";

uint256 constant MIN_COMMISSION_TO_SELL = 1e9; // If there is less than a gwei of commission to sell, we don't sell it

/// @title MultiPool (v1)
/// @author 0xvv @ Kiln
/// @notice This contract contains the common functions to all integration contracts
/// @notice Contains the functions to add pools, activate/deactivate a pool, change the fee of a pool and change the commission distribution
abstract contract MultiPool is IMultiPool, FeeDispatcher, Administrable, ExitQueueClaimHelper {
    using LArray for types.Array;
    using LMapping for types.Mapping;
    using LUint256 for types.Uint256;
    using LBool for types.Bool;

    using CAddress for address;
    using CBool for bool;
    using CUint256 for uint256;

    /// @dev The mapping of pool addresses
    /// @dev Type: mapping(uint256 => address)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolMap")) - 1
    types.Mapping internal constant $poolMap = types.Mapping.wrap(0xbbbff6eb43d00812703825948233d51219dc930ada33999d17cf576c509bebe5);

    /// @dev The mapping of fee amounts in basis point to be applied on rewards from different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.fees")) - 1
    types.Mapping internal constant $fees = types.Mapping.wrap(0x725bc5812d869f51ca713008babaeead3e54db7feab7d4cb185136396950f0e3);

    /// @dev The mapping of commission paid for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.commissionPaid")) - 1
    types.Mapping internal constant $commissionPaid = types.Mapping.wrap(0x6c8f9259db4f6802ea7a1e0a01ddb54668b622f1e8d6b610ad7ba4d95f59da29);

    /// @dev The mapping of injected Eth for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.injectedEth")) - 1
    types.Mapping internal constant $injectedEth = types.Mapping.wrap(0x03abd4c14227eca60c6fecceef3797455c352f43ab35128096ea0ac0d9b2170a);

    /// @dev The mapping of exited Eth for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.exitedEth")) - 1
    types.Mapping internal constant $exitedEth = types.Mapping.wrap(0x76a0ecda094c6ccf2a55f6f1ef41b98d3c1f2dfcb9c1970701fe842ce778ff9b);

    /// @dev The mapping storing whether users can deposit or not to each pool
    /// @dev Type: mapping(uint256 => bool)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolActivation")) - 1
    types.Mapping internal constant $poolActivation = types.Mapping.wrap(0x17b1774c0811229612ec3762023ccd209d6a131e52cdd22f3427eaa8005bcb2f);

    /// @dev The mapping of pool shares owned for each pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolShares")) - 1
    types.Mapping internal constant $poolShares = types.Mapping.wrap(0x357e26a850dc4edaa8b82b6511eec141075372c9c551d3ddb37c35a301f00018);

    /// @dev The number of pools.
    /// @dev Slot: keccak256(bytes("multiPool.1.poolCount")) - 1
    types.Uint256 internal constant $poolCount = types.Uint256.wrap(0xce6dbdcc28927f6ed428550e539c70c9145bd20fc6e3d7611bd20e170e9b1840);

    /// @dev True if deposits are paused
    /// @dev Slot: keccak256(bytes("multiPool.1.depositsPaused")) - 1
    types.Bool internal constant $depositPaused = types.Bool.wrap(0xa030c45ae387079bc9a34aa1365121b47b8ef2d06c04682ce63b90b7c06843e7);

    /// @dev The maximum commission that can be set for a pool, in basis points, to be set at initialization
    /// @dev Slot: keccak256(bytes("multiPool.1.maxCommission")) - 1
    types.Uint256 internal constant $maxCommission = types.Uint256.wrap(0x70be78e680b682a5a3c38e305d79e28594fd0c62048cca29ef1bd1d746ca8785);

    /// @notice This modifier reverts if the deposit is paused
    modifier notPaused() {
        if ($depositPaused.get()) {
            revert DepositsPaused();
        }
        _;
    }

    /// @inheritdoc IMultiPool
    function pools() public view returns (address[] memory) {
        uint256 length = $poolCount.get();
        address[] memory poolAddresses = new address[](length);
        for (uint256 i = 0; i < length;) {
            poolAddresses[i] = $poolMap.get()[i].toAddress();
            unchecked {
                i++;
            }
        }
        return poolAddresses;
    }

    /// @inheritdoc IMultiPool
    function pauseDeposits(bool isPaused) external onlyAdmin {
        emit SetDepositsPaused(isPaused);
        $depositPaused.set(isPaused);
    }

    /// @inheritdoc IMultiPool
    function depositsPaused() external view returns (bool) {
        return $depositPaused.get();
    }

    /// @inheritdoc IMultiPool
    function getFee(uint256 poolId) public view returns (uint256) {
        return $fees.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    // slither-disable-next-line reentrancy-events
    function changeFee(uint256 poolId, uint256 newFeeBps) external onlyAdmin {
        uint256 earnedBeforeFeeUpdate = _integratorCommissionEarned(poolId);
        _setFee(newFeeBps, poolId);
        uint256 earnedAfterFeeUpdate = _integratorCommissionEarned(poolId);

        uint256 paid = $commissionPaid.get()[poolId];
        uint256 paidAndEarnedAfter = paid + earnedAfterFeeUpdate;
        if (paidAndEarnedAfter < earnedBeforeFeeUpdate) {
            revert CommissionPaidUnderflow();
        }
        $commissionPaid.get()[poolId] = paidAndEarnedAfter - earnedBeforeFeeUpdate;
    }

    /// @inheritdoc IMultiPool
    function changeSplit(address[] calldata recipients, uint256[] calldata splits) external onlyAdmin {
        _setFeeSplit(recipients, splits);
    }

    /// @inheritdoc IMultiPool
    function addPool(address pool, uint256 feeBps) external onlyAdmin {
        _addPool(pool, feeBps);
    }

    /// @inheritdoc IMultiPool
    function getPoolActivation(uint256 poolId) external view returns (bool) {
        return $poolActivation.get()[poolId].toBool();
    }

    /// @inheritdoc IMultiPool
    function integratorCommissionOwed(uint256 poolId) external view returns (uint256) {
        return _integratorCommissionOwed(poolId);
    }

    /// @inheritdoc IMultiPool
    function exitCommissionShares(uint256 poolId) external onlyAdmin {
        _exitCommissionShares(poolId);
    }

    /// @inheritdoc IvPoolSharesReceiver
    function onvPoolSharesReceived(address operator, address from, uint256 amount, bytes memory) external returns (bytes4) {
        uint256 poolId = _findPoolIdOrRevert(msg.sender);
        if (!$poolActivation.get()[poolId].toBool()) revert PoolDisabled(poolId);
        // Check this callback is from minting, we can only receive shares from the pool when depositing
        if ($poolMap.get()[poolId].toAddress() != operator || from != address(0)) {
            revert CallbackNotFromMinting();
        }
        $poolShares.get()[poolId] += amount;
        emit VPoolSharesReceived(msg.sender, poolId, amount);
        return IvPoolSharesReceiver.onvPoolSharesReceived.selector;
    }

    /// PRIVATE METHODS

    /// @dev Internal utility to exit commission shares
    /// @param poolId The vPool id
    // slither-disable-next-line reentrancy-events
    function _exitCommissionShares(uint256 poolId) internal {
        if (poolId >= $poolCount.get()) revert InvalidPoolId(poolId);
        uint256 shares = _poolSharesOfIntegrator(poolId);
        if (shares == 0) revert NoSharesToExit(poolId);
        address[] memory recipients = $feeRecipients.toAddressA();
        uint256[] memory weights = $feeSplits.toUintA();
        IvPool pool = _getPool(poolId);
        for (uint256 i = 0; i < recipients.length;) {
            uint256 share = LibUint256.mulDiv(shares, weights[i], LibConstant.BASIS_POINTS_MAX);
            if (share > 0) {
                _sendSharesToExitQueue(poolId, share, pool, recipients[i]);
            }
            unchecked {
                ++i;
            }
        }
        $exitedEth.get()[poolId] += LibUint256.mulDiv(shares, pool.totalUnderlyingSupply(), pool.totalSupply());
        $commissionPaid.get()[poolId] = _integratorCommissionEarned(poolId);
        emit ExitedCommissionShares(poolId, shares, weights, recipients);
    }

    /// @dev Internal utility to send pool shares to the exit queue
    // slither-disable-next-line calls-loop
    function _sendSharesToExitQueue(uint256 poolId, uint256 shares, IvPool pool, address ticketOwner) internal {
        $poolShares.get()[poolId] -= shares;
        bool result = pool.transferShares(pool.exitQueue(), shares, abi.encodePacked(ticketOwner));
        if (!result) {
            revert PoolTransferFailed(poolId);
        }
    }

    /// @notice Internal utility to find the id of a pool using its address
    /// @dev Reverts if the address is not found
    /// @param poolAddress address of the pool to look up
    function _findPoolIdOrRevert(address poolAddress) internal view returns (uint256) {
        for (uint256 id = 0; id < $poolCount.get();) {
            if (poolAddress == $poolMap.get()[id].toAddress()) {
                return id;
            }
            unchecked {
                id++;
            }
        }
        revert NotARegisteredPool(poolAddress);
    }

    /// @dev Internal utility to set the integrator fee value
    /// @param integratorFeeBps The new integrator fee in bps
    /// @param poolId The vPool id
    function _setFee(uint256 integratorFeeBps, uint256 poolId) internal {
        if (integratorFeeBps > $maxCommission.get()) {
            revert FeeOverMax($maxCommission.get());
        }
        $fees.get()[poolId] = integratorFeeBps;
        emit SetFee(poolId, integratorFeeBps);
    }

    /// @dev Internal utility to get get the pool address
    /// @param poolId The index of the pool
    /// @return The pool
    // slither-disable-next-line naming-convention
    function _getPool(uint256 poolId) public view returns (IvPool) {
        if (poolId >= $poolCount.get()) {
            revert InvalidPoolId(poolId);
        }
        return IvPool($poolMap.get()[poolId].toAddress());
    }

    /// @dev Add a pool to the list.
    /// @param newPool new pool address.
    /// @param fee fees in basis points of ETH.
    // slither-disable-next-line dead-code
    function _addPool(address newPool, uint256 fee) internal {
        LibSanitize.notInvalidBps(fee);
        LibSanitize.notZeroAddress(newPool);
        uint256 poolId = $poolCount.get();
        for (uint256 i = 0; i < poolId;) {
            if (newPool == $poolMap.get()[i].toAddress()) {
                revert PoolAlreadyRegistered(newPool);
            }
            unchecked {
                i++;
            }
        }

        $poolMap.get()[poolId] = newPool.v();
        $fees.get()[poolId] = fee;
        $poolActivation.get()[poolId] = true.v();
        $poolCount.set(poolId + 1);

        emit PoolAdded(newPool, poolId);
        emit SetFee(poolId, fee);
    }

    /// @dev Reverts if the given pool is not enabled.
    /// @param poolId pool id.
    // slither-disable-next-line dead-code
    function _checkPoolIsEnabled(uint256 poolId) internal view {
        if (poolId >= $poolCount.get()) {
            revert InvalidPoolId(poolId);
        }
        bool status = $poolActivation.get()[poolId].toBool();
        if (!status) {
            revert PoolDisabled(poolId);
        }
    }

    /// @dev Returns the ETH value of the vPool shares in the contract.
    /// @return amount of ETH.
    // slither-disable-next-line calls-loop
    function _stakedEthValue(uint256 poolId) internal view returns (uint256) {
        IvPool pool = _getPool(poolId);
        uint256 poolTotalSupply = pool.totalSupply();
        if (poolTotalSupply == 0) {
            return 0;
        }
        return LibUint256.mulDiv($poolShares.get()[poolId], pool.totalUnderlyingSupply(), poolTotalSupply);
    }

    /// @dev Returns the amount of ETH earned by the integrator.
    /// @return amount of ETH.
    function _integratorCommissionEarned(uint256 poolId) internal view returns (uint256) {
        uint256 staked = _stakedEthValue(poolId);
        uint256 injected = $injectedEth.get()[poolId];
        uint256 exited = $exitedEth.get()[poolId];
        if (injected >= staked + exited) {
            // Can happen right after staking due to rounding error
            return 0;
        }
        uint256 rewardsEarned = staked + exited - injected;
        return LibUint256.mulDiv(rewardsEarned, $fees.get()[poolId], LibConstant.BASIS_POINTS_MAX);
    }

    /// @dev Returns the amount of ETH owed to the integrator.
    /// @return amount of ETH.
    // slither-disable-next-line dead-code
    function _integratorCommissionOwed(uint256 poolId) internal view returns (uint256) {
        uint256 earned = _integratorCommissionEarned(poolId);
        uint256 paid = $commissionPaid.get()[poolId];
        if (earned > paid) {
            return earned - paid;
        } else {
            return 0;
        }
    }

    /// @dev Returns the ETH value of the vPool shares after subtracting integrator commission.
    /// @return amount of ETH.
    // slither-disable-next-line dead-code
    function _ethAfterCommission(uint256 poolId) internal view returns (uint256) {
        return _stakedEthValue(poolId) - _integratorCommissionOwed(poolId);
    }

    /// @dev Returns the number of vPool shares owed as commission.
    /// @return amount of shares.
    // slither-disable-next-line calls-loop,dead-code
    function _poolSharesOfIntegrator(uint256 poolId) internal view returns (uint256) {
        IvPool pool = IvPool($poolMap.get()[poolId].toAddress());
        uint256 poolTotalUnderlying = pool.totalUnderlyingSupply();
        return poolTotalUnderlying == 0 ? 0 : LibUint256.mulDiv(_integratorCommissionOwed(poolId), pool.totalSupply(), poolTotalUnderlying);
    }

    /// @dev Internal utility to set the max commission value
    /// @param maxCommission The new max commission in bps
    // slither-disable-next-line dead-code
    function _setMaxCommission(uint256 maxCommission) internal {
        LibSanitize.notInvalidBps(maxCommission);
        $maxCommission.set(maxCommission);
        emit SetMaxCommission(maxCommission);
    }
}
