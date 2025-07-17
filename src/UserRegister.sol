// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Roles} from "../src/Roles.sol";
import {User} from "./User.sol";
import {UserUtils} from "./UserUtils.sol";

import {AccessManagedUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/manager/AccessManagedUpgradeable.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import {AccessManagerUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/manager/AccessManagerUpgradeable.sol";
import {AccessManagedUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/manager/AccessManagedUpgradeable.sol";
import {ERC2771ContextUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/metatx/ERC2771ContextUpgradeable.sol";
import {ContextUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol";
import {Clones} from "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {EnumerableSet} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

import {console} from "../lib/forge-std/src/console.sol";

/**
 * @title UserRegister
 * @dev User register contract
 */
contract UserRegister is AccessManagedUpgradeable, ERC2771ContextUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);
        __UUPSUpgradeable_init();
    }

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
     * @dev Get user of account
     * @param account User account
     * @return user of account
     */
    function userOf(address account) external virtual restricted returns (User) {
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
    function userOf(string memory nick) external virtual restricted returns (User) {
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
    function me() external view virtual returns (User) {
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
    function registerUser(string calldata nick) external virtual {
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
        //        User user = User(Clones.clone(userLibraryAddress));
        User user = new User();
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
    function getTotalUsers() external view virtual returns (uint256) {
        return EnumerableSet.length(userAccounts);
    }

    /**
     * @dev Get all nicks
     * @return result All nicks array
     */
    function getAllNicks() external view virtual returns (string[] memory result) {
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
    function _authorizeUpgrade(address) internal override restricted {}

    function _contextSuffixLength()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}
