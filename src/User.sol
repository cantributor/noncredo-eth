// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ShortString} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is Ownable {
    ShortString public nick;

    constructor(address owner, ShortString _nick) Ownable(owner) {
        nick = _nick;
    }
}
