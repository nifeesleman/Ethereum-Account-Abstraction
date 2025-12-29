// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

// The flow for ERC-4337 typically involves an EntryPoint contract
// calling into this account contract.
contract MinimalAccount is IAccount {
    function validateUserOp(
        PackedUserOperation calldata userOp, // The packed UserOperation data
        bytes32 userOpHash, // A hash of the userOp, used as the basis for the signature
        uint256 missingAccountFunds // Funds needed for the operation if the account hasn't pre-deposited enough into the EntryPoint
    )
        external
        returns (uint256 validationData); // Returns data indicating validity and optional time constraints
}
