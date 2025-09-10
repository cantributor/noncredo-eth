// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IUser} from "./IUser.sol";
import {Register} from "./Register.sol";

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is IUser, OwnableUpgradeable, ERC165 {
    ShortString internal nick;
    uint32 internal index;
    address internal registerAddress;

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
     * @dev Throws if called by any account other than the Register contract remembered in registerAddress
     */
    modifier onlyForRegister() {
        if (msg.sender != registerAddress) {
            revert OnlyRegisterMayCallThis(msg.sender);
        }
        _;
    }

    function getNick() external view virtual override returns (string memory) {
        return ShortStrings.toString(nick);
    }

    function getNickShortString() external view override returns (ShortString) {
        return nick;
    }

    function getIndex() external view override returns (uint32) {
        return index;
    }

    function setIndex(uint32 _index) external virtual override onlyForRegister {
        index = _index;
    }

    function goodbye() external virtual override onlyForRegister {
        // TODO: implement riddles removing
        // TODO: implement stop operating
    }

    function remove() external virtual override onlyOwner {
        Register(registerAddress).removeMe();
    }

    /**
     * @dev Implementation of ERC165
     * @param interfaceId Interface identifier
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IUser).interfaceId || super.supportsInterface(interfaceId);
    }
}
