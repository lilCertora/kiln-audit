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

import "vsuite/ctypes/ctypes.sol";
import "vsuite/ctypes/approvals_mapping.sol";

import "./MultiPool.sol";
import "./interfaces/IMultiPool20.sol";
import "./victypes/victypes.sol";
import "./victypes/balance.sol";

uint256 constant MIN_SUPPLY = 1e14; // If there is only dust in the pool, we mint 1:1
uint256 constant COMMISSION_MAX = 10; // 0.1% / 10 bps ~= 12 days of accrued commission at 3% GRR

/// @title MultiPool-20 (v1)
/// @author 0xvv @ Kiln
/// @notice This contract contains the internal logic for an ERC-20 token based on one or multiple pools.
abstract contract MultiPool20 is MultiPool, IMultiPool20 {
    using LArray for types.Array;
    using LMapping for types.Mapping;
    using LUint256 for types.Uint256;
    using LBalance for victypes.BalanceMapping;
    using LApprovalsMapping for ctypes.ApprovalsMapping;
    using CUint256 for uint256;

    using CBool for bool;

    /// @dev The total supply of ERC 20.
    /// @dev Slot: keccak256(bytes("multiPool20.1.totalSupply")) - 1
    types.Uint256 internal constant $totalSupply = types.Uint256.wrap(0xb24a0f21470b6927dcbaaf5b1f54865bd687f4a2ce4c43edf1e20339a4c05bae);

    /// @dev The list containing the percentages of ETH to route to each pool, in basis points, must add up to 10 000.
    /// @dev Slot: keccak256(bytes("multiPool20.1.poolRoutingList")) - 1
    types.Array internal constant $poolRoutingList = types.Array.wrap(0x3803482dd7707d12238e38a3b1b5e55fa6e13d81c36ce29ec5c267cc02c53fe3);

    /// @dev Stores the balances : mapping(address => uint256).
    /// @dev Slot: keccak256(bytes("multiPool20.1.balances")) - 1
    victypes.BalanceMapping internal constant $balances =
        victypes.BalanceMapping.wrap(0x4f74125ce1aafb5d1699fc2e5e8f96929ff1a99170dc9bda82c8944acc5c7286);

    /// @dev Stores the approvals
    /// @dev Type: mapping(address => mapping(address => bool).
    /// @dev Slot: keccak256(bytes("multiPool20.1.approvals")) - 1
    ctypes.ApprovalsMapping internal constant $approvals =
        ctypes.ApprovalsMapping.wrap(0xebc1e0a04bae59eb2e2b17f55cd491aec28c349ae4f6b6fe9be28a72f9c6b202);

    /// @dev The threshold below which we try to issue only one exit ticket
    /// @dev Slot: keccak256(bytes("multiPool20.1.monoTicketThreshold")) - 1
    types.Uint256 internal constant $monoTicketThreshold =
        types.Uint256.wrap(0x900053b761278bb5de4eeaea5ed9000b89943edad45dcf64a9dab96d0ce29c2e);

    /// @inheritdoc IMultiPool20
    function setPoolPercentages(uint256[] calldata split) external onlyAdmin {
        _setPoolPercentages(split);
    }

    /// @notice Sets the threshold below which we try to issue only one exit ticket
    /// @param minTicketEthValue The threshold
    function setMonoTicketThreshold(uint256 minTicketEthValue) external onlyAdmin {
        _setMonoTicketThreshold(minTicketEthValue);
    }

    /// @inheritdoc IMultiPool20
    function requestExit(uint256 amount) external virtual {
        _requestExit(amount);
    }

    /// @inheritdoc IMultiPool20
    function rate() external view returns (uint256) {
        uint256 currentTotalSupply = _totalSupply();
        return currentTotalSupply > 0 ? LibUint256.mulDiv(_totalUnderlyingSupply(), 1e18, currentTotalSupply) : 1e18;
    }

    /// Private functions

    /// @dev Internal function to requestExit
    /// @param amount The amount of shares to exit
    // slither-disable-next-line reentrancy-events
    function _requestExit(uint256 amount) internal {
        uint256 totalSupply = $totalSupply.get();
        uint256 totalUnderlyingSupply = _totalUnderlyingSupply();
        _burn(msg.sender, amount);
        uint256 ethValue = LibUint256.mulDiv(amount, totalUnderlyingSupply, totalSupply);
        uint256 poolCount_ = $poolCount.get();
        // Early return in case of mono pool operation
        if (poolCount_ == 1) {
            PoolExitDetails[] memory detail = new PoolExitDetails[](1);
            _sendToExitQueue(0, ethValue, detail[0]);
            _checkCommissionRatio(0);
            emit Exit(msg.sender, uint128(amount), detail);
            return;
        }
        uint256[] memory splits = $poolRoutingList.toUintA();
        // If the amount is below the set threshold we exit via the most imabalanced pool to print only 1 ticket
        if (ethValue < $monoTicketThreshold.get()) {
            int256 maxImbalance = 0;
            uint256 exitPoolId = 0;
            for (uint256 id = 0; id < poolCount_;) {
                uint256 expectedValue = LibUint256.mulDiv(totalUnderlyingSupply, splits[id], LibConstant.BASIS_POINTS_MAX);
                uint256 poolValue = _ethAfterCommission(id);
                int256 imbalance = int256(poolValue) - int256(expectedValue);
                if (poolValue >= ethValue && imbalance > maxImbalance) {
                    maxImbalance = imbalance;
                    exitPoolId = id;
                }
                unchecked {
                    id++;
                }
            }
            if (maxImbalance > 0) {
                PoolExitDetails[] memory detail = new PoolExitDetails[](1);
                _sendToExitQueue(exitPoolId, ethValue, detail[0]);
                _checkCommissionRatio(exitPoolId);
                emit Exit(msg.sender, uint128(amount), detail);
                return;
            }
        }
        // If the the amount is over the threshold or no pool has enough value to cover the exit
        // We exit proportionally to maintain the balance
        PoolExitDetails[] memory details = new PoolExitDetails[](poolCount_);
        for (uint256 id = 0; id < poolCount_;) {
            uint256 ethForPool = LibUint256.mulDiv(ethValue, splits[id], LibConstant.BASIS_POINTS_MAX);
            if (ethForPool > 0) _sendToExitQueue(id, ethForPool, details[id]);
            _checkCommissionRatio(id);
            unchecked {
                id++;
            }
        }
        emit Exit(msg.sender, uint128(amount), details);
    }

    /// @dev Internal function to exit the commission shares if needed
    /// @param id The pool id
    function _checkCommissionRatio(uint256 id) internal {
        // If the commission shares / all shares ratio go over the limit we exit them
        if (_poolSharesOfIntegrator(id) > LibUint256.mulDiv($poolShares.get()[id], COMMISSION_MAX, LibConstant.BASIS_POINTS_MAX)) {
            _exitCommissionShares(id);
        }
    }

    /// @dev Utility function to send a given ETH amount of shares to the exit queue of a pool
    // slither-disable-next-line calls-loop
    function _sendToExitQueue(uint256 poolId, uint256 ethAmount, PoolExitDetails memory details) internal {
        IvPool pool = _getPool(poolId);
        uint256 shares = LibUint256.mulDiv(ethAmount, pool.totalSupply(), pool.totalUnderlyingSupply());
        uint256 stakedValueBefore = _stakedEthValue(poolId);
        details.exitedPoolShares = uint128(shares);
        details.poolId = uint128(poolId);
        _sendSharesToExitQueue(poolId, shares, pool, msg.sender);
        $exitedEth.get()[poolId] += stakedValueBefore - _stakedEthValue(poolId);
    }

    /// @dev Internal function to stake in one or more pools with arbitrary amounts to each one
    /// @param totalAmount The amount of ETH to stake
    // slither-disable-next-line reentrancy-events,unused-return,dead-code
    function _stake(uint256 totalAmount) internal notPaused returns (bool) {
        uint256[] memory splits = $poolRoutingList.toUintA();
        PoolStakeDetails[] memory stakeDetails = new PoolStakeDetails[](splits.length);
        uint256 tokensBoughtTotal = 0;
        for (uint256 id = 0; id < $poolCount.get();) {
            if (splits[id] > 0) {
                stakeDetails[id].poolId = uint128(id);
                uint256 remainingEth = LibUint256.mulDiv(totalAmount, splits[id], LibConstant.BASIS_POINTS_MAX);
                _checkPoolIsEnabled(id);
                IvPool pool = _getPool(id);
                uint256 totalSupply = _totalSupply(); // we can use these values because the ratio of shares to underlying is constant in this function
                uint256 totalUnderlyingSupply = _totalUnderlyingSupply();
                if (totalSupply < MIN_SUPPLY) {
                    $injectedEth.get()[id] += remainingEth;
                    uint256 sharesAcquired = pool.deposit{value: remainingEth}();
                    tokensBoughtTotal += sharesAcquired;
                    _mint(msg.sender, sharesAcquired);
                    stakeDetails[id].ethToPool = uint128(remainingEth);
                    stakeDetails[id].pSharesFromPool = uint128(sharesAcquired);
                } else {
                    uint256 comOwed = _integratorCommissionOwed(id);
                    uint256 tokensBoughtPool = 0;
                    // If there is enough commission we sell it first
                    // This avoids wasting gas to sell infinitesimal amounts of commission + a potential DoS vector
                    if (comOwed > MIN_COMMISSION_TO_SELL) {
                        uint256 ethForCommission = LibUint256.min(comOwed, remainingEth);
                        remainingEth -= ethForCommission;
                        uint256 pSharesBought = LibUint256.mulDiv(
                            ethForCommission, $poolShares.get()[id] - _poolSharesOfIntegrator(id), _ethAfterCommission(id)
                        );
                        $commissionPaid.get()[id] += ethForCommission;
                        stakeDetails[id].ethToIntegrator = uint128(ethForCommission);
                        stakeDetails[id].pSharesFromIntegrator = uint128(pSharesBought);
                        emit CommissionSharesSold(pSharesBought, id, ethForCommission);
                        uint256 tokensAcquired = LibUint256.mulDiv(ethForCommission, totalSupply, totalUnderlyingSupply);
                        if (tokensAcquired == 0) revert ZeroSharesMint();
                        tokensBoughtPool += tokensAcquired;
                    }
                    if (remainingEth > 0) {
                        $injectedEth.get()[id] += remainingEth;
                        uint256 pShares = pool.deposit{value: remainingEth}();
                        uint256 tokensAcquired = LibUint256.mulDiv(remainingEth, totalSupply, totalUnderlyingSupply);
                        if (tokensAcquired == 0) revert ZeroSharesMint();
                        stakeDetails[id].ethToPool += uint128(remainingEth);
                        stakeDetails[id].pSharesFromPool += uint128(pShares);
                        tokensBoughtPool += tokensAcquired;
                    }
                    _mint(msg.sender, tokensBoughtPool);
                    tokensBoughtTotal += tokensBoughtPool;
                }
            }
            unchecked {
                id++;
            }
        }
        emit Stake(msg.sender, uint128(totalAmount), uint128(tokensBoughtTotal), stakeDetails);
        return true;
    }

    /// @dev Internal function to set the pool percentages
    /// @param percentages The new percentages
    function _setPoolPercentages(uint256[] calldata percentages) internal {
        if (percentages.length != $poolCount.get()) {
            revert UnequalLengths(percentages.length, $poolCount.get());
        }
        uint256 total = 0;
        $poolRoutingList.del();
        uint256[] storage percentagesList = $poolRoutingList.toUintA();
        for (uint256 i = 0; i < percentages.length;) {
            bool enabled = $poolActivation.get()[i].toBool();
            uint256 percentage = percentages[i];
            if (!enabled && percentage != 0) {
                revert NonZeroPercentageOnDeactivatedPool(i);
            } else {
                total += percentages[i];
                percentagesList.push(percentages[i]);
            }

            unchecked {
                i++;
            }
        }
        if (total != LibConstant.BASIS_POINTS_MAX) {
            revert LibErrors.InvalidBPSValue();
        }

        emit SetPoolPercentages(percentages);
    }

    /// @inheritdoc IMultiPool20
    function setPoolActivation(uint256 poolId, bool status, uint256[] calldata newPoolPercentages) external onlyAdmin {
        $poolActivation.get()[poolId] = status.v();
        _setPoolPercentages(newPoolPercentages);
    }

    /// @dev Internal function to retrieve the balance of a given account
    /// @param account The account to retrieve the balance of
    // slither-disable-next-line dead-code
    function _balanceOf(address account) internal view returns (uint256) {
        return $balances.get()[account];
    }

    /// @dev Internal function to retrieve the balance of a given account in underlying
    /// @param account The account to retrieve the balance of in underlying
    // slither-disable-next-line dead-code
    function _balanceOfUnderlying(address account) internal view returns (uint256) {
        uint256 tUnderlyingSupply = _totalUnderlyingSupply();
        uint256 tSupply = _totalSupply();
        if (tUnderlyingSupply == 0 || tSupply == 0) {
            return 0;
        }
        return LibUint256.mulDiv($balances.get()[account], tUnderlyingSupply, tSupply);
    }

    /// @dev Internal function retrieve the total underlying supply
    // slither-disable-next-line naming-convention
    function _totalUnderlyingSupply() internal view returns (uint256) {
        uint256 ethValue = 0;
        for (uint256 i = 0; i < $poolCount.get();) {
            unchecked {
                ethValue += _ethAfterCommission(i);
                i++;
            }
        }
        return ethValue;
    }

    /// @dev Internal function to retrieve the total supply
    // slither-disable-next-line naming-convention
    function _totalSupply() internal view returns (uint256) {
        return $totalSupply.get();
    }

    /// @dev Internal function to transfer tokens from one account to another
    /// @param from The account to transfer from
    /// @param to The account to transfer to
    /// @param amount The amount to transfer
    // slither-disable-next-line dead-code
    function _transfer(address from, address to, uint256 amount) internal virtual {
        uint256 fromBalance = $balances.get()[from];
        if (amount > fromBalance) {
            revert InsufficientBalance(amount, fromBalance);
        }
        unchecked {
            $balances.get()[from] = fromBalance - amount;
        }
        $balances.get()[to] += amount;

        emit Transfer(from, to, amount);
    }

    /// @dev Internal function to retrieve the allowance of a given spender
    /// @param owner The owner of the allowance
    /// @param spender The spender of the allowance
    // slither-disable-next-line dead-code
    function _allowance(address owner, address spender) internal view returns (uint256) {
        return $approvals.get()[owner][spender];
    }

    /// @dev Internal function to approve a spender
    /// @param owner The owner of the allowance
    /// @param spender The spender of the allowance
    /// @param amount The amount to approve
    // slither-disable-next-line dead-code
    function _approve(address owner, address spender, uint256 amount) internal {
        $approvals.get()[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /// @dev Internal function to transfer tokens from one account to another
    /// @param spender The spender of the allowance
    /// @param from The account to transfer from
    /// @param to The account to transfer to
    /// @param amount The amount to transfer
    // slither-disable-next-line dead-code
    function _transferFrom(address spender, address from, address to, uint256 amount) internal virtual {
        uint256 currentAllowance = $approvals.get()[from][spender];
        if (amount > currentAllowance) {
            revert InsufficientAllowance(amount, currentAllowance);
        }
        unchecked {
            $approvals.get()[from][spender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
    }

    /// @dev Internal function for minting
    /// @param account The address to mint to
    /// @param amount The amount to mint
    // slither-disable-next-line dead-code
    function _mint(address account, uint256 amount) internal {
        $totalSupply.set($totalSupply.get() + amount);
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, checked above
            $balances.get()[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    /// @dev Internal function to burn tokens
    /// @param account The account to burn from
    /// @param amount The amount to burn
    // slither-disable-next-line dead-code
    function _burn(address account, uint256 amount) internal {
        uint256 accountBalance = $balances.get()[account];
        if (amount > accountBalance) {
            revert InsufficientBalance(amount, accountBalance);
        }
        $totalSupply.set($totalSupply.get() - amount);
        unchecked {
            $balances.get()[account] = accountBalance - amount;
        }
        emit Transfer(account, address(0), amount);
    }

    /// @dev Internal function to set the mono ticket threshold
    /// @param minTicketEthValue The minimum ticket value
    function _setMonoTicketThreshold(uint256 minTicketEthValue) internal {
        $monoTicketThreshold.set(minTicketEthValue);
    }
}
