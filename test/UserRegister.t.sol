// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {Roles} from "../src/Roles.sol";
import {User} from "../src/User.sol";
import {UserUtils} from "../src/UserUtils.sol";
import {ERC2771Forwarder} from "../src/ERC2771Forwarder.sol";
import {AccessManagedBeaconHolder} from "../src/AccessManagedBeaconHolder.sol";

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {DeployScript} from "../script/Deploy.s.sol";

contract UserRegisterTest is Test {
    AccessManagerUpgradeable private accessManagerUpgradeable;
    UserRegister private userRegister;
    ERC2771Forwarder private erc2771Forwarder;
    ERC1967Proxy private erc1967Proxy;
    UserRegister private userRegisterProxy;

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private immutable USER = address(this);
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    UserRegister private userRegisterV2;
    User private userV2Impl;

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(SIGNER, "SIGNER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "USER_ADMIN");

        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(OWNER);

        erc2771Forwarder = new ERC2771Forwarder();
        erc2771Forwarder.initialize("erc2771Forwarder");

        AccessManagedBeaconHolder userBeacon = new AccessManagedBeaconHolder();
        userBeacon.initialize(
            address(accessManagerUpgradeable), new UpgradeableBeacon(address(new User()), address(userBeacon))
        );

        userRegister = new UserRegister(address(erc2771Forwarder));

        erc1967Proxy = new ERC1967Proxy(
            address(userRegister),
            abi.encodeCall(UserRegister.initialize, (address(accessManagerUpgradeable), userBeacon))
        );
        userRegisterProxy = UserRegister(address(erc1967Proxy));

        userRegisterV2 = new UserRegisterV2(address(erc2771Forwarder));
        userV2Impl = new UserV2();

        DeployScript deployScript = new DeployScript();
        deployScript.grantAccessToRoles(OWNER, accessManagerUpgradeable, address(erc1967Proxy), address(userBeacon));

        vm.startPrank(OWNER);

        accessManagerUpgradeable.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManagerUpgradeable.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_CallerIsNotAuthorized() public {
        bytes memory encodedUnauthorized =
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER);

        vm.expectRevert(encodedUnauthorized);
        userRegister.userOf(USER);

        vm.expectRevert(encodedUnauthorized);
        userRegister.userOf("user");

        vm.expectRevert(encodedUnauthorized);
        (bool s1,) = address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));
        assertTrue(s1);

        vm.expectRevert(encodedUnauthorized);
        (bool s2,) = address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "user"));
        assertTrue(s2);

        User userToRemove = userRegisterProxy.registerMeAs("user");
        vm.expectRevert(encodedUnauthorized);
        userRegisterProxy.remove(userToRemove);
    }

    function test_RevertWhen_NickTooShortOrTooLong() public {
        vm.expectRevert(abi.encodeWithSelector(UserUtils.NickTooShort.selector, "al", 2, 3));
        util_RegisterAccount(USER, "al");

        vm.expectRevert(
            abi.encodeWithSelector(UserUtils.NickTooLong.selector, "ab123456789012345678901234567890", 32, 31)
        );
        util_RegisterAccount(USER, "ab123456789012345678901234567890");

        // ok nick length
        util_RegisterAccount(USER, "a123456789012345678901234567890");
    }

    function test_RevertWhen_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountNotRegistered.selector, USER));
        (bool s1,) = address(erc1967Proxy).call(abi.encodeWithSignature("me()"));
        assertTrue(s1);

        vm.startPrank(address(USER_ADMIN));

        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountNotRegistered.selector, USER));
        (bool s2,) = address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));
        assertTrue(s2);

        vm.expectRevert(abi.encodeWithSelector(UserRegister.NickNotRegistered.selector, "user"));
        (bool s3,) = address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "user"));
        assertTrue(s3);

        vm.stopPrank();
    }

    function test_userOfAddress() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.prank(address(USER_ADMIN));

        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));
        User user = util_ResultAsUser(success, result);
        assertEq("user", user.getNick());
        assertEq(0, user.getIndex());
    }

    function test_userOfString() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq("user", util_UserOf("user").getNick());
        assertEq(0, util_UserOf("user").getIndex());
        assertEq("owner", util_UserOf("owner").getNick());
        assertEq(1, util_UserOf("owner").getIndex());
    }

    function test_me() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("me()"));
        assertEq("user", util_ResultAsUser(success, result).getNick());

        User user = userRegisterProxy.me();
        assertEq("user", user.getNick());
    }

    function test_getTotalUsers() public {
        assertEq(util_getTotalUsers(), 0);

        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq(util_getTotalUsers(), 2);
    }

    function test_getAllNicks() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";

        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("getAllNicks()"));
        assertTrue(success);
        string[] memory allNicksResult = abi.decode(result, (string[]));
        assertEq(expectedNicks, allNicksResult);
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.expectRevert(abi.encodeWithSelector(UserRegister.NickAlreadyRegistered.selector, "user"));
        util_RegisterAccount(USER, "user");

        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountAlreadyRegistered.selector, USER));
        util_RegisterAccount(USER, "user2");
    }

    function test_emit_UserRegistered() public {
        vm.expectEmit(true, true, false, false);

        emit UserRegister.UserRegistered(address(USER), "user");

        User user = util_RegisterAccount(USER, "user");

        assertEq("user", user.getNick());
        assertEq(0, user.getIndex());
    }

    function test_RevertWhen_TryingToReinitializeUser() public {
        util_RegisterAccount(USER, "user");

        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("me()"));
        User user = util_ResultAsUser(success, result);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        user.initialize(USER, ShortStrings.toShortString("hacker"), 666, address(userRegister));
    }

    function test_remove() public {
        vm.prank(address(101));
        User user1 = userRegisterProxy.registerMeAs("user1");
        vm.prank(address(102));
        User user2 = userRegisterProxy.registerMeAs("user2");
        vm.prank(address(103));
        User user3 = userRegisterProxy.registerMeAs("user3");

        assertEq(3, userRegisterProxy.getTotalUsers());

        assertEq(address(user1), address(util_UserOf("user1")));
        assertEq(0, util_UserOf("user1").getIndex());

        assertEq(address(user2), address(util_UserOf("user2")));
        assertEq(1, util_UserOf("user2").getIndex());
        assertEq(1, user2.getIndex());

        assertEq(address(user3), address(util_UserOf("user3")));
        assertEq(2, util_UserOf("user3").getIndex());

        vm.expectEmit(true, true, false, false);
        emit UserRegister.UserRemoved(address(102), "user2");

        vm.prank(USER_ADMIN);
        userRegisterProxy.remove(user2);

        assertEq(2, userRegisterProxy.getTotalUsers());

        vm.prank(USER_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountNotRegistered.selector, address(102)));
        userRegisterProxy.userOf(address(102));

        vm.prank(USER_ADMIN);
        vm.expectRevert(abi.encodeWithSelector(UserRegister.NickNotRegistered.selector, "user2"));
        userRegisterProxy.userOf("user2");

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user1";
        expectedNicks[1] = "user3";

        string[] memory allNicksResult = userRegisterProxy.getAllNicks();
        assertEq(expectedNicks, allNicksResult);

        assertEq(0, util_UserOf("user1").getIndex());
        assertEq(1, util_UserOf("user3").getIndex());
    }

    function test_MetaTransaction() public {
        ERC2771ForwarderUpgradeable.ForwardRequestData memory request = ERC2771ForwarderUpgradeable.ForwardRequestData({
            from: SIGNER,
            to: address(erc1967Proxy),
            data: abi.encodeCall(UserRegister.registerMeAs, ("signer")),
            value: 0,
            gas: 1000000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with util_signRequestData
        });

        util_signRequestData(request, erc2771Forwarder.nonces(SIGNER));

        erc2771Forwarder.execute(request);

        vm.prank(address(USER_ADMIN));
        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "signer"));
        User user = util_ResultAsUser(success, result);
        assertEq("signer", user.getNick());
        assertEq(0, user.getIndex());
    }

    function test_Upgrade_UserRegister_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        util_upgradeUserRegisterToV2();
    }

    function test_Upgrade_UserRegister_RevertWhen_DirectUpgrade() public {
        vm.expectRevert(abi.encodeWithSelector(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector));
        userRegister.upgradeToAndCall(
            address(userRegisterV2), abi.encodeWithSignature("initialize(address)", accessManagerUpgradeable)
        );
    }

    function test_Upgrade_UserRegister_Successful() public {
        util_RegisterAccount(USER, "user");
        assertEq(util_getTotalUsers(), 1);

        vm.prank(UPGRADE_ADMIN);
        util_upgradeUserRegisterToV2();
        assertEq(util_getTotalUsers(), 777);
    }

    function test_Upgrade_User_RevertWhen_CallerIsNotAuthorized() public {
        AccessManagedBeaconHolder userBeacon = userRegisterProxy.userBeacon();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        userBeacon.upgradeTo(address(userV2Impl));
    }

    function test_Upgrade_User_Successful() public {
        console.log(string.concat("abc", "123"));

        util_RegisterAccount(USER, "user");
        User user = util_UserOf("user");
        assertEq("user", user.getNick());

        vm.startPrank(UPGRADE_ADMIN);
        userRegisterProxy.userBeacon().upgradeTo(address(userV2Impl));
        vm.stopPrank();

        util_RegisterAccount(OWNER, "owner");

        assertEq("user_", user.getNick());
        assertEq("owner_", util_UserOf("owner").getNick());

        UserV2 userV2 = UserV2(address(util_UserOf("user")));
        userV2.setSuffix("V2");
        assertEq("user_V2", user.getNick());
    }

    function util_RegisterAccount(address account, string memory nick) private returns (User user) {
        vm.prank(account);
        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("registerMeAs(string)", nick));
        return util_ResultAsUser(success, result);
    }

    function util_ResultAsUser(bool success, bytes memory result) private pure returns (User) {
        assertTrue(success);
        User user = abi.decode(result, (User));
        return user;
    }

    function util_UserOf(string memory nick) private returns (User) {
        vm.prank(address(USER_ADMIN));

        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", nick));
        return util_ResultAsUser(success, result);
    }

    function util_getTotalUsers() private returns (uint256) {
        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("getTotalUsers()"));
        assertTrue(success);
        uint256 totalUsers = abi.decode(result, (uint256));
        return totalUsers;
    }

    function util_upgradeUserRegisterToV2() private {
        (bool success,) =
            address(erc1967Proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", userRegisterV2, ""));
        assertTrue(success);
    }

    function util_signRequestData(ERC2771ForwarderUpgradeable.ForwardRequestData memory request, uint256 nonce)
        private
        view
        returns (ERC2771ForwarderUpgradeable.ForwardRequestData memory)
    {
        bytes32 digest = erc2771Forwarder.forwardRequestStructHash(request, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        request.signature = abi.encodePacked(r, s, v);
        return request;
    }
}

contract UserRegisterV2 is UserRegister {
    constructor(address trustedForwarder) UserRegister(trustedForwarder) {}

    function getTotalUsers() external pure override returns (uint256) {
        return 777;
    }
}

contract UserV2 is User {
    string private suffix = "V2";

    function getNick() public view override returns (string memory) {
        return string.concat(super.getNick(), "_", suffix);
    }

    function setSuffix(string calldata _suffix) external {
        suffix = _suffix;
    }
}
