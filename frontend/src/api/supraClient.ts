import type {
  AccountProfile,
  AccountProfileUpdate,
  AchievementStatus,
  AchievementUnlockInput,
  AdminConfig,
  AdminMutationResult,
  Announcement,
  AvatarInfo,
  ChecklistCompleteInput,
  ChecklistStatus,
  ChatMessage,
  DepositStatus,
  HubStatus,
  LotteryBlueprintSummary,
  LotteryEvent,
  LotteryInstanceSummary,
  LotteryRegistrationSummary,
  LotteryStatsSummary,
  LotteryStatus,
  LotterySummary,
  LotteryTreasurySummary,
  LotteryVrfHubLog,
  LotteryVrfLog,
  LotteryVrfRoundLog,
  PostAnnouncementInput,
  PostChatMessageInput,
  PurchaseTicketInput,
  RecordClientWhitelistInput,
  RecordConsumerWhitelistInput,
  SupraCommandInfo,
  TicketPurchase,
  TreasuryBalances,
  TreasuryConfig,
  TreasuryStatus,
  UpdateGasConfigInput,
  UpdateTreasuryControlsInput,
  UpdateTreasuryDistributionInput,
  UpdateVrfConfigInput,
  VrfLogEvent,
  VrfStatus,
  WhitelistStatus,
} from "./types";
import {
  fetchAdminConfigMock,
  fetchTreasuryBalancesMock,
  fetchTreasuryConfigMock,
} from "./mockClient";

const DEFAULT_BASE_URL = "http://localhost:8000";
const baseUrl = (import.meta.env.VITE_SUPRA_API_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, "");
const DEFAULT_VRF_LOG_LIMIT = 25;
const MAX_VRF_LOG_LIMIT = 500;

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
  timestamp?: string | null;
  profile?: string | null;
  calculation?: unknown;
  addresses?: unknown;
  hub?: unknown;
  lotteries?: unknown;
  deposit?: unknown;
  treasury?: unknown;
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

function toBooleanOrNull(value: unknown): boolean | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (!normalized) {
      return null;
    }
    if (["true", "1", "yes", "on"].includes(normalized)) {
      return true;
    }
    if (["false", "0", "no", "off"].includes(normalized)) {
      return false;
    }
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

function normalizeChatRoom(value: string | null | undefined): string {
  if (!value) {
    return "global";
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return "global";
  }
  return trimmed.toLowerCase();
}

function mapLotteryRoundSnapshot(raw: unknown): LotteryStatus["lotteries"][number]["round"]["snapshot"] {
  const snapshot = toRecord(raw);
  if (!snapshot) {
    return null;
  }
  return {
    ticketCount: toNumberOrNull(snapshot.ticket_count),
    drawScheduled: toBooleanOrNull(snapshot.draw_scheduled),
    hasPendingRequest: toBooleanOrNull(snapshot.has_pending_request),
    nextTicketId: toNumberOrNull(snapshot.next_ticket_id),
  };
}

function mapLotteryRound(raw: unknown): LotteryStatus["lotteries"][number]["round"] {
  const record = toRecord(raw);
  if (!record) {
    return { snapshot: null, pendingRequestId: null };
  }
  return {
    snapshot: mapLotteryRoundSnapshot(record.snapshot),
    pendingRequestId: toStringOrNull(record.pending_request_id),
  };
}

function mapLotteryBlueprint(raw: unknown): LotteryBlueprintSummary | null {
  const record = toRecord(raw);
  if (!record) {
    return null;
  }
  return {
    ticketPriceSupra: toStringOrNull(record.ticket_price),
    jackpotShareBps: toNumberOrNull(record.jackpot_share_bps),
  };
}

function mapLotteryRegistration(raw: unknown): LotteryRegistrationSummary | null {
  const record = toRecord(raw);
  if (!record) {
    return null;
  }
  return {
    owner: toStringOrNull(record.owner),
    lotteryAddress: toStringOrNull(record.lottery),
    metadataHex: toStringOrNull(record.metadata),
    active: toBooleanOrNull(record.active) ?? false,
  };
}

