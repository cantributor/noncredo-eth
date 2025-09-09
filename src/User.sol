// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is OwnableUpgradeable {
    ShortString private nick;
    uint32 private index;
    address internal registerAddress;

    /**
     * @dev Trying to change index not from Register.sol
     * @param msgSender Illegal message sender
     */
    error UnauthorizedIndexChange(address msgSender);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _nick User nick initialization
     * @param _index User index initialization
     * @param _registerAddress Register.sol contract address
     */
    function initialize(address initialOwner, ShortString _nick, uint32 _index, address _registerAddress)
        external
        initializer
    {
        __Ownable_init(initialOwner);
        nick = _nick;
        index = _index;
        registerAddress = _registerAddress;
    }

    /**
     * @dev Get nick as string
     * @return Nick string
     */
    function getNick() public view virtual returns (string memory) {
        return ShortStrings.toString(nick);
    }

    /**
     * @dev Get nick ShortString
     * @return Nick ShortString
     */
    function getNickShortString() public view virtual returns (ShortString) {
        return nick;
    }

    /**
     * @dev Get index of user
     * @return result User index
     */
    function getIndex() public view virtual returns (uint32) {
        return index;
    }

    /**
     * @dev Set index of user
     * @param newIndex New index value
     */
    function setIndex(uint32 newIndex) public virtual {
        if (msg.sender != registerAddress) {
            revert UnauthorizedIndexChange(msg.sender);
        }
        index = newIndex;
    }
}
