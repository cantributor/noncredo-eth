// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRegister} from "./IRegister.sol";
import {IRiddle} from "./IRiddle.sol";

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title IUser
 * @dev User interface
 */
interface IUser {
    /**
     * @dev CommitmentError
     * @param commiterAccount Commiter account address
     * @param userAddress User contract address
     * @param statement Riddle statement
     * @param amount Value of commiter's bet
     */
    error CommitmentError(address commiterAccount, address userAddress, string statement, uint256 amount);

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
     * @param remover Who removed
     */
    event UserRemoved(address indexed owner, string indexed nick, address indexed remover);

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _nick User nick initialization
     * @param _index User index initialization
     * @param _registerAddress Register.sol contract address
     */
    function initialize(address initialOwner, ShortString _nick, uint32 _index, address payable _registerAddress)
        external;

    /**
     * @dev Ownable implementation
     * @return User contract Owner account
     */
    function owner() external view returns (address);

    /**
     * @dev Get number of active user riddles
     * @return number of active user riddles
     */
    function totalRiddles() external view returns (uint32);

    /**
     * @dev Find riddle index in riddles array
     * @param riddle Riddle to find
     * @return riddleIndex Riddle index in riddles array
     */
    function indexOf(IRiddle riddle) external view returns (uint256 riddleIndex);

    /**
     * @dev Get nick as string
     * @return Nick string
     */
    function nickString() external view returns (string memory);

    function nick() external view returns (ShortString);

    function registerAddress() external view returns (address payable);

    function riddles(uint256) external view returns (IRiddle);

    function index() external view returns (uint32);

    /**
     * @dev Set index of user (should be implemented with onlyForRegister modifier)
     * @param _index New index value
     */
    function setIndex(uint32 _index) external;

    /**
     * @dev Clean all children contracts and stop operating (should be implemented with onlyForRegister modifier)
     */
    function goodbye() external;

    /**
     * @dev Remove this contract from Register (should be implemented with onlyOwner modifier)
     */
    function remove() external;

    /**
     * @dev Remove riddle
     * @param riddle Riddle to remove
     */
    function remove(IRiddle riddle) external;

    /**
     * @dev Conversion of registerAddress to Register contract
     * @return Register contract
     */
    function register() external view returns (IRegister);

    /**
     * @dev Commit new Riddle contract
     * @param statement Riddle statement
     * @param encryptedSolution Encrypted solution
     */
    function commit(string calldata statement, uint256 encryptedSolution) external payable returns (IRiddle);
}