function mapLotteryFactory(raw: unknown): LotteryFactorySummary | null {
  const record = toRecord(raw);
  if (!record) {
    return null;
  }
  return {
    owner: toStringOrNull(record.owner),
    lotteryAddress: toStringOrNull(record.lottery),
    blueprint: mapLotteryBlueprint(record.blueprint),
  };
}

function mapLotteryInstance(raw: unknown): LotteryInstanceSummary | null {
  return mapLotteryFactory(raw);
}

function mapLotteryStats(raw: unknown): LotteryStatsSummary | null {
  const record = toRecord(raw);
  if (!record) {
    return null;
  }
  return {
    ticketsSold: toNumberOrNull(record.tickets_sold),
    jackpotAccumulatedSupra: toStringOrNull(record.jackpot_accumulated),
  };
}

function mapLotteryTreasury(raw: unknown): LotteryTreasurySummary {
  const record = toRecord(raw);
  const config = toRecord(record?.config);
  const pool = toRecord(record?.pool);
  return {
    config: config
      ? {
          jackpotBp: toNumberOrNull(config.jackpot_bps),
          prizeBp: toNumberOrNull(config.prize_bps),
          operationsBp: toNumberOrNull(config.operations_bps),
        }
      : null,
    pool: pool
      ? {
          prizeSupra: toStringOrNull(pool.prize_balance),
          operationsSupra: toStringOrNull(pool.operations_balance),
        }
      : null,
  };
}

function mapLotterySummary(raw: unknown): LotterySummary | null {
  const record = toRecord(raw);
  if (!record) {
    return null;
  }
  const id = toNumberOrNull(record.lottery_id);
  if (id === null) {
    return null;
  }
  return {
    id,
    registration: mapLotteryRegistration(record.registration),
    factory: mapLotteryFactory(record.factory),
    instance: mapLotteryInstance(record.instance),
    stats: mapLotteryStats(record.stats),
    round: mapLotteryRound(record.round),
    treasury: mapLotteryTreasury(record.treasury),
  };
}

function mapAddresses(raw: unknown): LotteryStatus["addresses"] {
  const record = toRecord(raw);
  return {
    lottery: toStringOrNull(record?.lottery) ?? null,
    hub: toStringOrNull(record?.hub) ?? null,
    factory: toStringOrNull(record?.factory) ?? null,
    deposit: toStringOrNull(record?.deposit) ?? null,
    client: toStringOrNull(record?.client) ?? null,
  };
}

function mapHub(raw: unknown): HubStatus {
  const record = toRecord(raw);
  const ids = toUnknownArray(record?.configured_lottery_ids)
    .map((item) => toNumberOrNull(item))
    .filter((item): item is number => item !== null);
  return {
    lotteryCount: toNumberOrNull(record?.lottery_count),
    nextLotteryId: toNumberOrNull(record?.next_lottery_id),
    callbackSender: toStringOrNull(record?.callback_sender),
    configuredLotteryIds: ids,
  };
}

function mapDeposit(raw: unknown): DepositStatus {
  const record = toRecord(raw);
  const subscription = toRecord(record?.subscription_info) ?? {};
  const contractDetails = toRecord(record?.contract_details) ?? {};
  const whitelistedContracts = toUnknownArray(record?.whitelisted_contracts)
    .map((item) => toStringOrNull(item))
    .filter((item): item is string => item !== null);
  return {
    balance: toStringOrNull(record?.balance),
    minBalance: toStringOrNull(record?.min_balance),
    minBalanceReached: toBooleanOrNull(record?.min_balance_reached),
    subscriptionInfo: subscription,
    contractDetails,
    whitelistedContracts,
    maxGasPrice: toStringOrNull(record?.max_gas_price),
    maxGasLimit: toStringOrNull(record?.max_gas_limit),
  };
}

