#!/usr/bin/env bash
# Push live marks into testnet AggregatorV3.
# Prefer Robinhood mainnet Chainlink when fresh (<2m); else Extended REST.
# Defaults: BTC + ETH. Extra pairs via MARK_PAIRS or TSLA_FEED / NVDA_FEED.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
set -a
# shellcheck disable=SC1091
source "$ROOT/.env"
set +a

MAINNET_RPC="${MAINNET_RPC_URL:-https://rpc.mainnet.chain.robinhood.com}"
EXTENDED_API="${EXTENDED_API_URL:-https://api.starknet.extended.exchange/api/v1}"
RPC_URL="${RPC_URL:?RPC_URL required}"
PRIVATE_KEY="${PRIVATE_KEY:?PRIVATE_KEY required}"
CHAINLINK_MAX_AGE_S="${CHAINLINK_MAX_AGE_S:-120}"

CL_BTC="${CHAINLINK_BTC_USD:-0xa2c5184bF03d373Dc9dE4876eb4Bce595B460251}"
CL_ETH="${CHAINLINK_ETH_USD:-0x78F3556b67E17Df817D51Ef5a990cDaF09E8d3A9}"
CL_TSLA="${CHAINLINK_TSLA_USD:-0x4A1166a659A55625345e9515b32adECea5547C38}"
CL_NVDA="${CHAINLINK_NVDA_USD:-0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15}"
BTC_FEED="${BTC_FEED:-0x104D9Fd02A550496cB35137D8333172b6CC5E77A}"
ETH_FEED="${ETH_FEED:-0x380a51874789e4d1362c07ecB27BE7FC3D040F38}"

pairs=()
if [[ -n "${MARK_PAIRS:-}" ]]; then
  IFS=',' read -ra raw_pairs <<< "$MARK_PAIRS"
  for chunk in "${raw_pairs[@]}"; do
    pairs+=("$chunk")
  done
else
  pairs+=("btc:${CL_BTC}:${BTC_FEED}:BTC-USD")
  pairs+=("eth:${CL_ETH}:${ETH_FEED}:ETH-USD")
  if [[ -n "${TSLA_FEED:-}" ]]; then
    pairs+=("tsla:${CL_TSLA}:${TSLA_FEED}:TSLA-USD")
  fi
  if [[ -n "${NVDA_FEED:-}" ]]; then
    pairs+=("nvda:${CL_NVDA}:${NVDA_FEED}:NVDA-USD")
  fi
fi

live_answer() {
  local mainnet="$1" extended="$2"
  local answer updated now age
  now=$(date -u +%s)
  if answer=$(cast call "$mainnet" "latestRoundData()(uint80,int256,uint256,uint256,uint80)" --rpc-url "$MAINNET_RPC" 2>/dev/null); then
    updated=$(echo "$answer" | awk 'NR==4{print $1}')
    answer=$(echo "$answer" | awk 'NR==2{print $1}')
    age=$((now - updated))
    if [[ -n "$answer" && "$answer" != "0" && "$age" -le "$CHAINLINK_MAX_AGE_S" ]]; then
      echo "$answer"
      return 0
    fi
  fi
  # Extended mark → 1e8
  python3 - <<PY
import json, urllib.request
url = "${EXTENDED_API}/info/markets?market=${extended}"
with urllib.request.urlopen(url) as r:
    body = json.load(r)
mark = float(body["data"][0]["marketStats"]["markPrice"])
print(int(round(mark * 1e8)))
PY
}

sync_one() {
  local key="$1" mainnet="$2" testnet="$3" extended="${4:-}"
  local answer
  answer=$(live_answer "$mainnet" "$extended")
  if [[ -z "$answer" || "$answer" == "0" ]]; then
    echo "skip $key: bad live answer" >&2
    return 1
  fi
  echo "$key live=$answer → testnet $testnet"
  cast send "$testnet" "setAnswer(int256)" "$answer" \
    --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --gas-price 20000001 >/dev/null
}

for chunk in "${pairs[@]}"; do
  IFS=':' read -r key mainnet testnet extended <<< "$chunk"
  sync_one "$key" "$mainnet" "$testnet" "${extended:-}"
done

ORACLE="${ORACLE:-}"
if [[ -n "$ORACLE" ]]; then
  for chunk in "${pairs[@]}"; do
    IFS=':' read -r key _mainnet testnet _extended <<< "$chunk"
    feed_id=$(cast --to-bytes32 "$(cast --to-uint256 "$testnet")")
    echo -n "oracle $key: "
    cast call "$ORACLE" "getPrice(bytes32)(uint256,uint256)" "$feed_id" --rpc-url "$RPC_URL" || true
  done
fi
echo "synced"
