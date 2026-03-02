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

import "utils.sol/libs/LibErrors.sol";
import "utils.sol/libs/LibUint256.sol";
import "utils.sol/libs/LibConstant.sol";

import "utils.sol/types/array.sol";
import "utils.sol/types/uint256.sol";

import "./interfaces/IFeeDispatcher.sol";

/// @title FeeDispatcher (V1) Contract
/// @author 0xvv @ Kiln
/// @notice This contract contains functions to dispatch the ETH in a contract upon withdrawal.
// slither-disable-next-line naming-convention
abstract contract FeeDispatcher is IFeeDispatcher {
    using LArray for types.Array;
    using LUint256 for types.Uint256;

    /// @dev The recipients of the fees upon withdrawal.
    /// @dev Slot: keccak256(bytes("feeDispatcher.1.feeRecipients")) - 1
    types.Array internal constant $feeRecipients = types.Array.wrap(0xd681f9d3e640a2dd835404271506ef93f020e2fc065878793505e5ea088fde3d);

    /// @dev The splits of each recipient of the fees upon withdrawal.
    /// @dev Slot: keccak256(bytes("feeDispatcher.1.feeSplits")) - 1
    types.Array internal constant $feeSplits = types.Array.wrap(0x31a3fa329157566a07927d0c2ba92ff801e4db8af2ec73f92eaf3e7f78d587a8);

    /// @dev The lock to prevent reentrancy
    /// @dev Slot: keccak256(bytes("feeDispatcher.1.locked")) - 1
    types.Uint256 internal constant $locked = types.Uint256.wrap(0x8472de2bbf04bc62a7ee894bd625126d381bf5e8b726e5cd498c3a9dad76d85b);

    /// @dev The states of the lock, 1 = unlocked, 2 = locked
    uint256 internal constant UNLOCKED = 1;
    uint256 internal constant LOCKED = 2;

    constructor() {
        $locked.set(LOCKED);
    }

    /// @dev An internal function to set the fee split & unlock the reentrancy lock.
    ///      Should be called in the initializer of the inheriting contract.
    // slither-disable-next-line dead-code
    function _initFeeDispatcher(address[] calldata recipients, uint256[] calldata splits) internal {
        _setFeeSplit(recipients, splits);
        $locked.set(UNLOCKED);
    }

    /// @notice Modifier to prevent reentrancy
    modifier nonReentrant() virtual {
        if ($locked.get() == LOCKED) {
            revert Reentrancy();
        }

        $locked.set(LOCKED);

        _;

        $locked.set(UNLOCKED);
    }

    /// @inheritdoc IFeeDispatcher
    // slither-disable-next-line low-level-calls,calls-loop,reentrancy-events,assembly
    function withdrawCommission() external nonReentrant {
        uint256 balance = address(this).balance;
        address[] memory recipients = $feeRecipients.toAddressA();
        uint256[] memory splits = $feeSplits.toUintA();
        for (uint256 i = 0; i < recipients.length;) {
            uint256 share = LibUint256.mulDiv(balance, splits[i], LibConstant.BASIS_POINTS_MAX);
            address recipient = recipients[i];
            emit CommissionWithdrawn(recipient, share);
            (bool success, bytes memory rdata) = recipient.call{value: share}("");
            if (!success) {
                assembly {
                    revert(add(32, rdata), mload(rdata))
                }
            }
            unchecked {
                i++;
            }
        }
    }

    /// @notice Returns the current fee split and recipients
    /// @return feeRecipients The current fee recipients
    /// @return feeSplits  The current fee splits
    /// @dev This function is not pure as it fetches the current fee split and recipients from storage
    function getCurrentSplit() external pure returns (address[] memory, uint256[] memory) {
        return ($feeRecipients.toAddressA(), $feeSplits.toUintA());
    }

    /// @dev Internal utility to set the fee distribution upon withdrawal
    /// @param recipients The new fee recipients list
    /// @param splits The new split between fee recipients
    // slither-disable-next-line dead-code
    function _setFeeSplit(address[] calldata recipients, uint256[] calldata splits) internal {
        if (recipients.length != splits.length) {
            revert UnequalLengths(recipients.length, splits.length);
        }
        $feeSplits.del();
        $feeRecipients.del();
        uint256 sum;
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 split = splits[i];
            sum += split;
            $feeSplits.toUintA().push(split);
            $feeRecipients.toAddressA().push(recipients[i]);
        }
        if (sum != LibConstant.BASIS_POINTS_MAX) {
            revert LibErrors.InvalidBPSValue();
        }
        emit NewCommissionSplit(recipients, splits);
    }
}
