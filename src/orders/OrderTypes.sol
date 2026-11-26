// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Order kinds the engine can route. Only Market is implemented in-protocol
/// (`open` / `close`). Register your own `IOrderModule` for the rest.
enum OrderKind {
    Market,
    Limit,
    StopMarket,
    TakeMarket,
    StopLimit,
    TakeLimit,
    Twap
}
