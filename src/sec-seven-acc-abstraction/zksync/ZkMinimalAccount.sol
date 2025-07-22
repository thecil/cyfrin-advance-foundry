// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.24;

// import {IAccount} from "@era-contracts/interfaces/IAccount.sol";
// import {Transaction} from "@era-contracts/libraries/TransactionHelper.sol";

// contract ZkMinimalAccount is IAccount {
//     /*//////////////////////////////////////////////////////////////
//                            EXTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//      * @notice MUST increase the nonce
//      * @notice MUST validate transaction
//      */
//     function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
//         external
//         payable
//         returns (bytes4 magic)
//     {}

//     function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
//         external
//         payable
//     {}

//     function executeTransactionFromOutside(Transaction memory _transaction) external payable {}

//     function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
//         external
//         payable
//     {}

//     function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
//         external
//         payable
//     {}
// }
