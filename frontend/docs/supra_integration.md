# Supra Integration Guide

This guide explains how the frontend communicates with SupraLottery contracts.

## 1. Prerequisites
- Whitelisting approved by Supra support (see `SupraLottery/docs/testnet_runbook.md`).
- VRF permissions for required contracts (deposit/configure/record APIs).
- Configured StarKey (or other Supra wallet) for signing transactions.
- RPC endpoints: `https://rpc-testnet.supra.com` or `https://rpc-mainnet.supra.com`.

## 2. API layer (`src/api/supraClient.ts`)
- View requests use JSON-RPC `move_view` (e.g. `lottery_core::core_main_v2::get_lottery_status`).
- Mutating requests build BCS transactions (`EntryFunction`) and sign them through StarKey SDK helpers.
- Helper functions in the file convert RPC responses to typed objects (`LotteryStatus`, `WhitelistStatus`, etc.).

## 3. Environment variables
```
VITE_API_MODE=supra
NEXT_PUBLIC_SUPRA_RPC_URL=https://rpc-testnet.supra.com
NEXT_PUBLIC_SUPRA_CHAIN_ID=6
```
Mock mode remains available through static JSON.

## 4. Error handling
- Log HTTP and RPC errors via `supraClient.handleError`.
- Handle `EXCEEDED_MAX_TRANSACTION_SIZE` and `TRANSACTION_EXPIRED` by prompting users to retry with fresh sequence numbers.

## 5. References
- https://docs.supra.com
- StarKey SDK (examples of signing)
- `supra/scripts/sync_lottery_queues.sh`

