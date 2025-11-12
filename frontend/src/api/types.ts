export type TicketStatus = 'pending' | 'confirmed' | 'won' | 'lost';

export interface TicketPurchase {
  ticketId: string;
  lotteryId: number;
  round: number;
  numbers: number[];
  purchaseTime: string;
  status: TicketStatus;
  txHash: string | null;
}

export interface PurchaseTicketInput {
  lotteryId: number;
  round: number;
  numbers: number[];
}

export type EventType = 'DrawRequested' | 'DrawHandled' | 'TicketBought' | 'TicketRefunded';
export type EventStatus = 'success' | 'failed' | 'retry';

export interface LotteryEvent {
  eventId: string;
  type: EventType;
  round: number;
  timestamp: string;
  details: string;
  txHash: string;
  status?: EventStatus;
}

export interface LotteryRoundSnapshot {
  ticketCount: number | null;
  drawScheduled: boolean | null;
  hasPendingRequest: boolean | null;
  nextTicketId: number | null;
}

export interface LotteryRoundStatus {
  snapshot: LotteryRoundSnapshot | null;
  pendingRequestId: string | null;
}

export interface LotteryRegistrationSummary {
  owner: string | null;
  lotteryAddress: string | null;
  metadataHex: string | null;
  active: boolean;
}

export interface LotteryBlueprintSummary {
  ticketPriceSupra: string | null;
  jackpotShareBps: number | null;
}

export interface LotteryFactorySummary {
  owner: string | null;
  lotteryAddress: string | null;
  blueprint: LotteryBlueprintSummary | null;
}

export interface LotteryInstanceSummary {
  owner: string | null;
  lotteryAddress: string | null;
  blueprint: LotteryBlueprintSummary | null;
}

export interface LotteryStatsSummary {
  ticketsSold: number | null;
  jackpotAccumulatedSupra: string | null;
}

export interface LotteryTreasuryConfigSummary {
  jackpotBp: number | null;
  prizeBp: number | null;
  operationsBp: number | null;
}

export interface LotteryTreasuryPoolSummary {
  prizeSupra: string | null;
  operationsSupra: string | null;
}

export interface LotteryTreasurySummary {
  config: LotteryTreasuryConfigSummary | null;
  pool: LotteryTreasuryPoolSummary | null;
}

export interface LotterySummary {
  id: number;
  registration: LotteryRegistrationSummary | null;
  factory: LotteryFactorySummary | null;
  instance: LotteryInstanceSummary | null;
  stats: LotteryStatsSummary | null;
  round: LotteryRoundStatus;
  treasury: LotteryTreasurySummary;
}

export type VrfLogEvent = Record<string, unknown>;

export interface LotteryVrfRoundLog {
  snapshot: Record<string, unknown> | null;
  pendingRequestId: string | null;
  requests: VrfLogEvent[];
  fulfillments: VrfLogEvent[];
}

export interface LotteryVrfHubLog {
  requests: VrfLogEvent[];
  fulfillments: VrfLogEvent[];
}

export interface LotteryVrfLog {
  lotteryId: number;
  limit: number;
  round: LotteryVrfRoundLog;
  hub: LotteryVrfHubLog;
}

export interface HubStatus {
  lotteryCount: number | null;
  nextLotteryId: number | null;
  callbackSender: string | null;
  configuredLotteryIds: number[];
}

export interface DepositStatus {
  balance: string | null;
  minBalance: string | null;
  minBalanceReached: boolean | null;
  subscriptionInfo: Record<string, unknown>;
  contractDetails: Record<string, unknown>;
  whitelistedContracts: string[];
  maxGasPrice: string | null;
  maxGasLimit: string | null;
}

export interface TreasuryStatus {
  jackpotBalance: string | null;
  tokenBalance: string | null;
  totalSupply: string | null;
  metadata: Record<string, unknown>;
}

export interface VrfStatus {
  subscriptionId: string | null;
  pendingRequestId: string | null;
  lastRequestTime: string | null;
  lastFulfillmentTime: string | null;
}

export interface LotteryStatus {
  timestamp: string;
  profile: string | null;
  calculation: Record<string, unknown> | null;
  addresses: {
    lottery: string | null;
    hub: string | null;
    factory: string | null;
    deposit: string | null;
    client: string | null;
  };
  hub: HubStatus;
  lotteries: LotterySummary[];
  deposit: DepositStatus;
  treasury: TreasuryStatus;
  vrf: VrfStatus;
}

export interface LotteryMultiViewsInfo {
  version: string | null;
  updatedAt: string | null;
}

export interface LotteryMultiStatusOverview {
  total: number;
  draft: number;
  active: number;
  closing: number;
  drawRequested: number;
  drawn: number;
  payout: number;
  finalized: number;
  canceled: number;
  vrfRequested: number;
  vrfFulfilledPending: number;
  vrfRetryBlocked: number;
  winnersPending: number;
  payoutBacklog: number;
}

export interface LotteryMultiViews {
  info: LotteryMultiViewsInfo;
  statusOverview: LotteryMultiStatusOverview;
  listActive: number[];
  listByPrimaryType: number[];
  listByTagMask: number[];
  listByAllTags: number[];
  listFinalizedIds: number[];
}

