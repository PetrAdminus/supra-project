export type TicketStatus = 'pending' | 'confirmed' | 'won' | 'lost';

export interface TicketPurchase {
  ticketId: string;
  round: number;
  numbers: number[];
  purchaseTime: string;
  status: TicketStatus;
  txHash: string | null;
}

export interface PurchaseTicketInput {
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

export interface VrfStatus {
  subscriptionId: string | null;
  requestPending: boolean;
  lastRequestTime: string | null;
  lastFulfillmentTime: string | null;
}

export interface LotteryStatus {
  round: number | null;
  jackpotSupra: string | null;
  ticketsSold: number | null;
  ticketPriceSupra: string | null;
  nextDrawTime: string | null;
  vrf: VrfStatus;
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

