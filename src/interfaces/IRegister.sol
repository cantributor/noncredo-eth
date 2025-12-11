// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Payment} from "../structs/Payment.sol";

import {IRiddle} from "./IRiddle.sol";
import {IUser} from "./IUser.sol";

import {AccessManagedBeaconHolder} from "../AccessManagedBeaconHolder.sol";

/**
 * @title IRegister
 * @dev Register interface
 */
interface IRegister {
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
    ) external;

    function riddleBeaconHolder() external returns (AccessManagedBeaconHolder);

    function guessDurationBlocks() external view returns (uint32);
    function revealDurationBlocks() external view returns (uint32);

    function registerRewardPercent() external view returns (uint8);

    function riddleBanThreshold() external view returns (uint8);

    function riddles(uint256) external view returns (IRiddle);
    function users(uint256) external view returns (IUser);

    function paused() external view returns (bool);

    /**
     * @dev Get user of account
     * @param account User account
     * @return user of account
     */
    function userOf(address account) external returns (IUser);

    /**
     * @dev Get user of nick
     * @param nick Account nick
     * @return user
     */
    function userOf(string memory nick) external returns (IUser);

    /**
     * @dev Register user for sender account with specific nickname
     * @param nick Nick for registration
     * @return user Registered user
     */
    function registerMeAs(string calldata nick) external returns (IUser user);

    /**
     * @dev Remove contract - restricted access function (for admins)
     */
    function remove(address contractAddress) external;

    /**
     * @dev Remove caller
     */
    function removeMe() external;

    /**
     * @dev Get total number of users
     * @return total number of users
     */
    function totalUsers() external view returns (uint32);

    /**
     * @dev Riddle id generator
     * @return Next riddle id value
     */
    function nextRiddleId() external returns (uint32);

    /**
     * @dev Get total number of active riddles
     * @return total number of active riddles
     */
    function totalRiddles() external view returns (uint32);

    /**
     * @dev Register riddle
     * @param riddle Riddle contract to register
     */
    function registerRiddle(IRiddle riddle) external;

    /**
     * @dev Set guess & reveal duration (in blocks)
     * @param _guessDuration New guess duration value
     * @param _revealDuration New reveal duration value
     */
    function setGuessAndRevealDuration(uint32 _guessDuration, uint32 _revealDuration) external;

    /**
     * @dev Set register & riddling rewards (in percents)
     * @param _registerReward New register reward percent value
     */
    function setRegisterReward(uint8 _registerReward) external;

    /**
     * @dev Set riddle ban threshold
     * @param _riddleBanThreshold Ban threshold for riddles
     */
    function setRiddleBanThreshold(uint8 _riddleBanThreshold) external;

    /**
     * @dev Get payments array
     * @return Payments array
     */
    function paymentsArray() external view returns (Payment[] memory);

    /**
     * @dev Get users array
     * @return Users array
     */
    function usersArray() external view returns (IUser[] memory);

    /**
     * @dev Pause execution
     */
    function pause() external;

    /**
     * @dev Resume execution
     */
    function resume() external;

    /**
     * @dev Withdraw funds
     * @param beneficiary Address to withdraw
     */
    function withdraw(address payable beneficiary) external;

    /**
     * @dev UUPSUpgradeable implementation
     */
    function upgradeToAndCall(address implementation, bytes memory data) external payable;

    /**
     * @dev Receive payment
     */
    receive() external payable;
}
