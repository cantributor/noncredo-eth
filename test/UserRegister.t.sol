// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {Roles} from "../src/Roles.sol";
import {User} from "../src/User.sol";
import {UserUtils} from "../src/UserUtils.sol";

import {IAccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {AccessManagerUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/manager/AccessManagerUpgradeable.sol";
import {ERC2771ForwarderUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/metatx/ERC2771ForwarderUpgradeable.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {Initializable} from
    "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UserFactoryTest is Test {
    AccessManagerUpgradeable public accessManagerUpgradeable;
    UserRegister public userRegister;
    TestERC2771Forwarder public testErc2771Forwarder;
    ERC1967Proxy erc1967Proxy;

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant OWNER = address(1);
    address private constant ADMIN = address(3);
    address private immutable USER = address(this);
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    UserRegister private userRegisterV2;

    function setUp() public {
        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(OWNER);

        testErc2771Forwarder = new TestERC2771Forwarder();
        testErc2771Forwarder.initialize("testForwarder");

        userRegister = new UserRegister(address(testErc2771Forwarder));

        erc1967Proxy = new ERC1967Proxy(
            address(userRegister), abi.encodeWithSignature("initialize(address)", accessManagerUpgradeable)
        );

        userRegisterV2 = new UserRegisterV2(address(testErc2771Forwarder));

        vm.startPrank(address(OWNER));

        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessManagerUpgradeable.setTargetFunctionRole(address(erc1967Proxy), userOfStringSelector, Roles.ADMIN_ROLE);

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessManagerUpgradeable.setTargetFunctionRole(address(erc1967Proxy), userOfAddressSelector, Roles.ADMIN_ROLE);

        bytes4[] memory upgradeToAndCallSelector = new bytes4[](1);
        upgradeToAndCallSelector[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), upgradeToAndCallSelector, Roles.ADMIN_ROLE
        );

        accessManagerUpgradeable.grantRole(Roles.ADMIN_ROLE, ADMIN, 0);

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

        vm.startPrank(address(ADMIN));

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

        vm.prank(address(ADMIN));

        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));
        assertEq("user", util_ResultAsUser(success, result).getNick());
    }

    function test_userOfString() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.prank(address(ADMIN));

        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "user"));
        assertEq("user", util_ResultAsUser(success, result).getNick());
    }

    function test_me() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("me()"));
        assertEq("user", util_ResultAsUser(success, result).getNick());
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

    function test_emit_SuccessfulUserRegistration() public {
        vm.expectEmit(true, true, false, false);

        emit UserRegister.SuccessfulUserRegistration(address(USER), "user");

        util_RegisterAccount(USER, "user");
    }

    function test_RevertWhen_TryingToReinitializeUser() public {
        util_RegisterAccount(USER, "user");

        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("me()"));
        User user = util_ResultAsUser(success, result);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        user.initialize(USER, ShortStrings.toShortString("hacker"));
    }

    function test_MetaTransaction() public {
        ERC2771ForwarderUpgradeable.ForwardRequestData memory request = ERC2771ForwarderUpgradeable.ForwardRequestData({
            from: SIGNER,
            to: address(erc1967Proxy),
            data: abi.encodeCall(UserRegister.registerUser, ("signer")),
            value: 0,
            gas: 1000000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with util_signRequestData
        });

        util_signRequestData(request, testErc2771Forwarder.nonces(SIGNER));

        testErc2771Forwarder.execute(request);

        vm.prank(address(ADMIN));
        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "signer"));
        assertEq("signer", util_ResultAsUser(success, result).getNick());
    }

    function test_Upgrade_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        util_upgradeToV2();
    }

    function test_Upgrade_RevertWhen_DirectUpgrade() public {
        vm.expectRevert(abi.encodeWithSelector(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector));
        userRegister.upgradeToAndCall(
            address(userRegisterV2), abi.encodeWithSignature("initialize(address)", accessManagerUpgradeable)
        );
    }

    function test_Upgrade_Successful() public {
        util_RegisterAccount(USER, "user");
        assertEq(util_getTotalUsers(), 1);

        vm.prank(ADMIN);
        util_upgradeToV2();
        assertEq(util_getTotalUsers(), 777);
    }

    function util_RegisterAccount(address account, string memory nick) private {
        vm.prank(account);
        (bool success,) = address(erc1967Proxy).call(abi.encodeWithSignature("registerUser(string)", nick));
        assertTrue(success);
    }

    function util_ResultAsUser(bool success, bytes memory result) private pure returns (User) {
        assertTrue(success);
        User user = abi.decode(result, (User));
        return user;
    }

    function util_getTotalUsers() private returns (uint256) {
        (bool success, bytes memory result) = address(erc1967Proxy).call(abi.encodeWithSignature("getTotalUsers()"));
        assertTrue(success);
        uint256 totalUsers = abi.decode(result, (uint256));
        return totalUsers;
    }

    function util_upgradeToV2() private {
        (bool success,) =
            address(erc1967Proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", userRegisterV2, ""));
        assertTrue(success);
    }

    function util_signRequestData(ERC2771ForwarderUpgradeable.ForwardRequestData memory request, uint256 nonce)
        private
        view
        returns (ERC2771ForwarderUpgradeable.ForwardRequestData memory)
    {
        bytes32 digest = testErc2771Forwarder.forwardRequestStructHash(request, nonce);
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

contract TestERC2771Forwarder is ERC2771ForwarderUpgradeable {
    constructor() ERC2771ForwarderUpgradeable() {}

    function forwardRequestStructHash(ERC2771ForwarderUpgradeable.ForwardRequestData calldata request, uint256 nonce)
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    nonce,
                    request.deadline,
                    keccak256(request.data)
                )
            )
        );
    }
}
