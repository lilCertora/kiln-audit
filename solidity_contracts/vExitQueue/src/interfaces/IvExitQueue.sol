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
import "../ctypes/ctypes.sol";

/// @title Exit Queue Interface
/// @author mortimr @ Kiln
/// @notice The exit queue stores exit requests until they are filled and claimable
interface IvExitQueue is IFixable, IvPoolSharesReceiver {
    /// @notice Emitted when the stored Pool address is changed
    /// @param pool The new pool address
    event SetPool(address pool);

    /// @notice Emitted when the stored token uri image url is changed
    /// @param tokenUriImageUrl The new token uri image url
    event SetTokenUriImageUrl(string tokenUriImageUrl);

    /// @notice Emitted when the transfer enabled status is changed
    /// @param enabled The new transfer enabled status
    event SetTransferEnabled(bool enabled);

    /// @notice Emitted when the unclaimed funds buffer is changed
    /// @param unclaimedFunds The new unclaimed funds buffer
    event SetUnclaimedFunds(uint256 unclaimedFunds);

    /// @notice Emitted when ether was supplied to the vPool
    /// @param amount The amount of ETH supplied
    event SuppliedEther(uint256 amount);

    /// @notice Emitted when a ticket is created
    /// @param owner The address of the ticket owner
    /// @param idx The index of the ticket
    /// @param id The ID of the ticket
    /// @param ticket The ticket details
    event PrintedTicket(address indexed owner, uint32 idx, uint256 id, ctypes.Ticket ticket);

    /// @notice Emitted when a cask is created
    /// @param id The ID of the cask
    /// @param cask The cask details
    event ReceivedCask(uint32 id, ctypes.Cask cask);

    /// @notice Emitted when a ticket is claimed against a cask, can happen several times for the same ticket but different casks
    /// @param ticketId The ID of the ticket
    /// @param caskId The ID of the cask
    /// @param amountFilled The amount of shares filled
    /// @param amountEthFilled The amount of ETH filled
    /// @param unclaimedEth The amount of ETH that is added to the unclaimed buffer
    event FilledTicket(
        uint256 indexed ticketId, uint32 indexed caskId, uint128 amountFilled, uint256 amountEthFilled, uint256 unclaimedEth
    );

    /// @notice Emitted when a ticket is "reminted" and its external id is modified
    /// @param oldTicketId The old ID of the ticket
    /// @param newTicketId The new ID of the ticket
    /// @param ticketIndex The index of the ticket
    event TicketIdUpdated(uint256 indexed oldTicketId, uint256 indexed newTicketId, uint32 indexed ticketIndex);

    /// @notice Emitted when a payment is made after a user performed a claim
    /// @param recipient The address of the recipient
    /// @param amount The amount of ETH paid
    event Payment(address indexed recipient, uint256 amount);

    /// @notice Transfer of tickets is disabled
    error TransferDisabled();

    /// @notice The provided ticket ID is invalid
    /// @param id The ID of the ticket
    error InvalidTicketId(uint256 id);

    /// @notice The provided cask ID is invalid
    /// @param id The ID of the cask
    error InvalidCaskId(uint32 id);

    /// @notice The provided ticket IDs and cask IDs are not the same length
    error InvalidLengths();

    /// @notice The ticket and cask are not associated
    /// @param ticketId The ID of the ticket
    /// @param caskId The ID of the cask
    error TicketNotMatchingCask(uint256 ticketId, uint32 caskId);

    /// @notice The claim transfer failed
    /// @param recipient The address of the recipient
    /// @param rdata The revert data
    error ClaimTransferFailed(address recipient, bytes rdata);

    enum ClaimStatus {
        CLAIMED,
        PARTIALLY_CLAIMED,
        SKIPPED
    }

    /// @notice Initializes the ExitQueue (proxy pattern)
    /// @param vpool The address of the associated vPool
    /// @param newTokenUriImageUrl The token uri image url
    function initialize(address vpool, string calldata newTokenUriImageUrl) external;

    /// @notice Returns the token uri image url
    /// @return The token uri image url
    function tokenUriImageUrl() external view returns (string memory);

    /// @notice Returns the transfer enabled status
    /// @return True if transfers are enabled
    function transferEnabled() external view returns (bool);

    /// @notice Returns the unclaimed funds buffer
    /// @return The unclaimed funds buffer
    function unclaimedFunds() external view returns (uint256);

    /// @notice Returns the id of the ticket based on the index
    /// @param idx The index of the ticket
    function ticketIdAtIndex(uint32 idx) external view returns (uint256);

    /// @notice Returns the details about the ticket with the provided ID
    /// @param id The ID of the ticket
    /// @return The ticket details
    function ticket(uint256 id) external view returns (ctypes.Ticket memory);

    /// @notice Returns the number of tickets
    /// @return The number of tickets
    function ticketCount() external view returns (uint256);

    /// @notice Returns the details about the cask with the provided ID
    /// @param id The ID of the cask
    /// @return The cask details
    function cask(uint32 id) external view returns (ctypes.Cask memory);

    /// @notice Returns the number of casks
    /// @return The number of casks
    function caskCount() external view returns (uint256);

    /// @notice Resolves the provided tickets to their associated casks or provide resolution error codes
    /// @dev TICKET_ID_OUT_OF_BOUNDS = -1;
    ///      TICKET_ALREADY_CLAIMED = -2;
    ///      TICKET_PENDING = -3;
    /// @param ticketIds The IDs of the tickets to resolve
    /// @return caskIdsOrErrors The IDs of the casks or error codes
    function resolve(uint256[] memory ticketIds) external view returns (int64[] memory caskIdsOrErrors);

    /// @notice Adds eth and creates a new cask
    /// @dev only callbacle by the vPool
    /// @param shares The amount of shares to cover with the provided eth
    function feed(uint256 shares) external payable;

    /// @notice Pulls eth from the unclaimed eth buffer
    /// @dev Only callable by the vPool
    /// @param max The maximum amount of eth to pull
    function pull(uint256 max) external;

    /// @notice Claims the provided tickets against their associated casks
    /// @dev To retrieve the list of casks, an off-chain resolve call should be performed
    /// @param ticketIds The IDs of the tickets to claim
    /// @param caskIds The IDs of the casks to claim against
    /// @param maxClaimDepth The maxiumum recursion depth for the claim, 0 for unlimited
    function claim(uint256[] calldata ticketIds, uint32[] calldata caskIds, uint16 maxClaimDepth)
        external
        returns (ClaimStatus[] memory statuses);

    /// @notice Sets the token uri image inside the returned token uri
    /// @param newTokenUriImageUrl The new token uri image url
    function setTokenUriImageUrl(string calldata newTokenUriImageUrl) external;

    /// @notice Enables or disables transfers of the tickets
    /// @param value True to allow transfers
    function setTransferEnabled(bool value) external;
}
