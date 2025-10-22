// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRegister} from "./interfaces/IRegister.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

library Utils {
    uint8 public constant MIN_NICK_LENGTH = 3;
    uint8 public constant MAX_NICK_LENGTH = 31;

    uint8 public constant MIN_RIDDLE_LENGTH = 10;
    uint8 public constant MAX_RIDDLE_LENGTH = 128;

    uint32 public constant MIN_DURATION = 1;
    uint32 public constant MAX_DURATION = 30 * 24 * 60 * 60 / 12; // 30 days * 24 hours * 60 min * 60 s /12 s per block

    uint8 public constant MIN_PERCENT = 0;
    uint8 public constant MAX_PERCENT = 100;

    /**
     * @dev Too short nick
     * @param nick Too short nick
     * @param actualLength Actual length
     * @param correctLength Correct length
     */
    error NickTooShort(string nick, uint256 actualLength, uint8 correctLength);

    /**
     * @dev Too long nick
     * @param nick Too long nick
     * @param actualLength Actual length
     * @param correctLength Correct length
     */
    error NickTooLong(string nick, uint256 actualLength, uint8 correctLength);

    /**
     * @dev Too short riddle
     * @param riddle Too short riddle
     * @param actualLength Actual length
     * @param correctLength Correct length
     */
    error RiddleTooShort(string riddle, uint256 actualLength, uint8 correctLength);

    /**
     * @dev Too long riddle
     * @param riddle Too long riddle
     * @param actualLength Actual length
     * @param correctLength Correct length
     */
    error RiddleTooLong(string riddle, uint256 actualLength, uint8 correctLength);

    /**
     * @dev Passed user secret key does not match encrypted solution
     * @param riddleId Riddle id
     * @param statement Riddle statement
     * @param encryptedCredo Encrypted Credo/NonCredo
     * @param userSecretKey Incorrect user secret key
     */
    error IncorrectUserSecretKey(uint32 riddleId, string statement, uint256 encryptedCredo, string userSecretKey);

    /**
     * @dev Invalid guess and/or reveal duration
     * @param _guessDurationBlocks Guess duration in blocks
     * @param _revealDurationBlocks Reveal duration in blocks
     */
    error InvalidDuration(uint32 _guessDurationBlocks, uint32 _revealDurationBlocks);

    /**
     * @dev Invalid percent
     * @param _percent Percent value
     */
    error InvalidPercent(uint8 _percent);

    /**
     * @dev Validate User nick
     * @param nick User nick
     * @return Nick in ShortString form
     */
    function validateNick(string calldata nick) public pure returns (ShortString) {
        bytes memory nickBytes = bytes(nick);

        if (nickBytes.length > MAX_NICK_LENGTH) {
            revert NickTooLong(nick, nickBytes.length, MAX_NICK_LENGTH);
        }
        if (nickBytes.length < MIN_NICK_LENGTH) {
            revert NickTooShort(nick, nickBytes.length, MIN_NICK_LENGTH);
        }
        ShortString nickShortString = ShortStrings.toShortString(nick);

        return nickShortString;
    }

    /**
     * @dev Validate Riddle statement
     * @param statement Riddle contract
     */
    function validateRiddle(string calldata statement) public pure {
        bytes memory statementBytes = bytes(statement);

        if (statementBytes.length > MAX_RIDDLE_LENGTH) {
            revert RiddleTooLong(statement, statementBytes.length, MAX_RIDDLE_LENGTH);
        }
        if (statementBytes.length < MIN_RIDDLE_LENGTH) {
            revert RiddleTooShort(statement, statementBytes.length, MIN_RIDDLE_LENGTH);
        }
    }

    /**
     * @dev Validate durations
     * @param _guessDurationBlocks Guess duration in blocks
     * @param _revealDurationBlocks Reveal duration in blocks
     */
    function validateDurations(uint32 _guessDurationBlocks, uint32 _revealDurationBlocks) public pure {
        if (
            _guessDurationBlocks < MIN_DURATION || _guessDurationBlocks > MAX_DURATION
                || _revealDurationBlocks < MIN_DURATION || _revealDurationBlocks > MAX_DURATION
        ) {
            revert InvalidDuration(_guessDurationBlocks, _revealDurationBlocks);
        }
    }

    /**
     * @dev Validate percent value
     * @param _percent Percent value
     */
    function validatePercent(uint8 _percent) public pure {
        if (_percent < MIN_PERCENT || _percent > MAX_PERCENT) {
            revert InvalidPercent(_percent);
        }
    }

    /**
     * @dev Encrypt Credo/NonCredo
     * @param riddleStatement Riddle statement
     * @param credo Credo/NonCredo
     * @param userSecretKey User secret key string to hide Credo/NonCredo
     * @return encryptedCredo Encrypted Credo/NonCredo
     */
    function encryptCredo(string memory riddleStatement, bool credo, string memory userSecretKey)
        public
        pure
        returns (uint256 encryptedCredo)
    {
        uint256 hash = uint256(keccak256(bytes(string.concat(riddleStatement, userSecretKey))));
        return credo ? hash + 1 : hash;
    }

    /**
     * @dev Decrypt Credo/NonCredo
     * @param riddle Riddle contract
     * @param encryptedCredo Encrypted Credo/NonCredo
     * @param userSecretKey User secret key string to hide Credo/NonCredo
     * @return decryptedCredo Decrypted Credo/NonCredo
     */
    function decryptCredo(IRiddle riddle, uint256 encryptedCredo, string calldata userSecretKey)
        public
        view
        returns (bool decryptedCredo)
    {
        uint256 hash = uint256(keccak256(bytes(string.concat(riddle.statement(), userSecretKey))));
        if (hash == encryptedCredo) {
            decryptedCredo = false;
        } else if (hash + 1 == encryptedCredo) {
            decryptedCredo = true;
        } else {
            revert IncorrectUserSecretKey(riddle.id(), riddle.statement(), encryptedCredo, userSecretKey);
        }
    }

    /**
     * @dev Get all nicks
     * @param register Register contract interface
     * @return result All nicks array
     */
    function allNicks(IRegister register) public view returns (string[] memory result) {
        IUser[] memory usersArray = register.usersArray();
        uint256 usersLength = usersArray.length;
        result = new string[](usersLength);
        for (uint256 i = 0; i < usersLength; ++i) {
            result[i] = usersArray[i].nickString();
        }
        return result;
    }

    /**
     * @dev Check if address is registered User
     */
    function addressIsRegisteredUser(address userAddress, IRegister register) public returns (bool) {
        bool isUser = ERC165Checker.supportsInterface(userAddress, type(IUser).interfaceId);
        if (isUser) {
            IUser user = IUser(userAddress);
            return register.userOf(user.owner()) == user;
        } else {
            return false;
        }
    }

    /**
     * @dev Check if address is registered Riddle
     */
    function addressIsRegisteredRiddle(address payable riddleAddress, IRegister register) public view returns (bool) {
        bool isRiddle = ERC165Checker.supportsInterface(riddleAddress, type(IRiddle).interfaceId);
        if (isRiddle) {
            IRiddle riddle = IRiddle(riddleAddress);
            return riddle.index() < register.totalRiddles() && register.riddles(riddle.index()) == riddle;
        } else {
            return false;
        }
    }
}
