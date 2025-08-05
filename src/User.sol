// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is OwnableUpgradeable {
    ShortString private nick;
    uint256 private index;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _nick User nick initialization
     * @param _index User index initialization
     */
    function initialize(address initialOwner, ShortString _nick, uint256 _index) external initializer {
        __Ownable_init(initialOwner);
        nick = _nick;
        index = _index;
    }

    /**
     * @dev Get nick as string
     * @return Nick string
     */
    function getNick() public view virtual returns (string memory) {
        return ShortStrings.toString(nick);
    }

    /**
     * @dev Get index of user
     * @return result User index
     */
    function getIndex() public view virtual returns (uint256) {
        return index;
    }
}
