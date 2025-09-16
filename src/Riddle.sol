// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Register} from "./Register.sol";
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
    IUser public user;

    string public statement;
    uint256 internal encryptedSolution;

    uint256 public guessDeadline;
    uint256 public revealDeadline;

    /**
     * @dev Riddle already registered
     * @param riddleId Found riddle id
     * @param riddleId Found riddle user nick
     * @param riddleId Found riddle user index
     */
    error RiddleAlreadyRegistered(uint32 riddleId, string userNick, uint32 riddleUserIndex);

    /**
     * @dev Riddle successfully registered
     * @param user User contract address
     * @param id Riddle id
     * @param statementHash Riddle statement hash
     */
    event RiddleRegistered(address indexed user, uint32 indexed id, bytes32 statementHash);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _id Identifier
     * @param _registerIndex Index in Register
     * @param _userIndex Index at User
     * @param _user User contract
     * @param _statement Riddle statement
     * @param _encryptedSolution Encrypted solution
     */
    function initialize(
        address initialOwner,
        uint32 _id,
        uint32 _registerIndex,
        uint32 _userIndex,
        IUser _user,
        string calldata _statement,
        uint256 _encryptedSolution
    ) external initializer {
        __Ownable_init(initialOwner);
        id = _id;
        registerIndex = _registerIndex;
        userIndex = _userIndex;
        user = _user;
        statement = _statement;
        encryptedSolution = _encryptedSolution;

        Register reg = user.register();
        guessDeadline = block.number + reg.guessDurationBlocks();
        revealDeadline = guessDeadline + reg.revealDurationBlocks();
    }
}
