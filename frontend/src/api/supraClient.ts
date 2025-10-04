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

const notImplemented = (method: string) =>
  Promise.reject(new Error(`${method}: Supra API client is not implemented yet`));

export async function fetchAdminConfigSupra(): Promise<AdminConfig> {
  return notImplemented("fetchAdminConfigSupra");
}

export async function fetchTreasuryConfigSupra(): Promise<TreasuryConfig> {
  return notImplemented("fetchTreasuryConfigSupra");
}

export async function fetchTreasuryBalancesSupra(): Promise<TreasuryBalances> {
  return notImplemented("fetchTreasuryBalancesSupra");
}

export async function fetchLotteryStatusSupra(): Promise<LotteryStatus> {
  return notImplemented("fetchLotteryStatusSupra");
}

export async function fetchWhitelistStatusSupra(): Promise<WhitelistStatus> {
  return notImplemented("fetchWhitelistStatusSupra");
}

export async function fetchTicketsSupra(): Promise<TicketPurchase[]> {
  return notImplemented("fetchTicketsSupra");
}

export async function fetchLotteryEventsSupra(): Promise<LotteryEvent[]> {
  return notImplemented("fetchLotteryEventsSupra");
}

export async function updateGasConfigSupra(
  input: UpdateGasConfigInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("updateGasConfigSupra");
}

export async function updateVrfConfigSupra(
  input: UpdateVrfConfigInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("updateVrfConfigSupra");
}

export async function updateTreasuryDistributionSupra(
  input: UpdateTreasuryDistributionInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("updateTreasuryDistributionSupra");
}

export async function updateTreasuryControlsSupra(
  input: UpdateTreasuryControlsInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("updateTreasuryControlsSupra");
}

export async function recordClientWhitelistSnapshotSupra(
  input: RecordClientWhitelistInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("recordClientWhitelistSnapshotSupra");
}

export async function recordConsumerWhitelistSnapshotSupra(
  input: RecordConsumerWhitelistInput,
): Promise<AdminMutationResult> {
  void input;
  return notImplemented("recordConsumerWhitelistSnapshotSupra");
}

export async function purchaseTicketSupra(
  input: PurchaseTicketInput,
): Promise<TicketPurchase> {
  void input;
  return notImplemented("purchaseTicketSupra");
}
