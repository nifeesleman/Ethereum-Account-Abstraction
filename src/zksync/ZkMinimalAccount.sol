// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
// The Transaction struct is defined within or alongside system contract interfaces.
// For direct use as per IAccount, ensure the path correctly resolves to its definition.
// The video lesson points to the struct being available via an import like this:
import {
    Transaction
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller
} from "lib/foundry-era-contracts/src/system-contracts/contracts/SystemContractsCaller.sol";

contract ZkMinimalAccount is IAccount {
    error ZkMinimalAccount__FailedToPay();
    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            // Check caller
            revert ZkMinimalAccount__NotFromBootloader(); // Custom error
        }
        _; // Proceed if check passes
    }
// INTERNAL FUNCTIONS
function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
    // Call nonceholder to increment nonce
    // This system call increments the nonce if the provided _transaction.nonce matches the current one.
    SystemContractsCaller.systemCallWithPropagatedRevert(
        uint32(gasleft()),
        address(NONCE_HOLDER_SYSTEM_CONTRACT),
        0,
        abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
    );
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
    return magic;}
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
        assembly {
            success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
        }
        if (!success) {
            revert ZkMinimalAccount_ExecutionFailed();
        }
    }
}
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        override
        returns (bytes4 magic)
    {
           return _validateTransaction(_transaction);
    }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        override
    {
        // Implement transaction logic here
        // Example: validate transaction, execute, and emit events
        // Validate the transaction
        require(_transaction.to != address(0), "Invalid recipient address");
        require(_transaction.value > 0, "Transaction value must be greater than zero");

        // Execute the transaction (this is a placeholder, actual implementation may vary)
        (bool success,) = _transaction.to.call{value: _transaction.value}(_transaction.data);
        require(success, "Transaction execution failed");

        // Emit an event for the executed transaction
        emit TransactionExecuted(_txHash, _transaction.to, _transaction.value, _transaction.data);
    }

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable override {
        revert("Not implemented"); // Placeholder
    }

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        override
    {
        revert("Not implemented"); // Placeholder
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
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
