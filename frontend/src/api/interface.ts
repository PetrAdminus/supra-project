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

export interface LotteryApi {
  fetchLotteryStatus(): Promise<LotteryStatus>;
  fetchWhitelistStatus(): Promise<WhitelistStatus>;
  fetchTickets(): Promise<TicketPurchase[]>;
  fetchEvents(): Promise<LotteryEvent[]>;
  purchaseTicket(input: PurchaseTicketInput): Promise<TicketPurchase>;

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
}