function mapTreasuryStatus(raw: unknown): TreasuryStatus {
  const record = toRecord(raw);
  return {
    jackpotBalance: toStringOrNull(record?.jackpot_balance),
    tokenBalance: toStringOrNull(record?.token_balance ?? record?.balance),
    totalSupply: toStringOrNull(record?.total_supply),
    metadata: toRecord(record?.metadata) ?? {},
  };
}

function mapLotteries(raw: unknown): LotterySummary[] {
  return toUnknownArray(raw)
    .map((item) => mapLotterySummary(item))
    .filter((item): item is LotterySummary => item !== null)
    .sort((a, b) => a.id - b.id);
}

function clampVrfLogLimit(limit?: number): number {
  if (typeof limit !== "number" || !Number.isFinite(limit)) {
    return DEFAULT_VRF_LOG_LIMIT;
  }
  const normalized = Math.trunc(limit);
  if (!Number.isFinite(normalized) || normalized <= 0) {
    return DEFAULT_VRF_LOG_LIMIT;
  }
  return Math.max(1, Math.min(normalized, MAX_VRF_LOG_LIMIT));
}

function mapVrfPending(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  return null;
}

function mapVrfSnapshot(value: unknown): Record<string, unknown> | null {
  const record = toRecord(value);
  return record ? { ...record } : null;
}

function mapVrfEvents(value: unknown, limit: number): VrfLogEvent[] {
  return toUnknownArray(value)
    .slice(0, limit)
    .map((item) =>
      item && typeof item === "object" && !Array.isArray(item)
        ? (item as Record<string, unknown>)
        : ({ value: item } as Record<string, unknown>),
    );
}

function mapLotteryVrfRound(raw: unknown, limit: number): LotteryVrfRoundLog {
  const record = toRecord(raw);
  if (!record) {
    return {
      snapshot: null,
      pendingRequestId: null,
      requests: [],
      fulfillments: [],
    };
  }
  return {
    snapshot: mapVrfSnapshot(record.snapshot),
    pendingRequestId: mapVrfPending(record.pending_request_id),
    requests: mapVrfEvents(record.requests, limit),
    fulfillments: mapVrfEvents(record.fulfillments, limit),
  };
}

function mapLotteryVrfHub(raw: unknown, limit: number): LotteryVrfHubLog {
  const record = toRecord(raw);
  if (!record) {
    return { requests: [], fulfillments: [] };
  }
  return {
    requests: mapVrfEvents(record.requests, limit),
    fulfillments: mapVrfEvents(record.fulfillments, limit),
  };
}

function mapLotteryVrfLog(payload: unknown, fallbackLotteryId: number, limit: number): LotteryVrfLog {
  const record = toRecord(payload);
  const lotteryId = toNumberOrNull(record?.lottery_id) ?? fallbackLotteryId;

  return {
    lotteryId,
    limit,
    round: mapLotteryVrfRound(record?.round, limit),
    hub: mapLotteryVrfHub(record?.hub, limit),
  };
}

function mapVrfStatus(payload: SupraStatusResponse, lotteries: LotterySummary[]): VrfStatus {
  const depositRecord = toRecord(payload.deposit);
  const subscription = toRecord(depositRecord?.subscription_info);
  const pendingRequestId = lotteries.find((entry) => entry.round.pendingRequestId)?.round.pendingRequestId ?? null;
  return {
    subscriptionId: toStringOrNull(subscription?.subscription_id),
    pendingRequestId,
    lastRequestTime: normalizeTimestamp(subscription?.last_request_time),
    lastFulfillmentTime: normalizeTimestamp(subscription?.last_fulfillment_time),
  };
}

function mapSupraStatus(payload: SupraStatusResponse): LotteryStatus {
  const timestamp = ensureTimestamp(normalizeTimestamp(payload.timestamp));
  const lotteries = mapLotteries(payload.lotteries);
  return {
    timestamp,
    profile: toStringOrNull(payload.profile),
    calculation: toRecord(payload.calculation),
    addresses: mapAddresses(payload.addresses),
    hub: mapHub(payload.hub),
    lotteries,
    deposit: mapDeposit(payload.deposit),
    treasury: mapTreasuryStatus(payload.treasury),
    vrf: mapVrfStatus(payload, lotteries),
  };
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
  const lottery = mapLotteries(payload.lotteries)[0];
  const config = lottery?.treasury.config;
  if (!config) {
    return null;
  }
  if (config.jackpotBp === null || config.prizeBp === null || config.operationsBp === null) {
    return null;
  }
  return {
    jackpot: config.jackpotBp,
    prize: config.prizeBp,
    treasury: config.operationsBp,
    marketing: 0,
  };
}

