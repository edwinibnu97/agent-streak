// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentStreak} from "../src/AgentStreak.sol";

/// @notice Deploy AgentStreak to BNB Chain (chain id 56).
/// The deployer must hold enough BNB for gas (see README for the measured estimate).
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org --broadcast --private-key <key>
/// Dry run (no broadcast, prints the would-be deployment):
///   forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org
contract Deploy is Script {
    /// @notice Official SPACE ID Agent ID contract on BNB Chain.
    address public constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentStreak streak) {
        vm.startBroadcast();
        streak = new AgentStreak(AGENT_ID);
        vm.stopBroadcast();
        console.log("AgentStreak deployed at:", address(streak));
        console.log("Agent ID contract:", AGENT_ID);
        console.log("Name:", streak.name());
        console.log("Symbol:", streak.symbol());
    }
}
