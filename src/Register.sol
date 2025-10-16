// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRegister} from "./interfaces/IRegister.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";
import {Payment} from "./structs/Payment.sol";

import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
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
import {IRegister} from "./interfaces/IRegister.sol";

/**
 * @title Register
 * @dev Main register contract
 */
contract Register is
    IRegister,
    AccessManagedUpgradeable,
    ERC2771ContextUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
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

    IRiddle[] public riddles;
    mapping(bytes32 statementHash => IRiddle) internal riddleByStatement;

    Payment[] internal payments;

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

    function userOf(address account) external virtual returns (IUser) {
        IUser foundUser = userByAccount[account];
        if (address(foundUser) == address(0)) {
            revert IRegister.AccountNotRegistered(account);
        }
        return foundUser;
    }

    function userOf(string memory nick) external virtual returns (IUser) {
        ShortString nickShortString = ShortStrings.toShortString(nick);
        IUser user = userByNick[nickShortString];
        if (address(user) == address(0)) {
            revert IRegister.NickNotRegistered(nick);
        }
        return user;
    }

    function me() external view virtual returns (IUser) {
        IUser foundUser = userByAccount[_msgSender()];
        if (address(foundUser) == address(0)) {
            revert IRegister.AccountNotRegistered(_msgSender());
        }
        return foundUser;
    }

    function registerMeAs(string calldata nick) external virtual whenNotPaused returns (IUser user) {
        ShortString nickShortString = Utils.validateNick(nick);
        address foundByNick = address(userByNick[nickShortString]);
        if (foundByNick != address(0)) {
            revert IRegister.NickAlreadyRegistered(nick);
        }
        address msgSender = _msgSender();
        address foundByAccount = address(userByAccount[msgSender]);
        if (foundByAccount != address(0)) {
            revert IRegister.AccountAlreadyRegistered(msgSender);
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
            revert IRegister.NickNotRegistered(user.nickString());
        }
        address userOwner = user.owner();
        address foundByAccount = address(userByAccount[userOwner]);
        if (foundByAccount == address(0)) {
            revert IRegister.AccountNotRegistered(userOwner);
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
    function removeRiddle(IRiddle riddle) internal virtual {
        bytes32 statementHash = keccak256(abi.encode(riddle.statement()));
        IRiddle foundByStatement = riddleByStatement[statementHash];
        if (address(foundByStatement) == address(0)) {
            revert IRegister.RiddleStatementNotRegistered(riddle.statement());
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
        riddle.goodbye();
        emit IRiddle.RiddleRemoved(address(riddle.user()), address(riddle), tx.origin, riddle.id());
    }

    /**
     * @dev Remove contract if it is registered User (internal implementation)
     * @param contractAddress Contract to remove
     */
    function removalImplementation(address contractAddress) internal virtual {
        if (addressIsRegisteredUser(contractAddress)) {
            removeUser(IUser(contractAddress));
        } else if (addressIsRegisteredRiddle(payable(contractAddress))) {
            removeRiddle(IRiddle(payable(contractAddress)));
        } else {
            revert IRegister.IllegalActionCall("remove", contractAddress, _msgSender(), tx.origin);
        }
    }

    function remove(address contractAddress) external virtual whenNotPaused restricted {
        removalImplementation(contractAddress);
    }

    function removeMe() external virtual whenNotPaused {
        removalImplementation(_msgSender());
    }

    function totalUsers() external view virtual returns (uint32) {
        return uint32(users.length);
    }

    function allNicks() external view virtual returns (string[] memory result) {
        uint256 usersLength = users.length;
        result = new string[](usersLength);
        for (uint256 i = 0; i < usersLength; ++i) {
            result[i] = users[i].nickString();
        }
        return result;
    }

    function nextRiddleId() external virtual whenNotPaused returns (uint32) {
        riddleCounter++;
        return riddleCounter;
    }

    function totalRiddles() external view virtual returns (uint32) {
        return uint32(riddles.length);
    }

    function registerRiddle(IRiddle riddle) external virtual whenNotPaused {
        bytes32 statementHash = keccak256(abi.encode(riddle.statement()));
        IRiddle foundRiddle = riddleByStatement[statementHash];
        if (address(foundRiddle) != address(0)) {
            revert IRiddle.RiddleAlreadyRegistered(
                foundRiddle.id(), foundRiddle.user().nickString(), foundRiddle.index()
            );
        }
        address userAddress = _msgSender();
        if (!addressIsRegisteredUser(userAddress)) {
            revert IRegister.IllegalActionCall("registerRiddle", address(riddle), userAddress, tx.origin);
        }
        riddles.push(riddle);
        riddleByStatement[statementHash] = riddle;
        emit IRiddle.RiddleRegistered(address(riddle.user()), address(riddle), riddle.id(), statementHash);
    }

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
     * @dev Necessary override
     */
    function upgradeToAndCall(address implementation, bytes memory data)
        public
        payable
        override(UUPSUpgradeable, IRegister)
    {
        UUPSUpgradeable.upgradeToAndCall(implementation, data);
    }

    /**
     * @dev Check if address is registered User
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
     * @dev Check if address is registered Riddle
     */
    function addressIsRegisteredRiddle(address payable riddleAddress) internal view virtual returns (bool) {
        bool isRiddle = ERC165Checker.supportsInterface(riddleAddress, type(IRiddle).interfaceId);
        if (isRiddle) {
            IRiddle riddle = IRiddle(riddleAddress);
            return riddle.index() < riddles.length && riddles[riddle.index()] == riddle;
        } else {
            return false;
        }
    }

    function withdraw(address payable beneficiary) external virtual whenNotPaused restricted {
        uint256 amount = address(this).balance;
        if (amount == 0) {
            revert IRegister.RegisterBalanceIsEmpty(beneficiary);
        }
        (bool success,) = beneficiary.call{value: amount}("");
        if (!success) {
            revert IRegister.WithdrawalError(beneficiary);
        }
        delete payments;
        emit IRegister.Withdrawal(beneficiary, _msgSender(), amount);
    }

    /**
     * @dev Necessary override
     */
    function paused() public view virtual override(PausableUpgradeable, IRegister) returns (bool) {
        return PausableUpgradeable.paused();
    }

    receive() external payable {
        address payable msgSender = payable(_msgSender());
        Payment memory payment;
        if (addressIsRegisteredRiddle(msgSender)) {
            IRiddle riddle = IRiddle(msgSender);
            payment = Payment(msgSender, riddle.id(), msg.value);
        } else {
            payment = Payment(msgSender, 0, msg.value);
        }
        payments.push(payment);
        emit IRegister.PaymentReceived(payment.payer, payment.riddleId, payment.amount);
    }
}
