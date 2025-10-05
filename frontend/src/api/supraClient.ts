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
  SupraCommandInfo,
  UpdateGasConfigInput,
  UpdateTreasuryControlsInput,
  UpdateTreasuryDistributionInput,
  UpdateVrfConfigInput,
  WhitelistStatus,
} from "./types";
import {
  fetchAdminConfigMock,
  fetchTreasuryBalancesMock,
  fetchTreasuryConfigMock,
} from "./mockClient";

const DEFAULT_BASE_URL = "http://localhost:8000";
const baseUrl = (import.meta.env.VITE_SUPRA_API_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, "");

interface CommandResponse {
  command: string;
  args: string[];
  returncode: number;
  stdout: string;
  stderr: string;
}

interface CommandRequestPayload {
  args?: string[];
  supra_config?: string | null;
}

interface SupraStatusResponse {
  timestamp?: string;
  profile?: string;
  calculation?: unknown;
  lottery?: {
    status?: unknown;
    vrf_request_config?: unknown;
    whitelist_status?: unknown;
    ticket_price?: unknown;
    registered_tickets?: unknown;
    client_whitelist_snapshot?: unknown;
    min_balance_snapshot?: unknown;
    consumer_whitelist_snapshot?: unknown;
  };
  deposit?: {
    balance?: unknown;
    min_balance?: unknown;
    min_balance_reached?: unknown;
    subscription_info?: unknown;
    contract_details?: unknown;
    whitelisted_contracts?: unknown;
    max_gas_price?: unknown;
    max_gas_limit?: unknown;
  };
  treasury?: {
    config?: unknown;
    recipients?: unknown;
    balance?: unknown;
    total_supply?: unknown;
    metadata?: unknown;
  };
}

type JsonRecord = Record<string, unknown>;

function toRecord(value: unknown): JsonRecord | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonRecord;
  }
  return null;
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => toStringOrNull(item))
    .filter((item): item is string => item !== null && item.length > 0);
}

function firstRecord(value: unknown): JsonRecord | null {
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return null;
    }
    return toRecord(value[0]);
  }
  return toRecord(value);
}

function toStringOrNull(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") {
    return String(value);
  }
  return null;
}

function toNumberOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  if (typeof value === "boolean") {
    return value ? 1 : 0;
  }
  return null;
}

function toCliValue(value: string | number): string {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      throw new Error("Supra CLI аргумент не может быть пустым");
    }
    return trimmed;
  }
  if (!Number.isFinite(value)) {
    throw new Error("Supra CLI аргумент должен быть конечным числом");
  }
  return String(value);
}