export interface LotteryMultiViewsOptions {
  nowTs?: number;
  limit?: number | null;
  primaryType?: number | null;
  tagMask?: number | null;
}

export interface WhitelistStatus {
  account: string | null;
  profile: string | null;
  isWhitelisted: boolean;
  checkedAt: string | null;
}

export interface TreasuryDistributionBp {
  jackpot: number;
  prize: number;
  treasury: number;
  marketing: number;
}

export interface TreasuryConfig {
  ticketPriceSupra: string;
  salesEnabled: boolean;
  treasuryAddress: string;
  distributionBp: TreasuryDistributionBp;
  updatedAt: string;
}

export interface TreasuryBalances {
  jackpotSupra: string;
  prizeSupra: string;
  treasurySupra: string;
  marketingSupra: string;
  updatedAt: string;
}

export interface AdminGasConfig {
  maxGasFee: number;
  minBalance: number;
  updatedAt: string;
}

export interface AdminVrfConfig {
  maxGasPrice: string;
  maxGasLimit: string;
  callbackGasPrice: string;
  callbackGasLimit: string;
  requestedRngCount: number;
  clientSeed: number;
  lastConfiguredAt: string;
}

export interface AdminWhitelistSnapshot {
  maxGasPrice: string;
  maxGasLimit: string;
  minBalanceLimit: string;
  updatedAt: string;
}

export interface AdminConsumerWhitelistSnapshot {
  callbackGasPrice: string;
  callbackGasLimit: string;
  updatedAt: string;
}

export interface AdminTreasuryConfig {
  config: TreasuryConfig;
  balances: TreasuryBalances;
}

export interface AdminConfig {
  gas: AdminGasConfig;
  vrf: AdminVrfConfig;
  whitelist: {
    clientConfigured: boolean;
    consumerConfigured: boolean;
    client: AdminWhitelistSnapshot | null;
    consumer: AdminConsumerWhitelistSnapshot | null;
  };
  treasury: AdminTreasuryConfig;
}

export interface AdminMutationResult {
  txHash: string;
  submittedAt: string;
}

export interface UpdateGasConfigInput {
  maxGasFee: number;
  minBalance: number;
}

export interface UpdateVrfConfigInput {
  maxGasPrice: string;
  maxGasLimit: string;
  callbackGasPrice: string;
  callbackGasLimit: string;
  requestedRngCount: number;
  clientSeed: number;
}

export interface RecordClientWhitelistInput {
  maxGasPrice: string;
  maxGasLimit: string;
  minBalanceLimit: string;
}

export interface RecordConsumerWhitelistInput {
  callbackGasPrice: string;
  callbackGasLimit: string;
}

export interface UpdateTreasuryDistributionInput {
  jackpotBp: number;
  prizeBp: number;
  treasuryBp: number;
  marketingBp: number;
}

export interface UpdateTreasuryControlsInput {
  ticketPriceSupra: string;
  treasuryAddress: string;
  salesEnabled: boolean;
}

export interface SupraCommandInfo {
  name: string;
  module: string;
  description: string;
}

export interface AvatarInfo {
  kind: string;
  value?: string | null;
}

export interface AccountProfile {
  address: string;
  nickname: string | null;
  avatar: AvatarInfo;
  telegram: string | null;
  twitter: string | null;
  settings: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface AccountProfileUpdate {
  nickname?: string | null;
  avatar?: AvatarInfo | null;
  telegram?: string | null;
  twitter?: string | null;
  settings?: Record<string, unknown> | null;
}

export interface ChecklistTask {
  code: string;
  title: string;
  description: string | null;
  dayIndex: number;
  rewardKind: string | null;
  rewardValue: Record<string, unknown> | null;
  metadata: Record<string, unknown> | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ChecklistProgressEntry {
  task: ChecklistTask;
  completed: boolean;
  completedAt: string | null;
  rewardClaimed: boolean;
  metadata: Record<string, unknown> | null;
}

export interface ChecklistStatus {
  address: string;
  tasks: ChecklistProgressEntry[];
}

export interface ChecklistCompleteInput {
  metadata?: Record<string, unknown> | null;
  rewardClaimed?: boolean;
}

export interface Achievement {
  code: string;
  title: string;
  description: string;
  points: number;
  metadata: Record<string, unknown> | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AchievementProgressEntry {
  achievement: Achievement;
  unlocked: boolean;
  unlockedAt: string | null;
  progressValue: number;
  metadata: Record<string, unknown> | null;
}

export interface AchievementStatus {
  address: string;
  achievements: AchievementProgressEntry[];
}

export interface AchievementUnlockInput {
  progressValue?: number | null;
  metadata?: Record<string, unknown> | null;
}

export interface ChatMessage {
  id: number;
  room: string;
  senderAddress: string;
  body: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface PostChatMessageInput {
  address: string;
  body: string;
  room?: string | null;
  metadata?: Record<string, unknown> | null;
}

export interface Announcement {
  id: number;
  title: string;
  body: string;
  lotteryId: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface PostAnnouncementInput {
  title: string;
  body: string;
  lotteryId?: string | null;
  metadata?: Record<string, unknown> | null;
}

