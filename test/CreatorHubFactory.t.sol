// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/CreatorHubFactory.sol";
import "../src/CreatorHub.sol";

contract CreatorHubFactoryTest is Test {
    CreatorHubFactory public factory;
    address public owner = address(0x1);
    address public creator = address(0x2);
    address public anotherCreator = address(0x3);
    uint96 public processingFee = 1000;

    function setUp() public {
        factory = new CreatorHubFactory(processingFee);
    }

    function testRegisterCreator() public {
        vm.prank(creator);
        factory.registerCreator();

        address creatorContract = factory.getCreatorContract(creator);
        assertTrue(creatorContract != address(0), "Creator contract should be deployed");
    }

    function testFailRegisterCreatorTwice() public {
        vm.prank(creator);
        factory.registerCreator();
        
        vm.prank(creator);
        factory.registerCreator(); // Should fail
    }

    function testUpdateProcessingFee() public {
        uint96 newFee = 2000;
        factory.updateProcessingFee(newFee);
        assertEq(factory.processingFee(), newFee, "Processing fee should be updated");
    }

    function testGetAllCreators() public {
        vm.prank(creator);
        factory.registerCreator();
        vm.prank(anotherCreator);
        factory.registerCreator();
        
        address[] memory creators = factory.getAllCreators();
        assertEq(creators.length, 2, "There should be 2 creators registered");
    }

    function testWithdrawFees() public {
        vm.deal(address(factory), 1 ether);
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(factory.owner());
        factory.withdrawFees();

        assertGt(owner.balance, ownerBalanceBefore, "Owner should receive withdrawn fees");
    }
}
