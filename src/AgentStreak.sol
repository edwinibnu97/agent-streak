// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Agent Streak
/// @notice Daily free check-in for Agent ID holders on BNB Chain.
/// @dev Agent ID ownership is checked on-chain via `balanceOf > 0` on the
/// official SPACE ID Agent ID contract (ERC-721, non-transferable).
/// There is NO owner and NO admin function: the contract is immutable after
/// deployment. No fees, no funds are ever held, no returns are promised.
/// A "day" is a UTC day: `block.timestamp / 1 days`.
contract AgentStreak is ERC721 {
    using Strings for uint256;

    /// @notice Official SPACE ID Agent ID contract on BNB Chain.
    IERC721 public immutable agentId;

    uint256 public constant POINTS_PER_CHECKIN = 10;
    uint256 public constant SECONDS_PER_DAY = 1 days;
    uint256 public constant MILESTONE_7 = 7;
    uint256 public constant MILESTONE_30 = 30;

    struct UserStats {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalCheckIns;
        uint256 points;
        uint256 lastCheckInDay;
    }

    mapping(address => UserStats) public stats;
    /// @notice user => milestone (7 or 30) => badge already claimed.
    mapping(address => mapping(uint256 => bool)) public badgeClaimed;
    /// @notice tokenId => milestone the badge was minted for.
    mapping(uint256 => uint256) public badgeMilestone;
    uint256 public nextTokenId = 1;

    event CheckedIn(address indexed user, uint256 indexed day, uint256 streak, uint256 totalCheckIns, uint256 points);
    event BadgeClaimed(address indexed user, uint256 indexed milestone, uint256 indexed tokenId);

    error NotAgentIdHolder();
    error AlreadyCheckedInToday();
    error MilestoneNotReached();
    error BadgeAlreadyClaimed();
    error InvalidMilestone();
    error ZeroAddress();

    /// @param agentId_ Address of the Agent ID contract (official: 0x60b9262456de011f7d15a54cdd8c48baaa8b022f).
    constructor(address agentId_) ERC721("Agent Streak Badge", "STREAK") {
        if (agentId_ == address(0)) revert ZeroAddress();
        agentId = IERC721(agentId_);
    }

    /// @notice Current UTC day number.
    function currentDay() public view returns (uint256) {
        return block.timestamp / SECONDS_PER_DAY;
    }

    /// @notice True when `user` holds at least one Agent ID.
    function isAgentIdHolder(address user) public view returns (bool) {
        return agentId.balanceOf(user) > 0;
    }

    /// @notice Free daily check-in. Only callable by Agent ID holders, once per UTC day.
    /// Streak continues when yesterday was checked in, otherwise it resets to 1.
    function checkIn() external {
        if (!isAgentIdHolder(msg.sender)) revert NotAgentIdHolder();
        uint256 day = currentDay();
        UserStats storage s = stats[msg.sender];
        if (s.lastCheckInDay == day) revert AlreadyCheckedInToday();
        if (s.lastCheckInDay != 0 && s.lastCheckInDay == day - 1) {
            s.currentStreak += 1;
        } else {
            s.currentStreak = 1;
        }
        if (s.currentStreak > s.longestStreak) s.longestStreak = s.currentStreak;
        s.totalCheckIns += 1;
        s.points += POINTS_PER_CHECKIN;
        s.lastCheckInDay = day;
        emit CheckedIn(msg.sender, day, s.currentStreak, s.totalCheckIns, s.points);
    }

    /// @notice Mint the badge NFT for a milestone (7 or 30 consecutive days).
    /// Uses the longest streak ever reached, so a broken streak does not lose
    /// an already-earned milestone. One badge per milestone per user.
    function claimBadge(uint256 milestone) external returns (uint256 tokenId) {
        if (milestone != MILESTONE_7 && milestone != MILESTONE_30) revert InvalidMilestone();
        if (!isAgentIdHolder(msg.sender)) revert NotAgentIdHolder();
        UserStats storage s = stats[msg.sender];
        if (s.longestStreak < milestone) revert MilestoneNotReached();
        if (badgeClaimed[msg.sender][milestone]) revert BadgeAlreadyClaimed();
        badgeClaimed[msg.sender][milestone] = true;
        tokenId = nextTokenId++;
        badgeMilestone[tokenId] = milestone;
        emit BadgeClaimed(msg.sender, milestone, tokenId);
        _safeMint(msg.sender, tokenId);
    }

    /// @notice Fully on-chain metadata: base64 JSON with an inline SVG image.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint256 milestone = badgeMilestone[tokenId];
        string memory svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">',
            '<rect width="400" height="400" rx="24" fill="#0B1F3A"/>',
            '<text x="200" y="150" font-family="sans-serif" font-size="28" fill="#F0B90B" text-anchor="middle">AGENT STREAK</text>',
            '<text x="200" y="230" font-family="sans-serif" font-size="72" font-weight="bold" fill="#FFFFFF" text-anchor="middle">',
            milestone.toString(),
            "</text>",
            '<text x="200" y="280" font-family="sans-serif" font-size="24" fill="#FFFFFF" text-anchor="middle">DAY STREAK</text>',
            '<text x="200" y="340" font-family="sans-serif" font-size="18" fill="#8A9BA8" text-anchor="middle">Agent ID holder badge</text>',
            "</svg>"
        );
        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name":"Agent Streak Badge - ',
                    milestone.toString(),
                    '-Day Streak","description":"Badge for an Agent ID holder who checked in ',
                    milestone.toString(),
                    ' days in a row on Agent Streak. No monetary value.","image":"data:image/svg+xml;base64,',
                    Base64.encode(bytes(svg)),
                    '","attributes":[{"trait_type":"Milestone (days)","value":',
                    milestone.toString(),
                    '},{"trait_type":"Streak type","value":"Consecutive check-ins"}]}'
                )
            )
        );
        return string.concat("data:application/json;base64,", json);
    }
}