function buildTreasuryConfig(
  payload: SupraStatusResponse,
  fallback: TreasuryConfig,
): TreasuryConfig {
  const parsedDistribution = parseTreasuryDistribution(payload);
  const distribution = parsedDistribution ?? { ...fallback.distributionBp };
  const status = mapSupraStatus(payload);
  const hasRealtimeData = status.lotteries.length > 0;
  const ticketPrice =
    status.lotteries[0]?.factory?.blueprint?.ticketPriceSupra ?? fallback.ticketPriceSupra;
  const updatedAt = hasRealtimeData ? status.timestamp ?? fallback.updatedAt : fallback.updatedAt;

  return {
    ticketPriceSupra: ticketPrice,
    salesEnabled: fallback.salesEnabled,
    treasuryAddress: fallback.treasuryAddress,
    distributionBp: distribution,
    updatedAt,
  };
}

function buildTreasuryBalances(
  payload: SupraStatusResponse,
  fallback: TreasuryBalances,
): TreasuryBalances {
  const status = mapSupraStatus(payload);
  const primary = status.lotteries[0];
  const jackpot = status.treasury.jackpotBalance ?? fallback.jackpotSupra;
  const prize = primary?.treasury.pool?.prizeSupra ?? fallback.prizeSupra;
  const treasuryBalance = primary?.treasury.pool?.operationsSupra ?? fallback.treasurySupra;
  const hasRealtimeData = Boolean(primary);
  const updatedAt = hasRealtimeData ? status.timestamp ?? fallback.updatedAt : fallback.updatedAt;

  return {
    jackpotSupra: jackpot,
    prizeSupra: prize,
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
  const contractDetails = toRecord(deposit?.contract_details);

  const maxGasPrice =
    toStringOrNull(deposit?.max_gas_price) ?? toStringOrNull(calculation?.max_gas_price);
  const maxGasLimit =
    toStringOrNull(deposit?.max_gas_limit) ?? toStringOrNull(calculation?.max_gas_limit);
  const callbackGasPrice = toStringOrNull(contractDetails?.callback_gas_price);
  const callbackGasLimit = toStringOrNull(contractDetails?.callback_gas_limit);

  if (
    maxGasPrice === null &&
    maxGasLimit === null &&
    callbackGasPrice === null &&
    callbackGasLimit === null
  ) {
    return null;
  }

  const timestamp = ensureTimestamp(normalizeTimestamp(payload.timestamp));

  return {
    maxGasPrice: maxGasPrice ?? "0",
    maxGasLimit: maxGasLimit ?? "0",
    callbackGasPrice: callbackGasPrice ?? "0",
    callbackGasLimit: callbackGasLimit ?? "0",
    requestedRngCount: 0,
    clientSeed: 0,
    lastConfiguredAt: timestamp,
  };
}

function buildWhitelistConfig(
  payload: SupraStatusResponse,
  fallback: AdminConfig["whitelist"],
): AdminConfig["whitelist"] {
  return fallback;
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

async function supraRequestOptional<T>(path: string, init?: RequestInit): Promise<T | null> {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: { "Accept": "application/json" },
    ...init,
  });

  if (response.status === 404) {
    return null;
  }

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`Supra API ${response.status}: ${text || response.statusText}`);
  }

  return (await response.json()) as T;
}

function toAvatarInfo(kind: string, value?: string | null): AvatarInfo {
  return {
    kind: kind || "none",
    value: value ?? null,
  };
}

function toProfileSettings(raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }
  return { ...(raw as Record<string, unknown>) };
}

