// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title IUser
 * @dev User interface
 */
interface IUser {
    function nickString() external view returns (string memory);
    function nick() external view returns (ShortString);
    function index() external view returns (uint32);
    function setIndex(uint32 _index) external;
    function goodbye() external;
    function remove() external;
}
