// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

library Utils {
    uint8 private constant MIN_NICK_LENGTH = 3;
    uint8 private constant MAX_NICK_LENGTH = 31;

    uint8 private constant MIN_RIDDLE_LENGTH = 10;
    uint8 private constant MAX_RIDDLE_LENGTH = 128;

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

    function validateNick(string calldata nick) internal pure returns (ShortString) {
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

    function validateRiddle(string calldata riddle) internal pure {
        bytes memory riddleBytes = bytes(riddle);

        if (riddleBytes.length > MAX_RIDDLE_LENGTH) {
            revert RiddleTooLong(riddle, riddleBytes.length, MAX_RIDDLE_LENGTH);
        }
        if (riddleBytes.length < MIN_RIDDLE_LENGTH) {
            revert RiddleTooShort(riddle, riddleBytes.length, MIN_RIDDLE_LENGTH);
        }
    }

    function encryptSolution(string calldata riddleStatement, bool solution, string calldata userSecretKey)
        external
        pure
        returns (uint256 encryptedSolution)
    {
        uint256 hash = uint256(keccak256(bytes(string.concat(riddleStatement, userSecretKey))));
        return solution ? hash + 1 : hash;
    }
}
