// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

library Utils {
    uint8 private constant MIN_NICK_LENGTH = 3;
    uint8 private constant MAX_NICK_LENGTH = 31;

    /**
     * @dev Too short nick
     * @param nick Too short nick
     * @param length Nick length
     * @param correctLength Correct length
     */
    error NickTooShort(string nick, uint256 length, uint8 correctLength);

    /**
     * @dev Too long nick
     * @param nick Too long nick
     * @param length Nick length
     * @param correctLength Correct length
     */
    error NickTooLong(string nick, uint256 length, uint8 correctLength);

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
}
