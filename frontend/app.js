// Agent Streak — frontend logic (static page, no server, no sessions).
// Every action is a transaction the user signs in their OWN wallet.
// This page never asks for a pairing code, seed phrase, or private key, and
// never stores any session: connecting only links the wallet to this page
// (standard injected-provider / WalletConnect dApp connection).
import { ethers } from "https://esm.sh/ethers@6.13.4";
import EthereumProvider from "https://esm.sh/@walletconnect/ethereum-provider@2.17.5";
import { CONFIG, ABI } from "./config.js";

const $ = (id) => document.getElementById(id);
const els = {
  status: $("status"), connectInjected: $("connect-injected"), connectWc: $("connect-wc"),
  disconnect: $("disconnect"), account: $("account"), holder: $("holder"), day: $("day"),
  streak: $("streak"), longest: $("longest"), total: $("total"), points: $("points"),
  lastDay: $("lastDay"), checkin: $("checkin"), badges: $("badges"),
  events: $("events"), message: $("message"), contractLink: $("contract-link"),
};

let provider = null; // ethers BrowserProvider
let signer = null;
let account = null;
let readContract = null; // read-only contract (public RPC)
let writeContract = null; // signer-bound contract

function showMessage(text, isError = false) {
  els.message.textContent = text;
  els.message.style.color = isError ? "#ff6b6b" : "#8affc1";
}

function fmtDay(day) {
  if (!day || day === 0n) return "-";
  return new Date(Number(day) * 86400 * 1000).toISOString().slice(0, 10);
}

async function refresh() {
  if (!readContract) return;
  try {
    const day = await readContract.currentDay();
    els.day.textContent = `${day} (${fmtDay(day)} UTC)`;
    if (!account) return;
    const holder = await readContract.isAgentIdHolder(account);
    els.holder.textContent = holder ? "Yes — Agent ID holder" : "No Agent ID found";
    els.holder.style.color = holder ? "#8affc1" : "#ff6b6b";
    const s = await readContract.stats(account);
    els.streak.textContent = s.currentStreak.toString();
    els.longest.textContent = s.longestStreak.toString();
    els.total.textContent = s.totalCheckIns.toString();
    els.points.textContent = s.points.toString();
    els.lastDay.textContent = fmtDay(s.lastCheckInDay);
    const alreadyToday = s.lastCheckInDay === day;
    els.checkin.disabled = !holder || alreadyToday;
    els.checkin.textContent = alreadyToday ? "Checked in today" : "Check in (free)";
    await renderBadges(s.longestStreak);
    await renderEvents();
  } catch (e) {
    showMessage("Read failed: " + (e?.shortMessage || e?.message || e), true);
  }
}

async function renderBadges(longestStreak) {
  els.badges.innerHTML = "";
  for (const m of CONFIG.MILESTONES) {
    const claimed = await readContract.badgeClaimed(account, m);
    const eligible = longestStreak >= BigInt(m);
    const btn = document.createElement("button");
    btn.textContent = claimed ? `${m}-day badge — claimed` : eligible ? `Claim ${m}-day badge` : `${m}-day badge — need ${m}-day streak`;
    btn.disabled = claimed || !eligible;
    btn.onclick = () => claimBadge(m);
    els.badges.appendChild(btn);
  }
}

async function renderEvents() {
  const filter = readContract.filters.CheckedIn(account);
  const checkins = await readContract.queryFilter(filter, -5000);
  const badgeFilter = readContract.filters.BadgeClaimed(account);
  const badges = await readContract.queryFilter(badgeFilter, -5000);
  const rows = [
    ...checkins.slice(-5).map((e) => `Day ${e.args.day}: checked in — streak ${e.args.streak}, ${e.args.points} pts`),
    ...badges.slice(-5).map((e) => `Badge claimed: ${e.args.milestone}-day streak (token #${e.args.tokenId})`),
  ];
  els.events.innerHTML = rows.length
    ? rows.map((r) => `<li>${r}</li>`).join("")
    : "<li>No activity yet.</li>";
}

