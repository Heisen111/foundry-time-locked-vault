//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimeLockedVault} from "src/TimeLockedVault.sol";
import {Test} from "forge-std/Test.sol";
import {DeployTimeLockedVault} from "script/DeployTimeLockedVault.s.sol";

contract TimeLockedVaultTest is Test {
    TimeLockedVault timeLockedVault;

    address USER = makeAddr("user");
    uint256 UNLOCKTIME = block.timestamp + 5 days;
    uint256 constant STARTING_VALUE = 10 ether;

    function setUp() external {
        DeployTimeLockedVault deployTimeLockedVault = new DeployTimeLockedVault();
        timeLockedVault = deployTimeLockedVault.run();
        vm.deal(USER, STARTING_VALUE);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(timeLockedVault.owner(), msg.sender);
    }

    function testDepositEthFailsWithoutEnoughEth() public {
        vm.expectRevert(TimeLockedVault.TimeLockedVault__InsufficientDeposit.selector);
        timeLockedVault.depositEth(0);
    }

    function testDepositEthFailsWithInvalidUnlockTime() public {
        vm.prank(USER);
        vm.expectRevert(TimeLockedVault.TimeLockedVault__InvalidUnlockTime.selector);
        timeLockedVault.depositEth{value: 2 ether}(block.timestamp - 1);
    }

    function testDepositEthFailsIfAlreadyLocked() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);

        vm.prank(USER);
        vm.expectRevert(TimeLockedVault.TimeLockedVault__LockNotExpired.selector);
        timeLockedVault.depositEth{value: 1 ether}(UNLOCKTIME + 1 days);
    }

    function testEthLocksIsUpdated() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);
        (uint256 amount, uint256 unlock) = timeLockedVault.getEthLock(USER);
        assertEq(amount, 2 ether);
        assertEq(unlock, UNLOCKTIME);
    }

    function testDepositEthEmitsEvent() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, true);
        emit TimeLockedVault.EthDeposited(USER, 2 ether, UNLOCKTIME);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);
    }

    function testWithdrawEthFailsIfInsufficientBalance() public {
        vm.prank(USER);
        vm.expectRevert(TimeLockedVault.TimeLockedVault__InsufficientBalance.selector);
        timeLockedVault.withdrawEth();
    }

    function testWithdrawFailsIfLockNotExpired() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);

        vm.prank(USER);
        vm.expectRevert(TimeLockedVault.TimeLockedVault__LockNotExpired.selector);
        timeLockedVault.withdrawEth();
    }

    function testWithdrawEthSucceedsAfterUnlockTime() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);
        vm.warp(UNLOCKTIME + 1);

        vm.prank(USER);
        vm.expectEmit(true, false, false, true);
        emit TimeLockedVault.EthWithdrawn(USER, 2 ether);
        timeLockedVault.withdrawEth();

        (uint256 amount,) = timeLockedVault.getEthLock(USER);
        assertEq(amount, 0);
    }

    function testExtendEthLockFailsIfNoActiveLock() public {
        vm.prank(USER);
        vm.expectRevert(TimeLockedVault.TimeLockedVault__NoActiveLock.selector);
        timeLockedVault.extendEthLock(UNLOCKTIME + 1 days);
    }

    function testExtendEthLockFailsIfNewUnlockTimeNotGreater() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);

        vm.prank(USER);
        vm.expectRevert("Must increase unlock time");
        timeLockedVault.extendEthLock(UNLOCKTIME - 1 days);
    }

    function testExtendEthLockSucceeds() public {
        vm.prank(USER);
        timeLockedVault.depositEth{value: 2 ether}(UNLOCKTIME);

        uint256 newUnlockTime = UNLOCKTIME + 2 days;
        vm.prank(USER);
        vm.expectEmit(true, false, false, true);
        emit TimeLockedVault.LockExtended(USER, newUnlockTime);
        timeLockedVault.extendEthLock(newUnlockTime);
        (, uint256 unlockTime) = timeLockedVault.getEthLock(USER);
        assertEq(unlockTime, newUnlockTime);
    }
}
