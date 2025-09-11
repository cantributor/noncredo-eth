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
    ShortString public nick;
    uint32 public index;
    address internal registerAddress;

    /**
     * @dev Trying to call some function that should be called only by Register contract
     * @param illegalCaller Illegal caller
     */
    error OnlyRegisterMayCallThis(address illegalCaller);

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

    /**
     * @dev Get nick as string
     * @return Nick string
     */
    function nickString() external view virtual override returns (string memory) {
        return ShortStrings.toString(nick);
    }

    /**
     * @dev Set index of user (should be implemented with onlyForRegister modifier)
     * @param _index New index value
     */
    function setIndex(uint32 _index) external virtual override onlyForRegister {
        index = _index;
    }

    /**
     * @dev Clean all children contracts and stop operating (should be implemented with onlyForRegister modifier)
     */
    function goodbye() external virtual override onlyForRegister {
        // TODO: implement riddles removing
        // TODO: implement stop operating
    }

    /**
     * @dev Remove this contract from Register (should be implemented with OnlyOwner modifier)
     */
    function remove() external virtual override onlyOwner {
        Register(registerAddress).removeMe();
    }

    /**
     * @dev Implementation of ERC165
     * @param interfaceId Interface identifier
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IUser).interfaceId || interfaceId == type(OwnableUpgradeable).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
