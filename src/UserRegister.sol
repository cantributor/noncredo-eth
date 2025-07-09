// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Roles} from "../src/Roles.sol";
import {User} from "./User.sol";
import {UserUtils} from "./UserUtils.sol";

import {Initializable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {AccessManager} from "../lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {AccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import {ERC2771Context} from "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Context} from "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Clones} from "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

import {console} from "../lib/forge-std/src/console.sol";

/**
 * @title UserRegister
 * @dev User register contract
 */
contract UserRegister is AccessManaged, ERC2771Context, UUPSUpgradeable {
    constructor(address accessManager, address trustedForwarder)
        AccessManaged(accessManager)
        ERC2771Context(trustedForwarder)
    {}

    mapping(address account => User user) private userByAccount;
    mapping(ShortString nick => User user) private userByNick;

    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private userAccounts;

    address private userLibraryAddress = address(new User());

    /**
     * @dev Trying to get unregistered account
     * @param account Unregistered account
     */
    error AccountNotRegistered(address account);

    /**
     * @dev Trying to get unregistered nickname user
     * @param nick Unregistered nick
     */
    error NickNotRegistered(string nick);

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
     * @dev Get contract version
     * @return contract version
     */
    function getVersion() external view virtual returns (string memory) {
        return "0.0.0";
    }

    /**
     * @dev Get user of account
     * @param account User account
     * @return user of account
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
     * @dev Get user of current account
     * @return user of current account
     */
    function me() external view returns (User) {
        User foundUser = userByAccount[_msgSender()];
        if (address(foundUser) == address(0)) {
            revert AccountNotRegistered(_msgSender());
        }
        return foundUser;
    }

    /**
     * @dev Register user for account
     * @param nick Nick for registration
     */
    function registerUser(string calldata nick) external {
        ShortString nickShortString = UserUtils.validateNick(nick);
        address foundByNick = address(userByNick[nickShortString]);
        if (foundByNick != address(0)) {
            revert NickAlreadyRegistered(nick);
        }
        address msgSender = _msgSender();
        address foundByAccount = address(userByAccount[msgSender]);
        if (foundByAccount != address(0)) {
            revert AccountAlreadyRegistered(msgSender);
        }
        User user = User(Clones.clone(userLibraryAddress));
        user.initialize(msgSender, nickShortString);
        userByNick[nickShortString] = user;
        userByAccount[msgSender] = user;
        EnumerableSet.add(userAccounts, msgSender);
        emit SuccessfulUserRegistration(msgSender, nick);
    }

    /**
     * @dev Get total number of users
     * @return total number of users
     */
    function getTotalUsers() external view returns (uint256) {
        return EnumerableSet.length(userAccounts);
    }

    /**
     * @dev Get all nicks
     * @return result All nicks array
     */
    function getAllNicks() external view returns (string[] memory result) {
        uint256 totalUsers = EnumerableSet.length(userAccounts);
        result = new string[](totalUsers);
        for (uint256 i = 0; i < totalUsers; ++i) {
            address account = EnumerableSet.at(userAccounts, i);
            User user = userByAccount[account];
            result[i] = user.getNick();
        }
        return result;
    }

    /**
     * @dev Upgrade authorization
     */
    function _authorizeUpgrade(address) internal view override {
        console.log("_authorizeUpgrade msg.sender: ", msg.sender);
        console.log("_authorizeUpgrade this: ", address(this));
        //        (bool authorized,) = AccessManager(authority()).hasRole(Roles.ADMIN_ROLE, msg.sender);
        console.log("authority(): ", authority());
        console.log("trustedForwarder(): ", trustedForwarder());
        //        if (!authorized) {
        //            console.log("upgrader: ", msg.sender);
        //            revert AccessManagedUnauthorized(msg.sender);
        //        }
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
