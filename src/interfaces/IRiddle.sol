// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "../structs/Guess.sol";

import {IUser} from "./IUser.sol";

/**
 * @title IRiddle
 * @dev Riddle interface
 */
interface IRiddle {
    /**
     * @dev Riddle already registered
     * @param riddleId Found riddle id
     * @param userNick Found riddle user nick
     * @param riddleIndex Found riddle register index
     */
    error RiddleAlreadyRegistered(uint32 riddleId, string userNick, uint32 riddleIndex);

    /**
     * @dev Guess of this sender already exists
     * @param riddleId Riddle id
     * @param guessSender Guess sender address
     * @param guessIndex Found Guess index in guesses array
     */
    error GuessOfSenderAlreadyExists(uint32 riddleId, address guessSender, uint256 guessIndex);

    /**
     * @dev Riddle is not registered
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleIsNotRegistered(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle has no guess from this caller, so nothing to reveal
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error NothingToReveal(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle already in revelation state
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleAlreadyInRevelationState(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle already finished
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleAlreadyFinished(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Riddle already revealed by this caller
     * @param riddleId Riddle id
     * @param riddleAddress Riddle contract address
     * @param msgSender Message sender address
     */
    error RiddleAlreadyRevealedByCaller(uint32 riddleId, address riddleAddress, address msgSender);

    /**
     * @dev Guess period not finished yet (revelation too early)
     * @param riddleId Riddle id
     * @param blockNumber Current block number
     * @param guessDeadline Guess deadline (when revelation will be possible)
     */
    error GuessPeriodNotFinished(uint32 riddleId, uint256 blockNumber, uint256 guessDeadline);

    /**
     * @dev Revelation period not finished yet (finalization too early)
     * @param riddleId Riddle id
     * @param blockNumber Current block number
     * @param revealDeadline Reveal deadline (when revelation will be possible)
     */
    error RevelationPeriodNotFinished(uint32 riddleId, uint256 blockNumber, uint256 revealDeadline);

    /**
     * @dev Payment error
     * @param riddleAddress Riddle contract address
     * @param riddleId Riddle id
     * @param receiverAddress Address of receiving account
     * @param amount Value of reward
     */
    error PaymentError(address riddleAddress, uint32 riddleId, address receiverAddress, uint256 amount);

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
     * @dev Riddle successfully removed
     * @param userAddress User contract address
     * @param riddleAddress Riddle contract address
     * @param id Riddle id
     */
    event RiddleRemoved(address indexed userAddress, address indexed riddleAddress, uint32 id);

    /**
     * @dev Riddle guess successfully registered
     * @param riddleAddress Riddle contract address
     * @param guessSender Guess sender address
     * @param id Riddle id
     * @param encryptedCredo Encrypted Credo/NonCredo
     * @param bet Placed bet value
     */
    event GuessRegistered(
        address indexed riddleAddress, address indexed guessSender, uint32 id, uint256 encryptedCredo, uint256 bet
    );

    /**
     * @dev Riddle guess successfully registered
     * @param riddleAddress Riddle contract address
     * @param guessSender Guess sender address
     * @param id Riddle id
     * @param credo Revealed Credo/NonCredo
     * @param bet Placed bet value
     */
    event GuessRevealed(address indexed riddleAddress, address indexed guessSender, uint32 id, bool credo, uint256 bet);

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

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _id Identifier
     * @param _index Index in Register
     * @param _user User contract
     * @param _statement Riddle statement
     * @param _encryptedCredo Encrypted owner's Credo/NonCredo
     */
    function initialize(
        address initialOwner,
        uint32 _id,
        uint32 _index,
        IUser _user,
        string calldata _statement,
        uint256 _encryptedCredo
    ) external payable;

    /**
     * @dev Ownable implementation
     * @return Riddle contract Owner account
     */
    function owner() external view returns (address);

    function id() external view returns (uint32);

    function user() external view returns (IUser);

    function guessDeadline() external view returns (uint256);

    function revealDeadline() external view returns (uint256);

    function index() external view returns (uint32);

    /**
     * @dev Set index of riddle (should be implemented with onlyForUser modifier)
     * @param _index New index value
     */
    function setIndex(uint32 _index) external;
    function statement() external view returns (string memory);

    /**
     * @dev Register the guess for the riddle
     * @param encryptedCredo Encrypted Credo/NonCredo
     * @return _guess Registered guess
     */
    function guess(uint256 encryptedCredo) external payable returns (Guess memory);

    /**
     * @dev Find guess for specified account
     * @param sender Guess sender account
     * @return _guess Registered guess
     * @return _guessIndex Guess index in guesses array
     */
    function guessOf(address sender) external view returns (Guess memory _guess, uint256 _guessIndex);

    /**
     * @dev Get number of riddle guesses
     * @return number of riddle guesses
     */
    function totalGuesses() external view returns (uint256);

    /**
     * @dev Find guess by its index in guesses array
     * @param _index Guess index in guesses array
     * @return Found guess
     */
    function guessByIndex(uint256 _index) external view returns (Guess memory);

    /**
     * @dev Reveal solution of the riddle
     * @param userSecretKey User secret key
     * @return solution Is the riddle statement true? (riddle author's point of view)
     */
    function reveal(string calldata userSecretKey) external returns (bool solution);

    /**
     * @dev Remove this contract from Register (should be implemented with onlyOwner modifier)
     */
    function remove() external;

    /**
     * @dev Enforced stopping riddle operation in case some guesses are not revealed
     */
    function finalize() external;

    /**
     * @dev In this process Riddle contract pays all its balance, clears guesses and stops operation
     */
    function goodbye() external;

    receive() external payable;
}
