// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {DeployBox} from "../../script/sec-six-upgradable/DeployBox.s.sol";
import {UpgradeBox} from "../../script/sec-six-upgradable/UpgradeBox.s.sol";
import {BoxV1} from "../../src/sec-six-upgradable/BoxV1.sol";
import {BoxV2} from "../../src/sec-six-upgradable/BoxV2.sol";

contract DeployAndUpgradeTest is Test {
    DeployBox public deployer;
    UpgradeBox public upgrader;
    address public OWNER = makeAddr("owner");

    address public proxy;

    function setUp() public {
        deployer = new DeployBox();
        upgrader = new UpgradeBox();
        proxy = deployer.run(); // right now, points to boxV1
    }

    function test_proxyStartsAsBoxV1() public {
        vm.expectRevert();
        BoxV2(proxy).setNumber(7);
    }

    function test_upgrades() public {
        BoxV2 boxV2 = new BoxV2();

        upgrader.upgradeBox(proxy, address(boxV2));
        uint256 expectedValue = 2;
        assertEq(
            expectedValue,
            BoxV2(proxy).version(),
            "Expected version to be 2"
        );

        BoxV2(proxy).setNumber(7);
        assertEq(7, BoxV2(proxy).getNumber(), "Expected number to be 7");
    }
}
