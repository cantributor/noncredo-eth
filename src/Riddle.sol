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

    uint40 public guessDeadline;
    uint40 public revealDeadline;

    int16 public rating;

    address[] public dislikers;

    Guess[] public guesses;

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
        Guess memory ownerGuess = Guess({
            account: _user.owner(), encryptedCredo: _encryptedCredo, bet: msg.value, revealed: false, credo: false
        });
        guesses.push(ownerGuess);

        IRegister reg = user.register();
        guessDeadline = uint40(block.number) + reg.guessDurationBlocks();
        revealDeadline = guessDeadline + reg.revealDurationBlocks();
        revelation = false;
        finished = false;
        rating = 0;
    }

    /**
     * @dev Throws if called by any account other than the Register contract remembered in User.registerAddress
     */
    modifier onlyForRegister() {
        _onlyForRegister();
        _;
    }

    function _onlyForRegister() internal view {
        if (_msgSender() != user.registerAddress()) {
            revert IRegister.OnlyRegisterMayCallThis(_msgSender());
        }
    }

    /**
     * @dev Throws if Riddle in "finished" state
     */
    modifier notFinished() {
        _notFinished();
        _;
    }

    function _notFinished() internal view {
        if (finished) {
            revert RiddleIsFinished(id, address(this), _msgSender());
        }
    }

    function setIndex(uint32 _index) external virtual override onlyForRegister {
        index = _index;
    }

    function guess(uint256 encryptedCredo) external payable override notFinished returns (Guess memory _guess) {
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
        _guess =
            Guess({account: msgSender, encryptedCredo: encryptedCredo, bet: msg.value, revealed: false, credo: false});
        guesses.push(_guess);
        if (rating < type(int16).max) {
            rating++;
            user.praise();
        }
        emit GuessRegistered(address(this), msgSender, id, encryptedCredo, msg.value, rating);
        return _guess;
    }

    function guessOf(address sender) external view virtual override returns (Guess memory _guess, uint256 _guessIndex) {
        _guess = Guess({account: address(0), encryptedCredo: 0, bet: 0, revealed: false, credo: false});
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

    function reveal(string calldata userSecretKey) external override notFinished returns (bool credo) {
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
        guessOfCaller.revealed = true;
        guesses[guessIndex] = guessOfCaller;
        if (!revelation) {
            revelation = true;
        }
        emit GuessRevealed(address(this), msgSender, id, guessOfCaller.credo, guessOfCaller.bet);
        if (allGuessesRevealed()) {
            register.removeMe();
        }
        return credo;
    }

    /**
     * @dev Are all riddle guesses revealed?
     * @return result True if all guesses are revealed, false otherwise
     */
    function allGuessesRevealed() internal view returns (bool result) {
        result = true;
        for (uint32 i = 0; i < guesses.length; i++) {
            result = result && guesses[i].revealed;
        }
    }

    /**
     * @dev Determine result of riddle guessing
     * @return determined Riddle solution (Credo/NonCredo) is determined by voting
     * @return credo Riddle solution (Credo/NonCredo)
     */
    function poll() internal view returns (bool determined, bool credo) {
        uint32 credos = 0;
        uint32 noncredos = 0;
        for (uint32 i = 0; i < guesses.length; i++) {
            if (guesses[i].revealed) {
                if (guesses[i].credo) {
                    credos++;
                } else {
                    noncredos++;
                }
            }
        }
        return (credos != noncredos, credos > noncredos);
    }

    /**
     * @dev Calculate financial result of riddle guessing
     * @param determined Is riddle solution (Credo/NonCredo) determined by voting?
     * @param credo Riddle solution (Credo/NonCredo)
     * @return winnerBetsSum Sum of winners' bets
     * @return prize Sum to be shared amongst winners (includes losers' bets and sponsor payments)
     */
    function calculate(bool determined, bool credo) internal view returns (uint256 winnerBetsSum, uint256 prize) {
        winnerBetsSum = 0;
        uint256 loserBetsSum = 0;
        uint256 refunds = address(this).balance;
        if (determined) {
            refunds = 0;
            for (uint32 i = 0; i < guesses.length; i++) {
                if (guesses[i].revealed) {
                    if (guesses[i].credo == credo) winnerBetsSum += guesses[i].bet;
                    else loserBetsSum += guesses[i].bet;
                } else {
                    refunds += guesses[i].bet;
                }
            }
        }
        uint256 registerReward = loserBetsSum * user.register().registerRewardPercent() / 100;
        prize = address(this).balance - registerReward - winnerBetsSum - refunds;
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

    /**
     * @dev Share the riddle balance amongst players, clear guesses array and mark riddle as finished
     */
    function goodbye() external virtual override onlyForRegister {
        (bool determined, bool credo) = (false, false);
        if (block.number > revealDeadline || allGuessesRevealed()) {
            (determined, credo) = poll();
        }
        (uint256 winnerBetsSum, uint256 prize) = calculate(determined, credo);
        bytes memory message = abi.encode(string.concat("Riddle: ", Strings.toString(id)));
        for (uint32 i = 0; i < guesses.length; i++) {
            if (guesses[i].bet > 0) {
                if (determined) {
                    if (guesses[i].revealed) {
                        if (guesses[i].credo == credo) {
                            uint256 thisAccountReward = guesses[i].bet + (guesses[i].bet * prize / winnerBetsSum);
                            payReward(guesses[i].account, thisAccountReward, message);
                        }
                    } else {
                        payReward(guesses[i].account, guesses[i].bet, message);
                    }
                } else {
                    payReward(guesses[i].account, guesses[i].bet, message);
                }
            }
        }
        uint256 remainder = address(this).balance;
        if (remainder > 0) {
            payReward(payable(user.register()), remainder, "");
        }
        delete guesses;
        delete dislikers;
        finished = true;
    }

    function remove() external virtual override onlyOwner notFinished {
        user.register().removeMe();
    }

    function finalize() external virtual override notFinished {
        IRegister register = user.register();
        if (register.paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
        register.userOf(_msgSender());
        if (block.number <= revealDeadline) {
            revert RevelationPeriodNotFinished(id, block.number, revealDeadline);
        }
        register.removeMe();
    }

    function dislike() external virtual override notFinished {
        address msgSender = _msgSender();
        IRegister register = user.register();
        register.userOf(msgSender);
        bool found = false;
        for (uint256 i = 0; i < dislikers.length; i++) {
            if (dislikers[i] == msgSender) {
                found = true;
                break;
            }
        }
        if (found) {
            revert DuplicateDislike(address(this), id, msgSender);
        }
        dislikers.push(msgSender);
        rating--;
        user.scold();
        emit RiddleDislike(address(this), msgSender, id, rating);
        int16 riddleBanThreshold = -int16(uint16(register.riddleBanThreshold()));
        if (rating <= riddleBanThreshold) {
            register.removeMe();
        }
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
    receive() external payable override notFinished {
        if (_msgSender() == address(user)) {
            guesses[0].bet = msg.value;
        } else {
            emit SponsorPaymentReceived(address(this), _msgSender(), id, msg.value);
        }
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
