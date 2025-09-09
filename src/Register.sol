// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Roles} from "./Roles.sol";
import {User} from "./User.sol";
import {Utils} from "./Utils.sol";
import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title Register
 * @dev Main register contract
 */
contract Register is AccessManagedUpgradeable, ERC2771ContextUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    mapping(address account => User user) private userByAccount;
    mapping(ShortString nick => User user) private userByNick;

    User[] private users;

    AccessManagedBeaconHolder public userBeaconHolder;

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
     * @dev User successfully registered
     * @param owner User owner address
     * @param nick User nick
     */
    event UserRegistered(address indexed owner, string indexed nick);

    /**
     * @dev User successfully removed
     * @param owner User owner address
     * @param nick User nick
     */
    event UserRemoved(address indexed owner, string indexed nick);

    /**
     * @dev Initializable implementation
     * @param initialAuthority Access manager
     */
    function initialize(address initialAuthority, AccessManagedBeaconHolder _userBeaconHolder) public initializer {
        __AccessManaged_init(initialAuthority);
        __UUPSUpgradeable_init();
        userBeaconHolder = _userBeaconHolder;
    }

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
     * @dev Register user for sender account with specific nickname
     * @param nick Nick for registration
     * @return user Registered user
     */
    function registerMeAs(string calldata nick) external virtual returns (User user) {
        ShortString nickShortString = Utils.validateNick(nick);
        address foundByNick = address(userByNick[nickShortString]);
        if (foundByNick != address(0)) {
            revert NickAlreadyRegistered(nick);
        }
        address msgSender = _msgSender();
        address foundByAccount = address(userByAccount[msgSender]);
        if (foundByAccount != address(0)) {
            revert AccountAlreadyRegistered(msgSender);
        }
        BeaconProxy userBeaconProxy = new BeaconProxy(
            address(userBeaconHolder.beacon()),
            abi.encodeCall(User.initialize, (msgSender, nickShortString, uint32(users.length), address(this)))
        );
        user = User(address(userBeaconProxy));
        userByNick[nickShortString] = user;
        userByAccount[msgSender] = user;
        users.push(user);
        emit UserRegistered(msgSender, nick);
        return user;
    }

    /**
     * @dev Remove user
     * @param user User to remove
     */
    function remove(User user) external virtual restricted {
        address foundByNick = address(userByNick[user.getNickShortString()]);
        if (foundByNick == address(0)) {
            revert NickNotRegistered(user.getNick());
        }
        address foundByAccount = address(userByAccount[user.owner()]);
        if (foundByAccount == address(0)) {
            revert AccountNotRegistered(user.owner());
        }
        delete userByNick[user.getNickShortString()];
        delete userByAccount[user.owner()];
        uint32 userIndex = user.getIndex();
        users[userIndex] = users[users.length - 1];
        users[userIndex].setIndex(userIndex);
        users.pop();
        emit UserRemoved(user.owner(), user.getNick());
    }

    /**
     * @dev Get total number of users
     * @return total number of users
     */
    function getTotalUsers() external view virtual returns (uint256) {
        return users.length;
    }

    /**
     * @dev Get all nicks
     * @return result All nicks array
     */
    function getAllNicks() external view virtual returns (string[] memory result) {
        uint256 totalUsers = users.length;
        result = new string[](totalUsers);
        for (uint256 i = 0; i < totalUsers; ++i) {
            result[i] = users[i].getNick();
        }
        return result;
    }

    /**
     * @dev Upgrade authorization
     */
    function _authorizeUpgrade(address) internal override restricted {}

    /**
     * @dev Necessary override
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    /**
     * @dev Necessary override
     */
    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Necessary override
     */
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
