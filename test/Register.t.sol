// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IRiddle} from "../src/interfaces/IRiddle.sol";
import {IUser} from "../src/interfaces/IUser.sol";

import {Payment} from "../src/structs/Payment.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";
import {Roles} from "src/Roles.sol";
import {Utils} from "src/Utils.sol";

import {RegisterV2} from "./upgrades/RegisterV2.sol";

import {FakeUser} from "./fakes/FakeUser.sol";

import {MetaTxUtils} from "./utils/MetaTxUtils.sol";

import {DeployScript} from "../script/Deploy.s.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RegisterTest is Test {
    IAccessManager private accessManager;
    ERC2771Forwarder private erc2771Forwarder;
    IRegister private registerImpl;
    IRegister private registerProxy;
    AccessManagedBeaconHolder private userBeaconHolder;
    AccessManagedBeaconHolder private riddleBeaconHolder;

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private constant FINANCE_ADMIN = address(0xC);
    address private constant BAD_GUY = address(0xF);
    address payable private immutable USER = payable(address(this));
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    IRegister private registerV2;

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(SIGNER, "SIGNER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "USER_ADMIN");
        vm.label(FINANCE_ADMIN, "FINANCE_ADMIN");
        vm.label(BAD_GUY, "BAD_GUY");

        DeployScript deployScript = new DeployScript();
        (accessManager, erc2771Forwarder, registerImpl, registerProxy, userBeaconHolder, riddleBeaconHolder) =
            deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(
            OWNER, accessManager, address(registerProxy), address(userBeaconHolder), address(riddleBeaconHolder)
        );

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);
        accessManager.grantRole(Roles.FINANCE_ADMIN_ROLE, FINANCE_ADMIN, 0);
        vm.stopPrank();

        registerV2 = new RegisterV2(address(erc2771Forwarder));
    }

    function test_RevertWhen_CallerIsNotAuthorized() public {
        bytes memory encodedUnauthorized =
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER);

        IUser userToRemove = registerProxy.registerMeAs("user");
        vm.expectRevert(encodedUnauthorized);
        registerProxy.remove(address(userToRemove));

        vm.expectRevert(encodedUnauthorized);
        registerProxy.upgradeToAndCall(address(registerV2), "");

        vm.expectRevert(encodedUnauthorized);
        registerProxy.setGuessAndRevealDuration(1, 1);

        vm.expectRevert(encodedUnauthorized);
        registerProxy.setRegisterAndRiddlingRewards(0, 0);

        vm.expectRevert(encodedUnauthorized);
        registerProxy.pause();

        vm.expectRevert(encodedUnauthorized);
        registerProxy.resume();

        vm.expectRevert(encodedUnauthorized);
        registerProxy.withdraw(USER);
    }

    function test_RevertWhen_OnPause() public {
        vm.prank(OWNER);
        IUser owner = registerProxy.registerMeAs("owner");

        vm.prank(USER_ADMIN);
        registerProxy.pause();

        bytes memory encodedEnforcedPause = abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector);

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.registerMeAs("user");

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.remove(address(owner));

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.setRegisterAndRiddlingRewards(0, 0);

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.setGuessAndRevealDuration(0, 0);

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.nextRiddleId();

        vm.expectRevert(encodedEnforcedPause);
        registerProxy.withdraw(USER);
    }

    function test_resume_Successful() public {
        vm.prank(USER_ADMIN);
        registerProxy.pause();

        vm.prank(USER_ADMIN);
        registerProxy.resume();

        registerProxy.registerMeAs("user");
    }

    function test_RevertWhen_NickTooShortOrTooLong() public {
        vm.expectRevert(abi.encodeWithSelector(Utils.NickTooShort.selector, "al", 2, 3));
        util_RegisterAccount(USER, "al");

        vm.expectRevert(abi.encodeWithSelector(Utils.NickTooLong.selector, "ab123456789012345678901234567890", 32, 31));
        util_RegisterAccount(USER, "ab123456789012345678901234567890");

        // ok nick length
        util_RegisterAccount(USER, "a123456789012345678901234567890");
    }

    function test_RevertWhen_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(IRegister.AccountNotRegistered.selector, USER));
        (bool s1,) = address(registerProxy).call(abi.encodeWithSignature("me()"));
        assertTrue(s1);

        vm.startPrank(address(USER_ADMIN));

        vm.expectRevert(abi.encodeWithSelector(IRegister.AccountNotRegistered.selector, USER));
        (bool s2,) = address(registerProxy).call(abi.encodeWithSignature("userOf(address)", USER));
        assertTrue(s2);

        vm.expectRevert(abi.encodeWithSelector(IRegister.NickNotRegistered.selector, "user"));
        (bool s3,) = address(registerProxy).call(abi.encodeWithSignature("userOf(string)", "user"));
        assertTrue(s3);

        vm.stopPrank();
    }

    function test_userOfAddress() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        (bool success, bytes memory result) =
            address(registerProxy).call(abi.encodeWithSignature("userOf(address)", USER));
        IUser user = util_ResultAsUser(success, result);
        assertEq("user", user.nickString());
        assertEq(0, user.index());
    }

    function test_userOfString() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq("user", util_UserOf("user").nickString());
        assertEq(0, util_UserOf("user").index());
        assertEq("owner", util_UserOf("owner").nickString());
        assertEq(1, util_UserOf("owner").index());
    }

    function test_me() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        (bool success, bytes memory result) = address(registerProxy).call(abi.encodeWithSignature("me()"));
        assertEq("user", util_ResultAsUser(success, result).nickString());

        IUser user = registerProxy.me();
        assertEq("user", user.nickString());
    }

    function test_totalUsers() public {
        assertEq(util_getTotalUsers(), 0);

        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq(util_getTotalUsers(), 2);
    }

    function test_allNicks() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";

        (bool success, bytes memory result) = address(registerProxy).call(abi.encodeWithSignature("allNicks()"));
        assertTrue(success);
        string[] memory allNicksResult = abi.decode(result, (string[]));
        assertEq(expectedNicks, allNicksResult);
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.expectRevert(abi.encodeWithSelector(IRegister.NickAlreadyRegistered.selector, "user"));
        util_RegisterAccount(USER, "user");

        vm.expectRevert(abi.encodeWithSelector(IRegister.AccountAlreadyRegistered.selector, USER));
        util_RegisterAccount(USER, "user2");
    }

    function test_registerMeAs_Successful() public {
        vm.expectEmit(true, true, false, false);
        emit IUser.UserRegistered(address(USER), "user");

        IUser user = registerProxy.registerMeAs("user");

        assertEq("user", user.nickString());
        assertEq(0, user.index());
        assertEq(USER, user.owner());
        assertEq(address(registerProxy), user.registerAddress());
        assertEq(address(user), address(registerProxy.users(0)));
    }

    function test_RevertWhen_TryingToReinitializeUser() public {
        util_RegisterAccount(USER, "user");

        (bool success, bytes memory result) = address(registerProxy).call(abi.encodeWithSignature("me()"));
        IUser user = util_ResultAsUser(success, result);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        user.initialize(USER, ShortStrings.toShortString("hacker"), 666, payable(registerImpl));
    }

    function test_removeUser() public {
        IUser user1 = util_RegisterAccount(address(101), "user1");
        IUser user2 = util_RegisterAccount(address(102), "user2");
        IUser user3 = util_RegisterAccount(address(103), "user3");

        assertEq(3, registerProxy.totalUsers());

        assertEq(address(user1), address(util_UserOf("user1")));
        assertEq(0, util_UserOf("user1").index());

        assertEq(address(user2), address(util_UserOf("user2")));
        assertEq(1, util_UserOf("user2").index());
        assertEq(1, user2.index());

        assertEq(address(user3), address(util_UserOf("user3")));
        assertEq(2, util_UserOf("user3").index());

        vm.expectEmit(true, true, true, false);
        emit IUser.UserRemoved(address(102), "user2", USER_ADMIN);

        vm.prank(USER_ADMIN, USER_ADMIN);
        registerProxy.remove(address(user2));

        assertEq(2, registerProxy.totalUsers());

        vm.expectRevert(abi.encodeWithSelector(IRegister.AccountNotRegistered.selector, address(102)));
        registerProxy.userOf(address(102));

        vm.expectRevert(abi.encodeWithSelector(IRegister.NickNotRegistered.selector, "user2"));
        registerProxy.userOf("user2");

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user1";
        expectedNicks[1] = "user3";

        string[] memory allNicksResult = registerProxy.allNicks();
        assertEq(expectedNicks, allNicksResult);

        assertEq(0, util_UserOf("user1").index());
        assertEq(1, util_UserOf("user3").index());
    }

    function test_removeRiddle() public {
        IUser user = registerProxy.registerMeAs("user");
        IRiddle riddle1 = user.commit("I am superman #1!", 101);
        IRiddle riddle2 = user.commit("I am superman #2!", 101);
        IRiddle riddle3 = user.commit("I am superman #3!", 101);

        assertEq(3, registerProxy.totalRiddles());
        assertEq(3, user.totalRiddles());
        assertEq(0, riddle1.index());
        assertEq(1, riddle2.index());
        assertEq(2, riddle3.index());

        vm.expectEmit(true, true, false, true);
        emit IRiddle.RiddleRemoved(address(user), address(riddle2), 2);
        vm.prank(USER_ADMIN);
        registerProxy.remove(address(riddle2));

        assertEq(2, registerProxy.totalRiddles());
        assertEq(2, user.totalRiddles());

        assertEq(0, riddle1.index());
        assertEq(1, riddle2.index());
        assertEq(1, riddle3.index());
        assertEq(address(riddle3), address(registerProxy.riddles(1)));

        // below commit is possible because Register.riddleByStatement cleaned from riddle2.statement
        user.commit(riddle2.statement(), 101);
    }

    function test_removeMe_RevertWhen_IllegalCaller() public {
        registerProxy.registerMeAs("user");

        vm.expectRevert(abi.encodeWithSelector(IRegister.IllegalActionCall.selector, "remove", USER, USER, OWNER));
        vm.prank(USER, OWNER);
        registerProxy.removeMe();
    }

    function test_removeMe_RevertWhen_FakeUser() public {
        IUser user = registerProxy.registerMeAs("user"); // owner: USER
        console.log("User owner:", user.owner());
        assertEq(1, registerProxy.totalUsers());

        vm.startPrank(BAD_GUY, BAD_GUY);
        FakeUser fakeUser = new FakeUser(user.owner(), user.nick(), user.index(), payable(registerProxy));
        console.log("Fake user owner:", fakeUser.owner());

        vm.expectRevert(
            abi.encodeWithSelector(
                IRegister.IllegalActionCall.selector, "remove", address(fakeUser), address(fakeUser), BAD_GUY
            )
        );
        fakeUser.remove();

        vm.stopPrank();

        assertEq(1, registerProxy.totalUsers());
    }

    function test_withdraw_RevertWhen_RegisterBalanceIsEmpty() public {
        vm.prank(FINANCE_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(IRegister.RegisterBalanceIsEmpty.selector, USER));

        registerProxy.withdraw(USER);
    }

    function test_receive_withdraw_Successful() public {
        uint256 initialBalance = USER.balance;
        assertEq(0, payable(registerProxy).balance);
        assertEq(0, registerProxy.paymentsArray().length);

        vm.expectEmit(true, true, false, true);
        emit IRegister.PaymentReceived(USER, 0, 1000);
        (bool success,) = payable(registerProxy).call{value: 1000}("");
        assertTrue(success);

        assertEq(1000, payable(registerProxy).balance);
        assertEq(initialBalance - 1000, USER.balance);
        Payment[] memory payments = registerProxy.paymentsArray();
        assertEq(1, payments.length);
        assertEq(1000, payments[0].amount);
        assertEq(0, payments[0].riddleId);
        assertEq(USER, payments[0].payer);

        vm.prank(FINANCE_ADMIN);
        vm.expectEmit(true, true, false, true);
        emit IRegister.Withdrawal(USER, FINANCE_ADMIN, 1000);
        registerProxy.withdraw(USER);

        assertEq(0, payable(registerProxy).balance);
        assertEq(0, registerProxy.paymentsArray().length);
        assertEq(0, FINANCE_ADMIN.balance);
        assertEq(initialBalance, USER.balance);
    }

    function test_MetaTransaction() public {
        ERC2771ForwarderUpgradeable.ForwardRequestData memory request = ERC2771ForwarderUpgradeable.ForwardRequestData({
            from: SIGNER,
            to: address(registerProxy),
            data: abi.encodeCall(IRegister.registerMeAs, ("signer")),
            value: 0,
            gas: 1000000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with signRequestData
        });

        request = MetaTxUtils.signRequestData(
            erc2771Forwarder, request, vm, SIGNER_PRIVATE_KEY, erc2771Forwarder.nonces(SIGNER)
        );

        erc2771Forwarder.execute(request);

        (bool success, bytes memory result) =
            address(registerProxy).call(abi.encodeWithSignature("userOf(string)", "signer"));
        IUser user = util_ResultAsUser(success, result);
        assertEq("signer", user.nickString());
        assertEq(0, user.index());
    }

    function test_Upgrade_RevertWhen_DirectUpgrade() public {
        vm.expectRevert(abi.encodeWithSelector(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector));
        registerImpl.upgradeToAndCall(
            address(registerV2),
            abi.encodeCall(IRegister.initialize, (address(accessManager), userBeaconHolder, riddleBeaconHolder))
        );
    }

    function test_Upgrade_Successful() public {
        util_RegisterAccount(USER, "user");
        assertEq(util_getTotalUsers(), 1);

        vm.prank(UPGRADE_ADMIN);
        registerProxy.upgradeToAndCall(address(registerV2), "");
        assertEq(util_getTotalUsers(), 777);
    }

    function util_RegisterAccount(address account, string memory nick) private returns (IUser user) {
        vm.prank(account);
        (bool success, bytes memory result) = address(registerProxy).call(abi.encodeCall(IRegister.registerMeAs, nick));
        return util_ResultAsUser(success, result);
    }

    function util_ResultAsUser(bool success, bytes memory result) private pure returns (IUser) {
        assertTrue(success);
        IUser user = abi.decode(result, (IUser));
        return user;
    }

    function util_UserOf(string memory nick) private returns (IUser) {
        (bool success, bytes memory result) =
            address(registerProxy).call(abi.encodeWithSignature("userOf(string)", nick));
        return util_ResultAsUser(success, result);
    }

    function util_getTotalUsers() private returns (uint256) {
        (bool success, bytes memory result) = address(registerProxy).call(abi.encodeWithSignature("totalUsers()"));
        assertTrue(success);
        uint256 totalUsers = abi.decode(result, (uint256));
        return totalUsers;
    }

    receive() external payable {
        console.log("RegisterTest received payment:", msg.value);
    }
}
