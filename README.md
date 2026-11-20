# Agent Streak

Daily free check-in for Agent ID holders. Check in once per UTC day, build a
streak, earn points, and claim a badge NFT at 7- and 30-day streak milestones.

Built for the Agent ID Hackathon (submission window 18 Nov – 9 Dec 2026,
15:00 WIB). Target award: **Agent Application Innovation Award**.

## Live

- **Contract (BNB Chain, chain id 56):**
  `0x23e9f9d45A3783CC34b55a79873D055038fc9Dd2`
  — deployed 21 Nov 2026, block 134773426, deploy tx
  `0x877b6b9c21288ad5f2a5cbb6139a96a9eeea5c224e02f726de96986e21a17a56`.
- **BscScan (source verified, Exact Match):**
  https://bscscan.com/address/0x23e9f9d45A3783CC34b55a79873D055038fc9Dd2#code
  (Sourcify exact match, compiler v0.8.35, optimizer 200 runs).
- **Frontend (live):** https://frontend-red-delta-10.vercel.app
- **Submit form:** https://app.binance.com/uni-qr/user-survey/fb26d2bd25e04329b1ba77c7b3811d23

## How Agent ID is used

- `checkIn()` and `claimBadge()` are gated on-chain: the caller must hold at
  least one Agent ID. Ownership is checked via `balanceOf > 0` on the
  official SPACE ID Agent ID contract
  (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, ERC-721, non-transferable).
- Nothing else in the dApp depends on off-chain identity. The frontend reads
  the same `balanceOf` check before enabling the buttons.

## Safety / hackathon red-line compliance

- **No owner, no admin functions.** The contract is immutable after
  deployment. There is nothing to disclose because there is no permission
  to disclose: no minting by an admin, no tax, no pause, no freeze, no
  withdrawal of user funds (the contract never holds funds).
- **No fees, no tax.** `checkIn()` and `claimBadge()` are free apart from
  network gas, which the user pays to the network, not to the project.
- **No returns promised.** Points and badges have no monetary value and are
  not redeemable for anything. The badge metadata says so explicitly.
- **No brand impersonation.** The project, token, and contract are named
  "Agent Streak" / "Agent Streak Badge (STREAK)". The words "Binance" and
  "BNB" do not appear in any project, token, or domain name.
- **No credential collection.** The frontend never asks for a seed phrase,
  private key, API secret, or pairing code.
- **No web QR login for the Agentic Wallet, no session storage.** Connecting
  a wallet uses the standard dApp flow only: an injected browser wallet, or
  a standard WalletConnect link that the user approves in their own wallet
  app. No session is stored on any server (there is no server). Every action
  is a transaction the user signs themselves in their own wallet; there are
  no automatic or scheduled transactions.
- **Not a wallet lookup tool.** The dApp shows only the connected wallet's
  own stats. It cannot look up other people's wallets by name.
- **No fake users.** The 30-address Innovation Award gate can only be met by
  real Agent ID holders using the live dApp.

## Contracts

- `src/AgentStreak.sol` — the whole dApp in one contract. ERC-721 badge
  (OpenZeppelin v5.3.0) + streak / points logic.
  - `checkIn()` — once per UTC day, Agent ID holders only. Streak continues
    when yesterday was checked in, otherwise resets to 1. +10 points.
  - `claimBadge(7 | 30)` — mints the badge NFT when the user's *longest*
    streak reached the milestone (a broken streak does not lose an
    already-earned milestone). One badge per milestone per user.
  - `tokenURI()` — fully on-chain metadata (base64 JSON + inline SVG).
  - Events: `CheckedIn`, `BadgeClaimed`.
  - A "day" is a UTC day: `block.timestamp / 1 days`.

## Tests

Foundry (forge 1.9.0). 18 tests, all passing:

```bash
forge test
```

