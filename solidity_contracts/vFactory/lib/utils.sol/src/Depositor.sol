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
pragma solidity >=0.8.17;

import "./interfaces/DepositContractLike.sol";
import "./interfaces/IDepositor.sol";
import "./libs/LibAddress.sol";
import "./libs/LibBytes.sol";
import "./libs/LibUint256.sol";
import "./libs/LibPublicKey.sol";
import "./libs/LibSignature.sol";
import "./libs/LibSanitize.sol";
import "./types/address.sol";

/// @title Depositor
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice The Depositor contract adds deposit capabilities to easily fund
///         validators and activate them on the Consensus Layer.
contract Depositor is IDepositor {
    using LAddress for types.Address;

    /// @dev The address of the Deposit Contract in storage.
    /// @dev Slot: keccak256(bytes("depositor.depositContract"))) - 1
    types.Address internal constant $depositContract =
        types.Address.wrap(0x51b708339b28db69fafc07d2fc5a46c3487f5c5cd1fcb575eb01044dd8dd4de5);

    /// @dev Precomputed deposit size amount in little endian.
    // slither-disable-next-line too-many-digits
    uint256 internal constant DEPOSIT_SIZE_AMOUNT_LITTLEENDIAN64 =
        0x0040597307000000000000000000000000000000000000000000000000000000;

    /// @inheritdoc IDepositor
    function depositContract() external view returns (address) {
        return $depositContract.get();
    }

    /// @dev Set the deposit contract address in storage.
    /// @param _depositContract The new deposit contract address
    // slither-disable-next-line dead-code
    function _setDepositContract(address _depositContract) internal {
        LibSanitize.notZeroAddress(_depositContract);
        $depositContract.set(_depositContract);
        emit SetDepositContract(_depositContract);
    }

    /// @dev Utility to perform a deposit of the provided keys and the current balance.
    /// @dev The current balance is used for the deposit.
    /// @param _publicKey BLS Public Key
    /// @param _signature BLS Signature
    /// @param _withdrawal The withdrawal address
    // slither-disable-next-line dead-code
    function _deposit(bytes memory _publicKey, bytes memory _signature, address _withdrawal) internal {
        if (_publicKey.length != LibPublicKey.PUBLIC_KEY_LENGTH) {
            revert InvalidPublicKeyLength();
        }
        if (_signature.length != LibSignature.SIGNATURE_LENGTH) {
            revert InvalidSignatureLength();
        }
        bytes32 withdrawalCredentials = LibAddress.toWithdrawalCredentials(_withdrawal);
        uint256 value = address(this).balance;

        if (value < LibConstant.DEPOSIT_SIZE) {
            revert InvalidDepositSize();
        }

        bytes32 pubkeyRoot = sha256(bytes.concat(_publicKey, bytes16(0)));
        bytes32 signatureRoot = sha256(
            bytes.concat(
                sha256(LibBytes.slice(_signature, 0, 64)),
                // 32 = LibSignature.SIGNATURE_LENGTH - 64
                sha256(bytes.concat(LibBytes.slice(_signature, 64, 32), bytes32(0)))
            )
        );

        bytes32 depositDataRoot = sha256(
            bytes.concat(
                sha256(bytes.concat(pubkeyRoot, withdrawalCredentials)),
                sha256(bytes.concat(bytes32(DEPOSIT_SIZE_AMOUNT_LITTLEENDIAN64), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance - LibConstant.DEPOSIT_SIZE;

        DepositContractLike($depositContract.get()).deposit{value: LibConstant.DEPOSIT_SIZE}(
            _publicKey, abi.encodePacked(withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert DepositError();
        }
    }
}
