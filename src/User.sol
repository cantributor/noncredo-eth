// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IUser} from "./interfaces/IUser.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";

import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
import {Register} from "./Register.sol";
import {Utils} from "./Utils.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
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
    address payable public registerAddress;

    IRiddle[] public riddles;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, ShortString _nick, uint32 _index, address payable _registerAddress)
        external
        override
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
            revert Register.OnlyRegisterMayCallThis(msg.sender);
        }
        _;
    }

    function commit(string calldata statement, uint256 encryptedSolution)
        external
        virtual
        override
        onlyOwner
        returns (IRiddle riddle)
    {
        Utils.validateRiddle(statement);
        Register reg = this.register();
        AccessManagedBeaconHolder riddleBeaconHolder = reg.riddleBeaconHolder();
        BeaconProxy riddleBeaconProxy = new BeaconProxy(
            address(riddleBeaconHolder.beacon()),
            abi.encodeCall(
                IRiddle.initialize,
                (owner(), reg.nextRiddleId(), reg.totalRiddles(), this, statement, encryptedSolution)
            )
        );
        riddle = IRiddle(payable(riddleBeaconProxy));
        riddles.push(riddle);
        reg.registerRiddle(riddle);
        return riddle;
    }

    function totalRiddles() external view virtual override returns (uint32) {
        return uint32(riddles.length);
    }

    function indexOf(IRiddle riddle) external view virtual override returns (int256 riddleIndex) {
        riddleIndex = -1;
        for (uint256 i = 0; i < riddles.length; i++) {
            if (riddles[i] == riddle) {
                riddleIndex = int256(i);
                break;
            }
        }
        return riddleIndex;
    }

    function nickString() external view virtual override returns (string memory) {
        return ShortStrings.toString(nick);
    }

    function setIndex(uint32 _index) external virtual override onlyForRegister {
        index = _index;
    }

    function goodbye() external virtual override onlyForRegister {
        for (int256 i = int256(riddles.length) - 1; i >= 0; i--) {
            riddles[uint256(i)].remove();
        }
    }

    function remove() external virtual override onlyOwner {
        register().removeMe();
    }

    function remove(IRiddle riddle) external virtual onlyForRegister {
        int256 foundRiddleIndex = this.indexOf(riddle);
        if (foundRiddleIndex < 0) {
            revert IRiddle.RiddleIsNotRegistered(riddle.id(), address(riddle), _msgSender());
        }
        uint256 riddleIndex = uint256(foundRiddleIndex);
        if (riddleIndex < riddles.length - 1) {
            riddles[riddleIndex] = riddles[riddles.length - 1];
        }
        riddles.pop();
    }

    function register() public virtual override returns (Register) {
        return Register(registerAddress);
    }

    /**
     * @dev Implementation of ERC165
     * @param interfaceId Interface identifier
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IUser).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Necessary override
     */
    function owner() public view virtual override(OwnableUpgradeable, IUser) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
