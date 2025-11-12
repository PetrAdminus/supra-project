import type {
  AccountProfile,
  AccountProfileUpdate,
  Achievement,
  AchievementProgressEntry,
  AchievementStatus,
  AchievementUnlockInput,
  AdminConfig,
  AdminMutationResult,
  Announcement,
  AvatarInfo,
  ChecklistCompleteInput,
  ChecklistProgressEntry,
  ChecklistStatus,
  ChecklistTask,
  ChatMessage,
  LotteryMultiViews,
  LotteryMultiViewsOptions,
  LotteryEvent,
  LotteryStatus,
  LotteryVrfLog,
  PostAnnouncementInput,
  PostChatMessageInput,
  PurchaseTicketInput,
  RecordClientWhitelistInput,
  RecordConsumerWhitelistInput,
  SupraCommandInfo,
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
import vrfLogJson from "../mocks/vrf-log.json";
import chatMessagesJson from "../mocks/chat-messages.json";
import announcementsJson from "../mocks/announcements.json";
import lotteryMultiViewsJson from "../mocks/lottery-multi-views.json";

const NETWORK_LATENCY_MS = 180;
const DEFAULT_VRF_LOG_LIMIT = 25;
const MAX_VRF_LOG_LIMIT = 200;
const statusSnapshot: LotteryStatus = structuredClone(lotteryStatusJson as LotteryStatus);
if (!statusSnapshot.vrf) {
  statusSnapshot.vrf = {
    subscriptionId: null,
    pendingRequestId: null,
    lastRequestTime: null,
    lastFulfillmentTime: null,
  };
}
const ticketStore: TicketPurchase[] = structuredClone(
  (ticketsJson as TicketPurchase[]).map((ticket) => ({
    ...ticket,
    lotteryId: ticket.lotteryId ?? 0,
  })),
);
const eventStore: LotteryEvent[] = structuredClone(eventsJson as LotteryEvent[]);
const adminConfigStore: AdminConfig = structuredClone(adminConfigJson as AdminConfig);
const chatMessageStore: ChatMessage[] = structuredClone(
  (chatMessagesJson as ChatMessage[]).map((message) => ({
    ...message,
    room: message.room ?? "global",
    metadata: isRecord(message.metadata) ? structuredClone(message.metadata) : {},
  })),
);
const announcementStore: Announcement[] = structuredClone(
  (announcementsJson as Announcement[]).map((announcement) => ({
    ...announcement,
    lotteryId: announcement.lotteryId ?? null,
    metadata: isRecord(announcement.metadata) ? structuredClone(announcement.metadata) : {},
  })),
);
const lotteryMultiViewsSnapshot: LotteryMultiViews = structuredClone(
  lotteryMultiViewsJson as LotteryMultiViews,
);
const profileStore = new Map<string, AccountProfile>();
const checklistTaskStore = new Map<string, ChecklistTask>();
const checklistProgressStore = new Map<string, Map<string, ChecklistProgressState>>();
const achievementStore = new Map<string, Achievement>();
const achievementProgressStore = new Map<string, Map<string, AchievementProgressState>>();

interface ChecklistProgressState {
  completedAt: string;
  rewardClaimed: boolean;
  metadata: Record<string, unknown> | null;
}

interface AchievementProgressState {
  unlockedAt: string | null;
  progressValue: number;
  metadata: Record<string, unknown> | null;
}

interface RawVrfLog {
  lottery_id?: number;
  limit?: number;
  round?: {
    snapshot?: unknown;
    pending_request_id?: unknown;
    requests?: unknown;
    fulfillments?: unknown;
  };
  hub?: {
    requests?: unknown;
    fulfillments?: unknown;
  };
}

const vrfLogStore = structuredClone(vrfLogJson as RawVrfLog);

const mockCommands: SupraCommandInfo[] = [
  {
    name: "configure-vrf-gas",
    module: "supra.scripts.configure_vrf_gas",
    description: "Update VRF gas limits via Supra CLI",
  },
  {
    name: "configure-vrf-request",
    module: "supra.scripts.configure_vrf_request",
    description: "Configure RNG count and client seed",
  },
  {
    name: "set-minimum-balance",
    module: "supra.scripts.set_minimum_balance",
    description: "Submit set_minimum_balance with validation",
  },
];

let ticketSequence = ticketStore.length;
let chatMessageSequence = chatMessageStore.reduce((max, message) => Math.max(max, message.id), 0);
let announcementSequence = announcementStore.reduce((max, item) => Math.max(max, item.id), 0);

function simulateDelay<T>(payload: T): Promise<T> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(structuredClone(payload)), NETWORK_LATENCY_MS);
  });
}

