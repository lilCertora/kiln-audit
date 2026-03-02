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
import "utils.sol/libs/LibAddress.sol";
import "utils.sol/types/address.sol";

import "./interfaces/IvWithdrawalRecipient.sol";
import "./interfaces/IvFactory.sol";
import "./interfaces/IvPool.sol";

/// @title Withdrawal Recipient
/// @author mortimr @ Kiln
/// @notice Used as the withdrawal credential of the vPool validators
// slither-disable-next-line naming-convention
contract vWithdrawalRecipient is Fixable, Initializable, Implementation, IvWithdrawalRecipient {
    using LAddress for types.Address;

    /// @dev Storage of the address of the vPool.
    /// @dev Slot: keccak256(bytes("withdrawalRecipient.1.vpool")) - 1
    types.Address internal constant $pool = types.Address.wrap(0xd5e4a4177588c20f2fb4b7d046c53a221698e1c0513464bf401c28c168cef367);

    modifier onlyPool() {
        if (msg.sender != $pool.get()) {
            revert LibErrors.Unauthorized(msg.sender, $pool.get());
        }
        _;
    }

    /// @inheritdoc IvWithdrawalRecipient
    // slither-disable-next-line missing-zero-check
    function initialize(address vpool) external init(0) {
        LibSanitize.notZeroAddress(vpool);
        $pool.set(vpool);
        emit SetPool(vpool);
    }

    /// @inheritdoc IvWithdrawalRecipient
    function pool() external view returns (address) {
        return $pool.get();
    }

    /// @inheritdoc IvWithdrawalRecipient
    function withdrawalCredentials() external view returns (bytes32) {
        return LibAddress.toWithdrawalCredentials(address(this));
    }

    /// @inheritdoc IvWithdrawalRecipient
    function pull(uint256 amount) external onlyPool {
        uint256 balance = address(this).balance;
        if (balance < amount) {
            revert InvalidRequestedAmount(amount, balance);
        }
        emit SuppliedEther(amount);
        IvPool($pool.get()).injectEther{value: amount}();
    }

    /// @inheritdoc IvWithdrawalRecipient
    function requestTotalExits(address factory, uint32 amount) external onlyPool returns (uint32) {
        return IvFactory(factory).exitTotal(amount);
    }
}
