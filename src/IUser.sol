// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title IUser
 * @dev User interface
 */
interface IUser {
    /**
     * @dev Trying to call some function that should be called only by Register contract
     * @param illegalCaller Illegal caller
     */
    error OnlyRegisterMayCallThis(address illegalCaller);

    /**
     * @dev Get nick as string
     * @return Nick string
     */
    function getNick() external view returns (string memory);

    /**
     * @dev Get nick ShortString
     * @return Nick ShortString
     */
    function getNickShortString() external view returns (ShortString);

    /**
     * @dev Get index of user
     * @return result User index
     */
    function getIndex() external view returns (uint32);

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
     * @dev Remove this contract from Register (should be implemented with OnlyOwner modifier)
     */
    function remove() external;
}
