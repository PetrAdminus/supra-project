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
  subscriptionId: string;
  requestPending: boolean;
  lastRequestTime: string;
  lastFulfillmentTime: string | null;
}

export interface LotteryStatus {
  round: number;
  jackpotSupra: string;
  ticketsSold: number;
  ticketPriceSupra: string;
  nextDrawTime: string;
  vrf: VrfStatus;
}

export interface WhitelistStatus {
  account: string;
  profile: string;
  isWhitelisted: boolean;
  checkedAt: string;
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

export interface AdminConfig {
  gas: AdminGasConfig;
  vrf: AdminVrfConfig;
  whitelist: {
    clientConfigured: boolean;
    consumerConfigured: boolean;
    client: AdminWhitelistSnapshot | null;
    consumer: AdminConsumerWhitelistSnapshot | null;
  };
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
