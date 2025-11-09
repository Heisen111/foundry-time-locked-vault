// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TimeLockedVault} from "src/TimeLockedVault.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Integration_TimeLockedVault is Test {
    TimeLockedVault vault;
    ERC20Mock token;

    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    address OWNER = makeAddr("owner");

    uint256 constant AMOUNT = 1 ether;
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LOCK_DURATION = 3 days;

    function setUp() public {
        vm.startPrank(OWNER);
        vault = new TimeLockedVault();
        vm.deal(USER, INITIAL_BALANCE);
        vm.deal(USER2, INITIAL_BALANCE);
        vm.stopPrank();

        token = new ERC20Mock();
        token.transfer(USER, 100 ether);
    }

    function test_UserCanDepositExtendAndWithdrawEthEndToEnd() public {
        vm.deal(USER, 5 ether);
        uint256 unlockTime = block.timestamp + 3 days;

        vm.startPrank(USER);
        vault.depositEth{value: 1 ether}(unlockTime);

        uint256 newUnlockTime = unlockTime + 2 days;
        vault.extendEthLock(newUnlockTime);

        vm.warp(newUnlockTime + 1);
        vault.withdrawEth();
        vm.stopPrank();

        (uint256 amount,) = vault.getEthLock(USER);
        assertEq(amount, 0, "ETH lock should be cleared");
        assertEq(USER.balance, 5 ether, "User should recover full amount");
    }

    function test_UserCanDepositAndWithdrawTokenEndToEnd() public {
        vm.startPrank(USER);
        token.approve(address(vault), 10 ether);
        uint256 unlock = block.timestamp + LOCK_DURATION;

        vault.depositToken(address(token), 5 ether, unlock);
        vm.warp(unlock + 1);
        vault.withdrawToken(address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(USER), 100 ether);
    }

    function test_ExtendTokenLockThenWithdrawWorks() public {
        vm.startPrank(USER);
        token.approve(address(vault), 10 ether);
        uint256 initialUnlock = block.timestamp + LOCK_DURATION;

        vault.depositToken(address(token), 3 ether, initialUnlock);

        uint256 extendUnlock = initialUnlock + 5 days;
        vault.extendTokenLock(address(token), extendUnlock);
        vm.warp(extendUnlock + 1);
        vault.withdrawToken(address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(USER), 100 ether);
    }

    function test_OwnerCanEmergencyWithdrawEth() public {
        vm.startPrank(USER);
        uint256 unlock = block.timestamp + 3 days;
        vault.depositEth{value: AMOUNT}(unlock);
        vm.stopPrank();

        vm.startPrank(OWNER);
        vault.emergencyWithdraw(USER, address(0));
        vm.stopPrank();

        assertEq(USER.balance, INITIAL_BALANCE);
    }

    function test_OwnerCanEmergencyWithdrawToken() public {
        vm.startPrank(USER);
        token.approve(address(vault), 20 ether);
        uint256 unlock = block.timestamp + LOCK_DURATION;

        vault.depositToken(address(token), 10 ether, unlock);
        vm.stopPrank();

        vm.startPrank(OWNER);
        vault.emergencyWithdraw(USER, address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(USER), 100 ether);
    }

    function test_TransferOwnershipAndExecuteAdminFunction() public {
        address newOwner = makeAddr("newOwner");

        vm.startPrank(OWNER);
        vault.transferOwnership(newOwner);
        vm.stopPrank();

        vm.startPrank(USER);
        uint256 unlock = block.timestamp + 3 days;
        vault.depositEth{value: AMOUNT}(unlock);
        vm.stopPrank();

        vm.startPrank(newOwner);
        vault.emergencyWithdraw(USER, address(0));
        vm.stopPrank();
    }

    function test_MultipleUsersIndependentEthLocks() public {
        uint256 unlock1 = block.timestamp + 2 days;
        uint256 unlock2 = block.timestamp + 3 days;

        vm.startPrank(USER);
        vault.depositEth{value: 1 ether}(unlock1);
        vm.stopPrank();

        vm.startPrank(USER2);
        vault.depositEth{value: 2 ether}(unlock2);
        vm.stopPrank();

        vm.warp(unlock1 + 1);
        vm.prank(USER);
        vault.withdrawEth();

        (uint256 amt1,) = vault.getEthLock(USER);
        (uint256 amt2,) = vault.getEthLock(USER2);

        assertEq(amt1, 0);
        assertEq(amt2, 2 ether);
    }

    function test_UserCannotWithdrawBeforeUnlock() public {
        vm.startPrank(USER);
        uint256 unlock = block.timestamp + 3 days;
        vault.depositEth{value: AMOUNT}(unlock);

        vm.expectRevert(TimeLockedVault.TimeLockedVault__LockNotExpired.selector);
        vault.withdrawEth();
        vm.stopPrank();
    }

    function test_TokenAndEthLocksWorkIndependently() public {
        vm.startPrank(USER);
        token.approve(address(vault), 5 ether);
        uint256 unlockEth = block.timestamp + 2 days;
        uint256 unlockToken = block.timestamp + 3 days;

        vault.depositEth{value: 1 ether}(unlockEth);
        vault.depositToken(address(token), 5 ether, unlockToken);

        vm.warp(unlockEth + 1);
        vault.withdrawEth();

        (uint256 ethAmt,) = vault.getEthLock(USER);
        assertEq(ethAmt, 0);
        (, uint256 tokenUnlock) = vault.tokenLocks(USER, address(token));
        assertEq(tokenUnlock, unlockToken);
        vm.stopPrank();
    }
}
