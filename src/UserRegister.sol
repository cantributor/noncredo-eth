// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "./User.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

/**
 * @title UserRegister
 * @dev User register contract
 */
contract UserRegister is AccessManaged, ERC2771Context {
    uint8 public constant MIN_NICK_LENGTH = 3;
    uint8 public constant MAX_NICK_LENGTH = 31;

    constructor(address accessManager, address trustedForwarder)
        AccessManaged(accessManager)
        ERC2771Context(trustedForwarder)
    {}

    mapping(address account => User user) private userByAccount;
    mapping(ShortString nick => User user) private userByNick;

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
     * @dev Account already registered
     * @param account Already registered account
     */
    error AccountAlreadyRegistered(address account);

    /**
     * @dev Nick successfully registered
     * @param account Nick account
     * @param nick Registered nick
     */
    event SuccessfulUserRegistration(address indexed account, string indexed nick);

    /**
     * @dev Get user of account
     * @param account User account
     * @return nick
     */
    function userOf(address account) external restricted returns (User) {
        User foundUser = userByAccount[account];
        if (address(foundUser) == address(0)) {
            revert AccountNotRegistered(account);
        }
        return foundUser;
    }

    /**
     * @dev Get user of nick
     * @param nick Account nick
     * @return user
     */
    function userOf(string memory nick) external restricted returns (User) {
        ShortString nickShortString = ShortStrings.toShortString(nick);
        User user = userByNick[nickShortString];
        if (address(user) == address(0)) {
            revert NickNotRegistered(nick);
        }
        return user;
    }

    /**
     * @dev Register user for account
     * @param nick Nick for registration
     */
    function registerUser(string calldata nick) external {
        bytes memory nickBytes = bytes(nick);
        if (nickBytes.length > MAX_NICK_LENGTH) {
            revert NickTooLong(nick, nickBytes.length, MAX_NICK_LENGTH);
        }
        if (nickBytes.length < MIN_NICK_LENGTH) {
            revert NickTooShort(nick, nickBytes.length, MIN_NICK_LENGTH);
        }
        ShortString nickShortString = ShortStrings.toShortString(nick);
        address foundByNick = address(userByNick[nickShortString]);
        if (foundByNick != address(0)) {
            revert NickAlreadyRegistered(nick);
        }
        address msgSender = _msgSender();
        address foundByAccount = address(userByAccount[msgSender]);
        if (foundByAccount != address(0)) {
            revert AccountAlreadyRegistered(msgSender);
        }
        User user = new User(msgSender, nickShortString);
        userByNick[nickShortString] = user;
        userByAccount[msgSender] = user;
        emit SuccessfulUserRegistration(msgSender, nick);
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
