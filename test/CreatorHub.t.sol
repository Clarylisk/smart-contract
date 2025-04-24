// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CreatorHub.sol";

contract CreatorHubTest is Test {
    CreatorHub creatorHub;
    address owner = address(0x1);
    address penyawer = address(0x2);
    address hubFactory = address(0x3);
    uint96 processingFee = 1 ether;

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.deal(penyawer, 5 ether);
        vm.deal(hubFactory, 5 ether);
        vm.prank(owner);
        creatorHub = new CreatorHub(owner, processingFee, hubFactory);
    }

    function testSawer() public {
        vm.prank(penyawer);
        vm.expectRevert("Insufficient Saweran amount");
        creatorHub.sawer{value: 1 ether}("First Saweran");
        
        vm.prank(penyawer);
        creatorHub.sawer{value: 2 ether}("Valid Saweran");
        
        (address penyawerAddr, uint96 value, , , ,) = creatorHub.getSaweran(0);
        assertEq(penyawerAddr, penyawer);
        assertEq(value, 2 ether);
    }

    function testApproveSaweran() public {
        vm.prank(penyawer);
        creatorHub.sawer{value: 2 ether}("Test Approval");

        vm.prank(owner);
        creatorHub.approveSaweran(0);

        (, uint96 value,,, bool approved,) = creatorHub.getSaweran(0);
        assertTrue(approved);
        assertEq(value, 2 ether);
    }

    function testDiscardSaweran() public {
        vm.prank(penyawer);
        creatorHub.sawer{value: 2 ether}("Test Discard");

        vm.prank(owner);
        creatorHub.discardSaweran(0);

        (, uint96 value,,, , bool discarded) = creatorHub.getSaweran(0);
        assertTrue(discarded);
        assertEq(value, 2 ether);
    }
}
