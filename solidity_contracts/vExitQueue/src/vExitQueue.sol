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
import "utils.sol/NFT.sol";
import "utils.sol/Implementation.sol";
import "utils.sol/types/bool.sol";
import "openzeppelin-contracts/utils/Base64.sol";

import "./lib/LibStringify.sol";
import "./ctypes/ticket_array.sol";
import "./ctypes/cask_array.sol";
import "./interfaces/IvExitQueue.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IvFactory.sol";

/// @title Exit Queue
/// @author mortimr @ Kiln
/// @notice The exit queue stores exit requests until they are filled and claimable
///
///           ⢀⣀ ⢀⣤⣤⣤⠄⣠⣤⣤⠄⢀⣀⡀
///         ⢀⣾⣿⠏⢰⣿⣿⣿⠃⣰⣿⣿⠁⣴⣿⣿⣿⣷⡀
///         ⣾⣿⡟⢀⣿⣿⣿⡏⢠⣿⣿⡇⢰⣿⣿⣿⣿⣿⣷
///        ⢸⣿⣿⡇⢸⣿⣿⣿⡇⢸⣿⣿ ⢸⣿⣿⣿⣿⣿⣿
///        ⠈⣿⣿⡇⠸⣿⣿⣿⡇⢸⣿⣿⡆⢸⣿⣿⠟⢿⣿⣿
///         ⠘⠛⠛ ⠛⠛⠛⠃⠈⠻⠿⠧⠈⣿⡇ ⢸⣿⠃
///      ⢀⣤⠄⢀⣶⣿⣿⡟⢠⣾⣿⠇⢀⣤⣤⣄⠛⠛⠛⢁ ⣤⣤⣄         ⢀⣤⠄⢀⣶⣿⣿⡟⢠⣾⣿⠇⢀⣤⣤⣄     ⣤⣤⣄
///     ⣴⣿⡏⢠⣿⣿⣿⡟⢠⣿⣿⠃⣰⣿⣿⣿⣿⣧  ⢠⣿⣿⣿⣿⣧      ⣴⣿⡏⢠⣿⣿⣿⡟⢠⣿⣿⠃⣰⣿⣿⣿⣿⣧  ⢠⣿⣿⣿⣿⣧
///    ⢰⣿⣿ ⣾⣿⣿⣿⠁⣼⣿⡏⢠⣿⣿⣿⣿⣿⣿⡄ ⣿⣿⣿⣿⣿⣿⡇    ⢰⣿⣿ ⣾⣿⣿⣿⠁⣼⣿⡏⢠⣿⣿⣿⣿⣿⣿⡄ ⣿⣿⣿⣿⣿⣿⡇
///    ⢸⣿⣿ ⣿⣿⣿⣿ ⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⡇ ⣿⣿⣿⣿⣿⣿⡇    ⢸⣿⣿ ⣿⣿⣿⣿ ⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⡇ ⣿⣿⣿⣿⣿⣿⡇
///    ⠘⣿⣿ ⣿⣿⣿⣿⡀⢻⣿⣧⠈⣿⣿⠟⠙⣿⣿⠁ ⢿⣿⡟⠙⢿⣿⠇    ⠘⣿⣿ ⣿⣿⣿⣿⡀⢻⣿⣧⠈⣿⣿⠟⠙⣿⣿⠁ ⢿⣿⡟⠙⢿⣿⠇
///     ⠙⢿⣇⠘⢿⣿⣿⣧⠈⣿⣿⣆⠘⣿⣄⣠⣾⠃⣰⣧⠘⢿⣇⢀⣾⠏      ⠙⢿⣇⠘⢿⣿⣿⣧⠈⣿⣿⣆⠘⣿⣄⣠⣾⠃⣰⣧⠘⢿⣇⢀⣾⠏
///       ⠈⠁⠈⠛⠛⠛⠃⠈⠛⠛⠓ ⠉⠉ ⠐⠛⠛⠓ ⠉⠉⠁          ⠈⠁⠈⠛⠛⠛⠃⠈⠛⠛⠓ ⠉⠉ ⠐⠛⠛⠓ ⠉⠉⠁
///
// slither-disable-next-line naming-convention
contract vExitQueue is NFT, Fixable, Initializable, Implementation, IvExitQueue {
    using LUint256 for types.Uint256;
    using LAddress for types.Address;
    using LBool for types.Bool;
    using LString for types.String;
    using LTicketArray for ctypes.TicketArray;
    using LCaskArray for ctypes.CaskArray;

    /// @dev Address of the associated vPool
    /// @dev Slot: keccak256(bytes("exitQueue.1.pool"))) - 1
    types.Address internal constant $pool = types.Address.wrap(0xdcdd87edea8fcbdc6d50bb4863c8269eed833245e48ec3e4f64dc4cd88a27283);

    /// @dev Total amount of unclaimed funds in the exit queue - 1
    /// @dev Slot: keccak256(bytes("exitQueue.1.unclaimedFunds")))
    types.Uint256 internal constant $unclaimedFunds = types.Uint256.wrap(0x51fae72b3be6f7b8c2f4de519c1a9fb3f8624c4c7d1f85109b6659ae4958c29a);

    /// @dev Flag enabling/disabling transfers
    /// @dev Slot: keccak256(bytes("exitQueue.1.transferEnabled"))) - 1
    types.Bool internal constant $transferEnabled = types.Bool.wrap(0xc1bfc3030aebadb3bfaa3fbc59cf364f7dee6ab92429159a4bfdf02fa88336a0);

    /// @dev Token URI image URL
    /// @dev Slot: keccak256(bytes("exitQueue.1.tokenUriImageUrl"))) - 1
    types.String internal constant $tokenUriImageUrl = types.String.wrap(0x0f0463b3f5083af4c7135d28606a2c0eaa2bd9e3f9f62db1539e47244df8dc49);

    /// @dev Array of tickets
    /// @dev Slot: keccak256(bytes("exitQueue.1.tickets"))) - 1
    ctypes.TicketArray internal constant $tickets =
        ctypes.TicketArray.wrap(0x409fdfd8838fda00128ca5d502af2ba15c034ca4130776e2ed6d3eb7811e3481);

    /// @dev Array of casks
    /// @dev Slot: keccak256(bytes("exitQueue.1.casks"))) - 1
    ctypes.CaskArray internal constant $casks = ctypes.CaskArray.wrap(0x39a5c864ceb6f99a196a385a148476994e3952fd6d71d040a2339a143eaeabe1);

    /// @dev Resolution error code for a ticket that is out of bounds
    int64 internal constant TICKET_ID_OUT_OF_BOUNDS = -1;
    /// @dev Resolution error code for a ticket that has already been claimed
    int64 internal constant TICKET_ALREADY_CLAIMED = -2;
    /// @dev Resolution error code for a ticket that is pending fulfillment
    int64 internal constant TICKET_PENDING = -3;

    /// @notice Prevents calls not coming from the associated vPool
    modifier onlyPool() {
        if (msg.sender != $pool.get()) {
            revert LibErrors.Unauthorized(msg.sender, $pool.get());
        }
        _;
    }

    /// @notice Prevents calls not coming from the vFactory admin
    modifier onlyAdmin() {
        {
            address admin = IvFactory(_castedPool().factory()).admin();
            if (msg.sender != admin) {
                revert LibErrors.Unauthorized(msg.sender, admin);
            }
        }
        _;
    }

    /// @inheritdoc IvExitQueue
    // slither-disable-next-line missing-zero-check
    function initialize(address vpool, string calldata newTokenUriImageUrl) external init(0) {
        _setTokenUriImageUrl(newTokenUriImageUrl);
        LibSanitize.notZeroAddress(vpool);
        $pool.set(vpool);
        emit SetPool(vpool);
    }

    /// @inheritdoc IvExitQueue
    function tokenUriImageUrl() external view returns (string memory) {
        return $tokenUriImageUrl.get();
    }

    /// @notice Get the Exit Queue name from the associated vPool -> Factory.
    /// @dev The name is mutable (can be updated by the Factory admin).
    /// @return The name of the Exit Queue.
    function name() external view override returns (string memory) {
        // slither-disable-next-line unused-return
        (string memory operatorName,,) = IvFactory(_castedPool().factory()).metadata();
        return string(abi.encodePacked(operatorName, " Exit Queue"));
    }

    /// @inheritdoc NFT
    function symbol() external pure override returns (string memory) {
        return "vEQ";
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) external view override(NFT) returns (string memory) {
        _requireExists(tokenId);
        uint256 tokenIdx = _getTicketIdx(tokenId);
        ctypes.Ticket memory t = $tickets.get()[tokenIdx];
        ctypes.Cask[] storage caskArray = $casks.get();
        uint256 claimable = 0;
        uint256 queueSize = 0;
        {
            ctypes.Cask memory c = caskArray.length > 0 ? caskArray[caskArray.length - 1] : ctypes.Cask({position: 0, size: 0, value: 0});

            //           | CASK |
            // | TICKET |
            if (c.position > t.position + t.size) {
                claimable = t.size;
                //       | CASK |
                // | TICKET |
            } else if (c.position >= t.position) {
                claimable = t.size - (c.position + c.size >= t.position + t.size ? 0 : (t.position + t.size) - (c.position + c.size));
                // | CASK |
                //      | TICKET |
            } else if (c.position < t.position && t.position < c.position + c.size) {
                claimable = (c.position + c.size) - t.position;
            }
            queueSize = c.position + c.size;
        }
        bytes memory fullImageUrl =
            abi.encodePacked($tokenUriImageUrl.get(), "/", Strings.toHexString(address(this)), "/", Strings.toString(tokenId));
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "{",
                        "\"name\":\"Exit Ticket #",
                        Strings.toString(tokenIdx),
                        "\",",
                        "\"description\":\"This exit ticket can be used to claim funds from the exit queue contract once it is fulfilled.\",",
                        _generateAttributes(t, claimable, queueSize),
                        "\"image_url\":\"",
                        fullImageUrl,
                        "\"}"
                    )
                )
            )
        );
    }

    /// @inheritdoc IvExitQueue
    function transferEnabled() external view returns (bool) {
        return $transferEnabled.get();
    }

    /// @inheritdoc IvExitQueue
    function unclaimedFunds() external view returns (uint256) {
        return $unclaimedFunds.get();
    }

    /// @inheritdoc IvExitQueue
    function ticketIdAtIndex(uint32 idx) external view returns (uint256) {
        return _getTicketId(idx, $tickets.get()[idx]);
    }

    /// @inheritdoc IvExitQueue
    function ticket(uint256 id) external view returns (ctypes.Ticket memory) {
        uint256 idx = _getTicketIdx(id);
        ctypes.Ticket[] storage ticketArray = $tickets.get();
        if (idx >= ticketArray.length) {
            revert InvalidTicketId(id);
        }
        return ticketArray[idx];
    }

    /// @inheritdoc IvExitQueue
    function ticketCount() external view returns (uint256) {
        return $tickets.get().length;
    }

    /// @inheritdoc IvExitQueue
    function cask(uint32 id) external view returns (ctypes.Cask memory) {
        ctypes.Cask[] storage caskArray = $casks.get();
        if (id >= caskArray.length) {
            revert InvalidCaskId(id);
        }
        return caskArray[id];
    }

    /// @inheritdoc IvExitQueue
    function caskCount() external view returns (uint256) {
        return $casks.get().length;
    }

    /// @inheritdoc IvExitQueue
    function resolve(uint256[] memory ticketIds) external view returns (int64[] memory caskIdsOrErrors) {
        uint256 ticketIdsLength = ticketIds.length;
        caskIdsOrErrors = new int64[](ticketIdsLength);
        uint256 totalTicketCount = $tickets.get().length;
        uint256 totalCaskCount = $casks.get().length;
        for (uint256 idx = 0; idx < ticketIdsLength;) {
            caskIdsOrErrors[idx] = _resolve(ticketIds[idx], totalTicketCount, totalCaskCount);
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IvExitQueue
    function feed(uint256 shares) external payable onlyPool {
        LibSanitize.notNullValue(shares);
        LibSanitize.notNullValue(msg.value);
        ctypes.Cask[] storage caskArray = $casks.get();
        uint256 casksLength = caskArray.length;
        ctypes.Cask memory lastCask = casksLength > 0 ? caskArray[casksLength - 1] : ctypes.Cask({position: 0, size: 0, value: 0});
        ctypes.Cask memory newCask =
            ctypes.Cask({position: lastCask.position + lastCask.size, size: uint128(shares), value: uint128(msg.value)});
        caskArray.push(newCask);
        emit ReceivedCask(uint32(casksLength), newCask);
    }

    /// @inheritdoc IvExitQueue
    function pull(uint256 max) external onlyPool {
        uint256 currentUnclaimedFunds = $unclaimedFunds.get();
        uint256 maxPullable = LibUint256.min(max, currentUnclaimedFunds);
        if (maxPullable > 0) {
            _setUnclaimedFunds(currentUnclaimedFunds - maxPullable);
            emit SuppliedEther(maxPullable);
            _castedPool().injectEther{value: maxPullable}();
        }
    }

    /// @inheritdoc IvPoolSharesReceiver
    //slither-disable-next-line assembly
    function onvPoolSharesReceived(address, address from, uint256 amount, bytes memory data) external override onlyPool returns (bytes4) {
        LibSanitize.notNullValue(amount);
        if (data.length == 20) {
            // If the data appears to be a packed encoded address we print a ticket to that address instead of the sender
            address to;
            assembly {
                // After skipping the length element of data, the first element (20 bytes padded on the right to 32 bytes) is
                // converted to an actual address by right shifting.
                to := shr(96, mload(add(data, 32)))
            }
            _printTicket(uint128(amount), to);
        } else {
            _printTicket(uint128(amount), from);
        }
        return IvPoolSharesReceiver.onvPoolSharesReceived.selector;
    }

    /// @inheritdoc IvExitQueue
    function setTokenUriImageUrl(string calldata newTokenUriImageUrl) external onlyAdmin {
        _setTokenUriImageUrl(newTokenUriImageUrl);
    }

    /// @inheritdoc IvExitQueue
    function setTransferEnabled(bool value) external onlyAdmin {
        _setTransferEnabled(value);
    }

    struct ClaimInternalVariables {
        uint256 ticketIdsLength;
        uint256 totalTicketCount;
        address[] recipients;
        uint256[] payments;
        uint256 usedRecipients;
        ConsumeTicketParameters params;
    }

    /// @inheritdoc IvExitQueue
    // slither-disable-next-line arbitrary-send-eth,calls-loop,reentrancy-events,cyclomatic-complexity
    function claim(uint256[] calldata ticketIds, uint32[] calldata caskIds, uint16 maxClaimDepth)
        external
        returns (ClaimStatus[] memory statuses)
    {
        // slither-disable-next-line uninitialized-local
        ClaimInternalVariables memory __;
        __.ticketIdsLength = ticketIds.length;
        if (__.ticketIdsLength == 0 || __.ticketIdsLength != caskIds.length) {
            revert InvalidLengths();
        }
        __.totalTicketCount = $tickets.get().length;
        __.params.totalCaskCount = $casks.get().length;

        statuses = new ClaimStatus[](ticketIds.length);

        __.recipients = new address[](ticketIds.length);
        __.payments = new uint256[](ticketIds.length);
        __.usedRecipients = 0;

        // slither-disable-next-line uninitialized-local
        for (uint256 idx; idx < __.ticketIdsLength;) {
            __.params.ticketId = ticketIds[idx];
            __.params.ticketIdx = _getTicketIdx(__.params.ticketId);
            __.params.caskId = caskIds[idx];
            __.params.depth = maxClaimDepth;
            __.params.ethToPay = 0;

            // this line reverts if the ticket id doesn't exist
            address owner = ownerOf(ticketIds[idx]);

            __.params.t = $tickets.get()[__.params.ticketIdx];

            if (__.params.t.size == 0) {
                statuses[idx] = ClaimStatus.SKIPPED;
                unchecked {
                    ++idx;
                }
                continue;
            }

            if (__.params.caskId >= __.params.totalCaskCount) {
                revert InvalidCaskId(__.params.caskId);
            }

            __.params.c = $casks.get()[__.params.caskId];

            if (!_matching(__.params.t, __.params.c)) {
                revert TicketNotMatchingCask(__.params.ticketId, __.params.caskId);
            }

            _consumeTicket(__.params);

            if (__.params.t.size > 0) {
                uint256 ticketIdx = _getTicketIdx(ticketIds[idx]);
                _burn(ticketIds[idx]);
                uint256 newTicketId = _getTicketId(ticketIdx, $tickets.get()[ticketIdx]);
                _mint(owner, newTicketId);
                emit TicketIdUpdated(ticketIds[idx], newTicketId, uint32(ticketIdx));
            }
            statuses[idx] = __.params.t.size > 0 ? ClaimStatus.PARTIALLY_CLAIMED : ClaimStatus.CLAIMED;
            if (__.params.ethToPay > 0) {
                int256 ownerIndex = -1;
                for (uint256 recipientIdx = 0; recipientIdx < __.usedRecipients;) {
                    if (__.recipients[recipientIdx] == owner) {
                        ownerIndex = int256(recipientIdx);
                        break;
                    }
                    unchecked {
                        ++recipientIdx;
                    }
                }

                if (ownerIndex == -1) {
                    __.recipients[__.usedRecipients] = owner;
                    __.payments[__.usedRecipients] = __.params.ethToPay;
                    unchecked {
                        ++__.usedRecipients;
                    }
                } else {
                    __.payments[uint256(ownerIndex)] += __.params.ethToPay;
                }
            }

            unchecked {
                ++idx;
            }
        }

        for (uint256 recipientIdx = 0; recipientIdx < __.usedRecipients;) {
            address recipient = __.recipients[recipientIdx];
            uint256 payment = __.payments[recipientIdx];
            // slither-disable-next-line missing-zero-check,low-level-calls
            (bool success, bytes memory reason) = recipient.call{value: payment}("");
            if (!success) {
                revert ClaimTransferFailed(recipient, reason);
            }
            emit Payment(recipient, payment);
            unchecked {
                ++recipientIdx;
            }
        }
    }

    /// @dev Internal utility function to retrieve the string status of a ticket
    /// @param t The ticket to get the status of
    /// @param claimable The amount of the ticket that is claimable
    /// @return The status of the ticket
    function _getStatusString(ctypes.Ticket memory t, uint256 claimable) internal pure returns (string memory) {
        if (claimable == 0) {
            return "Not yet claimable";
        } else if (claimable < t.size) {
            return "Partially claimable";
        }
        return "Fully claimable";
    }

    /// @dev Internal utility function to generate the attributes of a ticket
    /// @param t The ticket to get the attributes of
    /// @param claimable The amount of the ticket that is claimable
    /// @return The attributes of the ticket
    function _generateAttributes(ctypes.Ticket memory t, uint256 claimable, uint256 queueSize) internal pure returns (bytes memory) {
        return abi.encodePacked(
            "\"attributes\":[{\"trait_type\":\"Queue position\",\"value\":",
            LibStringify.uintToDecimalString(t.position, 18, 3),
            ",\"display_type\":\"number\",\"max_value\":",
            LibStringify.uintToDecimalString(queueSize, 18, 3),
            "},{\"trait_type\":\"Claimable amount\",\"value\":",
            LibStringify.uintToDecimalString(claimable, 18, 3),
            ",\"display_type\":\"number\",\"max_value\":",
            LibStringify.uintToDecimalString(t.size, 18, 3),
            "},{\"trait_type\":\"Status\",\"value\":\"",
            _getStatusString(t, claimable),
            "\"}],"
        );
    }

    /// @dev Internal hook happening at each transfer.
    ///      To override.
    function _onTransfer(address, address, uint256) internal view override {
        if (!$transferEnabled.get()) {
            revert TransferDisabled();
        }
    }

    /// @dev Internal hook happening at each mint.
    ///      To override.
    /// @param to The address receiving the token
    /// @param tokenId The token id
    function _onMint(address to, uint256 tokenId) internal override {}

    /// @dev Internal hook happening at each burn.
    ///      To override.
    /// @param tokenId The token id
    function _onBurn(uint256 tokenId) internal override {}

    /// @dev Internal utility to retrieve the vPool address casted to the vPool interface
    /// @return The vPool address casted to the vPool interface
    function _castedPool() internal view returns (IvPool) {
        return IvPool($pool.get());
    }

    /// @dev Internal utility to check if a ticket is claimable on a cask
    /// @param t The ticket to check
    /// @param p The cask to check
    /// @return True if the ticket is claimable on the cask
    function _matching(ctypes.Ticket memory t, ctypes.Cask memory p) internal pure returns (bool) {
        return (t.position < p.position + p.size && t.position >= p.position);
    }

    /// @dev Internal utility to perform a dichotomy search to find the cask matching a ticket
    /// @param ticketIdx The index of the ticket to find the cask for
    /// @return caskId The cask id matching the ticket
    function _searchCaskForTicket(uint256 ticketIdx) internal view returns (uint32 caskId) {
        ctypes.Cask[] storage caskArray = $casks.get();
        uint32 right = uint32(caskArray.length - 1);

        ctypes.Ticket memory t = $tickets.get()[ticketIdx];

        if (_matching(t, caskArray[right])) {
            return right;
        }

        uint32 left = 0;

        if (_matching(t, caskArray[left])) {
            return left;
        }

        while (left != right) {
            uint32 middle = (left + right) >> 1;

            ctypes.Cask memory middleC = caskArray[middle];
            if (_matching(t, middleC)) {
                return middle;
            }

            if (t.position < middleC.position) {
                right = middle;
            } else {
                left = middle;
            }
        }
        return left;
    }

    /// @dev Internal utility to resolve a ticket
    /// @param ticketId The ticket to resolve
    /// @param totalTicketCount The total number of tickets
    /// @param totalCaskCount The total number of casks
    /// @return caskIdOrError The cask id matching the ticket or an error code
    function _resolve(uint256 ticketId, uint256 totalTicketCount, uint256 totalCaskCount) internal view returns (int64 caskIdOrError) {
        uint256 ticketIdx = _getTicketIdx(ticketId);
        if (ticketIdx >= totalTicketCount) {
            return TICKET_ID_OUT_OF_BOUNDS;
        }
        ctypes.Ticket memory t = $tickets.get()[ticketIdx];
        if (t.size == 0) {
            return TICKET_ALREADY_CLAIMED;
        }
        if (totalCaskCount == 0 || $casks.get()[totalCaskCount - 1].position + $casks.get()[totalCaskCount - 1].size <= t.position) {
            return TICKET_PENDING;
        }
        return int64(uint64(_searchCaskForTicket(ticketIdx)));
    }

    /// @dev Retrieves the ticket id from its index and size.
    ///      The ticket id is dynamic, every time someone performs a partial claim of the ticket, its id changes.
    ///      If the claim is complete, the ticket is burned. This would lower secondary market attack vectors that
    ///      include claiming before selling.
    /// @param ticketIndex The index of the ticket
    /// @param t The ticket
    /// @return The ticket id
    function _getTicketId(uint256 ticketIndex, ctypes.Ticket memory t) internal pure returns (uint256) {
        return ticketIndex << 128 | uint256(t.size);
    }

    /// @dev Retrieves the ticket index from its id
    /// @param ticketId The ticket id
    /// @return The ticket index
    function _getTicketIdx(uint256 ticketId) internal pure returns (uint256) {
        return ticketId >> 128;
    }

    /// @dev Internal utility to create a new ticket
    /// @param amount The amount of shares in the ticket
    /// @param owner The owner of the ticket
    function _printTicket(uint128 amount, address owner) internal {
        IvPool pool = _castedPool();
        uint256 totalUnderlyingSupply = pool.totalUnderlyingSupply();
        uint256 totalSupply = pool.totalSupply();
        ctypes.Ticket[] storage ticketArray = $tickets.get();
        uint256 ticketsLength = ticketArray.length;
        ctypes.Ticket memory lastTicket =
            ticketArray.length > 0 ? ticketArray[ticketsLength - 1] : ctypes.Ticket({position: 0, size: 0, maxExitable: 0});
        ctypes.Ticket memory newTicket = ctypes.Ticket({
            position: lastTicket.position + lastTicket.size,
            size: amount,
            maxExitable: uint128(LibUint256.mulDiv(amount, totalUnderlyingSupply, totalSupply))
        });
        uint256 ticketId = _getTicketId(ticketsLength, newTicket);
        ticketArray.push(newTicket);
        _mint(owner, ticketId);
        emit PrintedTicket(owner, uint32(ticketsLength), ticketId, newTicket);
    }

    /// @notice The parameters of the consume call
    /// @param ticketId The ticket id
    /// @param ticketIdx The index of the ticket
    /// @param t The ticket itself
    /// @param caskId The cask id
    /// @param c The cask itself
    /// @param totalCaskCount The total number of casks
    /// @param depth The initial depth of the consume call
    /// @param ethToPay The resulting eth to pay the user
    struct ConsumeTicketParameters {
        uint256 ticketId;
        uint256 ticketIdx;
        ctypes.Ticket t;
        uint32 caskId;
        ctypes.Cask c;
        uint256 totalCaskCount;
        uint16 depth;
        uint256 ethToPay;
    }

    /// @dev Internal utility to consume a ticket.
    ///      Will call itself recursively to consume the ticket on all the casks it overlaps.
    ///      Recursive calls are limited to the initial depth.
    /// @param params The parameters of the consume call
    function _consumeTicket(ConsumeTicketParameters memory params) internal {
        // we compute the end position of the cask
        uint256 caskEnd = params.c.position + params.c.size;

        // we compute the amount of shares and eth that overlap between the ticket and the cask
        uint128 overlappingAmount = uint128(LibUint256.min(params.t.size, caskEnd - params.t.position));
        uint128 overlappingEthAmount = uint128(LibUint256.mulDiv(overlappingAmount, params.c.value, params.c.size));
        uint128 maxRedeemableEthAmount = uint128(LibUint256.mulDiv(overlappingAmount, params.t.maxExitable, params.t.size));

        // we initialize the unclaimable amount to 0 before checking if the ticket is exceeding the capped ticket rate
        uint256 unclaimableAmount = 0;

        // then we check if the overlapping amount is not exceeding the capped ticket rate
        // and if it's the case we adjust the amount of eth we can pay
        if (maxRedeemableEthAmount < overlappingEthAmount) {
            unclaimableAmount = overlappingEthAmount - maxRedeemableEthAmount;
            overlappingEthAmount = maxRedeemableEthAmount;
            _setUnclaimedFunds($unclaimedFunds.get() + unclaimableAmount);
        }

        // we update the ticket in memory
        params.t.position += overlappingAmount;
        params.t.size -= overlappingAmount;
        params.t.maxExitable -= overlappingEthAmount;

        // we update the total to pay for this ticket
        params.ethToPay += overlappingEthAmount;

        // we log the step
        emit FilledTicket(params.ticketId, params.caskId, uint128(overlappingAmount), overlappingEthAmount, unclaimableAmount);

        // if
        // - the ticket is not empty
        // - there are more casks to consume
        // - we are not at the maximum depth
        // then we call this method recursively with the next cask
        // otherwise we update the ticket in storage and burn it if it's empty
        if (params.t.size > 0 && params.caskId + 1 < params.totalCaskCount && params.depth > 0) {
            params.caskId += 1;
            params.c = $casks.get()[params.caskId];
            params.depth -= 1;
            _consumeTicket(params);
        } else {
            if (params.t.size == 0) {
                _burn(params.ticketId);
            }
            ctypes.Ticket[] storage ticketArray = $tickets.get();
            ticketArray[params.ticketIdx] = params.t;
        }
    }

    /// @dev Internal utility to set the unclaimed funds buffer
    /// @param newUnclaimedFunds The new unclaimed funds buffer
    function _setUnclaimedFunds(uint256 newUnclaimedFunds) internal {
        $unclaimedFunds.set(newUnclaimedFunds);
        emit SetUnclaimedFunds(newUnclaimedFunds);
    }

    /// @dev Internal utility to set the transfer enabled flag
    /// @param value The new transfer enabled flag
    function _setTransferEnabled(bool value) internal {
        $transferEnabled.set(value);
        emit SetTransferEnabled(value);
    }

    /// @dev Internal utility to set the token URI image URL
    /// @param newTokenUriImageUrl The new token URI image URL
    function _setTokenUriImageUrl(string calldata newTokenUriImageUrl) internal {
        LibSanitize.notEmptyString(newTokenUriImageUrl);
        $tokenUriImageUrl.set(newTokenUriImageUrl);
        emit SetTokenUriImageUrl($tokenUriImageUrl.get());
    }
}