function normalizeTimestamp(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  if (typeof value === "number") {
    const date = new Date(value * 1000);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  return null;
}

function ensureTimestamp(value: string | null): string {
  return value ?? new Date().toISOString();
}

function toUnknownArray(value: unknown): unknown[] {
  if (Array.isArray(value)) {
    return value;
  }
  if (value && typeof value === "object") {
    const entries = Object.values(value as Record<string, unknown>);
    if (entries.length === 1 && Array.isArray(entries[0])) {
      return entries[0] as unknown[];
    }
  }
  return [];
}

function extractVerificationGasValue(payload: SupraStatusResponse): string | null {
  const calculation = toRecord(payload.calculation);
  const deposit = toRecord(payload.deposit);
  const contractDetails = firstRecord(deposit?.contract_details);

  return (
    toStringOrNull(calculation?.verification_gas_value) ??
    toStringOrNull(calculation?.verification_gas) ??
    toStringOrNull(contractDetails?.verification_gas_value)
  );
}

function parseTreasuryDistribution(
  payload: SupraStatusResponse,
): TreasuryConfig["distributionBp"] | null {
  const raw = toUnknownArray(payload.treasury?.config);
  if (raw.length < 4) {
    return null;
  }

  const jackpot = toNumberOrNull(raw[0]);
  const prize = toNumberOrNull(raw[1]);
  const treasury = toNumberOrNull(raw[2]);
  const marketing = toNumberOrNull(raw[3]);

  if (jackpot === null || prize === null || treasury === null || marketing === null) {
    return null;
  }

  return {
    jackpot,
    prize,
    treasury,
    marketing,
  };
}

function parseTreasuryAddress(payload: SupraStatusResponse): string | null {
  const recipients = toUnknownArray(payload.treasury?.recipients);
  if (recipients.length === 0) {
    return null;
  }
  return toStringOrNull(recipients[0]);
}

function buildTreasuryConfig(
  payload: SupraStatusResponse,
  fallback: TreasuryConfig,
): TreasuryConfig {
  const parsedDistribution = parseTreasuryDistribution(payload);
  const distribution = parsedDistribution ?? { ...fallback.distributionBp };
  const ticketPriceRaw = Array.isArray(payload.lottery?.ticket_price)
    ? (payload.lottery?.ticket_price as unknown[])[0]
    : payload.lottery?.ticket_price;
  const ticketPrice = toStringOrNull(ticketPriceRaw) ?? fallback.ticketPriceSupra;
  const parsedAddress = parseTreasuryAddress(payload);
  const treasuryAddress = parsedAddress ?? fallback.treasuryAddress;
  const hasRealtimeData = Boolean(
    parsedDistribution || parsedAddress || ticketPriceRaw !== undefined,
  );
  const updatedAt = hasRealtimeData
    ? ensureTimestamp(normalizeTimestamp(payload.timestamp))
    : fallback.updatedAt;

  return {
    ticketPriceSupra: ticketPrice,
    salesEnabled: fallback.salesEnabled,
    treasuryAddress,
    distributionBp: distribution,
    updatedAt,
  };
}

function buildTreasuryBalances(
  payload: SupraStatusResponse,
  fallback: TreasuryBalances,
): TreasuryBalances {
  const status = firstRecord(payload.lottery?.status);
  const parsedJackpot = toStringOrNull(status?.jackpot_amount);
  const parsedBalance = toStringOrNull(payload.treasury?.balance);
  const jackpot = parsedJackpot ?? fallback.jackpotSupra;
  const treasuryBalance = parsedBalance ?? fallback.treasurySupra;
  const hasRealtimeData = Boolean(parsedJackpot || parsedBalance);
  const updatedAt = hasRealtimeData
    ? ensureTimestamp(normalizeTimestamp(payload.timestamp))
    : fallback.updatedAt;

  return {
    jackpotSupra: jackpot,
    prizeSupra: fallback.prizeSupra,
    treasurySupra: treasuryBalance,
    marketingSupra: fallback.marketingSupra,
    updatedAt,
  };
}

function parseAdminGasConfig(payload: SupraStatusResponse): AdminGasConfig | null {
  const calculation = toRecord(payload.calculation);
  const deposit = toRecord(payload.deposit);

  const perRequestFee = calculation ? toNumberOrNull(calculation.per_request_fee) : null;
  const depositMinBalance = deposit ? toNumberOrNull(deposit.min_balance) : null;
  const calculatedMinBalance = calculation ? toNumberOrNull(calculation.min_balance) : null;
  const minBalance = depositMinBalance ?? calculatedMinBalance;

  if (perRequestFee === null && minBalance === null) {
    return null;
  }

  const timestamp = normalizeTimestamp(payload.timestamp);

  return {
    maxGasFee: perRequestFee ?? 0,
    minBalance: minBalance ?? 0,
    updatedAt: ensureTimestamp(timestamp),
  };
}

function parseAdminVrfConfig(payload: SupraStatusResponse): AdminVrfConfig | null {
  const deposit = toRecord(payload.deposit);
  const calculation = toRecord(payload.calculation);
  const vrfConfig = firstRecord(payload.lottery?.vrf_request_config);
  const contractDetails = firstRecord(deposit?.contract_details);

  const maxGasPrice =
    toStringOrNull(deposit?.max_gas_price) ??
    toStringOrNull(calculation?.max_gas_price) ??
    toStringOrNull(vrfConfig?.max_gas_price);
  const maxGasLimit =
    toStringOrNull(deposit?.max_gas_limit) ??
    toStringOrNull(calculation?.max_gas_limit) ??
    toStringOrNull(vrfConfig?.max_gas_limit);
  const callbackGasPrice =
    toStringOrNull(contractDetails?.callback_gas_price) ??
    toStringOrNull(vrfConfig?.callback_gas_price);
  const callbackGasLimit =
    toStringOrNull(contractDetails?.callback_gas_limit) ??
    toStringOrNull(vrfConfig?.callback_gas_limit);
  const requestedRngCount = toNumberOrNull(vrfConfig?.rng_count);
  const clientSeed = toNumberOrNull(vrfConfig?.client_seed);

  if (
    maxGasPrice === null &&
    maxGasLimit === null &&
    callbackGasPrice === null &&
    callbackGasLimit === null &&
    requestedRngCount === null &&
    clientSeed === null
  ) {
    return null;
  }

  const timestamp = normalizeTimestamp(payload.timestamp);

  return {
    maxGasPrice: maxGasPrice ?? "0",
    maxGasLimit: maxGasLimit ?? "0",
    callbackGasPrice: callbackGasPrice ?? "0",
    callbackGasLimit: callbackGasLimit ?? "0",
    requestedRngCount: requestedRngCount ?? 0,
    clientSeed: clientSeed ?? 0,
    lastConfiguredAt: ensureTimestamp(timestamp),
  };
}

function buildWhitelistConfig(
  payload: SupraStatusResponse,
  fallback: AdminConfig["whitelist"],
): AdminConfig["whitelist"] {
  const timestamp = normalizeTimestamp(payload.timestamp);
  const clientSnapshotRaw = firstRecord(payload.lottery?.client_whitelist_snapshot);
  const consumerSnapshotRaw = firstRecord(payload.lottery?.consumer_whitelist_snapshot);
  const minBalanceSnapshot = toStringOrNull(payload.lottery?.min_balance_snapshot);

  const fallbackClient = fallback.client ? { ...fallback.client } : null;
  const fallbackConsumer = fallback.consumer ? { ...fallback.consumer } : null;

  const clientSnapshot = clientSnapshotRaw
    ? {
        maxGasPrice:
          toStringOrNull(clientSnapshotRaw.max_gas_price) ?? fallbackClient?.maxGasPrice ?? "0",
        maxGasLimit:
          toStringOrNull(clientSnapshotRaw.max_gas_limit) ?? fallbackClient?.maxGasLimit ?? "0",
        minBalanceLimit:
          toStringOrNull(clientSnapshotRaw.min_balance_limit ?? minBalanceSnapshot) ??
          fallbackClient?.minBalanceLimit ??
          "0",
        updatedAt: ensureTimestamp(timestamp ?? fallbackClient?.updatedAt ?? null),
      }
    : fallbackClient;

  const consumerSnapshot = consumerSnapshotRaw
    ? {
        callbackGasPrice:
          toStringOrNull(consumerSnapshotRaw.callback_gas_price) ??
          fallbackConsumer?.callbackGasPrice ??
          "0",
        callbackGasLimit:
          toStringOrNull(consumerSnapshotRaw.callback_gas_limit) ??
          fallbackConsumer?.callbackGasLimit ??
          "0",
        updatedAt: ensureTimestamp(timestamp ?? fallbackConsumer?.updatedAt ?? null),
      }
    : fallbackConsumer;

  return {
    clientConfigured: clientSnapshotRaw !== null ? true : Boolean(clientSnapshot),
    consumerConfigured: consumerSnapshotRaw !== null ? true : Boolean(consumerSnapshot),
    client: clientSnapshot ?? null,
    consumer: consumerSnapshot ?? null,
  };
}

async function supraRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: { "Accept": "application/json" },
    ...init,
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`Supra API ${response.status}: ${text || response.statusText}`);
  }

  return (await response.json()) as T;
}

