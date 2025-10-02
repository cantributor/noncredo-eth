// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "./structs/Guess.sol";

import {IRegister} from "./interfaces/IRegister.sol";
import {IRiddle} from "./interfaces/IRiddle.sol";
import {IUser} from "./interfaces/IUser.sol";

import {Utils} from "./Utils.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Riddle
 * @dev Riddle
 */
contract Riddle is IRiddle, OwnableUpgradeable, ERC165, ERC2771ContextUpgradeable {
    string public statement;

    uint32 public id;
    uint32 public index;
    IUser public user;
    bool public revelation;
    bool public finished;

    uint256 public guessDeadline;
    uint256 public revealDeadline;

    Guess[] internal guesses;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        uint32 _id,
        uint32 _index,
        IUser _user,
        string calldata _statement,
        uint256 _encryptedCredo
    ) external payable override initializer {
        __Ownable_init(initialOwner);
        id = _id;
        index = _index;
        user = _user;
        statement = _statement;
        Guess memory ownerGuess = Guess(_user.owner(), _encryptedCredo, msg.value, false, false);
        guesses.push(ownerGuess);

        IRegister reg = user.register();
        guessDeadline = block.number + reg.guessDurationBlocks();
        revealDeadline = guessDeadline + reg.revealDurationBlocks();
        revelation = false;
        finished = false;
    }

    /**
     * @dev Throws if called by any account other than the Register contract remembered in User.registerAddress
     */
    modifier onlyForRegister() {
        if (msg.sender != user.registerAddress()) {
            revert IRegister.OnlyRegisterMayCallThis(msg.sender);
        }
        _;
    }

    function setIndex(uint32 _index) external virtual override onlyForRegister {
        index = _index;
    }

    function guess(uint256 encryptedCredo) external payable override returns (Guess memory _guess) {
        address msgSender = _msgSender();
        if (revelation) {
            revert RiddleAlreadyInRevelationState(id, address(this), msgSender);
        }
        IRegister register = user.register();
        if (register.paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
        if (register.riddles(index) != this) {
            revert RiddleIsNotRegistered(id, address(this), msgSender);
        }
        register.userOf(msgSender);
        (Guess memory foundGuess, uint256 guessIndex) = this.guessOf(msgSender);
        if (guessIndex < guesses.length) {
            revert GuessOfSenderAlreadyExists(id, foundGuess.account, guessIndex);
        }
        _guess = Guess(msgSender, encryptedCredo, msg.value, false, false);
        guesses.push(_guess);
        emit GuessRegistered(address(this), msgSender, id, encryptedCredo, msg.value);
        return _guess;
    }

    function guessOf(address sender)
        external
        view
        virtual
        override
        returns (Guess memory _guess, uint256 _guessIndex)
    {
        _guess = Guess(address(0), 0, 0, false, false);
        _guessIndex;
        for (_guessIndex = 0; _guessIndex < guesses.length; _guessIndex++) {
            if (guesses[_guessIndex].account == sender) {
                _guess = guesses[_guessIndex];
                break;
            }
        }
        return (_guess, _guessIndex);
    }

    function totalGuesses() external view virtual override returns (uint256) {
        return guesses.length;
    }

    function guessByIndex(uint256 _index) external view virtual override returns (Guess memory) {
        return guesses[_index];
    }

    function reveal(string calldata userSecretKey) external override returns (bool credo) {
        address msgSender = _msgSender();
        IRegister register = user.register();
        if (register.paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
        if (block.number <= guessDeadline) {
            revert GuessPeriodNotFinished(id, block.number, guessDeadline);
        }
        (Guess memory guessOfCaller, uint256 guessIndex) = this.guessOf(msgSender);
        if (guessIndex == guesses.length) {
            revert NothingToReveal(id, address(this), msgSender);
        }
        if (guessOfCaller.revealed) {
            revert RiddleAlreadyRevealedByCaller(id, address(this), msgSender);
        }
        guessOfCaller.credo = Utils.decryptCredo(this, guessOfCaller.encryptedCredo, userSecretKey);
        //        if (address(this).balance > 0) {
        //            shareBalance(false, credo);
        //        }
        guessOfCaller.revealed = true;
        guesses[guessIndex] = guessOfCaller;
        if (!revelation) {
            revelation = true;
        }
        emit GuessRevealed(address(this), msgSender, id, guessOfCaller.credo, guessOfCaller.bet);
        return credo;
    }

    /**
     * @dev Share the riddle reward amongst players
     * @param solution Riddle solution (true/false)
     */
    function shareBalance(bool rollback, bool solution) internal {
        IRegister register = user.register();
        uint256 winnerBetsSum = 0;
        for (uint32 i = 0; i < guesses.length; i++) {
            if (rollback || guesses[i].credo == solution) winnerBetsSum += guesses[i].bet;
        }
        uint256 prize = address(this).balance - winnerBetsSum;
        uint256 registerReward = prize * register.registerRewardPercent() / 100;
        uint256 riddlingReward = prize * register.riddlingRewardPercent() / 100;
        uint256 guessingReward = address(this).balance - registerReward - riddlingReward;
        bytes memory message = abi.encode(string.concat("For Riddle: ", Strings.toString(id)));
        if (winnerBetsSum > 0) {
            for (uint32 i = 0; i < guesses.length; i++) {
                if (rollback || guesses[i].credo == solution) {
                    if (guesses[i].bet > 0) {
                        uint256 thisAccountReward = guesses[i].bet * guessingReward / winnerBetsSum;
                        payReward(guesses[i].account, thisAccountReward, message);
                    }
                }
            }
        }
        if (riddlingReward > 0) {
            payReward(owner(), riddlingReward, message);
        }
        uint256 remainder = address(this).balance;
        if (remainder > 0) {
            payReward(payable(register), remainder, "");
        }
    }

    /**
     * @dev Pay reward
     * @param beneficiary Beneficiary address
     * @param amount Reward amount
     */
    function payReward(address beneficiary, uint256 amount, bytes memory message) internal {
        (bool success,) = beneficiary.call{value: amount}(message);
        if (success) {
            emit RewardPayed(payable(this), beneficiary, amount);
        } else {
            revert PaymentError(payable(this), id, beneficiary, amount);
        }
    }

    function finalize() external virtual override onlyForRegister {
        shareBalance(true, true);
        delete guesses;
        finished = true;
    }

    function remove() external virtual override onlyOwner {
        user.register().removeMe();
    }

    /**
     * @dev Implementation of ERC165
     * @param interfaceId Interface identifier
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRiddle).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Necessary override
     */
    function owner() public view virtual override(OwnableUpgradeable, IRiddle) returns (address) {
        return OwnableUpgradeable.owner();
    }

    /**
     * @dev To receive sponsor payments (no guess)
     */
    receive() external payable override {
        emit SponsorPaymentReceived(address(this), _msgSender(), id, msg.value);
    }

    /**
     * @dev Override of OwnableUpgradeable: throws if the sender is not the owner and not the master User contract
     */
    function _checkOwner() internal view virtual override {
        address msgSender = _msgSender();
        if (msgSender != owner() && msgSender != address(user)) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
