// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";

uint256 constant SIG_VALIDATION_SUCCESS = 0;
uint256 constant SIG_VALIDATION_FAILED = 1;

// The flow for ERC-4337 typically involves an EntryPoint contract
// calling into this account contract.
contract MinimalAccount is Ownable {
    ////////////////////////////////////////////////////////////////
    //                         ERRORS                             //
    ////////////////////////////////////////////////////////////////
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner(); // New
    error MinimalAccount__CallFailed(bytes result); // New
    address private immutable I_ENTRY_POINT;

    modifier requireFromEntryPoint() {
        _requireFromEntryPoint();
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        _requireFromEntryPointOrOwner();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        FUNCTIONS                           //
    ////////////////////////////////////////////////////////////////
    // constructor(address entryPoint) Ownable(msg.sender) { ... } // (already shown)

    receive() external payable {}

    constructor(address entryPoint) Ownable(msg.sender) {
        I_ENTRY_POINT = entryPoint;
    }

    ////////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////
    function execute(address dest, uint256 value, bytes calldata functionData)
        external
        requireFromEntryPointOrOwner // We'll discuss this modifier next

    {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    function validateUserOp(
        ILegacyEntryPoint.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    ////////////////////////////////////////////////////////////////
    //                   INTERNAL FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////

    function _requireFromEntryPoint() internal view {
        if (msg.sender != address(I_ENTRY_POINT)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
    }

    function _requireFromEntryPointOrOwner() internal view {
        if (msg.sender != address(I_ENTRY_POINT) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
    }

    function _validateSignature(ILegacyEntryPoint.UserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        // A signature is valid if it's from the MinimalAccount owner
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer == address(0) || signer != owner()) {
            // Also check for invalid signature recovery
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
            // In a real implementation, you would transfer the required funds to the EntryPoint here.
            // For simplicity, this example does not implement actual fund transfers.
        }
    }
    // / ///////////////////////////////////////////////////////////////////////////
    // / ////////////////////////////// GETTERS ////////////////////////////////////
    // / ///////////////////////////////////////////////////////////////////////////

    function getEntryPoint() external view returns (address) {
        return I_ENTRY_POINT;
    }
}
