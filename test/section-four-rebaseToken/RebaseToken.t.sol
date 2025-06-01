// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/section-four-rebaseToken/RebaseToken.sol";
import {Vault} from "../../src/section-four-rebaseToken/Vault.sol";
import {IRebaseToken} from "../../src/section-four-rebaseToken/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}(
            ""
        );
    }
    function test_depositLinear(uint256 amount) public {
        // Deposit funds
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        console.log("block.timestamp", block.timestamp);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("endBalance", endBalance);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );

        vm.stopPrank();
    }

    function test_RedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function test_RedeemAfterTimePassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);
        vm.deal(user, depositAmount);
        vm.prank(user);
        // 1. deposit
        vault.deposit{value: depositAmount}();
        // 2. warp time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        // add rewards to vault
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        vm.stopPrank();
        // 3. redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = address(user).balance;
        // 4. check balances
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function test_transfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // owner reduce the interest
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2. transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check user interest rate has been inherited (5e10 not 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function test_cannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        rebaseToken.setInterestRate(newInterestRate);
    }

    function test_cannotCallMintAndBurn() public {
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        console.log("vault: %s", address(vault));
        console.log("user: %s", user);
        console.log("msg.sender: %s", msg.sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.mint(user, 100, interestRate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.burn(user, 100);
    }

    function test_principalBalanceOf(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principalBalanceOf(user), amount);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principalBalanceOf(user), amount);
    }

    function test_getRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function test_InterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 currentInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(
            newInterestRate,
            currentInterestRate + 1,
            type(uint256).max
        );
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
                currentInterestRate,
                newInterestRate
            )
        );
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), currentInterestRate);
    }
}