async function supraCommand(command: string, payload: CommandRequestPayload): Promise<CommandResponse> {
  return supraRequest<CommandResponse>(`/commands/${command}`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

function normalizeCommandInfo(record: unknown): SupraCommandInfo | null {
  const payload = toRecord(record);
  if (!payload) {
    return null;
  }

  const name = toStringOrNull(payload.name);
  const module = toStringOrNull(payload.module);
  const description = toStringOrNull(payload.description);

  if (!name || !module || !description) {
    return null;
  }

  return { name, module, description };
}

export async function listSupraCommandsSupra(): Promise<SupraCommandInfo[]> {
  const response = await supraRequest<unknown[]>("/commands");
  const commands = response
    .map((item) => normalizeCommandInfo(item))
    .filter((item): item is SupraCommandInfo => item !== null);

  return commands.sort((a, b) => a.name.localeCompare(b.name));
}

export const STATUS_CACHE_TTL_MS = 2_000;

interface StatusCacheRecord {
  data: SupraStatusResponse;
  expiresAt: number;
}

let statusCache: StatusCacheRecord | null = null;
let statusPromise: Promise<SupraStatusResponse> | null = null;

function getCachedStatus(): SupraStatusResponse | null {
  if (!statusCache) {
    return null;
  }

  if (statusCache.expiresAt <= Date.now()) {
    statusCache = null;
    return null;
  }

  return statusCache.data;
}

function storeStatus(data: SupraStatusResponse): void {
  statusCache = {
    data,
    expiresAt: Date.now() + STATUS_CACHE_TTL_MS,
  };
}

async function loadStatus(options?: { forceRefresh?: boolean }): Promise<SupraStatusResponse> {
  const forceRefresh = options?.forceRefresh ?? false;

  if (!forceRefresh) {
    const cached = getCachedStatus();
    if (cached) {
      return cached;
    }

    if (statusPromise) {
      return statusPromise;
    }
  }

  const query = forceRefresh ? "?refresh=1" : "";
  const request = supraRequest<SupraStatusResponse>(`/status${query}`);
  statusPromise = request;

  try {
    const result = await request;
    storeStatus(result);
    return result;
  } finally {
    if (statusPromise === request) {
      statusPromise = null;
    }
  }
}

export function invalidateSupraStatusCache(): void {
  statusCache = null;
  statusPromise = null;
}

export async function refreshSupraStatus(): Promise<SupraStatusResponse> {
  invalidateSupraStatusCache();
  return loadStatus({ forceRefresh: true });
}

const TX_HASH_REGEX = /0x[a-fA-F0-9]{64}/;

interface CommandEnvelope {
  tx_hash?: string | null;
  submitted_at?: string;
  stdout?: string;
  stderr?: string;
  [key: string]: unknown;
}

function parseCommandEnvelope(output: string): CommandEnvelope | null {
  if (!output) {
    return null;
  }

  try {
    return JSON.parse(output) as CommandEnvelope;
  } catch (error) {
    const lines = output
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    for (let index = lines.length - 1; index >= 0; index -= 1) {
      const line = lines[index];
      if (!line.startsWith("{")) {
        continue;
      }
      try {
        return JSON.parse(line) as CommandEnvelope;
      } catch (innerError) {
        continue;
      }
    }
  }
  return null;
}

function extractTxHash(...sources: Array<string | null | undefined>): string | null {
  for (const source of sources) {
    if (!source) {
      continue;
    }
    const match = source.match(TX_HASH_REGEX);
    if (match) {
      return match[0];
    }
  }
  return null;
}

function toAdminMutationResultFromCommand(
  command: string,
  response: CommandResponse,
): AdminMutationResult {
  const envelope = parseCommandEnvelope(response.stdout);

  if (response.returncode !== 0) {
    const detail = envelope?.stderr ?? response.stderr ?? response.stdout;
    throw new Error(
      `Команда ${command} завершилась с кодом ${response.returncode}: ${detail || "см. логи"}`,
    );
  }

  const submittedAt = envelope?.submitted_at ?? new Date().toISOString();
  const txHash =
    (typeof envelope?.tx_hash === "string" && envelope.tx_hash) ||
    extractTxHash(envelope?.stdout, envelope?.stderr, response.stdout, response.stderr);

  if (!txHash && import.meta.env.DEV) {
    console.warn(`Supra API: не удалось извлечь tx hash из ответа команды ${command}`);
  }

  return {
    txHash: txHash ?? "unknown",
    submittedAt,
  };
}

export async function fetchLotteryStatusSupra(): Promise<LotteryStatus> {
  const payload = await loadStatus();
  const status = firstRecord(payload.lottery?.status);
  const ticketPriceRaw = Array.isArray(payload.lottery?.ticket_price)
    ? (payload.lottery?.ticket_price as unknown[])[0]
    : payload.lottery?.ticket_price;
  const registeredTickets = toStringArray(payload.lottery?.registered_tickets);
  const subscriptionInfo = toRecord(payload.deposit?.subscription_info);

  const round =
    toNumberOrNull(status?.round) ??
    toNumberOrNull(status?.current_round) ??
    toNumberOrNull(status?.rng_response_count) ??
    toNumberOrNull(status?.rng_request_count);

  return {
    round,
    jackpotSupra: toStringOrNull(status?.jackpot_amount),
    ticketsSold:
      toNumberOrNull(status?.ticket_count) ?? (registeredTickets.length > 0 ? registeredTickets.length : null),
    ticketPriceSupra: toStringOrNull(ticketPriceRaw),
    nextDrawTime: payload.timestamp ?? null,
    vrf: {
      subscriptionId: toStringOrNull(subscriptionInfo?.subscription_id),
      requestPending: Boolean(status?.pending_request),
      lastRequestTime: normalizeTimestamp(subscriptionInfo?.last_request_time),
      lastFulfillmentTime: normalizeTimestamp(subscriptionInfo?.last_fulfillment_time),
    },
  };
}

export async function fetchWhitelistStatusSupra(): Promise<WhitelistStatus> {
  const payload = await loadStatus();
  const whitelist = firstRecord(payload.lottery?.whitelist_status);
  const aggregatorRaw = whitelist?.aggregator;

  let aggregator: string | null = null;
  if (Array.isArray(aggregatorRaw)) {
    aggregator = aggregatorRaw.length > 0 ? toStringOrNull(aggregatorRaw[0]) : null;
  } else {
    aggregator = toStringOrNull(aggregatorRaw);
  }

  return {
    account: aggregator,
    profile: payload.profile ?? null,
    isWhitelisted: Boolean(aggregator),
    checkedAt: payload.timestamp ?? null,
  };
}

export async function fetchTicketsSupra(): Promise<TicketPurchase[]> {
  const payload = await loadStatus();
  const registeredTickets = toStringArray(payload.lottery?.registered_tickets);

  if (registeredTickets.length === 0) {
    return [];
  }

  const status = firstRecord(payload.lottery?.status);
  const round =
    toNumberOrNull(status?.round) ??
    toNumberOrNull(status?.current_round) ??
    toNumberOrNull(status?.rng_response_count) ??
    toNumberOrNull(status?.rng_request_count) ??
    0;
  const fallbackTimestamp = normalizeTimestamp(payload.timestamp) ?? new Date().toISOString();

  return registeredTickets.map((ticketId) => ({
    ticketId,
    round,
    numbers: [],
    purchaseTime: fallbackTimestamp,
    status: "confirmed",
    txHash: null,
  }));
}

export async function fetchLotteryEventsSupra(): Promise<LotteryEvent[]> {
  return [];
}

function fallbackToMock<T>(method: string, fn: () => Promise<T>): Promise<T> {
  if (import.meta.env.DEV) {
    console.warn(`Supra API: ${method} falling back to mock data. Replace with real endpoint when available.`);
  }
  return fn();
}

export async function fetchAdminConfigSupra(): Promise<AdminConfig> {
  const payload = await loadStatus();
  const fallback = await fetchAdminConfigMock();

  const gas = parseAdminGasConfig(payload) ?? fallback.gas;
  const vrf = parseAdminVrfConfig(payload) ?? fallback.vrf;
  const whitelist = buildWhitelistConfig(payload, fallback.whitelist);
  const treasuryConfig = buildTreasuryConfig(payload, fallback.treasury.config);
  const treasuryBalances = buildTreasuryBalances(payload, fallback.treasury.balances);

  return {
    gas,
    vrf,
    whitelist,
    treasury: {
      config: treasuryConfig,
      balances: treasuryBalances,
    },
  };
}

export async function fetchTreasuryConfigSupra(): Promise<TreasuryConfig> {
  const payload = await loadStatus();
  const fallback = await fetchTreasuryConfigMock();
  return buildTreasuryConfig(payload, fallback);
}

export async function fetchTreasuryBalancesSupra(): Promise<TreasuryBalances> {
  const payload = await loadStatus();
  const fallback = await fetchTreasuryBalancesMock();
  return buildTreasuryBalances(payload, fallback);
}

function unsupportedMutation(method: string): never {
  throw new Error(
    `${method}: Supra mutations are not enabled yet. Use the CLI helpers or switch to mock mode for simulations.`,
  );
}

export async function updateGasConfigSupra(
  input: UpdateGasConfigInput,
): Promise<AdminMutationResult> {
  const status = await loadStatus({ forceRefresh: true });
  const calculation = toRecord(status.calculation);
  const deposit = toRecord(status.deposit);

  const expectedMaxGasFee = toNumberOrNull(calculation?.per_request_fee);
  const expectedMinBalance =
    toNumberOrNull(deposit?.min_balance) ?? toNumberOrNull(calculation?.min_balance);

  if (expectedMaxGasFee === null || expectedMinBalance === null) {
    throw new Error(
      "Supra API: не удалось определить расчётные значения min_balance/max_gas_fee. Проверьте конфигурацию мониторинга.",
    );
  }

  if (input.maxGasFee !== expectedMaxGasFee) {
    throw new Error(
      `Supra API: maxGasFee вычисляется на основе VRF и set_minimum_balance. Ожидается ${expectedMaxGasFee}, передано ${input.maxGasFee}.`,
    );
  }

  if (input.minBalance !== expectedMinBalance) {
    throw new Error(
      `Supra API: minBalance обновляется автоматически. Ожидается ${expectedMinBalance}, передано ${input.minBalance}.`,
    );
  }

  const response = await supraCommand("set-minimum-balance", {
    args: [
      "--expected-min-balance",
      toCliValue(expectedMinBalance),
      "--expected-max-gas-fee",
      toCliValue(expectedMaxGasFee),
      "--assume-yes",
    ],
  });

  const result = toAdminMutationResultFromCommand("set-minimum-balance", response);
  invalidateSupraStatusCache();
  return result;
}

export async function updateVrfConfigSupra(
  input: UpdateVrfConfigInput,
): Promise<AdminMutationResult> {
  const status = await loadStatus();
  const verificationGas = extractVerificationGasValue(status);

  const gasArgs: string[] = [
    "--max-gas-price",
    toCliValue(input.maxGasPrice),
    "--max-gas-limit",
    toCliValue(input.maxGasLimit),
    "--callback-gas-price",
    toCliValue(input.callbackGasPrice),
    "--callback-gas-limit",
    toCliValue(input.callbackGasLimit),
  ];

  if (verificationGas) {
    gasArgs.push("--verification-gas", toCliValue(verificationGas));
  }

  gasArgs.push("--assume-yes");

  const gasResponse = await supraCommand("configure-vrf-gas", { args: gasArgs });
  const gasResult = toAdminMutationResultFromCommand("configure-vrf-gas", gasResponse);

  const requestArgs: string[] = [
    "--rng-count",
    toCliValue(input.requestedRngCount),
    "--client-seed",
    toCliValue(input.clientSeed),
    "--assume-yes",
  ];

  try {
    const requestResponse = await supraCommand("configure-vrf-request", { args: requestArgs });
    const result = toAdminMutationResultFromCommand("configure-vrf-request", requestResponse);
    invalidateSupraStatusCache();
    return result;
  } catch (error) {
    if (gasResult?.txHash && error instanceof Error) {
      error.message = `${error.message} (газ обновлён, tx ${gasResult.txHash})`;
    }
    invalidateSupraStatusCache();
    throw error;
  }
}

export async function updateTreasuryDistributionSupra(
  _input: UpdateTreasuryDistributionInput,
): Promise<AdminMutationResult> {
  const total =
    _input.jackpotBp + _input.prizeBp + _input.treasuryBp + _input.marketingBp;

  if (total !== 10_000) {
    throw new Error(
      `Supra API: сумма распределения должна составлять 10000 bps, получено ${total}.`,
    );
  }

  const response = await supraCommand("configure-treasury-distribution", {
    args: [
      "--bp-jackpot",
      toCliValue(_input.jackpotBp),
      "--bp-prize",
      toCliValue(_input.prizeBp),
      "--bp-treasury",
      toCliValue(_input.treasuryBp),
      "--bp-marketing",
      toCliValue(_input.marketingBp),
      "--bp-community",
      "0",
      "--bp-team",
      "0",
      "--bp-partners",
      "0",
      "--assume-yes",
    ],
  });

  invalidateSupraStatusCache();

  return toAdminMutationResultFromCommand("configure-treasury-distribution", response);
}

export async function updateTreasuryControlsSupra(
  _input: UpdateTreasuryControlsInput,
): Promise<AdminMutationResult> {
  unsupportedMutation("updateTreasuryControlsSupra");
}

export async function recordClientWhitelistSnapshotSupra(
  input: RecordClientWhitelistInput,
): Promise<AdminMutationResult> {
  const response = await supraCommand("record-client-whitelist", {
    args: [
      "--max-gas-price",
      input.maxGasPrice,
      "--max-gas-limit",
      input.maxGasLimit,
      "--min-balance-limit",
      input.minBalanceLimit,
      "--assume-yes",
    ],
  });
  return toAdminMutationResultFromCommand("record-client-whitelist", response);
}

export async function recordConsumerWhitelistSnapshotSupra(
  input: RecordConsumerWhitelistInput,
): Promise<AdminMutationResult> {
  const response = await supraCommand("record-consumer-whitelist", {
    args: [
      "--callback-gas-price",
      input.callbackGasPrice,
      "--callback-gas-limit",
      input.callbackGasLimit,
      "--assume-yes",
    ],
  });
  return toAdminMutationResultFromCommand("record-consumer-whitelist", response);
}

export async function purchaseTicketSupra(
  _input: PurchaseTicketInput,
): Promise<TicketPurchase> {
  unsupportedMutation("purchaseTicketSupra");
}
