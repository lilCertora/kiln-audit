// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

import "./types/address.sol";
import "./types/string.sol";
import "./types/mapping.sol";
import "./libs/LibSanitize.sol";
import "./Initializable.sol";
import "./interfaces/INFT.sol";

import "./uctypes/operator_approvals.sol";

/// @title NFT
/// @author mortimr @ Kiln
/// @notice NFT contract using utils.sol storage format.
// slither-disable-next-line unimplemented-functions
abstract contract NFT is INFT {
    using LString for types.String;
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;
    using LOperatorApprovalsMapping for uctypes.OperatorApprovalsMapping;

    using CUint256 for uint256;
    using CAddress for address;

    /// @dev ERC721 name of the contract.
    /// @dev Slot: keccak256(bytes("nft.1.name")) - 1
    types.String internal constant $name =
        types.String.wrap(0x8be0d77374e3002afd46fd09ae2c8e3afc7315322504f7f1a09d189f4925e72f);
    /// @dev ERC721 symbol of the contract.
    /// @dev Slot: keccak256(bytes("nft.1.symbol")) - 1
    types.String internal constant $symbol =
        types.String.wrap(0xddad2df2277e0186b34991db0b7ceafa36b49b76d0a1e87f6e4d44b6b17a207f);
    /// @dev Internal ID counter to keep track of minted tokens.
    /// @dev Slot: keccak256(bytes("nft.1.mintCounter")) - 1
    types.Uint256 internal constant $mintCounter =
        types.Uint256.wrap(0x3d706fc25ad0e96a2c3fb1b58cdd70ba377f331d59f761caecaf2f3a236d99a1);
    /// @dev Internal burn counter used to keep track of the total supply.
    /// @dev Slot: keccak256(bytes("nft.1.burnCounter")) - 1
    types.Uint256 internal constant $burnCounter =
        types.Uint256.wrap(0x0644144c18bf2aa8e15d5433cc3f6e2273ab9ccd122cd4f430275a2997cc0dc2);
    /// @dev Internal mapping that holds the links between owners and NFT IDs.
    /// @dev Type: mapping (uint256 => address)
    /// @dev Slot: keccak256(bytes("nft.1.owners")) - 1
    types.Mapping internal constant $owners =
        types.Mapping.wrap(0xc1f66d46ebf7070ef20209d66f741219b00fb896714319503d158a28b0d103d3);
    /// @dev Internal mapping that holds the balances of every owner (how many NFTs they own).
    /// @dev Type: mapping (address => uint256)
    /// @dev Slot: keccak256(bytes("nft.1.balances")) - 1
    types.Mapping internal constant $balances =
        types.Mapping.wrap(0xf9245bc1df90ea86e77b9f2423fe9cc12aa083c8ab9a55e727b285192b30d98a);
    /// @dev Internal mapping that holds the token approval data.
    /// @dev Type: mapping (uint256 => address)
    /// @dev Slot: keccak256(bytes("nft.1.tokenApprovals")) - 1
    types.Mapping internal constant $tokenApprovals =
        types.Mapping.wrap(0x3790264503275ecd52e8f0b419eb5ce016ca8a1f0fbac5a9ede429d0c1732004);
    /// @dev Internal mapping of operator approvals.
    /// @dev Type: mapping (address => mapping (address => bool))
    /// @dev Slot: keccak256(bytes("nft.1.operatorApprovals")) - 1
    uctypes.OperatorApprovalsMapping internal constant $operatorApprovals =
        uctypes.OperatorApprovalsMapping.wrap(0x6c716a91f6b5f5a0aa2affaf44bd88ea94ec69e363cf1fe9251e00a0fcc6c34e);

    /// @dev Internal initializer to call when first deploying the contract.
    // slither-disable-next-line dead-code
    function initializeNFT(string memory name_, string memory symbol_) internal {
        _setName(name_);
        _setSymbol(symbol_);
    }

    /// @notice Returns the token uri for the given token id.
    /// @dev To override
    /// @param tokenId The token id to query
    function tokenURI(uint256 tokenId) external view virtual returns (string memory);

    /// @notice Internal hook happening at each transfer. Not called during mint or burn. Use _onMint and _onBurn instead.
    ///         The hook is called before state transitions are made.
    /// @dev To override
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The token id
    function _onTransfer(address from, address to, uint256 tokenId) internal virtual;

    /// @notice Internal hook happening at each mint.
    ///         The hook is called before state transitions are made.
    /// @dev To override
    /// @param to The address receiving the token
    /// @param tokenId The token id
    function _onMint(address to, uint256 tokenId) internal virtual;

    /// @notice Internal hook happening at each burn.
    ///         The hook is called before state transitions are made.
    /// @dev To override
    /// @param tokenId The token id
    function _onBurn(uint256 tokenId) internal virtual;

    /// @inheritdoc INFT
    function totalSupply() external view returns (uint256) {
        return $mintCounter.get() - $burnCounter.get();
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual override returns (uint256) {
        LibSanitize.notZeroAddress(owner);
        return $balances.get()[owner.k()];
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert InvalidTokenId(tokenId);
        }
        return owner;
    }

    /// @inheritdoc IERC721Metadata
    function name() external view virtual returns (string memory) {
        return string(abi.encodePacked($name.get()));
    }

    /// @inheritdoc IERC721Metadata
    function symbol() external view virtual returns (string memory) {
        return string(abi.encodePacked($symbol.get()));
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId;
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = _ownerOf(tokenId);
        if (to == owner) {
            revert ApprovalToOwner(owner);
        }

        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert LibErrors.Unauthorized(msg.sender, owner);
        }

        _approve(to, owner, tokenId);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireExists(tokenId);

        return $tokenApprovals.get()[tokenId].toAddress();
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return $operatorApprovals.get()[owner][operator];
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert LibErrors.Unauthorized(msg.sender, _ownerOf(tokenId));
        }
        _transfer(from, to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert LibErrors.Unauthorized(msg.sender, _ownerOf(tokenId));
        }
        _safeTransfer(from, to, tokenId, data);
    }

    /// @dev Internal utility to set the ERC721 name value.
    /// @param newName The new name to set
    // slither-disable-next-line dead-code
    function _setName(string memory newName) internal {
        LibSanitize.notEmptyString(newName);
        $name.set(newName);
        emit SetName(newName);
    }

    /// @dev Internal utility to set the ERC721 symbol value.
    /// @param newSymbol The new symbol to set
    // slither-disable-next-line dead-code
    function _setSymbol(string memory newSymbol) internal {
        LibSanitize.notEmptyString(newSymbol);
        $symbol.set(newSymbol);
        emit SetSymbol(newSymbol);
    }

    /// @dev Internal utility to perform a safe transfer (transfer + extra checks on contracts).
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token
    /// @param data The extra data provided to contract callback calls
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert NonERC721ReceiverTransfer(from, to, tokenId, data);
        }
    }

    /// @dev Internal utility to retrieve the owner of the specified token id.
    /// @param tokenId The token id to lookup
    /// @return The address of the token owner
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return $owners.get()[tokenId].toAddress();
    }

    /// @dev Internal utility to verify if a token id exists.
    /// @param tokenId The token id to verify
    /// @return True if exists
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @dev Internal utility to check if the specified address is either approved by the owner or the owner for the given token id.
    /// @param spender The address to verify
    /// @param tokenId The token id to verify
    /// @return True if approved or owner
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = _ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /// @dev Internal utility to perform a safe mint operation (mint + extra checks on contracts).
    /// @param to The address receiving the token
    /// @param tokenId The token id to create
    /// @param data The xtra data provided to contract callback calls
    // slither-disable-next-line dead-code
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, data)) {
            revert NonERC721ReceiverTransfer(address(0), to, tokenId, data);
        }
    }

    /// @dev Internal utility to mint the desired token id.
    /// @param to The address that receives the token id
    /// @param tokenId The token id to create
    // slither-disable-next-line dead-code
    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0)) {
            revert IllegalMintToZero();
        }

        if (_exists(tokenId)) {
            revert TokenAlreadyMinted(tokenId);
        }

        _onMint(to, tokenId);

        if (_exists(tokenId)) {
            revert TokenAlreadyMinted(tokenId);
        }

        unchecked {
            // increase owner balance
            $balances.get()[to.k()] += 1;
            // increase global mint counter
            $mintCounter.set($mintCounter.get() + 1);
        }

        // set owner
        $owners.get()[tokenId] = to.v();

        emit Transfer(address(0), to, tokenId);
    }

    /// @dev Internal utility to burn the desired token id.
    /// @param tokenId The token id to burn
    // slither-disable-next-line dead-code
    function _burn(uint256 tokenId) internal virtual {
        _requireExists(tokenId);
        _onBurn(tokenId);
        _requireExists(tokenId);

        address from = $owners.get()[tokenId].toAddress();

        unchecked {
            // decrease owner balance
            $balances.get()[from.k()] -= 1;
            // increase global burn counter
            $burnCounter.set($burnCounter.get() + 1);
        }

        // clear owner and approvals
        delete $tokenApprovals.get()[tokenId];
        delete $owners.get()[tokenId];

        emit Transfer(from, address(0), tokenId);
    }

    /// @dev Internal utility to perform a regular transfer of a token.
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The tokenId to transfer
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        if (to == address(0)) {
            revert IllegalTransferToZero();
        }

        if (_ownerOf(tokenId) != from) {
            revert LibErrors.Unauthorized(_ownerOf(tokenId), from);
        }

        _onTransfer(from, to, tokenId);

        if (_ownerOf(tokenId) != from) {
            revert LibErrors.Unauthorized(_ownerOf(tokenId), from);
        }

        // Clear approvals from the previous owner
        delete $tokenApprovals.get()[tokenId];

        unchecked {
            $balances.get()[from.k()] -= 1;
            $balances.get()[to.k()] += 1;
        }
        $owners.get()[tokenId] = to.v();

        emit Transfer(from, to, tokenId);
    }

    /// @dev Internal utility to approve an account for a token id.
    /// @param to The address receiving the approval
    /// @param owner The owner of the token id
    /// @param tokenId The token id
    function _approve(address to, address owner, uint256 tokenId) internal virtual {
        $tokenApprovals.get()[tokenId] = to.v();
        emit Approval(owner, to, tokenId);
    }

    /// @dev Internal utility to approve an account for all tokens of another account.
    /// @param owner The address owning the tokens
    /// @param operator The address receiving the approval
    /// @param approved True if approved, false otherwise
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (owner == operator) {
            revert ApprovalToOwner(owner);
        }
        $operatorApprovals.get()[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /// @dev Internal utility to check and revert if a token doesn't exists.
    /// @param tokenId The token id to verify
    function _requireExists(uint256 tokenId) internal view virtual {
        if (!_exists(tokenId)) {
            revert InvalidTokenId(tokenId);
        }
    }

    /// @dev Internal utility to perform checks upon transfer in the case of sending to a contract.
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param data The extra data to provide in the case where to is a contract
    /// @return True if all checks are good
    // slither-disable-next-line variable-scope,calls-loop,unused-return
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data)
        private
        returns (bool)
    {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert NonERC721ReceiverTransfer(from, to, tokenId, data);
                } else {
                    // slither-disable-next-line assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
