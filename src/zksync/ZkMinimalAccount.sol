// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
// The Transaction struct is defined within or alongside system contract interfaces.
// For direct use as per IAccount, ensure the path correctly resolves to its definition.
// The video lesson points to the struct being available via an import like this:
import {
    Transaction
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/SystemContractsCaller.sol";

contract ZkMinimalAccount is IAccount {


modifier requireFromBootloader() {
    if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) { // Check caller
        revert ZkMinimalAccount__NotFromBootloader(); // Custom error
    }
    _; // Proceed if check passes
}
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        override
        returns (bytes4 magic)
    {
    SystemContractsCaller.systemCallWithPropagatedRevert(
    uint32(gasleft()), // gas limit for the call
    address(NONCE_HOLDER_SYSTEM_CONTRACT), // Address of the system contract
    0, // value to send (must be 0 for system calls)
    abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)) // Encoded function call data
);
        revert("Not implemented"); // Placeholder
    }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        override
    {
        revert("Not implemented");
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
        revert("Not implemented"); // Placeholder
    }
}
