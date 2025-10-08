import type {
  AdminConfig,
  AdminMutationResult,
  AccountProfile,
  AccountProfileUpdate,
  AchievementStatus,
  AchievementUnlockInput,
  Announcement,
  ChecklistCompleteInput,
  ChecklistStatus,
  ChatMessage,
  LotteryEvent,
  LotteryVrfLog,
  LotteryStatus,
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

export interface LotteryApi {
  fetchLotteryStatus(): Promise<LotteryStatus>;
  fetchWhitelistStatus(): Promise<WhitelistStatus>;
  fetchTickets(): Promise<TicketPurchase[]>;
  fetchEvents(): Promise<LotteryEvent[]>;
  purchaseTicket(input: PurchaseTicketInput): Promise<TicketPurchase>;
  fetchAccountProfile(address: string): Promise<AccountProfile | null>;
  upsertAccountProfile(address: string, input: AccountProfileUpdate): Promise<AccountProfile>;
  fetchChecklist(address: string): Promise<ChecklistStatus>;
  completeChecklist(
    address: string,
    code: string,
    input?: ChecklistCompleteInput,
  ): Promise<ChecklistStatus['tasks'][number]>;
  fetchAchievements(address: string): Promise<AchievementStatus>;
  unlockAchievement(
    address: string,
    code: string,
    input?: AchievementUnlockInput,
  ): Promise<AchievementStatus['achievements'][number]>;

  fetchAdminConfig(): Promise<AdminConfig>;
  fetchTreasuryConfig(): Promise<TreasuryConfig>;
  fetchTreasuryBalances(): Promise<TreasuryBalances>;
  updateGasConfig(input: UpdateGasConfigInput): Promise<AdminMutationResult>;
  updateVrfConfig(input: UpdateVrfConfigInput): Promise<AdminMutationResult>;
  updateTreasuryDistribution(input: UpdateTreasuryDistributionInput): Promise<AdminMutationResult>;
  updateTreasuryControls(input: UpdateTreasuryControlsInput): Promise<AdminMutationResult>;
  recordClientWhitelistSnapshot(
    input: RecordClientWhitelistInput,
  ): Promise<AdminMutationResult>;
  recordConsumerWhitelistSnapshot(
    input: RecordConsumerWhitelistInput,
  ): Promise<AdminMutationResult>;
  listCommands(): Promise<SupraCommandInfo[]>;
  fetchLotteryVrfLog(lotteryId: number, limit?: number): Promise<LotteryVrfLog>;
  fetchChatMessages(room?: string, limit?: number): Promise<ChatMessage[]>;
  postChatMessage(input: PostChatMessageInput): Promise<ChatMessage>;
  fetchAnnouncements(limit?: number, lotteryId?: string | null): Promise<Announcement[]>;
  postAnnouncement(input: PostAnnouncementInput): Promise<Announcement>;
}
