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

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "utils.sol/Fixable.sol";
import "utils.sol/libs/LibUint256.sol";
import "utils.sol/libs/LibSanitize.sol";
import "utils.sol/Initializable.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/types/address.sol";
import "utils.sol/types/mapping.sol";

import "./interfaces/IGlobalRecipientHolder.sol";
import "./interfaces/IvTreasury.sol";
import "./interfaces/IvPool.sol";

/// @title Treasury
/// @author mortimr @ Kiln
/// @notice The vTreasury is in charge of collecting the operator commissions accross all the contracts
// slither-disable-next-line naming-convention
contract vTreasury is Initializable, Implementation, Fixable, IvTreasury {
    using SafeERC20 for IERC20;

    using LAddress for types.Address;
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;

    using CAddress for address;

    /// @notice The address to use to withdraw ethers
    /// @dev This address is used to represent pure ETH when assets need to be specified
    address public constant ETHER = LibConstant.ETHER;

    /// @dev The operator address receiving the funds.
    /// @dev Slot: keccak256(bytes("treasury.1.operator")) - 1
    types.Address internal constant $operator = types.Address.wrap(0x6b197e27d7d051f4674d9ccc9c8263682b1ac4bb57659a06c626b51ae30c4446);

    /// @dev The nexus address, used to retrieve the global recipient address.
    /// @dev Slot: keccak256(bytes("treasury.1.nexus")) - 1
    types.Address internal constant $nexus = types.Address.wrap(0x671927d522abab08110fa9a7a3ed81a12d9f3b092255514b22baca773a520dd7);

    /// @dev The fee value in bps.
    /// @dev Slot: keccak256(bytes("treasury.1.fee")) - 1
    types.Uint256 internal constant $fee = types.Uint256.wrap(0xcc590e3982d7134cd1f706d9bdeef910083b4701f3b2892c388372574ad942e3);

    /// @dev The operator fee vote value.
    ///      This value uses its first bit to indicate if the vote is active or not.
    ///      The rest of the bits are used to store the vote value.
    /// @dev Slot: keccak256(bytes("treasury.1.operatorFeeVote")) - 1
    types.Uint256 internal constant $operatorFeeVote =
        types.Uint256.wrap(0xff8120f43c5d6335d8f14da000306b8294e9e29bea95a6998da97c5b20ba4c95);

    /// @dev The globalRecipient fee vote value.
    ///      This value uses its first bit to indicate if the vote is active or not.
    ///      The rest of the bits are used to store the vote value.
    /// @dev Slot: keccak256(bytes("treasury.1.globalRecipientFeeVote")) - 1
    types.Uint256 internal constant $globalRecipientFeeVote =
        types.Uint256.wrap(0xe0ae6f9f0e8889166f8c373d9768604e1059e605659f4f10cc4b1cdd5303f676);

    /// @dev The balance mapping of received vpool shares.
    /// @dev Type: mapping(address => uint256)
    /// @dev Slot: keccak256(bytes("treasury.1.poolShares")) - 1
    types.Mapping internal constant $poolShares = types.Mapping.wrap(0x2d5aabe2deffc4826cabfeb8cd358608096063bfe7841cc54fd49f525f9b3476);

    /// @dev The auto cover mapping of vpool shares.
    /// @dev Type: mapping(address => uint256)
    /// @dev Slot: keccak256(bytes("treasury.1.autoCover")) - 1
    types.Mapping internal constant $autoCover = types.Mapping.wrap(0xf27e550551354587325f59447e48bba4969512775e2415dd0248e903ab1af44f);

    /// @notice Initialize the vTreasury (proxy pattern)
    /// @param operator_ The address of the operator owning this contract
    /// @param nexus_ The address of the nexus contract
    /// @param fee_ The initial fee value
    // slither-disable-next-line missing-zero-check
    function initialize(address operator_, address nexus_, uint256 fee_) external init(0) {
        LibSanitize.notZeroAddress(nexus_);
        _setOperator(operator_);
        _setFee(fee_);
        $nexus.set(nexus_);
        emit SetNexus(nexus_);
    }

    /// @notice Only allows the operator or the global recipient to perform the call
    modifier onlyOperatorOrGlobalRecipient() {
        if (msg.sender != $operator.get() && msg.sender != _globalRecipient()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @notice Only allows the operator to perform the call
    modifier onlyOperator() {
        if (msg.sender != $operator.get()) {
            revert LibErrors.Unauthorized(msg.sender, $operator.get());
        }
        _;
    }

    /// @inheritdoc IvTreasury
    function nexus() external view returns (address) {
        return $nexus.get();
    }

    /// @inheritdoc IvTreasury
    function operator() external view returns (address) {
        return $operator.get();
    }

    /// @inheritdoc IvTreasury
    function fee() external view returns (uint256) {
        return $fee.get();
    }

    /// @inheritdoc IvTreasury
    function autoCover(address pool) external view returns (uint256) {
        return $autoCover.get()[pool.k()];
    }

    /// @inheritdoc IvTreasury
    function votes() external view returns (uint256 operatorVote, uint256 globalRecipientVote) {
        return ($operatorFeeVote.get(), $globalRecipientFeeVote.get());
    }

    /// @inheritdoc IvTreasury
    function setOperator(address newOperator) external onlyOperator {
        _setOperator(newOperator);
    }

    /// @inheritdoc IvTreasury
    function setAutoCover(address pool, uint256 autoCoverBps) external onlyOperator {
        _setAutoCover(pool, autoCoverBps);
    }

    /// @inheritdoc IvPoolSharesReceiver
    function onvPoolSharesReceived(address, address, uint256 amount, bytes memory) external returns (bytes4) {
        $poolShares.get()[msg.sender.k()] += amount;
        emit VPoolSharesReceived(msg.sender, amount);
        return IvPoolSharesReceiver.onvPoolSharesReceived.selector;
    }

    /// @dev Allows the operator to send pool shares to the exit queue, split commissions and pay for coverage
    /// @param pool The pool to exit
    /// @param currentSharesCount The amount of shares to exit
    function _exitAndFundCoverageFund(IvPool pool, uint256 currentSharesCount) internal {
        $poolShares.get()[msg.sender.k()] = 0;
        uint256 currentFee = $fee.get();
        address exitQueue = pool.exitQueue();
        // if the global recipient commission is not null, we exit on behalf of the
        // global recipient in the exit queue
        if (currentFee > 0) {
            uint256 feeAmount = LibUint256.mulDiv(currentSharesCount, currentFee, LibConstant.BASIS_POINTS_MAX);
            if (feeAmount > 0 && !pool.transferShares(exitQueue, feeAmount, abi.encodePacked(_globalRecipient()))) {
                revert TransferError(address(pool), exitQueue, abi.encodePacked(_globalRecipient()));
            }
            currentSharesCount -= feeAmount;
        }
        // if the auto cover value for the pool is not null, we send the amount from the operator commission
        // to the coverage recipient
        uint256 autoCoverBps = $autoCover.get()[address(pool).k()];
        if (autoCoverBps > 0) {
            uint256 autoCoverAmount = LibUint256.mulDiv(currentSharesCount, autoCoverBps, LibConstant.BASIS_POINTS_MAX);
            address coverageRecipient = pool.coverageRecipient();
            if (autoCoverAmount > 0 && !pool.transferShares(coverageRecipient, autoCoverAmount, "")) {
                revert TransferError(address(pool), coverageRecipient, "");
            }
            currentSharesCount -= autoCoverAmount;
        }
        if (currentSharesCount > 0 && !pool.transferShares(exitQueue, currentSharesCount, abi.encodePacked($operator.get()))) {
            revert TransferError(address(pool), exitQueue, abi.encodePacked($operator.get()));
        }
    }

    /// @inheritdoc IvTreasury
    function exitShares(address pool) external onlyOperatorOrGlobalRecipient {
        uint256 currentSharesCount = $poolShares.get()[pool.k()];
        if (currentSharesCount == 0) {
            revert NoSharesToExit(pool);
        }
        _exitAndFundCoverageFund(IvPool(pool), currentSharesCount);
    }

    /// @inheritdoc IvTreasury
    function voteFee(uint256 newFee) external onlyOperatorOrGlobalRecipient {
        LibSanitize.notInvalidBps(newFee);
        if (msg.sender == _globalRecipient()) {
            uint256 opFeeVote = $operatorFeeVote.get();
            if (_hasVoted(opFeeVote) && _getVote(opFeeVote) == newFee) {
                emit VoteChanged(msg.sender, opFeeVote, _applyVote(newFee));
                _setFee(newFee);
                $operatorFeeVote.set(0);
                $globalRecipientFeeVote.set(0);
                emit VoteChanged(msg.sender, 0, 0);
            } else {
                uint256 newGlobalRecipientFeeVote = _applyVote(newFee);
                $globalRecipientFeeVote.set(newGlobalRecipientFeeVote);
                emit VoteChanged(msg.sender, opFeeVote, newGlobalRecipientFeeVote);
            }
        } else {
            uint256 grFeeVote = $globalRecipientFeeVote.get();
            if (_hasVoted(grFeeVote) && _getVote(grFeeVote) == newFee) {
                emit VoteChanged(msg.sender, _applyVote(newFee), grFeeVote);
                _setFee(newFee);
                $operatorFeeVote.set(0);
                $globalRecipientFeeVote.set(0);
                emit VoteChanged(msg.sender, 0, 0);
            } else {
                uint256 newOperatorFeeVote = _applyVote(newFee);
                $operatorFeeVote.set(newOperatorFeeVote);
                emit VoteChanged(msg.sender, newOperatorFeeVote, grFeeVote);
            }
        }
    }

    /// @inheritdoc IvTreasury
    // slither-disable-next-line reentrancy-events,reentrancy-eth
    function withdraw(address token) external onlyOperatorOrGlobalRecipient {
        LibSanitize.notZeroAddress(token);

        uint256 currentBalance = _balance(token);
        uint256 commission = 0;

        address globalRecipient = _globalRecipient();
        uint256 currentFee = $fee.get();

        if (currentFee > 0) {
            commission = LibUint256.mulDiv(currentBalance, currentFee, LibConstant.BASIS_POINTS_MAX);
            if (commission > 0) {
                _transfer(token, commission, globalRecipient);
                currentBalance -= commission;
            }
        }

        address currentOperatorAddress = $operator.get();

        _transfer(token, currentBalance, currentOperatorAddress);

        emit Withdraw(currentOperatorAddress, globalRecipient, currentBalance, commission);
    }

    /// @dev Internal utility to change the fee
    /// @param newFee New fee value in bps
    function _setFee(uint256 newFee) internal {
        LibSanitize.notInvalidBps(newFee);
        $fee.set(newFee);
        emit SetFee(newFee);
    }

    /// @dev Internal utility to change the auto cover amount for a pool
    /// @param pool The pool to change the auto cover amount for
    /// @param newAutoCoverBps The new auto cover amount in bps
    function _setAutoCover(address pool, uint256 newAutoCoverBps) internal {
        LibSanitize.notInvalidBps(newAutoCoverBps);
        $autoCover.get()[pool.k()] = newAutoCoverBps;
        emit SetAutoCover(pool, newAutoCoverBps);
    }

    /// @dev Internal utility to change the operator address
    /// @param newOperator The new operator address
    function _setOperator(address newOperator) internal {
        LibSanitize.notZeroAddress(newOperator);
        $operator.set(newOperator);
        emit SetOperator(newOperator);
    }

    /// @dev Internal utility to transfer out the specified token and amount to the recipient
    /// @param token The address of the token to transfer
    /// @param amount The amount to transfer
    /// @param recipient The address to receive the funds
    // slither-disable-next-line low-level-calls
    function _transfer(address token, uint256 amount, address recipient) internal {
        uint256 poolShares = $poolShares.get()[token.k()];
        if (poolShares > 0) {
            $poolShares.get()[token.k()] = poolShares - amount;
            if (!IvPool(token).transferShares(recipient, amount, "")) {
                revert TransferError(token, recipient, "");
            }
        } else if (token == ETHER) {
            (bool success, bytes memory rdata) = recipient.call{value: amount}("");
            if (!success) {
                revert TransferError(token, recipient, rdata);
            }
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    /// @dev Internal utility to apply the active bit to the vote value
    /// @param newFee The fee value in bps
    /// @return The vote value
    function _applyVote(uint256 newFee) internal pure returns (uint256) {
        return (1 << 255) + newFee;
    }

    /// @dev Internal utility to check on a vote value if a vote has been made
    /// @param vote The vote value
    /// @return True if contains a vote
    function _hasVoted(uint256 vote) internal pure returns (bool) {
        return (vote >> 255) & 1 == 1;
    }

    /// @dev Internal utility to retrieve the bps value from the vote value
    /// @param vote The vote value
    /// @return The voted fee value
    function _getVote(uint256 vote) internal pure returns (uint128) {
        return uint128(vote & uint256(type(uint128).max));
    }

    /// @dev Internal utility to retrieve the balance in the specified token
    /// @param token The address of the token
    /// @return The balance of the token
    function _balance(address token) internal view returns (uint256) {
        uint256 poolSharesBalance = $poolShares.get()[token.k()];
        if (poolSharesBalance > 0) {
            return poolSharesBalance;
        } else if (token == ETHER) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /// @dev Internal utility to retrieve the global recipient address
    /// @return The global recipient address
    function _globalRecipient() internal view returns (address) {
        return IGlobalRecipientHolder($nexus.get()).globalRecipient();
    }

    receive() external payable {}
    fallback() external payable {}
}
