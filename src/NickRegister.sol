// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

/**
 * @title NickRegister
 * @dev User nickname register contract
 */
contract NickRegister is AccessManaged, ERC2771Context {
    uint8 public constant MIN_NICK_LENGTH = 3;
    uint8 public constant MAX_NICK_LENGTH = 31;

    constructor(address accessManager, address trustedForwarder)
        AccessManaged(accessManager)
        ERC2771Context(trustedForwarder)
    {}

    mapping(address account => ShortString nick) private nickByAccount;
    mapping(ShortString nick => address account) private accountByNick;

    ShortString[] private allNicks;
    uint32 private nickCounter;

    /**
     * @dev Trying to get unregistered account nickname
     * @param account Unregistered account
     */
    error AccountNotRegistered(address account);

    /**
     * @dev Trying to get unregistered nickname account
     * @param nick Unregistered nick
     */
    error NickNotRegistered(string nick);

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

    /**
     * @dev Nick already registered
     * @param nick Already registered nick
     */
    error NickAlreadyRegistered(string nick);

    /**
     * @dev Nick successfully registered
     * @param account Nick account
     * @param nick Registered nick
     */
    event SuccessfulNickRegistration(address indexed account, string indexed nick);

    /**
     * @dev Get nick of account
     * @param account Nick account
     * @return nick
     */
    function nickOf(address account) external restricted returns (string memory) {
        ShortString foundNick = nickByAccount[account];
        if (ShortStrings.byteLength(foundNick) == 0) {
            revert AccountNotRegistered(account);
        }
        return ShortStrings.toString(foundNick);
    }

    /**
     * @dev Get account of nick
     * @param nick Account nick
     * @return account
     */
    function accountOf(string memory nick) external restricted returns (address) {
        ShortString nickShortString = ShortStrings.toShortString(nick);
        address foundAccount = accountByNick[nickShortString];
        if (foundAccount == address(0)) {
            revert NickNotRegistered(nick);
        }
        return foundAccount;
    }

    /**
     * @dev Get nick of caller
     * @return caller nick
     */
    function myNick() external view returns (string memory) {
        address account = _msgSender();
        ShortString foundNick = nickByAccount[account];
        if (ShortStrings.byteLength(foundNick) == 0) {
            revert AccountNotRegistered(account);
        }
        return ShortStrings.toString(foundNick);
    }

    /**
     * @dev Register nick for account
     * @param nick Nick for registration
     */
    function registerNick(string calldata nick) external {
        bytes memory nickBytes = bytes(nick);
        if (nickBytes.length > MAX_NICK_LENGTH) {
            revert NickTooLong(nick, nickBytes.length, MAX_NICK_LENGTH);
        }
        if (nickBytes.length < MIN_NICK_LENGTH) {
            revert NickTooShort(nick, nickBytes.length, MIN_NICK_LENGTH);
        }
        ShortString nickShortString = ShortStrings.toShortString(nick);
        address foundAccount = accountByNick[nickShortString];
        if (foundAccount != address(0)) {
            revert NickAlreadyRegistered(nick);
        }
        address msgSender = _msgSender();
        nickByAccount[msgSender] = nickShortString;
        accountByNick[nickShortString] = msgSender;
        allNicks.push(nickShortString);
        nickCounter++;
        emit SuccessfulNickRegistration(msgSender, nick);
    }

    /**
     * @dev Get nicks total number
     * @return Nicks total number
     */
    function nicksTotal() external restricted returns (uint32) {
        return nickCounter;
    }

    /**
     * @dev Get all nicks
     * @return result All nicks array
     */
    function getAllNicks() external restricted returns (string[] memory result) {
        result = new string[](allNicks.length);
        for (uint256 i = 0; i < allNicks.length; ++i) {
            result[i] = ShortStrings.toString(allNicks[i]);
        }
        return result;
    }

    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }

    function _msgSender() internal view virtual override(ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
