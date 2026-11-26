import { readFileSync, writeFileSync } from "node:fs";
import {
  createPublicClient,
  createWalletClient,
  defineChain,
  encodeDeployData,
  encodeFunctionData,
  getContractAddress,
  http,
} from "../../frontend/node_modules/viem/_esm/index.js";
import { privateKeyToAccount } from "../../frontend/node_modules/viem/_esm/accounts/index.js";

const artifact = JSON.parse(
  readFileSync(new URL("../out/AggregatorV3Feed.sol/AggregatorV3Feed.json", import.meta.url), "utf8"),
);
const ENGINE = "0x5135288399BCdDa309A5299244c46958477B7d91";
const chain = defineChain({
  id: 46630,
  name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [process.env.RPC_URL] } },
});

const missing = [
  ["hype", 7, 30, "HYPE / USD", "extended", "HYPE-USD"],
  ["tsla", 16, 10, "TSLA / USD", "rh", "TSLA"],
];

async function priceOf(kind, symbol) {
  if (kind === "rh") {
    const res = await fetch(`https://api.robinhood.com/rhj/prices/${symbol}`);
    if (!res.ok) throw new Error(`Robinhood ${res.status}`);
    const body = await res.json();
    const quote = body?.quotes?.[0];
    const mid = (Number(quote?.tokenBid) + Number(quote?.tokenAsk)) / 2;
    if (!Number.isFinite(mid) || mid <= 0) throw new Error(`no robinhood mark ${symbol}`);
    return BigInt(Math.round(mid * 1e8));
  }
  const res = await fetch(
    `https://api.starknet.extended.exchange/api/v1/info/markets?market=${encodeURIComponent(symbol)}`,
  );
  if (!res.ok) throw new Error(`Extended ${res.status}`);
  const body = await res.json();
  const mark = Number(body?.data?.[0]?.marketStats?.markPrice ?? 0);
  if (!Number.isFinite(mark) || mark <= 0) throw new Error(`no mark ${symbol}`);
  return BigInt(Math.round(mark * 1e8));
}

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const publicClient = createPublicClient({ chain, transport: http(process.env.RPC_URL) });
const fees = { maxPriorityFeePerGas: 2_000_000_000n, maxFeePerGas: 4_000_000_000n };
const listAbi = [
  {
    type: "function",
    name: "listMarket",
    stateMutability: "nonpayable",
    inputs: [
      { name: "marketId", type: "uint32" },
      { name: "pythFeedId", type: "bytes32" },
      { name: "maxLeverage", type: "uint32" },
      { name: "maintenanceMarginBps", type: "uint32" },
    ],
    outputs: [],
  },
];
const feedAbi = [
  {
    type: "function",
    name: "setAnswer",
    stateMutability: "nonpayable",
    inputs: [{ name: "answer", type: "int256" }],
    outputs: [],
  },
];

const file = new URL("./listed-feeds.json", import.meta.url);
const listed = JSON.parse(readFileSync(file, "utf8"));
const planned = [];
for (const [key, id, lev, desc, kind, symbol] of missing) {
  const current = listed.find((item) => item.key === key);
  if (current?.feed) {
    const code = await publicClient.getBytecode({ address: current.feed });
    if (code && code !== "0x") {
      console.log(`${key} already live ${current.feed}`);
      continue;
    }
  }
  const px = await priceOf(kind, symbol);
  let landed = false;
  for (let attempt = 0; attempt < 8 && !landed; attempt++) {
    const nonce = BigInt(
      await publicClient.getTransactionCount({ address: account.address, blockTag: "pending" }),
    );
    const feed = getContractAddress({ from: account.address, nonce });
    const feedId = `0x${feed.slice(2).padStart(64, "0")}`;
    const deployData = encodeDeployData({
      abi: artifact.abi,
      bytecode: artifact.bytecode.object,
      args: [account.address, 8, desc],
    });
    const signed = await Promise.all([
      account.signTransaction({ chainId: chain.id, nonce, data: deployData, gas: 12_000_000n, ...fees }),
      account.signTransaction({
        chainId: chain.id,
        nonce: nonce + 1n,
        to: feed,
        data: encodeFunctionData({ abi: feedAbi, functionName: "setAnswer", args: [px] }),
        gas: 4_000_000n,
        ...fees,
      }),
      account.signTransaction({
        chainId: chain.id,
        nonce: nonce + 2n,
        to: ENGINE,
        data: encodeFunctionData({
          abi: listAbi,
          functionName: "listMarket",
          args: [id, feedId, lev, 100],
        }),
        gas: 4_000_000n,
        ...fees,
      }),
    ]);
    try {
      const hashes = [];
      for (const raw of signed) hashes.push(await publicClient.sendRawTransaction({ serializedTransaction: raw }));
      for (const hash of hashes) {
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        if (receipt.status !== "success") throw new Error(`reverted ${hash}`);
      }
      planned.push({ key, id, leverage: lev, feed });
      landed = true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!/nonce/i.test(message) || attempt === 7) throw error;
    }
  }
}

for (const row of planned) {
  const current = listed.find((item) => item.key === row.key);
  if (current) current.feed = row.feed;
  console.log(`${row.key} ${row.id} ${row.leverage} ${row.feed}`);
}
writeFileSync(file, JSON.stringify(listed, null, 2));