function generateTicketId(lotteryId: number, round: number): string {
  ticketSequence += 1;
  return `LOT-${lotteryId}-R${round}-${ticketSequence.toString().padStart(3, "0")}`;
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

function normalizeAddress(address: string): string {
  return address.trim().toLowerCase();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function ensureMetadata(value: Record<string, unknown> | null | undefined): Record<string, unknown> {
  if (value && isRecord(value)) {
    return structuredClone(value);
  }
  return {};
}

function normalizeRoom(room: string | null | undefined): string {
  if (!room) {
    return "global";
  }
  const trimmed = room.trim();
  if (!trimmed) {
    return "global";
  }
  return trimmed.toLowerCase();
}

function sortByCreatedAtAsc<T extends { createdAt: string }>(values: T[]): T[] {
  return [...values].sort((a, b) => {
    const left = new Date(a.createdAt).getTime();
    const right = new Date(b.createdAt).getTime();
    return left - right;
  });
}

function normalizeSnapshot(value: unknown): Record<string, unknown> | null {
  if (isRecord(value)) {
    return structuredClone(value);
  }
  return null;
}

function normalizePending(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length ? trimmed : null;
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  return null;
}

function cloneEvents(raw: unknown, limit: number): VrfLogEvent[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.slice(0, limit).map((item) => {
    if (isRecord(item)) {
      return structuredClone(item);
    }
    return { value: item };
  });
}

function ensureChecklistSeed(): void {
  if (checklistTaskStore.size > 0) {
    return;
  }
  const now = new Date().toISOString();
  const templates: Array<Omit<ChecklistTask, "createdAt" | "updatedAt" | "dayIndex"> & { dayIndex: number }> = [
    {
      code: "day1",
      title: "День 1. Добро пожаловать",
      description: "Ознакомьтесь с правилами и выберите первую лотерею.",
      dayIndex: 0,
      rewardKind: "ticket",
      rewardValue: { lotteryId: "jackpot", amount: 1 },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day2",
      title: "День 2. Настройка профиля",
      description: "Добавьте никнейм и аватар, чтобы вас узнавали в чате.",
      dayIndex: 1,
      rewardKind: "bonus",
      rewardValue: { amount: "5", currency: "SUPRA" },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day3",
      title: "День 3. Социальные связи",
      description: "Привяжите Telegram или Twitter для уведомлений.",
      dayIndex: 2,
      rewardKind: "badge",
      rewardValue: { code: "social" },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day4",
      title: "День 4. Покупка билета",
      description: "Купите билет в любой активной лотерее.",
      dayIndex: 3,
      rewardKind: "ticket",
      rewardValue: { lotteryId: "daily", amount: 1 },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day5",
      title: "День 5. Fairness панель",
      description: "Просмотрите историю VRF для текущей лотереи.",
      dayIndex: 4,
      rewardKind: "bonus",
      rewardValue: { amount: "3", currency: "SUPRA" },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day6",
      title: "День 6. Чат сообщества",
      description: "Напишите сообщение в чате или прокомментируйте результат.",
      dayIndex: 5,
      rewardKind: "badge",
      rewardValue: { code: "socializer" },
      metadata: { group: "daily" },
      isActive: true,
    },
    {
      code: "day7",
      title: "День 7. Билет джекпота",
      description: "Получите билет в еженедельный розыгрыш джекпота.",
      dayIndex: 6,
      rewardKind: "ticket",
      rewardValue: { lotteryId: "jackpot-weekly", amount: 1 },
      metadata: { group: "daily", bonus: true },
      isActive: true,
    },
  ];

  templates.forEach((template) => {
    checklistTaskStore.set(template.code, {
      code: template.code,
      title: template.title,
      description: template.description,
      dayIndex: template.dayIndex,
      rewardKind: template.rewardKind,
      rewardValue: structuredClone(template.rewardValue) as Record<string, unknown>,
      metadata: structuredClone(template.metadata) as Record<string, unknown>,
      isActive: template.isActive,
      createdAt: now,
      updatedAt: now,
    });
  });
}

function ensureAchievementSeed(): void {
  if (achievementStore.size > 0) {
    return;
  }
  const now = new Date().toISOString();
  const definitions: Achievement[] = [
    {
      code: "early-bird",
      title: "Ранний птах",
      description: "Выполните чек-лист в первую неделю.",
      points: 25,
      metadata: { category: "daily" },
      isActive: true,
      createdAt: now,
      updatedAt: now,
    },
    {
      code: "lottery-pro",
      title: "Профессионал",
      description: "Участвуйте в 10 розыгрышах за месяц.",
      points: 75,
      metadata: { category: "engagement" },
      isActive: true,
      createdAt: now,
      updatedAt: now,
    },
    {
      code: "community-voice",
      title: "Голос сообщества",
      description: "Оставьте 5 сообщений в чате.",
      points: 40,
      metadata: { category: "social" },
      isActive: true,
      createdAt: now,
      updatedAt: now,
    },
  ];

  definitions.forEach((achievement) => {
    achievementStore.set(achievement.code, structuredClone(achievement));
  });
}

function getChecklistProgressMap(address: string): Map<string, ChecklistProgressState> {
  const normalized = normalizeAddress(address);
  let progress = checklistProgressStore.get(normalized);
  if (!progress) {
    progress = new Map();
    checklistProgressStore.set(normalized, progress);
  }
  return progress;
}

function getAchievementProgressMap(address: string): Map<string, AchievementProgressState> {
  const normalized = normalizeAddress(address);
  let progress = achievementProgressStore.get(normalized);
  if (!progress) {
    progress = new Map();
    achievementProgressStore.set(normalized, progress);
  }
  return progress;
}

function cloneChecklistTask(task: ChecklistTask): ChecklistTask {
  return {
    code: task.code,
    title: task.title,
    description: task.description,
    dayIndex: task.dayIndex,
    rewardKind: task.rewardKind,
    rewardValue: task.rewardValue ? { ...task.rewardValue } : null,
    metadata: task.metadata ? { ...task.metadata } : null,
    isActive: task.isActive,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  };
}

function buildChecklistStatus(address: string): ChecklistStatus {
  ensureChecklistSeed();
  const normalized = normalizeAddress(address);
  const progress = getChecklistProgressMap(normalized);

  const tasks = Array.from(checklistTaskStore.values())
    .sort((a, b) => a.dayIndex - b.dayIndex || a.code.localeCompare(b.code))
    .map((task) => {
      const entry = progress.get(task.code) ?? null;
      return {
        task: cloneChecklistTask(task),
        completed: Boolean(entry),
        completedAt: entry?.completedAt ?? null,
        rewardClaimed: entry?.rewardClaimed ?? false,
        metadata: entry?.metadata ? { ...entry.metadata } : null,
      } satisfies ChecklistProgressEntry;
    });

  return { address: normalized, tasks } satisfies ChecklistStatus;
}

function buildAchievementStatus(address: string): AchievementStatus {
  ensureAchievementSeed();
  const normalized = normalizeAddress(address);
  const progress = getAchievementProgressMap(normalized);

  const achievements = Array.from(achievementStore.values())
    .sort((a, b) => a.points - b.points || a.code.localeCompare(b.code))
    .map((achievement) => {
      const entry = progress.get(achievement.code) ?? null;
      return {
        achievement: structuredClone(achievement),
        unlocked: Boolean(entry?.unlockedAt),
        unlockedAt: entry?.unlockedAt ?? null,
        progressValue: entry?.progressValue ?? 0,
        metadata: entry?.metadata ? { ...entry.metadata } : null,
      } satisfies AchievementProgressEntry;
    });

  return { address: normalized, achievements } satisfies AchievementStatus;
}

function buildVrfLog(raw: RawVrfLog | null, lotteryId: number, limit: number): LotteryVrfLog {
  const effectiveRaw = raw ?? {
    round: {},
    hub: {},
  };

  return {
    lotteryId,
    limit,
    round: {
      snapshot: normalizeSnapshot(effectiveRaw.round?.snapshot),
      pendingRequestId: normalizePending(effectiveRaw.round?.pending_request_id),
      requests: cloneEvents(effectiveRaw.round?.requests, limit),
      fulfillments: cloneEvents(effectiveRaw.round?.fulfillments, limit),
    },
    hub: {
      requests: cloneEvents(effectiveRaw.hub?.requests, limit),
      fulfillments: cloneEvents(effectiveRaw.hub?.fulfillments, limit),
    },
  };
}

function buildDefaultProfile(address: string): AccountProfile {
  const now = new Date().toISOString();
  return {
    address,
    nickname: null,
    avatar: { kind: "none", value: null },
    telegram: null,
    twitter: null,
    settings: {},
    createdAt: now,
    updatedAt: now,
  };
}

function resolveProfile(address: string): AccountProfile {
  const normalized = normalizeAddress(address);
  const existing = profileStore.get(normalized);
  if (existing) {
    return structuredClone(existing);
  }
  const profile = buildDefaultProfile(normalized);
  profileStore.set(normalized, profile);
  return structuredClone(profile);
}

function mergeAvatar(current: AvatarInfo, update?: AvatarInfo | null): AvatarInfo {
  if (!update) {
    return current;
  }
  return {
    kind: update.kind ?? current.kind,
    value: update.value ?? current.value,
  };
}

function applyProfileUpdate(base: AccountProfile, input: AccountProfileUpdate): AccountProfile {
  const next: AccountProfile = structuredClone(base);
  if (input.nickname !== undefined) {
    next.nickname = input.nickname ? input.nickname.trim() : null;
  }
  if (input.telegram !== undefined) {
    next.telegram = input.telegram ? input.telegram.trim() : null;
  }
  if (input.twitter !== undefined) {
    next.twitter = input.twitter ? input.twitter.trim() : null;
  }
  if (input.settings !== undefined) {
    next.settings = input.settings ? { ...input.settings } : {};
  }
  next.avatar = mergeAvatar(next.avatar, input.avatar ?? undefined);
  next.updatedAt = new Date().toISOString();
  return next;
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

export async function fetchLotteryMultiViewsMock(
  options?: LotteryMultiViewsOptions,
): Promise<LotteryMultiViews> {
  const limitValue =
    typeof options?.limit === "number" && Number.isFinite(options.limit) && options.limit >= 0
      ? Math.floor(options.limit)
      : null;

  const clamp = (values: number[]): number[] => {
    if (limitValue === null) {
      return structuredClone(values);
    }
    return structuredClone(values.slice(0, limitValue));
  };

  return simulateDelay({
    info: structuredClone(lotteryMultiViewsSnapshot.info),
    statusOverview: structuredClone(lotteryMultiViewsSnapshot.statusOverview),
    listActive: clamp(lotteryMultiViewsSnapshot.listActive),
    listByPrimaryType: clamp(lotteryMultiViewsSnapshot.listByPrimaryType),
    listByTagMask: clamp(lotteryMultiViewsSnapshot.listByTagMask),
    listByAllTags: clamp(lotteryMultiViewsSnapshot.listByAllTags),
    listFinalizedIds: clamp(lotteryMultiViewsSnapshot.listFinalizedIds),
  });
}

export async function fetchLotteryStatusMock(): Promise<LotteryStatus> {
  return simulateDelay(statusSnapshot);
}

export async function fetchLotteryVrfLogMock(
  lotteryId: number,
  limit = DEFAULT_VRF_LOG_LIMIT,
): Promise<LotteryVrfLog> {
  const normalizedLimit = Math.max(1, Math.min(limit, MAX_VRF_LOG_LIMIT));
  const baseLotteryId = typeof vrfLogStore.lottery_id === "number" ? vrfLogStore.lottery_id : 0;
  const raw = lotteryId === baseLotteryId ? vrfLogStore : null;
  return simulateDelay(buildVrfLog(raw, lotteryId, normalizedLimit));
}

export async function fetchChatMessagesMock(
  room: string = "global",
  limit = 50,
): Promise<ChatMessage[]> {
  const safeLimit = Math.min(Math.max(1, limit), 200);
  const normalizedRoom = normalizeRoom(room);
  const messages = sortByCreatedAtAsc(
    chatMessageStore.filter((message) => normalizeRoom(message.room) === normalizedRoom),
  );
  return simulateDelay(messages.slice(-safeLimit));
}

export async function postChatMessageMock(input: PostChatMessageInput): Promise<ChatMessage> {
  const now = new Date().toISOString();
  const room = normalizeRoom(input.room ?? undefined);
  const body = (input.body ?? "").trim();
  if (!body) {
    throw new Error("Текст сообщения не может быть пустым");
  }

  chatMessageSequence += 1;
  const message: ChatMessage = {
    id: chatMessageSequence,
    room,
    senderAddress: normalizeAddress(input.address),
    body,
    metadata: ensureMetadata(input.metadata ?? undefined),
    createdAt: now,
  };
  chatMessageStore.push(message);
  return simulateDelay(message);
}

export async function fetchAnnouncementsMock(
  limit = 20,
  lotteryId?: string | null,
): Promise<Announcement[]> {
  const safeLimit = Math.min(Math.max(1, limit), 100);
  const normalizedLottery = lotteryId ? lotteryId.trim().toLowerCase() : null;
  const items = [...announcementStore]
    .filter((item) => {
      if (!normalizedLottery) {
        return true;
      }
      if (item.lotteryId === null) {
        return false;
      }
      return item.lotteryId.toLowerCase() === normalizedLottery;
    })
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, safeLimit);
  return simulateDelay(items);
}

export async function postAnnouncementMock(input: PostAnnouncementInput): Promise<Announcement> {
  const now = new Date().toISOString();
  const title = (input.title ?? "").trim();
  const body = (input.body ?? "").trim();
  if (!title || !body) {
    throw new Error("Объявление должно содержать заголовок и текст");
  }
  const lotteryId = input.lotteryId ? input.lotteryId.trim() : null;

  announcementSequence += 1;
  const announcement: Announcement = {
    id: announcementSequence,
    title,
    body,
    lotteryId: lotteryId && lotteryId.length ? lotteryId : null,
    metadata: ensureMetadata(input.metadata ?? undefined),
    createdAt: now,
  };
  announcementStore.push(announcement);
  return simulateDelay(announcement);
}

export async function fetchAccountProfileMock(address: string): Promise<AccountProfile | null> {
  if (!address.trim()) {
    return simulateDelay(null);
  }
  const profile = resolveProfile(address);
  return simulateDelay(profile);
}

export async function upsertAccountProfileMock(
  address: string,
  input: AccountProfileUpdate,
): Promise<AccountProfile> {
  const normalized = normalizeAddress(address);
  const current = resolveProfile(normalized);
  const next = applyProfileUpdate(current, input);
  profileStore.set(normalized, structuredClone(next));
  return simulateDelay(next);
}

export async function fetchChecklistStatusMock(address: string): Promise<ChecklistStatus> {
  const target = address.trim() ? address : "guest";
  return simulateDelay(buildChecklistStatus(target));
}

export async function completeChecklistTaskMock(
  address: string,
  code: string,
  input?: ChecklistCompleteInput,
): Promise<ChecklistProgressEntry> {
  ensureChecklistSeed();
  const task = checklistTaskStore.get(code);
  if (!task) {
    throw new Error(`Mock checklist task ${code} не найден`);
  }
  const normalized = normalizeAddress(address);
  const progressMap = getChecklistProgressMap(normalized);
  const existing = progressMap.get(code) ?? null;
  const now = new Date().toISOString();
  const completedAt = existing?.completedAt ?? now;
  const rewardClaimed =
    input?.rewardClaimed !== undefined ? input.rewardClaimed : existing?.rewardClaimed ?? false;
  const metadata = (() => {
    if (input?.metadata === undefined) {
      return existing?.metadata ? { ...existing.metadata } : null;
    }
    if (!input.metadata) {
      return null;
    }
    return { ...input.metadata };
  })();

  progressMap.set(code, { completedAt, rewardClaimed, metadata });

  const entry: ChecklistProgressEntry = {
    task: cloneChecklistTask(task),
    completed: true,
    completedAt,
    rewardClaimed,
    metadata,
  };

  return simulateDelay(entry);
}

export async function fetchAchievementsStatusMock(address: string): Promise<AchievementStatus> {
  const target = address.trim() ? address : "guest";
  return simulateDelay(buildAchievementStatus(target));
}

export async function unlockAchievementMock(
  address: string,
  code: string,
  input?: AchievementUnlockInput,
): Promise<AchievementProgressEntry> {
  ensureAchievementSeed();
  const achievement = achievementStore.get(code);
  if (!achievement) {
    throw new Error(`Mock achievement ${code} не найдено`);
  }
  const normalized = normalizeAddress(address);
  const progressMap = getAchievementProgressMap(normalized);
  const existing = progressMap.get(code) ?? { unlockedAt: null, progressValue: 0, metadata: null };
  const now = new Date().toISOString();
  const progressValue = input?.progressValue ?? existing.progressValue ?? 0;
  const metadata = (() => {
    if (input?.metadata === undefined) {
      return existing.metadata ? { ...existing.metadata } : null;
    }
    if (!input.metadata) {
      return null;
    }
    return { ...input.metadata };
  })();
  const unlockedAt = existing.unlockedAt ?? now;
  progressMap.set(code, { unlockedAt, progressValue, metadata });

  const entry: AchievementProgressEntry = {
    achievement: structuredClone(achievement),
    unlocked: true,
    unlockedAt,
    progressValue,
    metadata,
  };

  return simulateDelay(entry);
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
  const lottery = statusSnapshot.lotteries.find((item) => item.id === input.lotteryId) ?? null;

  if (!lottery) {
    throw new Error(`Mock lottery ${input.lotteryId} is not available.`);
  }

  const ticket: TicketPurchase = {
    ticketId: generateTicketId(input.lotteryId, input.round),
    lotteryId: input.lotteryId,
    round: input.round,
    numbers: input.numbers,
    purchaseTime: now.toISOString(),
    status: "pending",
    txHash: generateTxHash(),
  };

  ticketStore.unshift(ticket);

  const ticketPriceSupra = toNumber(adminConfigStore.treasury.config.ticketPriceSupra);
  if (lottery) {
    const stats = lottery.stats ?? { ticketsSold: 0, jackpotAccumulatedSupra: "0" };
    stats.ticketsSold = (stats.ticketsSold ?? 0) + 1;
    stats.jackpotAccumulatedSupra = formatAmount(
      toNumber(stats.jackpotAccumulatedSupra ?? "0") + ticketPriceSupra,
    );
    lottery.stats = stats;

    const pool = lottery.treasury.pool ?? { prizeSupra: "0", operationsSupra: "0" };
    const distribution = adminConfigStore.treasury.config.distributionBp;
    pool.prizeSupra = formatAmount(
      toNumber(pool.prizeSupra ?? "0") + ticketPriceSupra * (distribution.prize / 10_000),
    );
    pool.operationsSupra = formatAmount(
      toNumber(pool.operationsSupra ?? "0") + ticketPriceSupra * (distribution.treasury / 10_000),
    );
    lottery.treasury.pool = pool;

    const snapshot = lottery.round.snapshot ?? {
      ticketCount: 0,
      drawScheduled: true,
      hasPendingRequest: false,
      nextTicketId: 0,
    };
    snapshot.ticketCount = (snapshot.ticketCount ?? 0) + 1;
    snapshot.nextTicketId = (snapshot.nextTicketId ?? 0) + 1;
    lottery.round = {
      snapshot,
      pendingRequestId: lottery.round.pendingRequestId,
    };
  }

  statusSnapshot.treasury.jackpotBalance = formatAmount(
    toNumber(statusSnapshot.treasury.jackpotBalance ?? "0") +
      ticketPriceSupra * (adminConfigStore.treasury.config.distributionBp.jackpot / 10_000),
  );
  statusSnapshot.timestamp = now.toISOString();

  applyTreasurySplit(ticketPriceSupra);

  eventStore.unshift({
    eventId: `EVT-${eventStore.length + 1}`,
    type: "TicketBought",
    round: input.round,
    timestamp: now.toISOString(),
    details: `Mock purchase of ticket ${ticket.ticketId} for lottery ${input.lotteryId}`,
    txHash: ticket.txHash,
    status: "success",
  });

  return simulateDelay(ticket);
}

export async function listCommandsMock(): Promise<SupraCommandInfo[]> {
  return simulateDelay(mockCommands);
}
