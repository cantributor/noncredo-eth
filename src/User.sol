// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {Initializable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is Ownable, Initializable {
    ShortString private nick;

    constructor() Ownable(msg.sender) {}

    function initialize(address owner, ShortString _nick) external initializer {
        _transferOwnership(owner);
        nick = _nick;
    }

    function getNick() public view returns (string memory) {
        return ShortStrings.toString(nick);
    }
}
