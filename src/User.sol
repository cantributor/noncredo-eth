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

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializable implementation
     * @param initialOwner Ownable implementation
     * @param _nick User nick initialization
     */
    function initialize(address initialOwner, ShortString _nick) external initializer {
        __Ownable_init(initialOwner);
        nick = _nick;
    }

    /**
     * @dev Get nick as string
     * @return result Nick string
     */
    function getNick() public view virtual returns (string memory result) {
        return ShortStrings.toString(nick);
    }
}
