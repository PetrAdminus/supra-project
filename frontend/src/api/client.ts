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
import type { LotteryApi } from "./interface";
import {
  fetchAdminConfigMock,
  fetchEventsMock,
  fetchLotteryStatusMock,
  fetchTicketsMock,
  fetchTreasuryBalancesMock,
  fetchTreasuryConfigMock,
  fetchWhitelistStatusMock,
  purchaseTicketMock,
  recordClientWhitelistSnapshotMock,
  recordConsumerWhitelistSnapshotMock,
  updateGasConfigMock,
  updateTreasuryControlsMock,
  updateTreasuryDistributionMock,
  updateVrfConfigMock,
} from "./mockClient";
import {
  fetchAdminConfigSupra,
  fetchLotteryEventsSupra,
  fetchLotteryStatusSupra,
  fetchTicketsSupra,
  fetchTreasuryBalancesSupra,
  fetchTreasuryConfigSupra,
  fetchWhitelistStatusSupra,
  purchaseTicketSupra,
  recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshotSupra,
  updateGasConfigSupra,
  updateTreasuryControlsSupra,
  updateTreasuryDistributionSupra,
  updateVrfConfigSupra,
} from "./supraClient";
import { useUiStore } from "../store/uiStore";
import type { ApiMode } from "../config/appConfig";

const mockApi: LotteryApi = {
  fetchLotteryStatus: fetchLotteryStatusMock,
  fetchWhitelistStatus: fetchWhitelistStatusMock,
  fetchTickets: fetchTicketsMock,
  fetchEvents: fetchEventsMock,
  purchaseTicket: purchaseTicketMock,
  fetchAdminConfig: fetchAdminConfigMock,
  fetchTreasuryConfig: fetchTreasuryConfigMock,
  fetchTreasuryBalances: fetchTreasuryBalancesMock,
  updateGasConfig: updateGasConfigMock,
  updateVrfConfig: updateVrfConfigMock,
  updateTreasuryDistribution: updateTreasuryDistributionMock,
  updateTreasuryControls: updateTreasuryControlsMock,
  recordClientWhitelistSnapshot: recordClientWhitelistSnapshotMock,
  recordConsumerWhitelistSnapshot: recordConsumerWhitelistSnapshotMock,
};

const supraApi: LotteryApi = {
  fetchLotteryStatus: fetchLotteryStatusSupra,
  fetchWhitelistStatus: fetchWhitelistStatusSupra,
  fetchTickets: fetchTicketsSupra,
  fetchEvents: fetchLotteryEventsSupra,
  purchaseTicket: purchaseTicketSupra,
  fetchAdminConfig: fetchAdminConfigSupra,
  fetchTreasuryConfig: fetchTreasuryConfigSupra,
  fetchTreasuryBalances: fetchTreasuryBalancesSupra,
  updateGasConfig: updateGasConfigSupra,
  updateVrfConfig: updateVrfConfigSupra,
  updateTreasuryDistribution: updateTreasuryDistributionSupra,
  updateTreasuryControls: updateTreasuryControlsSupra,
  recordClientWhitelistSnapshot: recordClientWhitelistSnapshotSupra,
  recordConsumerWhitelistSnapshot: recordConsumerWhitelistSnapshotSupra,
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

export function getCurrentApi(): LotteryApi {
  return getApi();
}
