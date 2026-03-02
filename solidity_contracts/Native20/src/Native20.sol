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

import "utils.sol/types/mapping.sol";
import "utils.sol/types/string.sol";

import "utils.sol/Implementation.sol";
import "utils.sol/Initializable.sol";

import "./MultiPool20.sol";
import "./interfaces/INative20.sol";

/// @title Native20 (V1)
/// @author 0xvv @ Kiln
/// @notice This contract allows users to stake any amount of ETH in the vPool(s)
/// @notice Users are given non transferable ERC-20 type shares to track their stake
contract Native20 is MultiPool20, INative20, Implementation, Initializable {
    using LMapping for types.Mapping;
    using LString for types.String;
    using LUint256 for types.Uint256;

    /// @dev The name of the shares.
    /// @dev Slot: keccak256(bytes("native20.1.name")) - 1
    types.String internal constant $name = types.String.wrap(0xeee152275d096301850a53ae85c6991c818bc6bac8a2174c268aa94ed7cf06f1);

    /// @dev The symbol of the shares.
    /// @dev Slot: keccak256(bytes("native20.1.symbol")) - 1
    types.String internal constant $symbol = types.String.wrap(0x4a8b3e24ebc795477af927068865c6fcc26e359a994edca2492e515a46aad711);

    /// @inheritdoc INative20
    function initialize(Native20Configuration calldata args) external init(0) {
        $name.set(args.name);
        emit SetName(args.name);
        $symbol.set(args.symbol);
        emit SetSymbol(args.symbol);

        Administrable._setAdmin(args.admin);

        if (args.pools.length == 0) {
            revert EmptyPoolList();
        }
        if (args.pools.length != args.poolFees.length) {
            revert UnequalLengths(args.pools.length, args.poolFees.length);
        }
        for (uint256 i = 0; i < args.pools.length;) {
            _addPool(args.pools[i], args.poolFees[i]);
            unchecked {
                i++;
            }
        }
        _setPoolPercentages(args.poolPercentages);
        _initFeeDispatcher(args.commissionRecipients, args.commissionDistribution);
        _setMaxCommission(args.maxCommissionBps);
        _setMonoTicketThreshold(args.monoTicketThreshold);
    }

    /// @inheritdoc INative20
    function name() external view returns (string memory) {
        return string(abi.encodePacked($name.get()));
    }

    /// @inheritdoc INative20
    function symbol() external view returns (string memory) {
        return string(abi.encodePacked($symbol.get()));
    }

    /// @inheritdoc INative20
    function decimals() external view virtual override returns (uint8) {
        return 18;
    }

    /// @inheritdoc INative20
    function balanceOf(address account) external view virtual returns (uint256) {
        return _balanceOf(account);
    }

    /// @inheritdoc INative20
    function balanceOfUnderlying(address account) external view virtual returns (uint256) {
        return _balanceOfUnderlying(account);
    }

    /// @inheritdoc INative20
    function totalSupply() external view virtual returns (uint256) {
        return _totalSupply();
    }

    /// @inheritdoc INative20
    function totalUnderlyingSupply() external view virtual returns (uint256) {
        return _totalUnderlyingSupply();
    }

    /// @inheritdoc INative20
    function stake() external payable {
        LibSanitize.notNullValue(msg.value);
        _stake(msg.value);
    }
}