function mapAccountProfile(payload: AccountProfileResponse): AccountProfile {
  const createdAt = normalizeTimestamp(payload.created_at) ?? new Date().toISOString();
  const updatedAt = normalizeTimestamp(payload.updated_at) ?? createdAt;

  return {
    address: payload.address,
    nickname: payload.nickname ?? null,
    avatar: toAvatarInfo(payload.avatar_kind, payload.avatar_value ?? null),
    telegram: payload.telegram ?? null,
    twitter: payload.twitter ?? null,
    settings: toProfileSettings(payload.settings ?? {}),
    createdAt,
    updatedAt,
  };
}

function buildAvatarPayload(update: AvatarInfo | null | undefined): AccountProfileUpdatePayload["avatar"] {
  if (update === undefined) {
    return undefined;
  }
  if (update === null) {
    return null;
  }
  return { kind: update.kind, value: update.value ?? null };
}

function cloneRecord(value: unknown): Record<string, unknown> | null {
  const record = toRecord(value);
  if (!record) {
    return null;
  }
  return { ...record };
}

function mapChecklistTaskResponse(payload: ChecklistTaskResponsePayload): ChecklistTask {
  const createdAt = normalizeTimestamp(payload.created_at) ?? new Date().toISOString();
  const updatedAt = normalizeTimestamp(payload.updated_at) ?? createdAt;
  return {
    code: payload.code,
    title: payload.title,
    description: payload.description ?? null,
    dayIndex: typeof payload.day_index === "number" ? payload.day_index : 0,
    rewardKind: payload.reward_kind ?? null,
    rewardValue: cloneRecord(payload.reward_value),
    metadata: cloneRecord(payload.metadata),
    isActive: payload.is_active ?? true,
    createdAt,
    updatedAt,
  };
}

function mapChecklistProgressResponse(
  payload: ChecklistProgressResponsePayload,
): ChecklistStatus["tasks"][number] {
  return {
    task: mapChecklistTaskResponse(payload.task),
    completed: payload.completed,
    completedAt: normalizeTimestamp(payload.completed_at) ?? null,
    rewardClaimed: payload.reward_claimed ?? false,
    metadata: cloneRecord(payload.metadata),
  };
}

function mapChecklistStatusResponse(payload: ChecklistStatusResponsePayload): ChecklistStatus {
  return {
    address: payload.address,
    tasks: payload.tasks.map((entry) => mapChecklistProgressResponse(entry)),
  };
}

function buildChecklistCompletePayload(
  input?: ChecklistCompleteInput,
): ChecklistCompleteRequestPayload {
  if (!input) {
    return {};
  }
  const payload: ChecklistCompleteRequestPayload = {};
  if (input.metadata !== undefined) {
    payload.metadata = input.metadata ?? null;
  }
  if (input.rewardClaimed !== undefined) {
    payload.reward_claimed = input.rewardClaimed;
  }
  return payload;
}

function mapAchievementResponse(payload: AchievementResponsePayload): Achievement {
  const createdAt = normalizeTimestamp(payload.created_at) ?? new Date().toISOString();
  const updatedAt = normalizeTimestamp(payload.updated_at) ?? createdAt;
  return {
    code: payload.code,
    title: payload.title,
    description: payload.description,
    points: typeof payload.points === "number" ? payload.points : 0,
    metadata: cloneRecord(payload.metadata),
    isActive: payload.is_active ?? true,
    createdAt,
    updatedAt,
  };
}

function mapAchievementProgressResponse(
  payload: AchievementProgressResponsePayload,
): AchievementStatus["achievements"][number] {
  return {
    achievement: mapAchievementResponse(payload.achievement),
    unlocked: payload.unlocked,
    unlockedAt: normalizeTimestamp(payload.unlocked_at) ?? null,
    progressValue: typeof payload.progress_value === "number" ? payload.progress_value : 0,
    metadata: cloneRecord(payload.metadata),
  };
}

