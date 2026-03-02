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

import "utils.sol/types/address.sol";
import "utils.sol/types/mapping.sol";
import "utils.sol/types/bool.sol";
import "utils.sol/Fixable.sol";
import "utils.sol/Initializable.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/libs/LibSanitize.sol";
import "utils.sol/libs/LibUint256.sol";

import "./interfaces/IvFactory.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IvCoverageRecipient.sol";

/// @title Coverage Recipient
/// @author mortimr @ Kiln
/// @notice The Coverage Recipient can hold ETH or vPool shares to repay losses due to slashing
// slither-disable-next-line naming-convention
contract vCoverageRecipient is Fixable, Initializable, Implementation, IvCoverageRecipient {
    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;

    using CAddress for address;
    using CBool for bool;
    using CUint256 for uint256;

    /// @dev Address of the associated vPool.
    /// @dev Slot: keccak256(bytes("coverageRecipient.1.pool")) - 1
    types.Address internal constant $pool = types.Address.wrap(0x3f6b00da921f714b689216a684d384d1c9424b44bd8e3cc08df2fe8279d24b43);

    /// @dev Amount of donated ETH for coverage purposes.
    /// @dev Slot: keccak256(bytes("coverageRecipient.1.etherForCoverage")) - 1
    types.Uint256 internal constant $etherForCoverage =
        types.Uint256.wrap(0x78404ead9f301e938b68369206f64ac56344c119b95a4ffd13a4e2603a24fec9);

    /// @dev Donor authorizations.
    /// @dev Type: mapping(address => bool)
    /// @dev Slot: keccak256(bytes("coverageRecipient.1.donors")) - 1
    types.Mapping internal constant $donors = types.Mapping.wrap(0xd52f49d8be2d7ce601d95522fbe5210aa3f0742fb69b41f8de3ce0f3de50d11e);

    /// @inheritdoc IvCoverageRecipient
    // slither-disable-next-line missing-zero-check
    function initialize(address vpool) external init(0) {
        LibSanitize.notZeroAddress(vpool);
        $pool.set(vpool);
        emit SetPool(vpool);
    }

    /// @notice Only allows the admin to perform the call
    modifier onlyAdmin() {
        {
            address admin = IvFactory(IvPool($pool.get()).factory()).admin();
            if (msg.sender != admin) {
                revert LibErrors.Unauthorized(msg.sender, admin);
            }
        }
        _;
    }

    /// @notice Only allows the vPool to perform the call
    modifier onlyPool() {
        if (msg.sender != $pool.get()) {
            revert LibErrors.Unauthorized(msg.sender, $pool.get());
        }
        _;
    }

    /// @notice Only allows an authorized donor or the vTreasury to perform the call
    modifier onlyDonorOrTreasury() {
        if (!_isDonorOrTreasury(msg.sender)) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @inheritdoc IvCoverageRecipient
    function pool() external view returns (address) {
        return $pool.get();
    }

    /// @inheritdoc IvCoverageRecipient
    function donor(address donorAddress) external view returns (bool) {
        return $donors.get()[donorAddress.k()].toBool();
    }

    /// @inheritdoc IvCoverageRecipient
    function hasFunds() external view returns (bool) {
        return ($etherForCoverage.get() + _sharesForCoverage()) > 0;
    }

    /// @inheritdoc IvCoverageRecipient
    function etherFunds() external view returns (uint256) {
        return $etherForCoverage.get();
    }

    /// @inheritdoc IvCoverageRecipient
    function sharesFunds() external view returns (uint256) {
        return _sharesForCoverage();
    }

    /// @inheritdoc IvCoverageRecipient
    function allowDonor(address donorAddress, bool allowed) external onlyAdmin {
        $donors.get()[donorAddress.k()] = allowed.v();
        emit AllowedDonor(donorAddress, allowed);
    }

    /// @inheritdoc IvCoverageRecipient
    // slither-disable-next-line reentrancy-benign,reentrancy-events
    function cover(uint256 max) external onlyPool {
        uint256 sharesForCoverage = _sharesForCoverage();
        uint256 etherForCoverage = $etherForCoverage.get();
        uint256 maxCoverableEther = LibUint256.min(etherForCoverage, max);
        IvPool vpool = IvPool($pool.get());
        if (maxCoverableEther > 0) {
            uint256 newEtherForCoverage = etherForCoverage - maxCoverableEther;
            $etherForCoverage.set(newEtherForCoverage);
            emit UpdatedEtherForCoverage(newEtherForCoverage);
            emit SuppliedEther(maxCoverableEther);
            vpool.injectEther{value: maxCoverableEther}();
        }
        if (maxCoverableEther < max && sharesForCoverage > 0) {
            uint256 totalUnderlyingSupply = vpool.totalUnderlyingSupply();
            uint256 totalSupply = vpool.totalSupply();
            uint256 amountToVoid =
                totalSupply - LibUint256.mulDiv(totalUnderlyingSupply, totalSupply, (totalUnderlyingSupply + (max - maxCoverableEther))) - 1;
            uint256 maxRelativeAllowedShares = LibUint256.mulDiv(totalSupply, 100, LibConstant.BASIS_POINTS_MAX);
            uint256 maxCoverableShares = LibUint256.min(LibUint256.min(sharesForCoverage, amountToVoid), maxRelativeAllowedShares);
            if (maxCoverableShares > 0) {
                uint256 newSharesForCoverage = sharesForCoverage - maxCoverableShares;
                emit UpdatedSharesForCoverage(newSharesForCoverage);
                emit VoidedShares(maxCoverableShares);
                vpool.voidShares(maxCoverableShares);
            }
        }
    }

    /// @inheritdoc IvCoverageRecipient
    function fundWithEther() external payable onlyDonorOrTreasury {
        uint256 etherForCoverage = $etherForCoverage.get() + msg.value;
        emit UpdatedEtherForCoverage(etherForCoverage);
        $etherForCoverage.set(etherForCoverage);
    }

    /// @inheritdoc IvCoverageRecipient
    function removeEther(address recipient, uint256 amount) external onlyAdmin {
        LibSanitize.notZeroAddress(recipient);
        LibSanitize.notNullValue(amount);
        uint256 etherForCoverage = $etherForCoverage.get();
        if (amount > etherForCoverage) {
            revert RemovedAmountTooHigh(amount, etherForCoverage);
        }
        etherForCoverage -= amount;
        emit UpdatedEtherForCoverage(etherForCoverage);
        $etherForCoverage.set(etherForCoverage);
        // slither-disable-next-line missing-zero-check,low-level-calls
        (bool success, bytes memory rdata) = recipient.call{value: amount}("");
        if (!success) {
            // slither-disable-next-line assembly
            assembly {
                revert(add(32, rdata), mload(rdata))
            }
        }
    }

    /// @inheritdoc IvCoverageRecipient
    function removeShares(address recipient, uint256 amount) external onlyAdmin {
        LibSanitize.notZeroAddress(recipient);
        LibSanitize.notNullValue(amount);
        uint256 currentSharesForCoverage = _sharesForCoverage();
        if (amount > currentSharesForCoverage) {
            revert RemovedAmountTooHigh(amount, currentSharesForCoverage);
        }
        emit UpdatedSharesForCoverage(currentSharesForCoverage - amount);
        bool success = IvPool($pool.get()).transferShares(recipient, amount, "");

        if (!success) {
            revert SharesTransferError(recipient, amount, "");
        }
    }

    /// @inheritdoc IvPoolSharesReceiver
    function onvPoolSharesReceived(address operator, address from, uint256, bytes memory) external onlyPool returns (bytes4) {
        if (!_isDonorOrTreasury(operator) && !_isDonorOrTreasury(from)) {
            revert LibErrors.Unauthorized(operator, address(0));
        }
        emit UpdatedSharesForCoverage(_sharesForCoverage());
        return IvPoolSharesReceiver.onvPoolSharesReceived.selector;
    }

    /// @dev Internal utility to check if the caller is a donor or the treasury
    /// @param caller The address to check
    /// @return True if the caller is a donor or the treasury
    function _isDonorOrTreasury(address caller) internal view returns (bool) {
        if (!$donors.get()[caller.k()].toBool()) {
            address treasury = IvFactory(IvPool($pool.get()).factory()).treasury();
            return caller == treasury;
        }
        return true;
    }

    /// @dev Internal utility to retrieve the current vPool shares balance of the Coverage Recipient
    /// @return The current vPool shares balance of this contract
    function _sharesForCoverage() internal view returns (uint256) {
        return IvPool($pool.get()).balanceOf(address(this));
    }
}
