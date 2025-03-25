// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";

import {OurToken} from "../../src/section-one-erc20/OurToken.sol";
import {DeployOurToken} from "../../script/section-one-erc20/DeployOurToken.s.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;
    uint256 public constant STARTING_BALANCE = 10 ether;
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        vm.startPrank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testAllowance() public {
        uint256 allowance = 5 ether;
        vm.startPrank(bob);
        ourToken.approve(alice, allowance);
        assertEq(ourToken.allowance(bob, alice), allowance);
    }

    function testTransferFrom() public {
        uint256 allowance = 5 ether;
        vm.startPrank(bob);
        ourToken.approve(alice, allowance);
        vm.stopPrank();
        assertEq(ourToken.allowance(bob, alice), allowance);
        vm.startPrank(alice);
        ourToken.transferFrom(bob, alice, allowance);
        vm.stopPrank();
        assertEq(ourToken.balanceOf(alice), allowance);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - allowance);
        assertEq(ourToken.allowance(bob, alice), 0);
    }
}
