import { readFileSync, writeFileSync } from "node:fs";
import {
  createPublicClient,
  defineChain,
  encodeDeployData,
  encodeFunctionData,
  http,
} from "../../frontend/node_modules/viem/_esm/index.js";
import { privateKeyToAccount } from "../../frontend/node_modules/viem/_esm/accounts/index.js";

const artifact = JSON.parse(
  readFileSync(new URL("../out/AggregatorV3Feed.sol/AggregatorV3Feed.json", import.meta.url), "utf8"),
);
const ENGINE = "0x5135288399BCdDa309A5299244c46958477B7d91";
const ORACLE = "0x59f63f4499A5136B53dB4Bdb83d11DFa9b303D8B";
const MARKET_ID = 19;
const MAX_LEVERAGE = 50;
const MAINTENANCE_BPS = 100;

const rpc = process.env.RPC_URL || "https://rpc.testnet.chain.robinhood.com/rpc";
const chain = defineChain({
  id: 46630,
  name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [rpc] } },
});

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
  {
    type: "function",
    name: "markets",
    stateMutability: "view",
    inputs: [{ name: "marketId", type: "uint32" }],
    outputs: [
      { name: "pythFeedId", type: "bytes32" },
      { name: "maxLeverage", type: "uint32" },
      { name: "maintenanceMarginBps", type: "uint32" },
      { name: "active", type: "bool" },
    ],
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

const oracleAbi = [
  {
    type: "function",
    name: "getPrice",
    stateMutability: "view",
    inputs: [{ name: "feedId", type: "bytes32" }],
    outputs: [
      { name: "price", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
    ],
  },
];

async function liveAntPrice1e8() {
  const res = await fetch("https://api.robinhood.com/rhj/prices/ANT");
  if (!res.ok) throw new Error(`Robinhood HTTP ${res.status}`);
  const body = await res.json();
  const quote = body?.quotes?.[0];
  const mid = (Number(quote?.tokenBid) + Number(quote?.tokenAsk)) / 2;
  if (!Number.isFinite(mid) || mid <= 0) throw new Error("No live Robinhood ANT price");
  return BigInt(Math.round(mid * 1e8));
}

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const publicClient = createPublicClient({ chain, transport: http(rpc) });

async function sendTx(tx) {
  const block = await publicClient.getBlock();
  const base = block.baseFeePerGas ?? 0n;
  const fees = {
    maxPriorityFeePerGas: 1_500_000_000n,
    maxFeePerGas: base + 3_000_000_000n,
  };
  let nonce = BigInt(
    await publicClient.getTransactionCount({ address: account.address, blockTag: "pending" }),
  );
  for (let attempt = 0; attempt < 12; attempt++) {
    const raw = await account.signTransaction({
      chainId: chain.id,
      nonce,
      ...fees,
      ...tx,
    });
    try {
      const hash = await publicClient.sendRawTransaction({ serializedTransaction: raw });
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success") throw new Error(`Reverted ${hash}`);
      return receipt;
    } catch (error) {
      const text = `${error?.details ?? ""} ${error?.message ?? ""}`;
      if (!/nonce/i.test(text) || attempt === 11) throw error;
      const stated = text.match(/state:\s*(\d+)/);
      const pending = BigInt(
        await publicClient.getTransactionCount({ address: account.address, blockTag: "pending" }),
      );
      nonce = stated ? BigInt(stated[1]) : pending;
      if (pending > nonce) nonce = pending;
    }
  }
  throw new Error("Exceeded nonce retries");
}

const existing = await publicClient.readContract({
  address: ENGINE,
  abi: listAbi,
  functionName: "markets",
  args: [MARKET_ID],
});
if (existing[3]) {
  if (Number(existing[1]) === MAX_LEVERAGE) {
    console.log(`Market ${MARKET_ID} already active at ${MAX_LEVERAGE}x with feedId ${existing[0]}`);
    process.exit(0);
  }
  const updateReceipt = await sendTx({
    to: ENGINE,
    data: encodeFunctionData({
      abi: listAbi,
      functionName: "listMarket",
      args: [MARKET_ID, existing[0], MAX_LEVERAGE, MAINTENANCE_BPS],
    }),
    gas: 2_000_000n,
  });
  const after = await publicClient.readContract({
    address: ENGINE,
    abi: listAbi,
    functionName: "markets",
    args: [MARKET_ID],
  });
  console.log(
    JSON.stringify(
      {
        updated: true,
        marketId: MARKET_ID,
        feedId: after[0],
        maxLeverage: Number(after[1]),
        maintenanceMarginBps: Number(after[2]),
        active: after[3],
        tx: updateReceipt.transactionHash,
      },
      null,
      2,
    ),
  );
  process.exit(0);
}

const px = await liveAntPrice1e8();

const deployData = encodeDeployData({
  abi: artifact.abi,
  bytecode: artifact.bytecode.object,
  args: [account.address, 8, "ANT / USD"],
});
const deployReceipt = await sendTx({ data: deployData, gas: 4_000_000n });
const feed = deployReceipt.contractAddress;
if (!feed) throw new Error("Missing deployed feed address");
const feedId = `0x${feed.slice(2).padStart(64, "0")}`;

const setReceipt = await sendTx({
  to: feed,
  data: encodeFunctionData({ abi: feedAbi, functionName: "setAnswer", args: [px] }),
  gas: 2_000_000n,
});

const listReceipt = await sendTx({
  to: ENGINE,
  data: encodeFunctionData({
    abi: listAbi,
    functionName: "listMarket",
    args: [MARKET_ID, feedId, MAX_LEVERAGE, MAINTENANCE_BPS],
  }),
  gas: 2_000_000n,
});

const [oraclePrice, updatedAt] = await publicClient.readContract({
  address: ORACLE,
  abi: oracleAbi,
  functionName: "getPrice",
  args: [feedId],
});

const file = new URL("./listed-feeds.json", import.meta.url);
const listed = JSON.parse(readFileSync(file, "utf8"));
const next = listed.filter((row) => row.key !== "ant" && row.id !== MARKET_ID);
next.push({ key: "ant", id: MARKET_ID, leverage: MAX_LEVERAGE, feed: feed.toLowerCase() });
writeFileSync(file, JSON.stringify(next, null, 2));

console.log(
  JSON.stringify(
    {
      key: "ant",
      marketId: MARKET_ID,
      leverage: MAX_LEVERAGE,
      feed: feed.toLowerCase(),
      feedId,
      initialPrice1e8: px.toString(),
      oraclePrice: oraclePrice.toString(),
      updatedAt: updatedAt.toString(),
      txs: [deployReceipt.transactionHash, setReceipt.transactionHash, listReceipt.transactionHash],
    },
    null,
    2,
  ),
);
