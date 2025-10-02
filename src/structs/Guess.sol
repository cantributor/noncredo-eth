// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

/**
 * @dev Guess for the riddle (Credo/NonCredo)
 * @param account Guessing account
 * @param encryptedCredo Encrypted credo (Credo/NonCredo)
 * @param bet Placed bet
 * @param revealed Is Credo/NonCredo already revealed?
 * @param credo Credo/NonCredo
 */
struct Guess {
    address account;
    uint256 encryptedCredo;
    uint256 bet;
    bool revealed;
    bool credo;
}
