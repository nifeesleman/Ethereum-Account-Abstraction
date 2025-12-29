// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

// The flow for ERC-4337 typically involves an EntryPoint contract
// calling into this account contract.
contract MinimalAccount is IAccount {
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        view
        override
        returns (uint256 validationData)
    {
        // TODO: Implement actual validation logic (signature, nonce)
        return 0; // Placeholder for successful validation
    }
}
