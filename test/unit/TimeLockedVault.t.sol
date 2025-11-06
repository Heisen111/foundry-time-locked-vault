//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimeLockedVault} from "src/TimeLockedVault.sol";
import {Test} from "forge-std/Test.sol";
import {DeployTimeLockedVault} from "script/DeployTimeLockedVault.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract TimeLockedVaultTest is Test {
    TimeLockedVault timeLockedVault;
    ERC20Mock token;

    address USER = makeAddr("user");
    uint256 UNLOCKTIME = block.timestamp + 5 days;
    uint256 constant STARTING_VALUE = 10 ether;

    function setUp() external {
        DeployTimeLockedVault deployTimeLockedVault = new DeployTimeLockedVault();
        timeLockedVault = deployTimeLockedVault.run();
        vm.deal(USER, STARTING_VALUE);
        token = new ERC20Mock();
        token.transfer(USER, 500 ether);
        vm.startPrank(USER);
        token.approve(address(timeLockedVault), type(uint256).max);
        vm.stopPrank();
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

    function testDepositTokenWorks() public {
        vm.prank(USER);
        timeLockedVault.depositToken(address(token), 100 ether, UNLOCKTIME);

        (uint256 amount, uint256 unlock) = timeLockedVault.tokenLocks(USER, address(token));

        assertEq(amount, 100 ether);
        assertEq(unlock, UNLOCKTIME);
        assertEq(token.balanceOf(address(timeLockedVault)), 100 ether);
    }

    function testWithdrawTokenWorks() public {
        vm.prank(USER);
        timeLockedVault.depositToken(address(token), 100 ether, UNLOCKTIME);
        vm.warp(UNLOCKTIME + 1);

        vm.prank(USER);
        timeLockedVault.withdrawToken(address(token));
        (uint256 amount,) = timeLockedVault.tokenLocks(USER, address(token));
        assertEq(amount, 0);
    }

    function testExtendTokenLockWorks() public {
        vm.prank(USER);
        timeLockedVault.depositToken(address(token), 100 ether, UNLOCKTIME);

        uint256 newUnlockTime = UNLOCKTIME + 3 days;
        vm.prank(USER);
        timeLockedVault.extendTokenLock(address(token), newUnlockTime);
        (, uint256 unlocktime) = timeLockedVault.tokenLocks(USER, address(token));
        assertEq(unlocktime, newUnlockTime);
    }

    function testTransferOwnershipWorks() public {
        address newOwner = makeAddr("newOwner");
        address owner = timeLockedVault.owner();

        vm.prank(owner);
        timeLockedVault.transferOwnership(newOwner);

        assertEq(timeLockedVault.owner(), newOwner);
    }

    function testTransferOwnershipFailsWithInvalidNewOwner() public {
        address owner = timeLockedVault.owner();

        vm.prank(owner);
        vm.expectRevert("Invalid new owner");
        timeLockedVault.transferOwnership(address(0));
    }

    function testEmergencyWithdrawWorks() public {
        vm.prank(USER);
        timeLockedVault.depositToken(address(token), 100 ether, UNLOCKTIME);

        address owner = timeLockedVault.owner();
        vm.prank(owner);
        timeLockedVault.emergencyWithdraw(USER, address(token));

        assertEq(token.balanceOf(USER), 500 ether);
    }
}
