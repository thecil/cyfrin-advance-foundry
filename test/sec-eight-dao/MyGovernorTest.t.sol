// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "src/sec-eight-dao/MyGovernor.sol";
import {Box} from "src/sec-eight-dao/Box.sol";
import {Timelock} from "src/sec-eight-dao/Timelock.sol";
import {GovToken} from "src/sec-eight-dao/GovToken.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    Timelock timelock;
    GovToken govToken;

    address public USER = makeAddr("USER");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 1 hours;
    uint256 public constant VOTING_DELAY = 7200; // from MyGov constructor
    uint256 public constant VOTING_PERIOD = 50400; // from MyGov constructor
    uint256 public constant MIN_VOTE_VALUE = 1 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);

        timelock = new Timelock(MIN_DELAY, proposers, executors, USER);
        governor = new MyGovernor(govToken, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);

        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function test_canUpdateBoxWithoutGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        box.store(123);
    }

    function test_governanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store 1 in Box";
        bytes memory encodedFuntionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFuntionCall);
        targets.push(address(box));

        // 1. propose to DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the state
        console.log("Proposal state: %s", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal state, after time: %s", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "cuz blue frog is cool";
        GovernorCountingSimple.VoteType voteWay = GovernorCountingSimple.VoteType.For;

        vm.startPrank(USER);
        governor.castVoteWithReason(proposalId, uint8(voteWay), reason);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queueOperations(proposalId, targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        governor.executeOperations(proposalId, targets, values, calldatas, descriptionHash);

        assertEq(box.getNumber(), valueToStore, "Box number should be updated to the stored value");
    }
}
