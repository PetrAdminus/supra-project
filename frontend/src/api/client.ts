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
  LotteryMultiViews,
  LotteryMultiViewsOptions,
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
import type { LotteryApi } from "./interface";
import {
  completeChecklistTaskMock,
  fetchAccountProfileMock,
  fetchAchievementsStatusMock,
  fetchAdminConfigMock,
  fetchAnnouncementsMock,
  fetchLotteryMultiViewsMock,
  fetchChecklistStatusMock,
  fetchEventsMock,
  fetchLotteryStatusMock,
  fetchLotteryVrfLogMock,
  fetchTicketsMock,
  fetchTreasuryBalancesMock,
  fetchTreasuryConfigMock,
  fetchWhitelistStatusMock,
  listCommandsMock,
  postAnnouncementMock,
  postChatMessageMock,
  purchaseTicketMock,
  recordClientWhitelistSnapshotMock,
  recordConsumerWhitelistSnapshotMock,
  unlockAchievementMock,
  updateGasConfigMock,
  updateTreasuryControlsMock,
  updateTreasuryDistributionMock,
  updateVrfConfigMock,
  upsertAccountProfileMock,
  fetchChatMessagesMock,
} from "./mockClient";
import {
  completeChecklistTaskSupra,
  fetchAccountProfileSupra,
  fetchAchievementsSupra,
  fetchAdminConfigSupra,
  fetchChecklistSupra,
  fetchChatMessagesSupra,
  fetchLotteryEventsSupra,
  fetchLotteryStatusSupra,
  fetchLotteryMultiViewsSupra,
  fetchLotteryVrfLogSupra,
  fetchTicketsSupra,
  fetchTreasuryBalancesSupra,
  fetchTreasuryConfigSupra,
  fetchWhitelistStatusSupra,
  listSupraCommandsSupra,
  fetchAnnouncementsSupra,
  postAnnouncementSupra,
  postChatMessageSupra,
  purchaseTicketSupra,
  recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshotSupra,
  unlockAchievementSupra,
  updateGasConfigSupra,
  updateTreasuryControlsSupra,
  updateTreasuryDistributionSupra,
  updateVrfConfigSupra,
  upsertAccountProfileSupra,
} from "./supraClient";
import { useUiStore } from "../store/uiStore";
import type { ApiMode } from "../config/appConfig";

const mockApi: LotteryApi = {
  fetchLotteryStatus: fetchLotteryStatusMock,
  fetchLotteryMultiViews: fetchLotteryMultiViewsMock,
  fetchWhitelistStatus: fetchWhitelistStatusMock,
  fetchTickets: fetchTicketsMock,
  fetchEvents: fetchEventsMock,
  purchaseTicket: purchaseTicketMock,
  fetchAccountProfile: fetchAccountProfileMock,
  upsertAccountProfile: upsertAccountProfileMock,
  fetchChecklist: fetchChecklistStatusMock,
  completeChecklist: completeChecklistTaskMock,
  fetchAchievements: fetchAchievementsStatusMock,
  unlockAchievement: unlockAchievementMock,
  fetchAdminConfig: fetchAdminConfigMock,
  fetchTreasuryConfig: fetchTreasuryConfigMock,
  fetchTreasuryBalances: fetchTreasuryBalancesMock,
  updateGasConfig: updateGasConfigMock,
  updateVrfConfig: updateVrfConfigMock,
  updateTreasuryDistribution: updateTreasuryDistributionMock,
  updateTreasuryControls: updateTreasuryControlsMock,
  recordClientWhitelistSnapshot: recordClientWhitelistSnapshotMock,
  recordConsumerWhitelistSnapshot: recordConsumerWhitelistSnapshotMock,
  listCommands: listCommandsMock,
  fetchLotteryVrfLog: fetchLotteryVrfLogMock,
  fetchChatMessages: fetchChatMessagesMock,
  postChatMessage: postChatMessageMock,
  fetchAnnouncements: fetchAnnouncementsMock,
  postAnnouncement: postAnnouncementMock,
};

const supraApi: LotteryApi = {
  fetchLotteryStatus: fetchLotteryStatusSupra,
  fetchLotteryMultiViews: fetchLotteryMultiViewsSupra,
  fetchWhitelistStatus: fetchWhitelistStatusSupra,
  fetchTickets: fetchTicketsSupra,
  fetchEvents: fetchLotteryEventsSupra,
  purchaseTicket: purchaseTicketSupra,
  fetchAccountProfile: fetchAccountProfileSupra,
  upsertAccountProfile: upsertAccountProfileSupra,
  fetchChecklist: fetchChecklistSupra,
  completeChecklist: completeChecklistTaskSupra,
  fetchAchievements: fetchAchievementsSupra,
  unlockAchievement: unlockAchievementSupra,
  fetchAdminConfig: fetchAdminConfigSupra,
  fetchTreasuryConfig: fetchTreasuryConfigSupra,
  fetchTreasuryBalances: fetchTreasuryBalancesSupra,
  updateGasConfig: updateGasConfigSupra,
  updateVrfConfig: updateVrfConfigSupra,
  updateTreasuryDistribution: updateTreasuryDistributionSupra,
  updateTreasuryControls: updateTreasuryControlsSupra,
  recordClientWhitelistSnapshot: recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshot: recordConsumerWhitelistSnapshotSupra,
  listCommands: listSupraCommandsSupra,
  fetchLotteryVrfLog: fetchLotteryVrfLogSupra,
  fetchChatMessages: fetchChatMessagesSupra,
  postChatMessage: postChatMessageSupra,
  fetchAnnouncements: fetchAnnouncementsSupra,
  postAnnouncement: postAnnouncementSupra,
};

