// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Register} from "../Register.sol";
import {Riddle} from "../Riddle.sol";

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title IUser
 * @dev User interface
 */
interface IUser {
    function totalRiddles() external view returns (uint32);
    function indexOf(Riddle) external view returns (int256);
    function nickString() external view returns (string memory);
    function nick() external view returns (ShortString);
    function registerAddress() external view returns (address payable);
    function index() external view returns (uint32);
    function setIndex(uint32 _index) external;
    function goodbye() external;
    function remove() external;
    function remove(Riddle) external;
    function register() external returns (Register);
    function commit(string calldata statement, uint256 encryptedSolution) external returns (Riddle);
}
