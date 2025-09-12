// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Riddle
 * @dev Riddle
 */
contract Riddle is IRiddle, OwnableUpgradeable {
    uint32 public id;
    uint32 public registerIndex;
    uint32 public userIndex;
    IUser public author;

    string public statement;

    /**
     * @dev Trying to change indexes not from author
     * @param msgSender Illegal message sender
     */
    error UnauthorizedIndexChange(address msgSender);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _id Identifier
     * @param _registerIndex Index in Register
     * @param _userIndex Index at User
     * @param _statement Riddle statement
     */
    function initialize(
        address initialOwner,
        uint32 _id,
        uint32 _registerIndex,
        uint32 _userIndex,
        string calldata _statement
    ) external initializer {
        __Ownable_init(initialOwner);
        id = _id;
        registerIndex = _registerIndex;
        userIndex = _userIndex;
        statement = _statement;
    }
}
