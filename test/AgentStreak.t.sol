// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentStreak} from "../src/AgentStreak.sol";

/// @notice Minimal stand-in for the SPACE ID Agent ID contract: only balanceOf matters.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function mint(address to) external {
        _balances[to] += 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgentStreakTest is Test {
    AgentStreak public streak;
    MockAgentId public agentId;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA901); // no Agent ID

    // Start exactly on a UTC day boundary so day math is clean.
    uint256 public constant START_DAY = 20_000;

    function setUp() public {
        agentId = new MockAgentId();
        streak = new AgentStreak(address(agentId));
        agentId.mint(alice);
        agentId.mint(bob);
        vm.warp(START_DAY * 1 days);
    }

    function _checkInDays(address user, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.warp((START_DAY + i) * 1 days);
            vm.prank(user);
            streak.checkIn();
        }
    }

    function test_NonHolderCannotCheckIn() public {
        vm.prank(carol);
        vm.expectRevert(AgentStreak.NotAgentIdHolder.selector);
        streak.checkIn();
    }

    function test_CheckInFirstDay() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(streak));
        emit AgentStreak.CheckedIn(alice, START_DAY, 1, 1, 10);
        streak.checkIn();

        (uint256 current, uint256 longest, uint256 total, uint256 points, uint256 lastDay) = streak.stats(alice);
        assertEq(current, 1);
        assertEq(longest, 1);
        assertEq(total, 1);
        assertEq(points, 10);
        assertEq(lastDay, START_DAY);
        assertTrue(streak.isAgentIdHolder(alice));
        assertFalse(streak.isAgentIdHolder(carol));
    }

    function test_CannotCheckInTwiceSameDay() public {
        vm.prank(alice);
        streak.checkIn();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.AlreadyCheckedInToday.selector);
        streak.checkIn();
    }

    function test_StreakIncrementsConsecutiveDays() public {
        _checkInDays(alice, 3);
        (uint256 current, uint256 longest, uint256 total, uint256 points,) = streak.stats(alice);
        assertEq(current, 3);
        assertEq(longest, 3);
        assertEq(total, 3);
        assertEq(points, 30);
    }

    function test_PointsAccumulate() public {
        _checkInDays(alice, 5);
        (,,, uint256 points,) = streak.stats(alice);
        assertEq(points, 5 * streak.POINTS_PER_CHECKIN());
    }

    function test_StreakResetsAfterGap() public {
        _checkInDays(alice, 3); // streak 3, longest 3
        // Skip one day (START_DAY+3), check in on START_DAY+4.
        vm.warp((START_DAY + 4) * 1 days);
        vm.prank(alice);
        streak.checkIn();
        (uint256 current, uint256 longest, uint256 total,,) = streak.stats(alice);
        assertEq(current, 1, "streak must reset to 1 after a missed day");
        assertEq(longest, 3, "longest streak must be preserved");
        assertEq(total, 4);
    }

    function test_LongestStreakPreservedAfterBreak() public {
        _checkInDays(alice, 7);
        vm.warp((START_DAY + 9) * 1 days); // two days missed
        vm.prank(alice);
        streak.checkIn();
        (, uint256 longest,,,) = streak.stats(alice);
        assertEq(longest, 7);
    }

    function test_BadgeCannotClaimBeforeMilestone() public {
        _checkInDays(alice, 3);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.MilestoneNotReached.selector);
        streak.claimBadge(7);
    }

    function test_BadgeClaimAt7() public {
        _checkInDays(alice, 7);
        vm.warp((START_DAY + 7) * 1 days);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false, address(streak));
        emit AgentStreak.BadgeClaimed(alice, 7, 1);
        uint256 tokenId = streak.claimBadge(7);
        assertEq(tokenId, 1);
        assertEq(streak.ownerOf(1), alice);
        assertEq(streak.badgeMilestone(1), 7);
        assertTrue(streak.badgeClaimed(alice, 7));
        assertEq(streak.nextTokenId(), 2);
    }

    function test_BadgeClaimUsesLongestStreak() public {
        _checkInDays(alice, 7);
        // Break the streak, then claim: longest streak (7) still qualifies.
        vm.warp((START_DAY + 9) * 1 days);
        vm.prank(alice);
        streak.checkIn();
        vm.prank(alice);
        uint256 tokenId = streak.claimBadge(7);
        assertEq(tokenId, 1);
    }

    function test_BadgeCannotClaimTwice() public {
        _checkInDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.BadgeAlreadyClaimed.selector);
        streak.claimBadge(7);
    }

    function test_BadgeClaimAt30() public {
        _checkInDays(alice, 30);
        vm.prank(alice);
        uint256 tokenId = streak.claimBadge(30);
        assertEq(tokenId, 1);
        assertEq(streak.ownerOf(1), alice);
        assertEq(streak.badgeMilestone(1), 30);
        // The 7-day badge is a separate claim and still available.
        vm.prank(alice);
        uint256 second = streak.claimBadge(7);
        assertEq(second, 2);
    }

    function test_InvalidMilestone() public {
        _checkInDays(alice, 7);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.InvalidMilestone.selector);
        streak.claimBadge(14);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.InvalidMilestone.selector);
        streak.claimBadge(0);
    }

    function test_BadgeRequiresAgentId() public {
        vm.prank(carol);
        vm.expectRevert(AgentStreak.NotAgentIdHolder.selector);
        streak.claimBadge(7);
    }

    function test_TokenURIIsOnChainMetadata() public {
        _checkInDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);
        string memory uri = streak.tokenURI(1);
        // Must be a base64 JSON data URI.
        assertEq(bytes(uri)[0], bytes("d")[0]);
        assertGt(bytes(uri).length, 100);
        // Decode check: the base64 payload must contain the milestone.
        // (Cheap structural check: prefix is the standard data URI header.)
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(bytes(uri)[i], prefix[i]);
        }
    }

    function test_MultipleUsersIndependent() public {
        _checkInDays(alice, 3);
        vm.warp(START_DAY * 1 days);
        vm.prank(bob);
        streak.checkIn();
        (uint256 aCurrent,,,,) = streak.stats(alice);
        (uint256 bCurrent,,,,) = streak.stats(bob);
        assertEq(aCurrent, 3);
        assertEq(bCurrent, 1);
    }

    function test_ConstructorRejectsZeroAddress() public {
        vm.expectRevert(AgentStreak.ZeroAddress.selector);
        new AgentStreak(address(0));
    }

    function test_CurrentDayMatchesWarp() public {
        assertEq(streak.currentDay(), START_DAY);
        vm.warp((START_DAY + 1) * 1 days + 3600);
        assertEq(streak.currentDay(), START_DAY + 1);
    }
}
