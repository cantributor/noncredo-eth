// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "./Guess.sol";
import {Register} from "./Register.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Riddle
 * @dev Riddle
 */
contract Riddle is IRiddle, OwnableUpgradeable {
    string public statement;
    uint256 internal encryptedSolution;

    uint32 public id;
    uint32 public registerIndex;
    uint32 public userIndex;
    IUser public user;
    bool public revealed = false;

    uint256 public guessDeadline;
    uint256 public revealDeadline;

    Guess[] internal guesses;

    /**
     * @dev Riddle already registered
     * @param riddleId Found riddle id
     * @param userNick Found riddle user nick
     * @param riddleUserIndex Found riddle user index
     */
    error RiddleAlreadyRegistered(uint32 riddleId, string userNick, uint32 riddleUserIndex);

    /**
     * @dev Owner of the Riddle cannot guess his own nick
     * @param riddleId Riddle id
     * @param guessSender Guess sender address
     */
    error OwnerCannotGuess(uint32 riddleId, address guessSender);

    /**
     * @dev Guess of this sender already exists
     * @param riddleId Riddle id
     * @param guessSender Guess sender address
     * @param credo Guess credo/noncredo
     * @param bet Guess bet value
     */
    error GuessOfSenderAlreadyExists(uint32 riddleId, address guessSender, bool credo, uint256 bet);

    /**
     * @dev Riddle is not registered
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleIsNotRegistered(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle already revealed
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleAlreadyRevealed(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle successfully registered
     * @param userAddress User contract address
     * @param riddleAddress Riddle contract address
     * @param id Riddle id
     * @param statementHash Riddle statement hash
     */
    event RiddleRegistered(
        address indexed userAddress, address indexed riddleAddress, uint32 id, bytes32 statementHash
    );

    /**
     * @dev Riddle guess successfully registered
     * @param riddleAddress Riddle contract address
     * @param guessSender Guess sender address
     * @param id Riddle id
     * @param credo Guess credo/noncredo
     * @param bet Placed bet value
     */
    event RiddleGuessRegistered(
        address indexed riddleAddress, address indexed guessSender, uint32 id, bool credo, uint256 bet
    );

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

    /**
     * @dev Register the attempt to guess the riddle
     * @param credo Credo/NonCredo
     * @return _guess Registered guess attempt
     */
    function guess(bool credo) external payable override returns (Guess memory _guess) {
        address msgSender = _msgSender();
        if (revealed) {
            revert RiddleAlreadyRevealed(id, address(this), msgSender);
        }
        Register register = user.register();
        if (register.riddles(registerIndex) != this) {
            revert RiddleIsNotRegistered(id, address(this), msgSender);
        }
        register.userOf(msgSender);
        if (msgSender == owner()) {
            revert OwnerCannotGuess(id, owner());
        }
        Guess memory foundGuess = this.guessOf(msgSender);
        if (foundGuess.account != address(0)) {
            revert GuessOfSenderAlreadyExists(id, msgSender, foundGuess.credo, foundGuess.bet);
        }
        _guess = Guess(msgSender, credo, msg.value);
        guesses.push(_guess);
        emit RiddleGuessRegistered(address(this), msgSender, id, credo, msg.value);
        return _guess;
    }

    /**
     * @dev Find guess attempt for specified account
     * @param sender Guess sender account
     * @return _guess Registered guess attempt
     */
    function guessOf(address sender) external view virtual override returns (Guess memory _guess) {
        _guess = Guess(address(0), false, 0);
        for (uint256 i = 0; i < guesses.length; i++) {
            if (guesses[i].account == sender) {
                _guess = guesses[i];
                break;
            }
        }
        return _guess;
    }
}
