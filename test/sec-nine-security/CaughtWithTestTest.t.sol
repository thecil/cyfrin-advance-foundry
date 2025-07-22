// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CaughtWithTest} from "src/sec-nine-security/CaughtWithTest.sol";

contract CaughtWithTestTest is Test {
    CaughtWithTest public caughtWithTest;

    function setUp() public {
        caughtWithTest = new CaughtWithTest();
    }

    function testSetNumber() public {
        uint256 myNumber = 55;
        caughtWithTest.setNumber(myNumber);
        assertEq(myNumber, caughtWithTest.number());
    }
}
