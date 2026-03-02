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

import "./interfaces/IvPool.sol";
import "./interfaces/IvExecLayerRecipient.sol";

/// @title Exec Layer Recipient
/// @author mortimr @ Kiln
/// @notice The Exec Layer Recipient is the recipient expected to receive rewards from block proposals
// slither-disable-next-line naming-convention
contract vExecLayerRecipient is Fixable, Initializable, Implementation, IvExecLayerRecipient {
    using LAddress for types.Address;

    /// @dev Address of the associated vPool
    /// @dev Slot: keccak256(bytes("execLayerRecipient.1.pool")) - 1
    types.Address internal constant $pool = types.Address.wrap(0x337d60f91925df34a029a8bca2e4d34812d59c4bfcdcd47113ce5715768cc0df);

    /// @inheritdoc IvExecLayerRecipient
    // slither-disable-next-line missing-zero-check
    function initialize(address vpool) external init(0) {
        LibSanitize.notZeroAddress(vpool);
        $pool.set(vpool);
        emit SetPool(vpool);
    }

    /// @notice Only allows the vPool to perform the call
    modifier onlyPool() {
        if (msg.sender != $pool.get()) {
            revert LibErrors.Unauthorized(msg.sender, $pool.get());
        }
        _;
    }

    /// @inheritdoc IvExecLayerRecipient
    function pool() external view returns (address) {
        return $pool.get();
    }
    /// @inheritdoc IvExecLayerRecipient

    function hasFunds() external view returns (bool) {
        return address(this).balance > 0;
    }

    /// @inheritdoc IvExecLayerRecipient
    function funds() external view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc IvExecLayerRecipient
    function pull(uint256 max) external onlyPool {
        uint256 maxPullable = LibUint256.min(address(this).balance, max);
        if (maxPullable > 0) {
            emit SuppliedEther(maxPullable);
            IvPool($pool.get()).injectEther{value: maxPullable}();
        }
    }

    /// @inheritdoc IvExecLayerRecipient
    receive() external payable {}

    /// @inheritdoc IvExecLayerRecipient
    fallback() external payable {}
}