const apiByMode: Record<ApiMode, LotteryApi> = {
  mock: mockApi,
  supra: supraApi,
};

function getMode() {
  return useUiStore.getState().apiMode;
}

function getApi(): LotteryApi {
  return apiByMode[getMode()];
}

export async function fetchLotteryStatus(): Promise<LotteryStatus> {
  return getApi().fetchLotteryStatus();
}

export async function fetchLotteryMultiViews(
  options?: LotteryMultiViewsOptions,
): Promise<LotteryMultiViews> {
  return getApi().fetchLotteryMultiViews(options);
}

export async function fetchWhitelistStatus(): Promise<WhitelistStatus> {
  return getApi().fetchWhitelistStatus();
}

export async function fetchTickets(): Promise<TicketPurchase[]> {
  return getApi().fetchTickets();
}

export async function fetchLotteryEvents(): Promise<LotteryEvent[]> {
  return getApi().fetchEvents();
}

export async function purchaseTicket(input: PurchaseTicketInput): Promise<TicketPurchase> {
  return getApi().purchaseTicket(input);
}

export async function fetchAccountProfile(address: string): Promise<AccountProfile | null> {
  return getApi().fetchAccountProfile(address);
}

export async function upsertAccountProfile(
  address: string,
  input: AccountProfileUpdate,
): Promise<AccountProfile> {
  return getApi().upsertAccountProfile(address, input);
}

export async function fetchChecklist(address: string): Promise<ChecklistStatus> {
  return getApi().fetchChecklist(address);
}

export async function completeChecklist(
  address: string,
  code: string,
  input?: ChecklistCompleteInput,
): Promise<ChecklistStatus["tasks"][number]> {
  return getApi().completeChecklist(address, code, input);
}

export async function fetchAchievements(address: string): Promise<AchievementStatus> {
  return getApi().fetchAchievements(address);
}

export async function unlockAchievement(
  address: string,
  code: string,
  input?: AchievementUnlockInput,
): Promise<AchievementStatus["achievements"][number]> {
  return getApi().unlockAchievement(address, code, input);
}

export async function fetchAdminConfig(): Promise<AdminConfig> {
  return getApi().fetchAdminConfig();
}

export async function fetchTreasuryConfig(): Promise<TreasuryConfig> {
  return getApi().fetchTreasuryConfig();
}

export async function fetchTreasuryBalances(): Promise<TreasuryBalances> {
  return getApi().fetchTreasuryBalances();
}

export async function updateGasConfig(
  input: UpdateGasConfigInput,
): Promise<AdminMutationResult> {
  return getApi().updateGasConfig(input);
}

export async function updateVrfConfig(
  input: UpdateVrfConfigInput,
): Promise<AdminMutationResult> {
  return getApi().updateVrfConfig(input);
}

export async function updateTreasuryDistribution(
  input: UpdateTreasuryDistributionInput,
): Promise<AdminMutationResult> {
  return getApi().updateTreasuryDistribution(input);
}

export async function updateTreasuryControls(
  input: UpdateTreasuryControlsInput,
): Promise<AdminMutationResult> {
  return getApi().updateTreasuryControls(input);
}

export async function recordClientWhitelistSnapshot(
  input: RecordClientWhitelistInput,
): Promise<AdminMutationResult> {
  return getApi().recordClientWhitelistSnapshot(input);
}

export async function recordConsumerWhitelistSnapshot(
  input: RecordConsumerWhitelistInput,
): Promise<AdminMutationResult> {
  return getApi().recordConsumerWhitelistSnapshot(input);
}

export async function listCommands(): Promise<SupraCommandInfo[]> {
  return getApi().listCommands();
}

export async function fetchLotteryVrfLog(
  lotteryId: number,
  limit?: number,
): Promise<LotteryVrfLog> {
  return getApi().fetchLotteryVrfLog(lotteryId, limit);
}

export async function fetchChatMessages(
  room?: string,
  limit?: number,
): Promise<ChatMessage[]> {
  return getApi().fetchChatMessages(room, limit);
}

export async function postChatMessage(input: PostChatMessageInput): Promise<ChatMessage> {
  return getApi().postChatMessage(input);
}

export async function fetchAnnouncements(
  limit?: number,
  lotteryId?: string | null,
): Promise<Announcement[]> {
  return getApi().fetchAnnouncements(limit, lotteryId);
}

export async function postAnnouncement(input: PostAnnouncementInput): Promise<Announcement> {
  return getApi().postAnnouncement(input);
}

export function getCurrentApi(): LotteryApi {
  return getApi();
}
