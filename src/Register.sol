// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IUser} from "./interfaces/IUser.sol";
import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
import {Riddle} from "./Riddle.sol";
import {Roles} from "./Roles.sol";
import {User} from "./User.sol";
import {Utils} from "./Utils.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/**
 * @title Register
 * @dev Main register contract
 */
contract Register is AccessManagedUpgradeable, ERC2771ContextUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    mapping(address account => User user) internal userByAccount;
    mapping(ShortString nick => User user) internal userByNick;

    User[] internal users;

    AccessManagedBeaconHolder public userBeaconHolder;
    AccessManagedBeaconHolder public riddleBeaconHolder;

    uint32 public riddleCounter = 0;
    uint16 public guessDurationBlocks = 3 * 24 * 60 * (60 / 12); // 3 days * 24 hours * 60 minutes (12 seconds per block)
    uint16 public revealDurationBlocks = 24 * 60 * (60 / 12); // 24 hours * 60 minutes (12 seconds per block)
    Riddle[] internal riddles;
    mapping(bytes32 statementHash => Riddle) internal riddleByStatement;

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
     * @dev Action call for illegal object or by illegal object
     * @param action Action called
     * @param object Object of action
     * @param msgSender Message sender
     * @param txOrigin Transaction origin
     */
    error IllegalActionCall(string action, address object, address msgSender, address txOrigin);

    /**
     * @dev Initializable implementation
     * @param _initialAuthority Access manager
     * @param _userBeaconHolder AccessManagedBeaconHolder for User contract
     * @param _riddleBeaconHolder AccessManagedBeaconHolder for Riddle contract
     */
    function initialize(
        address _initialAuthority,
        AccessManagedBeaconHolder _userBeaconHolder,
        AccessManagedBeaconHolder _riddleBeaconHolder
    ) public initializer {
        __AccessManaged_init(_initialAuthority);
        __UUPSUpgradeable_init();
        userBeaconHolder = _userBeaconHolder;
        riddleBeaconHolder = _riddleBeaconHolder;
    }

    /**
     * @dev Get user of account
     * @param account User account
     * @return user of account
     */
    function userOf(address account) external virtual returns (User) {
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
    function userOf(string memory nick) external virtual returns (User) {
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
        emit User.UserRegistered(msgSender, nick);
        return user;
    }

    /**
     * @dev Remove user. Internal implementation
     * @param user User to remove
     */
    function removeUser(User user) internal virtual {
        address foundByNick = address(userByNick[user.nick()]);
        if (foundByNick == address(0)) {
            revert NickNotRegistered(user.nickString());
        }
        address foundByAccount = address(userByAccount[user.owner()]);
        if (foundByAccount == address(0)) {
            revert AccountNotRegistered(user.owner());
        }
        delete userByNick[user.nick()];
        delete userByAccount[user.owner()];
        uint32 userIndex = user.index();
        users[userIndex] = users[users.length - 1];
        users[userIndex].setIndex(userIndex);
        users.pop();
        user.goodbye();
        emit User.UserRemoved(user.owner(), user.nickString(), tx.origin);
    }

    /**
     * @dev Remove contract if it is registered User (internal implementation)
     * @param contractAddress Contract to remove
     */
    function removalImplementation(address contractAddress) internal virtual {
        if (addressIsRegisteredUser(contractAddress)) {
            removeUser(User(contractAddress));
        } else {
            revert IllegalActionCall("remove", contractAddress, _msgSender(), tx.origin);
        }
    }

    /**
     * @dev Remove contract - restricted access function (for admins)
     */
    function remove(address contractAddress) external virtual restricted {
        removalImplementation(contractAddress);
    }

    /**
     * @dev Remove caller
     */
    function removeMe() external virtual {
        removalImplementation(_msgSender());
    }

    /**
     * @dev Get total number of users
     * @return total number of users
     */
    function totalUsers() external view virtual returns (uint32) {
        return uint32(users.length);
    }

    /**
     * @dev Get all nicks
     * @return result All nicks array
     */
    function allNicks() external view virtual returns (string[] memory result) {
        uint256 usersLength = users.length;
        result = new string[](usersLength);
        for (uint256 i = 0; i < usersLength; ++i) {
            result[i] = users[i].nickString();
        }
        return result;
    }

    /**
     * @dev Riddle id generator
     * @return Next riddle id value
     */
    function nextRiddleId() external virtual returns (uint32) {
        riddleCounter++;
        return riddleCounter;
    }

    /**
     * @dev Get total number of active riddles
     * @return total number of active riddles
     */
    function totalRiddles() external view virtual returns (uint32) {
        return uint32(riddles.length);
    }

    /**
     * @dev Register riddle
     * @param riddle Riddle contract to register
     */
    function registerRiddle(Riddle riddle) external virtual {
        bytes32 statementHash = keccak256(abi.encode(riddle.statement()));
        Riddle foundRiddle = riddleByStatement[statementHash];
        if (address(foundRiddle) != address(0)) {
            revert Riddle.RiddleAlreadyRegistered(
                foundRiddle.id(), foundRiddle.user().nickString(), foundRiddle.userIndex()
            );
        }
        address userAddress = _msgSender();
        if (!addressIsRegisteredUser(userAddress)) {
            revert IllegalActionCall("registerRiddle", address(riddle), userAddress, tx.origin);
        }
        riddles.push(riddle);
        riddleByStatement[statementHash] = riddle;
        emit Riddle.RiddleRegistered(address(riddle.user()), riddle.id(), statementHash);
    }

    /**
     * @dev Set guess duration (in blocks)
     * @param _guessDurationBlocks New guess duration value
     * @param _revealDurationBlocks New reveal duration value
     */
    function setGuessAndRevealDuration(uint16 _guessDurationBlocks, uint16 _revealDurationBlocks)
        external
        virtual
        restricted
    {
        guessDurationBlocks = _guessDurationBlocks;
        revealDurationBlocks = _revealDurationBlocks;
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

    /**
     * @dev Check if address is registered user
     */
    function addressIsRegisteredUser(address userAddress) internal view virtual returns (bool) {
        bool isUser = ERC165Checker.supportsInterface(userAddress, type(IUser).interfaceId);
        if (isUser) {
            User user = User(userAddress);
            return userByAccount[user.owner()] == user;
        } else {
            return false;
        }
    }
}
