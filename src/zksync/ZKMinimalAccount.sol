pragma solidity ^0.8.24;

import {IAccount} from "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "@foundry-era-contracts/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry-era-contracts/system-contracts/contracts/Constants.sol";

import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from
    "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {INonceHolder} from "@foundry-era-contracts/system-contracts/contracts/interfaces/INonceHolder.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Utils} from "@foundry-era-contracts/system-contracts/contracts/libraries/Utils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ZKMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZKMinimalAccount__NotEnoughBalance();
    error ZKMinimalAccount__InvalidSignature();
    error ZKMinimalAccount__NotFromBootLoader();
    error ZKMinimalAccount__NotFromBootLoaderOrOwner();
    error ZKMinimalAccount__ExecuteCallToDestFailed();
    error ZKMinimalAccount__PayToBootLoaderFailed();
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier requireFromBootLoader() {
        if (msg.sender != address(BOOTLOADER_FORMAL_ADDRESS)) {
            revert ZKMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != address(BOOTLOADER_FORMAL_ADDRESS) && msg.sender != owner()) {
            revert ZKMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice must increase the nonce and validate the transaction
     */
    function validateTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        return _validateTransaction(_transaction);
    }

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);

        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZKMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    function executeTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction calldata _transaction)
        external
        payable
    {
        bool success = MemoryTransactionHelper.payToTheBootloader(_transaction);
        if (!success) {
            revert ZKMinimalAccount__PayToBootLoaderFailed();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateTransaction(Transaction calldata _transaction) internal returns (bytes4 magic) {
        // call nonce holder
        // increment the nonce
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        //check fee to pay
        uint256 totalRequireBalance = _transaction.totalRequiredBalance();
        if (totalRequireBalance > address(this).balance) {
            revert ZKMinimalAccount__NotEnoughBalance();
        }

        // check the signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(signedHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function _executeTransaction(Transaction calldata _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZKMinimalAccount__ExecuteCallToDestFailed();
            }
        }
    }
}
