// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IRegister} from "./interfaces/IRegister.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";

import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
import {Utils} from "./Utils.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

/**
 * @title User
 * @dev User contract
 */
contract User is IUser, OwnableUpgradeable, ERC165, ERC2771ContextUpgradeable {
    ShortString public nick;
    uint32 public index;
    address payable public registerAddress;

    IRiddle[] public riddles;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
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
        _onlyForRegister();
        _;
    }

    function _onlyForRegister() internal view {
        if (msg.sender != registerAddress) {
            revert IRegister.OnlyRegisterMayCallThis(msg.sender);
        }
    }

    function commit(string calldata statement, uint256 encryptedSolution)
        external
        payable
        virtual
        override
        onlyOwner
        returns (IRiddle riddle)
    {
        Utils.validateRiddle(statement);
        IRegister reg = this.register();
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
        if (msg.value > 0) {
            (bool success,) = payable(riddle).call{value: msg.value}("");
            if (!success) {
                revert IUser.CommitmentError(owner(), address(this), statement, msg.value);
            }
        }
        return riddle;
    }

    function totalRiddles() external view virtual override returns (uint32) {
        return uint32(riddles.length);
    }

    function indexOf(IRiddle riddle) external view virtual override returns (uint256 riddleIndex) {
        riddleIndex = type(uint256).max;
        for (uint256 i = 0; i < riddles.length; i++) {
            if (riddles[i] == riddle) {
                riddleIndex = i;
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
        for (uint256 i = riddles.length; i > 0; i--) {
            riddles[i - 1].remove();
        }
    }

    function remove() external virtual override onlyOwner {
        register().removeMe();
    }

    function remove(IRiddle riddle) external virtual onlyForRegister {
        uint256 foundRiddleIndex = this.indexOf(riddle);
        if (foundRiddleIndex == type(uint256).max) {
            revert IRiddle.RiddleIsNotRegistered(riddle.id(), address(riddle), _msgSender());
        }
        if (foundRiddleIndex < riddles.length - 1) {
            riddles[foundRiddleIndex] = riddles[riddles.length - 1];
        }
        riddles.pop();
    }

    function register() public view virtual override returns (IRegister) {
        return IRegister(registerAddress);
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

    /**
     * @dev Necessary override
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
    /**
     * @dev Necessary override
     */
    /**
     * @dev Necessary override
     */

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}
