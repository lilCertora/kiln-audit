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

import "utils.sol/interfaces/IFixable.sol";

import "./IvPoolSharesReceiver.sol";

/// @title Treasury Interface
/// @author mortimr @ Kiln
/// @notice The vTreasury is in charge of collecting the operator commissions accross all the contracts
interface IvTreasury is IvPoolSharesReceiver, IFixable {
    /// @notice Emitted when the operator address has changed
    /// @param operator New operator address
    event SetOperator(address operator);

    /// @notice Emitted when the fee has changed
    /// @param fee New fee value
    event SetFee(uint256 fee);

    /// @notice Emitted when the auto cover amount for a pool has changed
    /// @param pool The address of the pool
    /// @param autoCover The new auto cover amount
    event SetAutoCover(address indexed pool, uint256 autoCover);

    /// @notice Emitted when the nexus address has changed
    /// @param nexus New nexus address
    event SetNexus(address nexus);

    /// @notice Emitted when a vote has been made
    /// @param voter The address that performed the vote
    /// @param operatorFeeVote The operator fee vote after the vote
    /// @param globalRecipientFeeVote The global recipient fee vote after the vote
    event VoteChanged(address voter, uint256 operatorFeeVote, uint256 globalRecipientFeeVote);

    /// @notice Emitted when funds have been withdrawn from the treasury
    /// @param operator The address of the operator receiving the operator cut
    /// @param globalRecipient The address of the global recipient receiving the global cut
    /// @param rewards The amount withdrawn by the operator
    /// @param commission The amount received by the global recipient
    event Withdraw(address indexed operator, address indexed globalRecipient, uint256 rewards, uint256 commission);

    /// @notice Emitted when vpool shares are received
    /// @param vpool Address of the vpool sending the shares
    /// @param amount The amount of vpool shares received
    event VPoolSharesReceived(address vpool, uint256 amount);

    /// @notice An error happened during the token transfer
    /// @param token The address of the withdrawn token
    /// @param recipient The address that should be receiving the token
    /// @param rdata Error return data
    error TransferError(address token, address recipient, bytes rdata);

    /// @notice No shares available to exit for the specified vpool
    /// @param pool The address of the vpool
    error NoSharesToExit(address pool);

    /// @notice Initializer of the vTreasury
    /// @param operator_ The address of the operator
    /// @param nexus_ The address of the system nexus
    /// @param fee_ The initial treasury fee
    function initialize(address operator_, address nexus_, uint256 fee_) external;

    /// @notice Retrieve the address of the nexus contract
    /// @return nexusAddress The nexus address
    function nexus() external view returns (address nexusAddress);

    /// @notice Retrieve the address of the operator
    /// @return operatorAddress The operator address
    function operator() external view returns (address operatorAddress);

    /// @notice Retrieve the current fee value
    /// @return currentFee The fee value in bps
    function fee() external view returns (uint256 currentFee);

    function autoCover(address pool) external view returns (uint256);

    /// @notice Retrieve the current vote values
    /// @return operatorVote The operator vote value
    /// @return globalRecipientVote The global recipient vote value
    function votes() external view returns (uint256 operatorVote, uint256 globalRecipientVote);

    /// @notice Change the address of the operator owning this contract
    /// @param newOperator The new operator address
    function setOperator(address newOperator) external;

    /// @notice Force exits the shares of the specified vpool
    /// @param pool The address of the vpool
    function exitShares(address pool) external;

    /// @notice Vote on a new fee value in bps
    /// @dev The vote value has bit 255 set to 1 if a vote has been made
    /// @param newFee New fee value in bps
    function voteFee(uint256 newFee) external;

    /// @notice Update the auto cover amount for a pool
    /// param pool The updated pool
    /// param autoCoverBps The new auto cover amount in bps
    function setAutoCover(address pool, uint256 autoCoverBps) external;

    /// @notice Perform a withdrawal of the specified token
    /// @dev Specifying the ETHER address as value withdraws eth
    /// @param token The address of the token to withdraw
    function withdraw(address token) external;
}
