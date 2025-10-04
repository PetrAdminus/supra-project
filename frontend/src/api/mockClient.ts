import type {
  AdminConfig,
  AdminMutationResult,
  LotteryEvent,
  LotteryStatus,
  PurchaseTicketInput,
  RecordClientWhitelistInput,
  RecordConsumerWhitelistInput,
  TicketPurchase,
  TreasuryBalances,
  TreasuryConfig,
  UpdateGasConfigInput,
  UpdateTreasuryControlsInput,
  UpdateTreasuryDistributionInput,
  UpdateVrfConfigInput,
  WhitelistStatus,
} from "./types";
import lotteryStatusJson from "../mocks/lottery-status.json";
import whitelistStatus from "../mocks/whitelist-status.json";
import ticketsJson from "../mocks/tickets.json";
import eventsJson from "../mocks/events.json";
import adminConfigJson from "../mocks/admin-config.json";

const NETWORK_LATENCY_MS = 180;
const lotterySnapshot: LotteryStatus = structuredClone(lotteryStatusJson as LotteryStatus);
const ticketStore: TicketPurchase[] = structuredClone(ticketsJson as TicketPurchase[]);
const eventStore: LotteryEvent[] = structuredClone(eventsJson as LotteryEvent[]);
const adminConfigStore: AdminConfig = structuredClone(adminConfigJson as AdminConfig);

let ticketSequence = ticketStore.length;

function simulateDelay<T>(payload: T): Promise<T> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(structuredClone(payload)), NETWORK_LATENCY_MS);
  });
}

function generateTicketId(round: number): string {
  ticketSequence += 1;
  return `TICK-${round}-${ticketSequence.toString().padStart(3, "0")}`;
}

function generateTxHash(): string {
  return `0x${Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join("")}`;
}

function toNumber(value: string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function formatAmount(value: number): string {
  return value.toFixed(2);
}

function applyTreasurySplit(ticketPriceSupra: number): void {
  const distribution = adminConfigStore.treasury.config.distributionBp;
  const jackpotShare = (ticketPriceSupra * distribution.jackpot) / 10_000;
  const prizeShare = (ticketPriceSupra * distribution.prize) / 10_000;
  const treasuryShare = (ticketPriceSupra * distribution.treasury) / 10_000;
  const marketingShare = ticketPriceSupra - jackpotShare - prizeShare - treasuryShare;

  const balances = adminConfigStore.treasury.balances;
  balances.jackpotSupra = formatAmount(toNumber(balances.jackpotSupra) + jackpotShare);
  balances.prizeSupra = formatAmount(toNumber(balances.prizeSupra) + prizeShare);
  balances.treasurySupra = formatAmount(toNumber(balances.treasurySupra) + treasuryShare);
  balances.marketingSupra = formatAmount(toNumber(balances.marketingSupra) + marketingShare);
  balances.updatedAt = new Date().toISOString();
}

export async function fetchAdminConfigMock(): Promise<AdminConfig> {
  return simulateDelay(adminConfigStore);
}

export async function fetchTreasuryConfigMock(): Promise<TreasuryConfig> {
  return simulateDelay(adminConfigStore.treasury.config);
}

export async function fetchTreasuryBalancesMock(): Promise<TreasuryBalances> {
  return simulateDelay(adminConfigStore.treasury.balances);
}

function createMutationResult(): AdminMutationResult {
  return {
    txHash: generateTxHash(),
    submittedAt: new Date().toISOString(),
  };
}

export async function updateGasConfigMock(input: UpdateGasConfigInput): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.gas = {
    maxGasFee: input.maxGasFee,
    minBalance: input.minBalance,
    updatedAt: result.submittedAt,
  };
  return simulateDelay(result);
}

export async function updateVrfConfigMock(input: UpdateVrfConfigInput): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.vrf = {
    maxGasPrice: input.maxGasPrice,
    maxGasLimit: input.maxGasLimit,
    callbackGasPrice: input.callbackGasPrice,
    callbackGasLimit: input.callbackGasLimit,
    requestedRngCount: input.requestedRngCount,
    clientSeed: input.clientSeed,
    lastConfiguredAt: result.submittedAt,
  };
  return simulateDelay(result);
}

export async function updateTreasuryDistributionMock(
  input: UpdateTreasuryDistributionInput,
): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.treasury.config.distributionBp = {
    jackpot: input.jackpotBp,
    prize: input.prizeBp,
    treasury: input.treasuryBp,
    marketing: input.marketingBp,
  };
  adminConfigStore.treasury.config.updatedAt = result.submittedAt;
  adminConfigStore.treasury.balances.updatedAt = result.submittedAt;
  return simulateDelay(result);
}

export async function updateTreasuryControlsMock(
  input: UpdateTreasuryControlsInput,
): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.treasury.config.ticketPriceSupra = input.ticketPriceSupra;
  adminConfigStore.treasury.config.treasuryAddress = input.treasuryAddress;
  adminConfigStore.treasury.config.salesEnabled = input.salesEnabled;
  adminConfigStore.treasury.config.updatedAt = result.submittedAt;
  adminConfigStore.treasury.balances.updatedAt = result.submittedAt;
  return simulateDelay(result);
}

export async function recordClientWhitelistSnapshotMock(
  input: RecordClientWhitelistInput,
): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.whitelist.clientConfigured = true;
  adminConfigStore.whitelist.client = {
    maxGasPrice: input.maxGasPrice,
    maxGasLimit: input.maxGasLimit,
    minBalanceLimit: input.minBalanceLimit,
    updatedAt: result.submittedAt,
  };
  return simulateDelay(result);
}

export async function recordConsumerWhitelistSnapshotMock(
  input: RecordConsumerWhitelistInput,
): Promise<AdminMutationResult> {
  const result = createMutationResult();
  adminConfigStore.whitelist.consumerConfigured = true;
  adminConfigStore.whitelist.consumer = {
    callbackGasPrice: input.callbackGasPrice,
    callbackGasLimit: input.callbackGasLimit,
    updatedAt: result.submittedAt,
  };
  return simulateDelay(result);
}

export async function fetchLotteryStatusMock(): Promise<LotteryStatus> {
  return simulateDelay(lotterySnapshot);
}

export async function fetchWhitelistStatusMock(): Promise<WhitelistStatus> {
  return simulateDelay(whitelistStatus as WhitelistStatus);
}

export async function fetchTicketsMock(): Promise<TicketPurchase[]> {
  return simulateDelay(ticketStore);
}

export async function fetchEventsMock(): Promise<LotteryEvent[]> {
  return simulateDelay(eventStore);
}

export async function purchaseTicketMock(input: PurchaseTicketInput): Promise<TicketPurchase> {
  const now = new Date();
  const ticket: TicketPurchase = {
    ticketId: generateTicketId(input.round),
    round: input.round,
    numbers: input.numbers,
    purchaseTime: now.toISOString(),
    status: "pending",
    txHash: generateTxHash(),
  };

  ticketStore.unshift(ticket);
  lotterySnapshot.ticketsSold += 1;

  applyTreasurySplit(toNumber(adminConfigStore.treasury.config.ticketPriceSupra));

  eventStore.unshift({
    eventId: `EVT-${eventStore.length + 1}`,
    type: "TicketBought",
    round: input.round,
    timestamp: now.toISOString(),
    details: `Mock purchase of ticket ${ticket.ticketId}`,
    txHash: ticket.txHash,
    status: "success",
  });

  return simulateDelay(ticket);
}
