// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title NFT
/// @author mortimr @ Kiln
/// @notice NFT contract using utils.sol storage format.
interface INFT is IERC721Metadata {
    /// @notice Emitted when name is changed.
    /// @param name The new ERC721 contract name
    event SetName(string name);

    /// @notice Emitted when symbol is changed.
    /// @param symbol The new ERC721 contract symbol
    event SetSymbol(string symbol);

    /// @notice Thrown when the token is already minted when it shouldn't.
    /// @param tokenId The id of the already existing token
    error TokenAlreadyMinted(uint256 tokenId);

    /// @notice Thrown when a mint operation to address zero is attempted.
    error IllegalMintToZero();

    /// @notice Thrown when a transfer operation to address zero is attempted.
    error IllegalTransferToZero();

    /// @notice Thrown when approval to self is made.
    /// @param owner Address attempting approval to self
    error ApprovalToOwner(address owner);

    /// @notice Thrown when provided token id is invalid.
    /// @param tokenId The invalid token id
    error InvalidTokenId(uint256 tokenId);

    /// @notice Thrown when the receiving contract is not able to receive the token.
    /// @param from The address sending the token
    /// @param to The address (contract) receiving the token and failing to properly receive it
    /// @param tokenId The token id
    /// @param data The extra data provided to the call
    error NonERC721ReceiverTransfer(address from, address to, uint256 tokenId, bytes data);

    /// @notice Throw when an nft transfer was attempted while the nft is frozen.
    ///         NFTs get frozen for ever once the exit request is made.
    ///         NFTs get frozen for 6 hours when a withdrawal is made.
    /// @param tokenId The frozen token id
    /// @param currentTimestamp The timestamp where the transfer was attempted
    /// @param freezeTimestamp The timestamp until which the token is frozen
    error IllegalTransferWhileFrozen(uint256 tokenId, uint256 currentTimestamp, uint256 freezeTimestamp);

    /// @notice Retrieve the total count of validator created with this contract.
    /// @return The total count of NFT validators of this contract
    function totalSupply() external view returns (uint256);
}
