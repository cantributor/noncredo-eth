// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "./structs/Guess.sol";
import {Register} from "./Register.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";
import {Utils} from "./Utils.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title Riddle
 * @dev Riddle
 */
contract Riddle is IRiddle, OwnableUpgradeable {
    string public statement;
    uint256 public encryptedSolution;

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
     * @dev Guess period not finished yet (revelation too early)
     * @param riddleId Riddle id
     * @param blockNumber Current block number
     * @param guessDeadline Guess deadline (when revelation will be possible)
     */
    error GuessPeriodNotFinished(uint32 riddleId, uint256 blockNumber, uint256 guessDeadline);

    /**
     * @dev Reward error
     * @param riddleAddress Riddle contract address
     * @param riddleId Riddle id
     * @param rewardAddress Address of guessing account
     * @param rewardValue Value of reward
     */
    error RewardError(address riddleAddress, uint32 riddleId, address rewardAddress, uint256 rewardValue);

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
    event GuessRegistered(
        address indexed riddleAddress, address indexed guessSender, uint32 id, bool credo, uint256 bet
    );

    /**
     * @dev Riddle reward payed
     * @param riddleAddress Riddle contract address
     * @param beneficiaryAddress Beneficiary address
     * @param amount Payed amount
     */
    event RewardPayed(address indexed riddleAddress, address indexed beneficiaryAddress, uint256 amount);

    /**
     * @dev Sponsor payment received
     * @param riddleAddress Riddle contract address
     * @param paymentSender Payment sender address
     * @param id Riddle id
     * @param amount Payment amount
     */
    event SponsorPaymentReceived(
        address indexed riddleAddress, address indexed paymentSender, uint32 id, uint256 amount
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
        if (register.paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
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
        emit GuessRegistered(address(this), msgSender, id, credo, msg.value);
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

    /**
     * @dev Reveal solution of the riddle
     * @param userSecretKey User secret key
     * @return solution Is the riddle statement true? (riddle author's point of view)
     */
    function reveal(string calldata userSecretKey) external override onlyOwner returns (bool solution) {
        address msgSender = _msgSender();
        Register register = user.register();
        if (register.paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
        if (revealed) {
            revert RiddleAlreadyRevealed(id, address(this), msgSender);
        }
        if (block.number <= guessDeadline) {
            revert GuessPeriodNotFinished(id, block.number, guessDeadline);
        }
        solution = Utils.decryptSolution(this, userSecretKey);
        if (address(this).balance > 0) {
            shareReward(solution);
        }
        revealed = true;
        return solution;
    }

    /**
     * @dev Share the riddle reward amongst players
     * @param solution Riddle solution (true/false)
     */
    function shareReward(bool solution) internal {
        Register register = user.register();
        uint256 winnerBetsSum = 0;
        for (uint32 i = 0; i < guesses.length; i++) {
            if (guesses[i].credo == solution) winnerBetsSum += guesses[i].bet;
        }
        uint256 prize = address(this).balance - winnerBetsSum;
        uint256 registerReward = prize * register.registerRewardPercent() / 100;
        uint256 riddlingReward = prize * register.riddlingRewardPercent() / 100;
        uint256 guessingReward = address(this).balance - registerReward - riddlingReward;
        if (winnerBetsSum > 0) {
            for (uint32 i = 0; i < guesses.length; i++) {
                if (guesses[i].credo == solution) {
                    if (guesses[i].bet > 0) {
                        uint256 thisAccountReward = guesses[i].bet * guessingReward / winnerBetsSum;
                        payReward(guesses[i].account, thisAccountReward);
                    }
                }
            }
        }
        if (riddlingReward > 0) {
            payReward(owner(), riddlingReward);
        }
        uint256 remainder = address(this).balance;
        if (remainder > 0) {
            payReward(payable(register), remainder);
        }
    }

    /**
     * @dev Pay reward
     * @param beneficiary Beneficiary address
     * @param amount Reward amount
     */
    function payReward(address beneficiary, uint256 amount) internal {
        (bool success,) = beneficiary.call{value: amount}("");
        if (success) {
            emit RewardPayed(payable(this), beneficiary, amount);
        } else {
            revert RewardError(payable(this), id, beneficiary, amount);
        }
    }

    /**
     * @dev To receive sponsor payments (no guess)
     */
    receive() external payable override {
        emit SponsorPaymentReceived(address(this), _msgSender(), id, msg.value);
    }
}
