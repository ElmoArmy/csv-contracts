// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "prb-test/PRBTest.sol";

import "../src/Token.sol";

contract TokenTest is PRBTest {
    Token t;

    function setUp() public {
        t = new Token();
    }

    function testName() public {
        assertEq(t.name(), "Token");
    }
}