async function checkIn() {
  if (!writeContract) return;
  try {
    showMessage("Waiting for your signature in your wallet…");
    const tx = await writeContract.checkIn();
    showMessage("Sent: " + tx.hash + " — waiting for confirmation…");
    await tx.wait();
    showMessage("Checked in. Streak updated.");
    await refresh();
  } catch (e) {
    showMessage("Check-in failed: " + (e?.shortMessage || e?.message || e), true);
  }
}

async function claimBadge(milestone) {
  if (!writeContract) return;
  try {
    showMessage("Waiting for your signature in your wallet…");
    const tx = await writeContract.claimBadge(milestone);
    showMessage("Sent: " + tx.hash + " — waiting for confirmation…");
    await tx.wait();
    showMessage(`${milestone}-day badge claimed.`);
    await refresh();
  } catch (e) {
    showMessage("Claim failed: " + (e?.shortMessage || e?.message || e), true);
  }
}

async function afterConnect(ethProvider, label) {
  provider = new ethers.BrowserProvider(ethProvider);
  const network = await provider.getNetwork();
  if (Number(network.chainId) !== CONFIG.CHAIN_ID) {
    showMessage(`Please switch your wallet to chain ID ${CONFIG.CHAIN_ID}.`, true);
    return;
  }
  signer = await provider.getSigner();
  account = await signer.getAddress();
  writeContract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, ABI, signer);
  els.account.textContent = account;
  els.status.textContent = `Connected (${label})`;
  els.connectInjected.style.display = "none";
  els.connectWc.style.display = "none";
  els.disconnect.style.display = "inline-block";
  showMessage("Connected. Your stats load below.");
  await refresh();
}

async function connectInjected() {
  if (!window.ethereum) {
    showMessage("No browser wallet found. Install a wallet extension or use WalletConnect.", true);
    return;
  }
  try {
    await window.ethereum.request({ method: "eth_requestAccounts" });
    await afterConnect(window.ethereum, "browser wallet");
  } catch (e) {
    showMessage("Connection failed: " + (e?.message || e), true);
  }
}

async function connectWalletConnect() {
  try {
    const wc = await EthereumProvider.init({
      projectId: CONFIG.WALLETCONNECT_PROJECT_ID,
      chains: [CONFIG.CHAIN_ID],
      showQrModal: true,
      metadata: {
        name: "Agent Streak",
        description: "Daily free check-in for Agent ID holders.",
        url: window.location.origin,
        icons: [],
      },
    });
    await wc.connect();
    await afterConnect(wc, "WalletConnect");
  } catch (e) {
    showMessage("WalletConnect failed: " + (e?.message || e), true);
  }
}

function disconnect() {
  provider = null; signer = null; account = null; writeContract = null;
  els.account.textContent = "-";
  els.status.textContent = "Not connected";
  els.connectInjected.style.display = "inline-block";
  els.connectWc.style.display = "inline-block";
  els.disconnect.style.display = "none";
  showMessage("Disconnected.");
}

function initReadOnly() {
  if (CONFIG.CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
    showMessage("Contract not deployed yet — set CONTRACT_ADDRESS in config.js after deploy.", true);
    els.checkin.disabled = true;
    return;
  }
  const rpc = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  readContract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, ABI, rpc);
  els.contractLink.href = `https://bscscan.com/address/${CONFIG.CONTRACT_ADDRESS}`;
  els.contractLink.textContent = CONFIG.CONTRACT_ADDRESS;
  refresh();
  setInterval(refresh, 30000);
}

els.connectInjected.onclick = connectInjected;
els.connectWc.onclick = connectWalletConnect;
els.disconnect.onclick = disconnect;
els.checkin.onclick = checkIn;
initReadOnly();