function mapAchievementStatusResponse(payload: AchievementStatusResponsePayload): AchievementStatus {
  return {
    address: payload.address,
    achievements: payload.achievements.map((entry) => mapAchievementProgressResponse(entry)),
  };
}

function mapChatMessageResponse(payload: ChatMessageResponsePayload): ChatMessage {
  const createdAt = normalizeTimestamp(payload.created_at) ?? new Date().toISOString();
  const body = (payload.body ?? "").toString();
  const sender = toStringOrNull(payload.sender_address) ?? "";
  return {
    id: payload.id,
    room: normalizeChatRoom(payload.room ?? undefined),
    senderAddress: sender,
    body,
    metadata: cloneRecord(payload.metadata) ?? {},
    createdAt,
  };
}

function buildChatMessageRequest(input: PostChatMessageInput): ChatMessageRequestPayload {
  const address = input.address.trim();
  if (!address) {
    throw new Error("Адрес отправителя обязателен");
  }
  const body = (input.body ?? "").trim();
  if (!body) {
    throw new Error("Сообщение не может быть пустым");
  }
  return {
    address,
    body,
    room: normalizeChatRoom(input.room ?? undefined),
    metadata: input.metadata ? { ...input.metadata } : null,
  };
}

function mapAnnouncementResponse(payload: AnnouncementResponsePayload): Announcement {
  const createdAt = normalizeTimestamp(payload.created_at) ?? new Date().toISOString();
  return {
    id: payload.id,
    title: payload.title ?? "",
    body: payload.body ?? "",
    lotteryId: payload.lottery_id ?? null,
    metadata: cloneRecord(payload.metadata) ?? {},
    createdAt,
  };
}

function buildAnnouncementRequest(input: PostAnnouncementInput): AnnouncementRequestPayload {
  const title = (input.title ?? "").trim();
  const body = (input.body ?? "").trim();
  if (!title || !body) {
    throw new Error("Необходимо указать заголовок и текст объявления");
  }
  const payload: AnnouncementRequestPayload = {
    title,
    body,
  };
  if (input.lotteryId !== undefined) {
    const value = input.lotteryId ? input.lotteryId.trim() : null;
    payload.lottery_id = value && value.length ? value : null;
  }
  if (input.metadata !== undefined) {
    payload.metadata = input.metadata ?? null;
  }
  return payload;
}

