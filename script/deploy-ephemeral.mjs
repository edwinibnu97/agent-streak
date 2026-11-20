// Ephemeral deployer for AgentStreak (BNB Chain mainnet).
// Generates a fresh random keypair IN MEMORY ONLY. The private key is NEVER
// printed, NEVER written to disk, and dies when this process exits.
// Flow: print deployer address -> wait for funding -> deploy -> refund leftover
// to wallet B -> print contract address -> exit.
// Usage: node script/deploy-ephemeral.mjs   (run in background; funding is sent separately)
import { createRequire } from 'module';
import { readFileSync } from 'fs';

const require = createRequire('/home/hatch/workspace/goals/free-agent-nft-scan/hidden_files/');
const { ethers } = require('ethers');

const RPC = 'https://bsc-dataseed.bnbchain.org';
const WALLET_B = '0xB2B14a46950a2D8141D11329b73a629AC06Caa6c';
const AGENT_ID = '0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F';
const FUND_TARGET = ethers.parseEther('0.00019'); // deploy needs ~0.000085 @ 0.05 gwei; 0.0002 funded
const POLL_MS = 5000;
const TIMEOUT_MS = 15 * 60 * 1000;
const DEPLOY_GAS_EST = 1_700_000n;

const artifact = JSON.parse(readFileSync(new URL('../out/AgentStreak.sol/AgentStreak.json', import.meta.url), 'utf8'));

const provider = new ethers.JsonRpcProvider(RPC);
const deployer = ethers.Wallet.createRandom().connect(provider);
console.log('DEPLOYER_ADDRESS=' + deployer.address);
console.log('FUND_TARGET=0.0002 BNB from wallet B (0xB2B14a46950a2D8141D11329b73a629AC06Caa6c)');

// 1. Wait for funding
const start = Date.now();
let funded = false;
while (Date.now() - start < TIMEOUT_MS) {
  const bal = await provider.getBalance(deployer.address);
  if (bal >= FUND_TARGET) { funded = true; console.log('FUNDED balance=' + ethers.formatEther(bal) + ' BNB'); break; }
  await new Promise((r) => setTimeout(r, POLL_MS));
}
if (!funded) { console.log('TIMEOUT: funding never arrived. No deploy, key dies with this process.'); process.exit(1); }

// 2. Gas-price guard: abort (and refund) if deploy would not fit in the funded balance
const fee = await provider.getFeeData();
const gasPrice = fee.gasPrice ?? ethers.parseUnits('0.05', 'gwei');
const deployCostEst = DEPLOY_GAS_EST * gasPrice;
const balAfterFund = await provider.getBalance(deployer.address);
console.log('gasPrice=' + ethers.formatUnits(gasPrice, 'gwei') + ' gwei, est deploy cost=' + ethers.formatEther(deployCostEst) + ' BNB, balance=' + ethers.formatEther(balAfterFund) + ' BNB');
if (deployCostEst > balAfterFund) {
  console.log('ABORT: gas price too high for funded balance. Refunding...');
  const refund = balAfterFund - 21000n * gasPrice;
  if (refund > 0n) {
    const tx = await deployer.sendTransaction({ to: WALLET_B, value: refund, gasLimit: 21000, gasPrice });
    await tx.wait();
    console.log('REFUNDED tx=' + tx.hash + ' amount=' + ethers.formatEther(refund) + ' BNB');
  }
  process.exit(2);
}

// 3. Deploy
const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode.object, deployer);
console.log('DEPLOYING AgentStreak...');
const contract = await factory.deploy(AGENT_ID);
const deployTx = contract.deploymentTransaction();
console.log('DEPLOY_TX=' + deployTx.hash);
await contract.waitForDeployment();
const address = await contract.getAddress();
const receipt = await provider.getTransactionReceipt(deployTx.hash);
console.log('CONTRACT_ADDRESS=' + address);
console.log('DEPLOY_BLOCK=' + receipt.blockNumber + ' gasUsed=' + receipt.gasUsed.toString() + ' status=' + receipt.status);
if (receipt.status !== 1) { console.log('DEPLOY FAILED on-chain.'); process.exit(3); }

// 4. Refund leftover to wallet B
const balLeft = await provider.getBalance(deployer.address);
const refund2 = balLeft - 21000n * gasPrice - ethers.parseUnits('0.0000005', 'ether');
if (refund2 > 0n) {
  try {
    const tx = await deployer.sendTransaction({ to: WALLET_B, value: refund2, gasLimit: 21000, gasPrice });
    await tx.wait();
    console.log('REFUNDED tx=' + tx.hash + ' amount=' + ethers.formatEther(refund2) + ' BNB');
  } catch (e) { console.log('REFUND FAILED (leftover ' + ethers.formatEther(balLeft) + ' BNB stays in ephemeral deployer): ' + String(e.message || e).slice(0, 120)); }
} else {
  console.log('No leftover to refund (balance=' + ethers.formatEther(balLeft) + ' BNB).');
}
console.log('DEPLOY_DONE contract=' + address);
