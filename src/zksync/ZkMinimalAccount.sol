// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    BOOTLOADER_FORMAL_ADDRESS,
    NONCE_HOLDER_SYSTEM_CONTRACT,
    DEPLOYER_SYSTEM_CONTRACT
} from "foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller
} from "foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {INonceHolder} from "foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount_NotEnoughBalance();
    error ZkMinimalAccount_ExecutionFailed();
    error ZkMinimalAccount_InvalidSignature();
    error ZkMinimalAccount__NotFromBootloader();
    error ZkMinimalAccount__NotFromBootloaderOrOwner();

    modifier requireFromBootloader() {
        _requireFromBootloader();
        _; // Proceed if check passes
    }

    modifier requireFromBootloaderOrOwner() {
        _requireFromBootloaderOrOwner();
        _; // Proceed if check passes
    }

    function _requireFromBootloader() internal view {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            // Check caller
            revert ZkMinimalAccount__NotFromBootloader(); // Custom error
        }
    }

    function _requireFromBootloaderOrOwner() internal view {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            // Check caller
            revert ZkMinimalAccount__NotFromBootloaderOrOwner(); // Custom error
        }
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    receive() external payable {}

    // INTERNAL FUNCTIONS
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // Call nonceholder to increment nonce only if system contract code exists
        // In plain forge tests (non-zk context), the system contracts are not deployed.
        if (address(NONCE_HOLDER_SYSTEM_CONTRACT).code.length > 0) {
            // This system call increments the nonce if the provided _transaction.nonce matches the current one.
            SystemContractsCaller.systemCallWithPropagatedRevert(
                uint32(gasleft()),
                address(NONCE_HOLDER_SYSTEM_CONTRACT),
                0,
                abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
            );
        }
        // Check if the account has enough balance to cover the transaction's cost
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount_NotEnoughBalance();
        }

        // Verify the transaction signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(convertedHash, _transaction.signature);
        bool isValidSigner = signer == owner();

        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0); // Indicates invalid signature
        }
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        // Handle calls to the DEPLOYER_SYSTEM_CONTRACT for contract deployments
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            // Standard external call
            bool success;
            /// @solidity memory-safe-assembly
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount_ExecutionFailed();
            }
        }
    }
    //--------------EXTERNAL FUNCTIONS----------------//

    function validateTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
        override
        returns (bytes4 magic)
    {
        magic = _validateTransaction(_transaction);
    }

    function executeTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction calldata _transaction
    )
        external
        payable
        override
        requireFromBootloaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable override {
        bytes4 magic = _validateTransaction(_transaction);
        // IMPORTANT: Always check the result of validation.
        // If the signature is not valid, or other validation checks fail,
        // _validateTransaction will return a magic value other than ACCOUNT_VALIDATION_SUCCESS_MAGIC.
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount_InvalidSignature(); // Or a more generic validation failed error
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction calldata _transaction
    )
        external
        payable
        override
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction calldata _transaction
    )
        external
        payable
        override
    {
        // In this minimal implementation, we can ignore _txHash and _suggestedSignedHash.
        // All necessary information for payment is contained within the _transaction struct.

        // The core logic relies on a helper function, payToTheBootloader,
        // which is part of the TransactionHelper library (via _transaction).
        bool success = _transaction.payToTheBootloader();

        // If the payment to the bootloader fails, revert the transaction.
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }
}
