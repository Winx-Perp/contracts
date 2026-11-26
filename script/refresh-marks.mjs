import { readFileSync } from "node:fs";
import { createPublicClient, createWalletClient, defineChain, encodeFunctionData, http } from "../../frontend/node_modules/viem/_esm/index.js";
import { privateKeyToAccount } from "../../frontend/node_modules/viem/_esm/accounts/index.js";

const feeds = JSON.parse(readFileSync(new URL("./listed-feeds.json", import.meta.url), "utf8"));
const chain = defineChain({
  id: 46630,
  name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [process.env.RPC_URL] } },
});
const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const publicClient = createPublicClient({ chain, transport: http(process.env.RPC_URL) });
const wallet = createWalletClient({ account, chain, transport: http(process.env.RPC_URL) });
const abi = [{ type: "function", name: "setAnswer", stateMutability: "nonpayable", inputs: [{ name: "answer", type: "int256" }], outputs: [] }];

const crypto = {
  bnb: "BNB-USD", xrp: "XRP-USD", sol: "SOL-USD", trx: "TRX-USD",
  hype: "HYPE-USD", zec: "ZEC-USD", xmr: "XMR-USD", doge: "DOGE-USD",
};
const stocks = new Set(["nvda", "spcx", "meta", "coin", "tteq", "tsla", "googl", "aapl"]);

async function price(row) {
  if (stocks.has(row.key)) {
    const res = await fetch(`https://api.robinhood.com/rhj/prices/${row.key.toUpperCase()}`);
    const body = await res.json();
    const q = body.quotes[0];
    return BigInt(Math.round(((Number(q.tokenBid) + Number(q.tokenAsk)) / 2) * 1e8));
  }
  const res = await fetch(`https://api.starknet.extended.exchange/api/v1/info/markets?market=${crypto[row.key]}`);
  const body = await res.json();
  return BigInt(Math.round(Number(body.data[0].marketStats.markPrice) * 1e8));
}

let nonce = BigInt(await publicClient.getTransactionCount({ address: account.address, blockTag: "pending" }));
const hashes = [];
for (const row of feeds) {
  const px = await price(row);
  const data = encodeFunctionData({ abi, functionName: "setAnswer", args: [px] });
  hashes.push(await wallet.sendTransaction({
    nonce,
    to: row.feed,
    data,
    gas: 2_000_000n,
    maxPriorityFeePerGas: 2_000_000_000n,
    maxFeePerGas: 4_000_000_000n,
  }));
  nonce += 1n;
  console.log(`${row.key} ${px}`);
}
for (const hash of hashes) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") process.exit(1);
}
console.log("refreshed", hashes.length);
