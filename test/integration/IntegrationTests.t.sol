// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TimeLockedVault} from "src/TimeLockedVault.sol";

contract Integration_TimeLockedVault is Test {
    TimeLockedVault vault;

    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");

    uint256 constant AMOUNT = 1 ether;
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LOCK_DURATION = 3 days;

    function setUp() public {
        vm.startPrank(OWNER);
        vault = new TimeLockedVault();
        vm.stopPrank();
    }

    function test_UserCanDepositExtendAndWithdrawEthEndToEnd() public {
        // ---------- Arrange ----------
        vm.deal(USER, 5 ether);
        uint256 unlockTime = block.timestamp + 3 days;

        vm.startPrank(USER);
        vault.depositEth{value: 1 ether}(unlockTime);

        // ---------- Act ----------
        // Extend lock
        uint256 newUnlockTime = unlockTime + 2 days;
        vault.extendEthLock(newUnlockTime);

        // Fast forward time beyond extended unlock time
        vm.warp(newUnlockTime + 1);
        vault.withdrawEth();
        vm.stopPrank();

        // ---------- Assert ----------
        (uint256 amount, uint256 time) = vault.getEthLock(USER);
        assertEq(amount, 0, "ETH lock should be cleared");
        assertEq(USER.balance, 5 ether, "User should recover full amount");
    }
}
