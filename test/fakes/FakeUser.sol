// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {console} from "forge-std/Test.sol";

import {IUser} from "../../src/interfaces/IUser.sol";

import {Riddle} from "src/Riddle.sol";
import {Register} from "src/Register.sol";

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @dev FakeUser repeats User except:
 * FakeUser is not OwnableUpgradeable so it can be create without any proxy stuff
 * FakeUser allows to call its remove to anybody (now OnlyOwner modifier on remove function)
 */
contract FakeUser is IUser, Ownable, ERC165 {
    ShortString public nick;
    uint32 public index;
    address payable public registerAddress;
    Riddle[] public riddles;

    constructor(address initialOwner, ShortString _nick, uint32 _index, address payable _registerAddress)
        Ownable(initialOwner)
    {
        nick = _nick;
        index = _index;
        registerAddress = _registerAddress;
    }

    function initialize(address initialOwner, ShortString _nick, uint32 _index, address payable _registerAddress)
        external
    {}

    function owner() public view virtual override(Ownable, IUser) returns (address) {
        return Ownable.owner();
    }

    function commit(string calldata statement, uint256 encryptedSolution) external virtual override returns (Riddle) {
        console.log("Just to escape compiler warning about variables not used", statement, encryptedSolution);
        return Riddle(payable(0));
    }

    function totalRiddles() external view virtual override returns (uint32) {
        return 0;
    }

    function indexOf(Riddle) external view virtual returns (int256) {
        return -1;
    }

    function nickString() external view virtual override returns (string memory) {
        return ShortStrings.toString(nick);
    }

    function setIndex(uint32 _index) external virtual override {
        index = _index;
    }

    function goodbye() external virtual override {}

    function remove() external virtual override {
        Register(registerAddress).removeMe();
    }

    function remove(Riddle riddle) external virtual {}

    function register() external virtual override returns (Register) {
        return Register(registerAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IUser).interfaceId || interfaceId == type(OwnableUpgradeable).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
