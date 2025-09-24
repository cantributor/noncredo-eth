// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {IUser} from "./interfaces/IUser.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";

import {AccessManagedBeaconHolder} from "./AccessManagedBeaconHolder.sol";
import {Register} from "./Register.sol";
import {Riddle} from "./Riddle.sol";
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

    Riddle[] public riddles;

    /**
     * @dev User successfully registered
     * @param owner User owner address
     * @param nick User nick
     */
    event UserRegistered(address indexed owner, string indexed nick);

    /**
     * @dev User successfully removed
     * @param owner User owner address
     * @param nick User nick
     * @param remover Who removed
     */
    event UserRemoved(address indexed owner, string indexed nick, address indexed remover);

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
    function initialize(address initialOwner, ShortString _nick, uint32 _index, address payable _registerAddress)
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
            revert Register.OnlyRegisterMayCallThis(msg.sender);
        }
        _;
    }

    /**
     * @dev Commit new Riddle contract
     * @param statement Riddle statement
     * @param encryptedSolution Encrypted solution
     */
    function commit(string calldata statement, uint256 encryptedSolution)
        external
        virtual
        override
        onlyOwner
        returns (Riddle riddle)
    {
        Utils.validateRiddle(statement);
        Register reg = this.register();
        AccessManagedBeaconHolder riddleBeaconHolder = reg.riddleBeaconHolder();
        BeaconProxy riddleBeaconProxy = new BeaconProxy(
            address(riddleBeaconHolder.beacon()),
            abi.encodeCall(
                Riddle.initialize, (owner(), reg.nextRiddleId(), reg.totalRiddles(), this, statement, encryptedSolution)
            )
        );
        riddle = Riddle(payable(riddleBeaconProxy));
        riddles.push(riddle);
        reg.registerRiddle(riddle);
        return riddle;
    }

    /**
     * @dev Get number of active user riddles
     * @return number of active user riddles
     */
    function totalRiddles() external view virtual override returns (uint32) {
        return uint32(riddles.length);
    }

    /**
     * @dev Find riddle index in riddles array
     * @param riddle Riddle to find
     * @return riddleIndex Riddle index in riddles array
     */
    function indexOf(Riddle riddle) external view virtual override returns (int256 riddleIndex) {
        riddleIndex = -1;
        for (uint256 i = 0; i < riddles.length; i++) {
            if (riddles[i] == riddle) {
                riddleIndex = int256(i);
                break;
            }
        }
        return riddleIndex;
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
        for (int256 i = int256(riddles.length) - 1; i >= 0; i--) {
            riddles[uint256(i)].remove();
        }
    }

    /**
     * @dev Remove this contract from Register (should be implemented with onlyOwner modifier)
     */
    function remove() external virtual override onlyOwner {
        register().removeMe();
    }

    /**
     * @dev Remove riddle
     * @param riddle Riddle to remove
     */
    function remove(Riddle riddle) external virtual onlyForRegister {
        int256 foundRiddleIndex = this.indexOf(riddle);
        if (foundRiddleIndex < 0) {
            revert Riddle.RiddleIsNotRegistered(riddle.id(), address(riddle), _msgSender());
        }
        uint256 riddleIndex = uint256(foundRiddleIndex);
        riddles[riddleIndex] = riddles[riddles.length - 1];
        riddles.pop();
    }

    /**
     * @dev Conversion of registerAddress to Register contract
     * @return Register contract
     */
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
}
