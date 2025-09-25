// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

/**
 * @dev Payment to the Register contract
 * @param payer Payer address
 * @param amount Payment amount
 */
struct Payment {
    address payer;
    uint32 riddleId;
    uint256 amount;
}
