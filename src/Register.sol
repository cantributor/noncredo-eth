// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";
import {Payment} from "./structs/Payment.sol";

import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
import {Riddle} from "./Riddle.sol";
import {Roles} from "./Roles.sol";
import {Utils} from "./Utils.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable//utils/PausableUpgradeable.sol";

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/**
 * @title Register
 * @dev Main register contract
 */
contract Register is AccessManagedUpgradeable, ERC2771ContextUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    mapping(address account => IUser user) internal userByAccount;
    mapping(ShortString nick => IUser user) internal userByNick;

    IUser[] public users;

    AccessManagedBeaconHolder public userBeaconHolder;
    AccessManagedBeaconHolder public riddleBeaconHolder;

    uint32 public riddleCounter;

    uint32 public guessDurationBlocks;
    uint32 public revealDurationBlocks;

    uint8 public registerRewardPercent;
    uint8 public riddlingRewardPercent;

    Riddle[] public riddles;
    mapping(bytes32 statementHash => Riddle) internal riddleByStatement;

    Payment[] internal payments;

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
     * @dev Trying to get not registered riddle statement
     * @param statement Not found statement
     */
    error RiddleStatementNotRegistered(string statement);

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
     * @dev Trying to call some function that should be called only by Register contract
     * @param illegalCaller Illegal caller
     */
    error OnlyRegisterMayCallThis(address illegalCaller);

    /**
     * @dev Trying to withdraw funds with empty Register balance
     * @param beneficiary Beneficiary address
     */
    error RegisterBalanceIsEmpty(address beneficiary);

    /**
     * @dev Withdrawal error
     * @param beneficiary Beneficiary address
     */
    error WithdrawalError(address beneficiary);

    /**
     * @dev Payment received
     * @param paymentSender Payment sender address
     * @param riddleId Riddle id
     * @param amount Payment amount
     */
    event PaymentReceived(address indexed paymentSender, uint32 indexed riddleId, uint256 amount);

    /**
     * @dev Withdrawal of register funds with payments array cleaning
     * @param beneficiary Beneficiary address
     * @param withdrawer Withdrawer address
     * @param amount Amount of funds withdrawn
     */
    event Withdrawal(address indexed beneficiary, address indexed withdrawer, uint256 amount);

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
        guessDurationBlocks = 3 * 24 * 60 * 60 / 12; // 3 days * 24 hours * 60 minutes * 60 seconds / 12 sec per block
        revealDurationBlocks = 24 * 60 * 60 / 12; // 24 hours * 60 minutes * 60 seconds / 12 sec per block
        registerRewardPercent = 1;
        riddlingRewardPercent = 10;
    }

    /**
     * @dev Get user of account
     * @param account User account
     * @return user of account
     */
    function userOf(address account) external virtual returns (IUser) {
        IUser foundUser = userByAccount[account];
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
    function userOf(string memory nick) external virtual returns (IUser) {
        ShortString nickShortString = ShortStrings.toShortString(nick);
        IUser user = userByNick[nickShortString];
        if (address(user) == address(0)) {
            revert NickNotRegistered(nick);
        }
        return user;
    }

    /**
     * @dev Get user of current account
     * @return user of current account
     */
    function me() external view virtual returns (IUser) {
        IUser foundUser = userByAccount[_msgSender()];
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
    function registerMeAs(string calldata nick) external virtual whenNotPaused returns (IUser user) {
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
            abi.encodeCall(IUser.initialize, (msgSender, nickShortString, uint32(users.length), payable(this)))
        );
        user = IUser(address(userBeaconProxy));
        userByNick[nickShortString] = user;
        userByAccount[msgSender] = user;
        users.push(user);
        emit IUser.UserRegistered(msgSender, nick);
        return user;
    }

    /**
     * @dev Remove user. Internal implementation
     * @param user User to remove
     */
    function removeUser(IUser user) internal virtual {
        address foundByNick = address(userByNick[user.nick()]);
        if (foundByNick == address(0)) {
            revert NickNotRegistered(user.nickString());
        }
        address userOwner = user.owner();
        address foundByAccount = address(userByAccount[userOwner]);
        if (foundByAccount == address(0)) {
            revert AccountNotRegistered(userOwner);
        }
        delete userByNick[user.nick()];
        delete userByAccount[userOwner];
        uint32 userIndex = user.index();
        if (userIndex < users.length - 1) {
            users[userIndex] = users[users.length - 1];
            users[userIndex].setIndex(userIndex);
        }
        users.pop();
        user.goodbye();
        emit IUser.UserRemoved(userOwner, user.nickString(), tx.origin);
    }

    /**
     * @dev Remove riddle. Internal implementation
     * @param riddle Riddle to remove
     */
    function removeRiddle(Riddle riddle) internal virtual {
        bytes32 statementHash = keccak256(abi.encode(riddle.statement()));
        Riddle foundByStatement = riddleByStatement[statementHash];
        if (address(foundByStatement) == address(0)) {
            revert RiddleStatementNotRegistered(riddle.statement());
        }
        delete riddleByStatement[statementHash];
        // check for existence in riddles already done in addressIsRegisteredRiddle(payable)
        uint32 riddleIndex = riddle.index();
        if (riddleIndex < riddles.length - 1) {
            riddles[riddleIndex] = riddles[riddles.length - 1];
            riddles[riddleIndex].setIndex(riddleIndex);
        }
        riddles.pop();
        riddle.user().remove(riddle);
        riddle.finalize();
        emit Riddle.RiddleRemoved(address(riddle.user()), address(riddle), riddle.id());
    }

    /**
     * @dev Remove contract if it is registered User (internal implementation)
     * @param contractAddress Contract to remove
     */
    function removalImplementation(address contractAddress) internal virtual {
        if (addressIsRegisteredUser(contractAddress)) {
            removeUser(IUser(contractAddress));
        } else if (addressIsRegisteredRiddle(payable(contractAddress))) {
            removeRiddle(Riddle(payable(contractAddress)));
        } else {
            revert IllegalActionCall("remove", contractAddress, _msgSender(), tx.origin);
        }
    }

    /**
     * @dev Remove contract - restricted access function (for admins)
     */
    function remove(address contractAddress) external virtual whenNotPaused restricted {
        removalImplementation(contractAddress);
    }

    /**
     * @dev Remove caller
     */
    function removeMe() external virtual whenNotPaused {
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
    function nextRiddleId() external virtual whenNotPaused returns (uint32) {
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
    function registerRiddle(Riddle riddle) external virtual whenNotPaused {
        bytes32 statementHash = keccak256(abi.encode(riddle.statement()));
        Riddle foundRiddle = riddleByStatement[statementHash];
        if (address(foundRiddle) != address(0)) {
            revert Riddle.RiddleAlreadyRegistered(
                foundRiddle.id(), foundRiddle.user().nickString(), foundRiddle.index()
            );
        }
        address userAddress = _msgSender();
        if (!addressIsRegisteredUser(userAddress)) {
            revert IllegalActionCall("registerRiddle", address(riddle), userAddress, tx.origin);
        }
        riddles.push(riddle);
        riddleByStatement[statementHash] = riddle;
        emit Riddle.RiddleRegistered(address(riddle.user()), address(riddle), riddle.id(), statementHash);
    }

    /**
     * @dev Set guess & reveal duration (in blocks)
     * @param _guessDuration New guess duration value
     * @param _revealDuration New reveal duration value
     */
    function setGuessAndRevealDuration(uint32 _guessDuration, uint32 _revealDuration)
        external
        virtual
        whenNotPaused
        restricted
    {
        Utils.validateDurations(_guessDuration, _revealDuration);
        guessDurationBlocks = _guessDuration;
        revealDurationBlocks = _revealDuration;
    }

    /**
     * @dev Set register & riddling rewards (in percents)
     * @param _registerReward New register reward percent value
     * @param _riddlingReward New riddling reward percent value
     */
    function setRegisterAndRiddlingRewards(uint8 _registerReward, uint8 _riddlingReward)
        external
        virtual
        whenNotPaused
        restricted
    {
        Utils.validatePercent(_registerReward);
        Utils.validatePercent(_riddlingReward);
        registerRewardPercent = _registerReward;
        riddlingRewardPercent = _riddlingReward;
    }

    /**
     * @dev Get payments array
     * @return payments array
     */
    function paymentsArray() external view virtual returns (Payment[] memory) {
        return payments;
    }

    /**
     * @dev Pause execution
     */
    function pause() external virtual restricted {
        _pause();
    }

    /**
     * @dev Resume execution
     */
    function resume() external virtual restricted {
        _unpause();
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
            IUser user = IUser(userAddress);
            return userByAccount[user.owner()] == user;
        } else {
            return false;
        }
    }

    /**
     * @dev Check if address is registered user
     */
    function addressIsRegisteredRiddle(address payable riddleAddress) internal view virtual returns (bool) {
        bool isRiddle = ERC165Checker.supportsInterface(riddleAddress, type(IRiddle).interfaceId);
        if (isRiddle) {
            Riddle riddle = Riddle(riddleAddress);
            return riddles[riddle.index()] == riddle;
        } else {
            return false;
        }
    }

    /**
     * @dev Withdraw funds
     * @param beneficiary Address to withdraw
     */
    function withdraw(address payable beneficiary) external virtual whenNotPaused restricted {
        uint256 amount = address(this).balance;
        if (amount == 0) {
            revert RegisterBalanceIsEmpty(beneficiary);
        }
        (bool success,) = beneficiary.call{value: amount}("");
        if (!success) {
            revert WithdrawalError(beneficiary);
        }
        delete payments;
        emit Withdrawal(beneficiary, _msgSender(), amount);
    }

    /**
     * @dev Receive payment
     */
    receive() external payable {
        address payable msgSender = payable(_msgSender());
        Payment memory payment;
        if (addressIsRegisteredRiddle(msgSender)) {
            Riddle riddle = Riddle(msgSender);
            payment = Payment(msgSender, riddle.id(), msg.value);
        } else {
            payment = Payment(msgSender, 0, msg.value);
        }
        payments.push(payment);
        emit PaymentReceived(payment.payer, payment.riddleId, payment.amount);
    }
}