Covered: non-holders cannot check in or claim; streak increments on
consecutive days; streak resets after a missed day (longest streak
preserved); points accumulate; badge cannot be claimed before its milestone;
badge claims at 7 and 30; double-claim reverts; invalid milestones revert;
`tokenURI` returns an on-chain data URI; users' streaks are independent;
constructor rejects the zero address.

## Deploy (BNB Chain, chain id 56) — DONE 21 Nov 2026

Deployed with an ephemeral deployer (fresh random keypair, funded with
0.0002 BNB, key deleted after deploy — see `script/deploy-ephemeral.mjs`).
Contract: `0x23e9f9d45A3783CC34b55a79873D055038fc9Dd2` (block 134773426,
1,687,048 gas, status 1). Source verified on BscScan via Sourcify
(exact match, no API key needed):

```bash
forge verify-contract --verifier sourcify --chain-id 56 \
  0x23e9f9d45A3783CC34b55a79873D055038fc9Dd2 src/AgentStreak.sol:AgentStreak
```

To reproduce the deploy from scratch (dry run first, no broadcast):

```bash
# Dry run (no broadcast)
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org
# Real deploy
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org \
  --broadcast --private-key <deployer-private-key>
```

After deploy, set `CONTRACT_ADDRESS` in `frontend/config.js` (already set
to the live address in this repo).

## Setup (fresh clone)

```bash
git submodule update --init          # OpenZeppelin contracts
forge install foundry-rs/forge-std   # test library (not a submodule here)
forge test
```

## Measured gas (not guessed)

Measured 21 Nov 2026 on local anvil + `cast estimate` (both agree) and the
`forge test --gas-report` run, with the optimizer on (200 runs, as set in
`foundry.toml`). BSC gas price that day: **0.05 gwei** (checked on two
public RPCs).

| Action | Gas | Cost @ 0.05 gwei | Cost @ 0.1 gwei | Cost @ 1 gwei |
|---|---|---|---|---|
| Deploy contract | 1,687,048 | **0.00008435 BNB** | 0.00016870 BNB | 0.00168705 BNB |
| `checkIn()` (first) | ~140,774 max | ~0.00000704 BNB | ~0.00001408 BNB | ~0.00014077 BNB |
| `checkIn()` (typical) | ~55,574 median | ~0.00000278 BNB | ~0.00000556 BNB | ~0.00005557 BNB |
| `claimBadge()` | ~110,898 median | ~0.00000554 BNB | ~0.00001109 BNB | ~0.00011090 BNB |

Wallet context (21 Nov 2026): the deployer wallet held ~0.00067 BNB, so at
the then-current 0.05 gwei the deploy (~0.000084 BNB) fits with room to
spare; at 1 gwei it would not. Gas price can spike — check the live gas price
before deploying.

## Frontend

Live at https://frontend-red-delta-10.vercel.app (static page, no build
step, no server). To run locally, serve it over HTTP (ES modules +
WalletConnect do not work from `file://`):

```bash
cd frontend
python3 -m http.server 8000
# open http://localhost:8000
```

1. `CONTRACT_ADDRESS` in `frontend/config.js` is already set to the live
   contract.
2. Connect with a browser wallet or WalletConnect (chain ID 56).
3. Check in once per day; claim badges at 7- and 30-day streaks.

The page reads state from the public RPC and only writes through
transactions the user signs in their own wallet.

## Repo layout

```
src/AgentStreak.sol      contract
test/AgentStreak.t.sol   18 Foundry tests (+ MockAgentId)
script/Deploy.s.sol      deploy script (official Agent ID address)
script/deploy-ephemeral.mjs  ephemeral-deployer flow (key in memory only)
frontend/                static dApp (index.html, app.js, config.js)
```

## Still open

- **Distribution**: reaching 30 real interacting Agent ID addresses before
  9 Dec 2026 needs promotion (X post + community channels). Nothing here
  can or should fake that. (2 check-ins already arrived unprompted:
  19861115.ai and 2777.ai, 21 Nov 2026.)
- **Submit**: the project still has to be submitted through the form above
  (name, website, contract address, Agent ID usage description).
