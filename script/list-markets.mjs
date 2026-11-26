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

const rows = [
  ["bnb", 3, 40, 55_427_240_535n, "BNB / USD"],
  ["xrp", 4, 30, 95_297_640n, "XRP / USD"],
  ["sol", 5, 50, 7_078_782_375n, "SOL / USD"],
  ["trx", 6, 30, 30_340_635n, "TRX / USD"],
  ["hype", 7, 30, 6_116_217_787n, "HYPE / USD"],
  ["zec", 8, 30, 74_723_177_304n, "ZEC / USD"],
  ["xmr", 9, 30, 52_241_164_235n, "XMR / USD"],
  ["doge", 10, 30, 5_646_047n, "DOGE / USD"],
  ["nvda", 11, 10, 14_316_589_039n, "NVDA / USD"],
  ["spcx", 12, 10, 12_899_500_000n, "SPCX / USD"],
  ["meta", 13, 10, 63_209_206_728n, "META / USD"],
  ["coin", 14, 10, 10_174_000_000n, "COIN / USD"],
  ["tteq", 15, 10, 3_383_500_000n, "TTEQ / USD"],
  ["tsla", 16, 10, 38_445_000_000n, "TSLA / USD"],
  ["googl", 17, 10, 27_740_378_494n, "GOOGL / USD"],
  ["aapl", 18, 10, 34_816_930_567n, "AAPL / USD"],
];

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const publicClient = createPublicClient({ chain, transport: http(process.env.RPC_URL) });
const wallet = createWalletClient({ account, chain, transport: http(process.env.RPC_URL) });
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

async function pendingNonce() {
  return BigInt(
    await publicClient.getTransactionCount({ address: account.address, blockTag: "pending" }),
  );
}

const planned = [];
const hashes = [];

for (const [key, id, lev, px, desc] of rows) {
  let landed = false;
  for (let attempt = 0; attempt < 8 && !landed; attempt++) {
    const nonce = await pendingNonce();
    const feed = getContractAddress({ from: account.address, nonce });
    const feedId = `0x${feed.slice(2).padStart(64, "0")}`;
    const deployData = encodeDeployData({
      abi: artifact.abi,
      bytecode: artifact.bytecode.object,
      args: [account.address, 8, desc],
    });
    const signed = await Promise.all([
      account.signTransaction({
        chainId: chain.id,
        nonce,
        data: deployData,
        gas: 4_000_000n,
        ...fees,
      }),
      account.signTransaction({
        chainId: chain.id,
        nonce: nonce + 1n,
        to: feed,
        data: encodeFunctionData({ abi: feedAbi, functionName: "setAnswer", args: [px] }),
        gas: 2_000_000n,
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
        gas: 2_000_000n,
        ...fees,
      }),
    ]);
    try {
      const sent = [];
      for (const raw of signed) {
        sent.push(await publicClient.sendRawTransaction({ serializedTransaction: raw }));
      }
      planned.push({ key, id, lev, feed });
      hashes.push(...sent);
      landed = true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!/nonce/i.test(message) || attempt === 7) throw error;
    }
  }
}
for (const hash of hashes) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") {
    console.error(`reverted ${hash}`);
    process.exit(1);
  }
}

const out = planned.map((row) => ({ key: row.key, id: row.id, leverage: row.lev, feed: row.feed }));
writeFileSync(new URL("./listed-feeds.json", import.meta.url), JSON.stringify(out, null, 2));
for (const row of out) console.log(`${row.key} ${row.id} ${row.leverage} ${row.feed}`);