function buildAchievementUnlockPayload(
  input?: AchievementUnlockInput,
): AchievementUnlockRequestPayload {
  if (!input) {
    return {};
  }
  const payload: AchievementUnlockRequestPayload = {};
  if (input.progressValue !== undefined) {
    payload.progress_value = input.progressValue ?? null;
  }
  if (input.metadata !== undefined) {
    payload.metadata = input.metadata ?? null;
  }
  return payload;
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

interface AccountProfileResponse {
  address: string;
  nickname?: string | null;
  avatar_kind: string;
  avatar_value?: string | null;
  telegram?: string | null;
  twitter?: string | null;
  settings?: Record<string, unknown> | null;
  created_at?: string | null;
  updated_at?: string | null;
}

interface AccountProfileUpdatePayload {
  nickname?: string | null;
  avatar?: { kind: string; value?: string | null } | null;
  telegram?: string | null;
  twitter?: string | null;
  settings?: Record<string, unknown> | null;
}

interface ChecklistTaskResponsePayload {
  code: string;
  title: string;
  description?: string | null;
  day_index?: number | null;
  reward_kind?: string | null;
  reward_value?: unknown;
  metadata?: unknown;
  is_active?: boolean;
  created_at?: string | null;
  updated_at?: string | null;
}

interface ChecklistProgressResponsePayload {
  task: ChecklistTaskResponsePayload;
  completed: boolean;
  completed_at?: string | null;
  reward_claimed?: boolean;
  metadata?: unknown;
}

interface ChecklistStatusResponsePayload {
  address: string;
  tasks: ChecklistProgressResponsePayload[];
}

interface ChecklistCompleteRequestPayload {
  metadata?: Record<string, unknown> | null;
  reward_claimed?: boolean | null;
}

interface AchievementResponsePayload {
  code: string;
  title: string;
  description: string;
  points?: number | null;
  metadata?: unknown;
  is_active?: boolean;
  created_at?: string | null;
  updated_at?: string | null;
}

interface AchievementProgressResponsePayload {
  achievement: AchievementResponsePayload;
  unlocked: boolean;
  unlocked_at?: string | null;
  progress_value?: number | null;
  metadata?: unknown;
}

interface AchievementStatusResponsePayload {
  address: string;
  achievements: AchievementProgressResponsePayload[];
}

interface AchievementUnlockRequestPayload {
  progress_value?: number | null;
  metadata?: Record<string, unknown> | null;
}

interface ChatMessageResponsePayload {
  id: number;
  room?: string | null;
  sender_address?: string | null;
  body?: string | null;
  metadata?: unknown;
  created_at?: string | null;
}

interface ChatMessageRequestPayload {
  address: string;
  body: string;
  room?: string | null;
  metadata?: Record<string, unknown> | null;
}

interface AnnouncementResponsePayload {
  id: number;
  title?: string | null;
  body?: string | null;
  lottery_id?: string | null;
  metadata?: unknown;
  created_at?: string | null;
}

interface AnnouncementRequestPayload {
  title: string;
  body: string;
  lottery_id?: string | null;
  metadata?: Record<string, unknown> | null;
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
  return mapSupraStatus(payload);
}

export async function fetchChecklistSupra(address: string): Promise<ChecklistStatus> {
  const trimmed = address.trim();
  if (!trimmed) {
    return { address: "", tasks: [] };
  }

  const encodedAddress = encodeURIComponent(trimmed);
  const payload = await supraRequestOptional<ChecklistStatusResponsePayload>(
    `/progress/${encodedAddress}/checklist`,
  );

  if (!payload) {
    return { address: trimmed.toLowerCase(), tasks: [] };
  }

  return mapChecklistStatusResponse(payload);
}

export async function completeChecklistTaskSupra(
  address: string,
  code: string,
  input?: ChecklistCompleteInput,
): Promise<ChecklistStatus["tasks"][number]> {
  const trimmedAddress = address.trim();
  const trimmedCode = code.trim();
  if (!trimmedAddress || !trimmedCode) {
    throw new Error("Необходимо указать адрес и код задания");
  }

  const payload = await supraRequest<ChecklistProgressResponsePayload>(
    `/progress/${encodeURIComponent(trimmedAddress)}/checklist/${encodeURIComponent(trimmedCode)}/complete`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(buildChecklistCompletePayload(input)),
    },
  );

  return mapChecklistProgressResponse(payload);
}

export async function fetchAchievementsSupra(address: string): Promise<AchievementStatus> {
  const trimmed = address.trim();
  if (!trimmed) {
    return { address: "", achievements: [] };
  }

  const payload = await supraRequestOptional<AchievementStatusResponsePayload>(
    `/progress/${encodeURIComponent(trimmed)}/achievements`,
  );

  if (!payload) {
    return { address: trimmed.toLowerCase(), achievements: [] };
  }

  return mapAchievementStatusResponse(payload);
}

export async function unlockAchievementSupra(
  address: string,
  code: string,
  input?: AchievementUnlockInput,
): Promise<AchievementStatus["achievements"][number]> {
  const trimmedAddress = address.trim();
  const trimmedCode = code.trim();
  if (!trimmedAddress || !trimmedCode) {
    throw new Error("Необходимо указать адрес и код достижения");
  }

  const payload = await supraRequest<AchievementProgressResponsePayload>(
    `/progress/${encodeURIComponent(trimmedAddress)}/achievements/${encodeURIComponent(trimmedCode)}/unlock`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(buildAchievementUnlockPayload(input)),
    },
  );

  return mapAchievementProgressResponse(payload);
}

export async function fetchWhitelistStatusSupra(): Promise<WhitelistStatus> {
  const payload = await loadStatus();
  const status = mapSupraStatus(payload);
  const account = status.deposit.whitelistedContracts[0] ?? null;
  return {
    account,
    profile: status.profile,
    isWhitelisted: Boolean(account),
    checkedAt: status.timestamp,
  };
}

