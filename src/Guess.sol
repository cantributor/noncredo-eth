// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

/**
 * @dev Attempt to guess the riddle's author game
 * @param account Guessing account
 * @param credo Credo/NonCredo of guessing
 * @param bet Placed bet
 */
struct Guess {
    address account;
    bool credo;
    uint256 bet;
}
