// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Register} from "src/Register.sol";
import {Riddle} from "src/Riddle.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployScript is Script {
    IAccessManager private accessManager;
    ERC2771Forwarder private erc2771Forwarder;
    Register private registerImpl;
    Register private registerProxy;
    AccessManagedBeaconHolder private userBeaconHolder;
    AccessManagedBeaconHolder private riddleBeaconHolder;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        (accessManager, erc2771Forwarder, registerImpl, registerProxy, userBeaconHolder, riddleBeaconHolder) =
            createContracts(msg.sender);

        console.log("AccessManager address:", address(accessManager));
        console.log("ERC2771Forwarder address:", address(erc2771Forwarder));
        console.log("Beacon holder address for User contract:", address(userBeaconHolder));
        console.log("Beacon holder address for Riddle contract:", address(riddleBeaconHolder));
        console.log("Register implementation address:", address(registerImpl));
        console.log("Register proxy address:", address(registerProxy));

        grantAccessToRoles(
            address(0), accessManager, address(registerProxy), address(userBeaconHolder), address(riddleBeaconHolder)
        );

        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, msg.sender, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, msg.sender, 0);
        accessManager.grantRole(Roles.FINANCE_ADMIN_ROLE, msg.sender, 0);
        console.log("UPGRADE_ADMIN_ROLE & USER_ADMIN_ROLE & FINANCE_ADMIN_ROLE granted to:", msg.sender);

        vm.stopBroadcast();
    }

    function createContracts(address owner)
        public
        returns (
            IAccessManager,
            ERC2771Forwarder resultErc2771Forwarder,
            Register resultRegisterImpl,
            Register resultRegisterProxy,
            AccessManagedBeaconHolder resultAccessManagedUserBeaconHolder,
            AccessManagedBeaconHolder resultAccessManagedRiddleBeaconHolder
        )
    {
        AccessManagerUpgradeable accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(owner);

        resultErc2771Forwarder = new ERC2771Forwarder();
        resultErc2771Forwarder.initialize("erc2771Forwarder");

        resultAccessManagedUserBeaconHolder = new AccessManagedBeaconHolder(address(accessManagerUpgradeable));
        address userUpgradeableBeaconAddress = UnsafeUpgrades.deployBeacon(
            address(new User(address(resultErc2771Forwarder))), address(resultAccessManagedUserBeaconHolder)
        );
        UpgradeableBeacon userUpgradeableBeacon = UpgradeableBeacon(userUpgradeableBeaconAddress);
        resultAccessManagedUserBeaconHolder.initialize(userUpgradeableBeacon);

        resultAccessManagedRiddleBeaconHolder = new AccessManagedBeaconHolder(address(accessManagerUpgradeable));
        address riddleUpgradeableBeaconAddress = UnsafeUpgrades.deployBeacon(
            address(new Riddle(address(resultErc2771Forwarder))), address(resultAccessManagedRiddleBeaconHolder)
        );
        UpgradeableBeacon riddleUpgradeableBeacon = UpgradeableBeacon(riddleUpgradeableBeaconAddress);
        resultAccessManagedRiddleBeaconHolder.initialize(riddleUpgradeableBeacon);

        resultRegisterImpl = new Register(address(resultErc2771Forwarder));

        address registerProxyAddress = UnsafeUpgrades.deployUUPSProxy(
            address(resultRegisterImpl),
            abi.encodeCall(
                Register.initialize,
                (
                    address(accessManagerUpgradeable),
                    resultAccessManagedUserBeaconHolder,
                    resultAccessManagedRiddleBeaconHolder
                )
            )
        );
        resultRegisterProxy = Register(payable(registerProxyAddress));

        return (
            accessManagerUpgradeable,
            resultErc2771Forwarder,
            resultRegisterImpl,
            resultRegisterProxy,
            resultAccessManagedUserBeaconHolder,
            resultAccessManagedRiddleBeaconHolder
        );
    }

    function grantAccessToRoles(
        address userForPrank,
        IAccessManager accessMgr,
        address registerProxyAddr,
        address userBeaconHolderAddr,
        address riddleBeaconHolderAddr
    ) public {
        if (userForPrank != address(0)) {
            vm.startPrank(userForPrank);
        }

        bytes4[] memory removeSelector = new bytes4[](1);
        removeSelector[0] = bytes4(keccak256("remove(address)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, removeSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory pauseSelector = new bytes4[](1);
        pauseSelector[0] = bytes4(keccak256("pause()"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, pauseSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory resumeSelector = new bytes4[](1);
        resumeSelector[0] = bytes4(keccak256("resume()"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, resumeSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory setBanThresholdsSelector = new bytes4[](1);
        setBanThresholdsSelector[0] = bytes4(keccak256("setBanThresholds(uint8,uint8)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, setBanThresholdsSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory setGuessAndRevealDurationSelector = new bytes4[](1);
        setGuessAndRevealDurationSelector[0] = bytes4(keccak256("setGuessAndRevealDuration(uint32,uint32)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, setGuessAndRevealDurationSelector, Roles.FINANCE_ADMIN_ROLE);

        bytes4[] memory setRegisterRewardSelector = new bytes4[](1);
        setRegisterRewardSelector[0] = bytes4(keccak256("setRegisterReward(uint8)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, setRegisterRewardSelector, Roles.FINANCE_ADMIN_ROLE);

        bytes4[] memory withdrawSelector = new bytes4[](1);
        withdrawSelector[0] = bytes4(keccak256("withdraw(address)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, withdrawSelector, Roles.FINANCE_ADMIN_ROLE);

        bytes4[] memory upgradeToAndCallSelector = new bytes4[](1);
        upgradeToAndCallSelector[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, upgradeToAndCallSelector, Roles.UPGRADE_ADMIN_ROLE);

        if (userBeaconHolderAddr != address(0)) {
            bytes4[] memory userBeaconUpgradeToSelector = new bytes4[](1);
            userBeaconUpgradeToSelector[0] = bytes4(keccak256("upgradeTo(address)"));
            accessMgr.setTargetFunctionRole(userBeaconHolderAddr, userBeaconUpgradeToSelector, Roles.UPGRADE_ADMIN_ROLE);
        }

        if (riddleBeaconHolderAddr != address(0)) {
            bytes4[] memory riddleBeaconUpgradeToSelector = new bytes4[](1);
            riddleBeaconUpgradeToSelector[0] = bytes4(keccak256("upgradeTo(address)"));
            accessMgr.setTargetFunctionRole(
                riddleBeaconHolderAddr, riddleBeaconUpgradeToSelector, Roles.UPGRADE_ADMIN_ROLE
            );
        }

        if (userForPrank != address(0)) {
            vm.stopPrank();
        }
    }
}
