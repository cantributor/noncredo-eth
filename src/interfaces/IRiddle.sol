// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "../Guess.sol";

/**
 * @title IRiddle
 * @dev Riddle interface
 */
interface IRiddle {
    function id() external view returns (uint32);
    function registerIndex() external view returns (uint32);
    function userIndex() external view returns (uint32);
    function statement() external view returns (string memory);
    function guess(bool credo) external payable returns (Guess memory);
    function guessOf(address sender) external view returns (Guess memory);
}