export async function fetchTicketsSupra(): Promise<TicketPurchase[]> {
  await loadStatus();
  return [];
}

export async function fetchLotteryEventsSupra(): Promise<LotteryEvent[]> {
  return [];
}

export async function fetchLotteryVrfLogSupra(
  lotteryId: number,
  limit = DEFAULT_VRF_LOG_LIMIT,
): Promise<LotteryVrfLog> {
  const normalizedLotteryId = Number.isFinite(lotteryId) ? Math.trunc(lotteryId) : 0;
  const normalizedLimit = clampVrfLogLimit(limit);
  const searchParams = new URLSearchParams();
  searchParams.set("limit", String(normalizedLimit));
  const payload = await supraRequest<unknown>(
    `/lotteries/${normalizedLotteryId}/vrf-log?${searchParams.toString()}`,
  );
  return mapLotteryVrfLog(payload, normalizedLotteryId, normalizedLimit);
}

export async function fetchChatMessagesSupra(
  room: string = "global",
  limit = 50,
): Promise<ChatMessage[]> {
  const safeLimit = Math.min(Math.max(1, limit), 200);
  const searchParams = new URLSearchParams();
  searchParams.set("room", normalizeChatRoom(room));
  searchParams.set("limit", String(safeLimit));
  const payload = await supraRequest<ChatMessageResponsePayload[]>(
    `/chat/messages?${searchParams.toString()}`,
  );
  return payload.map((item) => mapChatMessageResponse(item));
}

export async function postChatMessageSupra(input: PostChatMessageInput): Promise<ChatMessage> {
  const payload = await supraRequest<ChatMessageResponsePayload>("/chat/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(buildChatMessageRequest(input)),
  });
  return mapChatMessageResponse(payload);
}

export async function fetchAnnouncementsSupra(
  limit = 20,
  lotteryId?: string | null,
): Promise<Announcement[]> {
  const safeLimit = Math.min(Math.max(1, limit), 100);
  const searchParams = new URLSearchParams();
  searchParams.set("limit", String(safeLimit));
  if (lotteryId !== undefined && lotteryId !== null && lotteryId.trim().length > 0) {
    searchParams.set("lottery_id", lotteryId.trim());
  }
  const payload = await supraRequest<AnnouncementResponsePayload[]>(
    `/chat/announcements?${searchParams.toString()}`,
  );
  return payload.map((item) => mapAnnouncementResponse(item));
}

export async function postAnnouncementSupra(input: PostAnnouncementInput): Promise<Announcement> {
  const payload = await supraRequest<AnnouncementResponsePayload>("/chat/announcements", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(buildAnnouncementRequest(input)),
  });
  return mapAnnouncementResponse(payload);
}

export async function fetchAccountProfileSupra(address: string): Promise<AccountProfile | null> {
  if (!address.trim()) {
    return null;
  }

  const response = await supraRequestOptional<AccountProfileResponse>(`/accounts/${address}`);
  return response ? mapAccountProfile(response) : null;
}

export async function upsertAccountProfileSupra(
  address: string,
  update: AccountProfileUpdate,
): Promise<AccountProfile> {
  if (!address.trim()) {
    throw new Error("Адрес не может быть пустым");
  }

  const payload: AccountProfileUpdatePayload = {};
  if (update.nickname !== undefined) {
    payload.nickname = update.nickname;
  }
  if (update.telegram !== undefined) {
    payload.telegram = update.telegram;
  }
  if (update.twitter !== undefined) {
    payload.twitter = update.twitter;
  }
  if (update.settings !== undefined) {
    payload.settings = update.settings;
  }
  const avatarPayload = buildAvatarPayload(update.avatar);
  if (avatarPayload !== undefined) {
    payload.avatar = avatarPayload;
  }

  const response = await supraRequest<AccountProfileResponse>(`/accounts/${address}`, {
    method: "PUT",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  return mapAccountProfile(response);
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
