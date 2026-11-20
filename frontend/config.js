// Agent Streak — frontend configuration.
// Fill CONTRACT_ADDRESS after the contract is deployed (see ../README.md).
// No secrets here: everything in this file is public.
export const CONFIG = {
  // Deployed 21 Nov 2026 ~05:15 WIB, block 134773426 (tx 0x877b6b9c21288ad5f2a5cbb6139a96a9eeea5c224e02f726de96986e21a17a56).
  CONTRACT_ADDRESS: "0x23e9f9d45A3783CC34b55a79873D055038fc9Dd2",
  // Official SPACE ID Agent ID contract on chain 56.
  AGENT_ID_ADDRESS: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  CHAIN_ID: 56,
  RPC_URL: "https://bsc-dataseed.bnbchain.org",
  // WalletConnect project ID (free, from https://cloud.reown.com).
  // Replace with your own if you fork this frontend.
  WALLETCONNECT_PROJECT_ID: "b3baf51433b2b89ee409d9e531020fe3",
  MILESTONES: [7, 30],
  POINTS_PER_CHECKIN: 10,
};

// Minimal ABI for the AgentStreak contract.
export const ABI = [
  "function checkIn()",
  "function claimBadge(uint256 milestone) returns (uint256)",
  "function stats(address user) view returns (uint256 currentStreak, uint256 longestStreak, uint256 totalCheckIns, uint256 points, uint256 lastCheckInDay)",
  "function currentDay() view returns (uint256)",
  "function isAgentIdHolder(address user) view returns (bool)",
  "function badgeClaimed(address user, uint256 milestone) view returns (bool)",
  "function badgeMilestone(uint256 tokenId) view returns (uint256)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function tokenURI(uint256 tokenId) view returns (string)",
  "function balanceOf(address owner) view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "event CheckedIn(address indexed user, uint256 indexed day, uint256 streak, uint256 totalCheckIns, uint256 points)",
  "event BadgeClaimed(address indexed user, uint256 indexed milestone, uint256 indexed tokenId)",
];
