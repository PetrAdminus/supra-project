export type WalletStatus = "disconnected" | "connecting" | "connected";
export type WalletProvider = "starkey" | "walletconnect";

export interface WalletInfo {
  status: WalletStatus;
  provider: WalletProvider;
  address?: string;
  lastConnectedAt?: string;
}

type WalletListener = (wallet: WalletInfo) => void;

const DEFAULT_PROVIDER: WalletProvider = "starkey";
const ACCOUNT_POOL = [
  "0x9a96...4490",
  "0x1c3e...f00d",
  "0xdead...beef",
  "0xcafe...babe",
];

let accountCursor = 0;
let currentWallet: WalletInfo = {
  status: "disconnected",
  provider: DEFAULT_PROVIDER,
};

const listeners = new Set<WalletListener>();

function clone(wallet: WalletInfo): WalletInfo {
  return { ...wallet };
}

function notify() {
  const snapshot = clone(currentWallet);
  listeners.forEach((listener) => listener(snapshot));
}

function nextAddress(): string {
  const address = ACCOUNT_POOL[accountCursor % ACCOUNT_POOL.length];
  accountCursor += 1;
  return address;
}

export function subscribeWallet(listener: WalletListener): () => void {
  listeners.add(listener);
  listener(clone(currentWallet));
  return () => {
    listeners.delete(listener);
  };
}

export function getWallet(): WalletInfo {
  return clone(currentWallet);
}

async function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function connectWallet(
  provider: WalletProvider = currentWallet.provider,
): Promise<WalletInfo> {
  currentWallet = {
    status: "connecting",
    provider,
  };
  notify();

  await delay(500);

  currentWallet = {
    status: "connected",
    provider,
    address: nextAddress(),
    lastConnectedAt: new Date().toISOString(),
  };
  notify();
  return clone(currentWallet);
}

export async function disconnectWallet(): Promise<void> {
  if (currentWallet.status === "disconnected") {
    return;
  }

  await delay(150);
  currentWallet = {
    status: "disconnected",
    provider: currentWallet.provider,
  };
  notify();
}

export function setWalletProvider(provider: WalletProvider) {
  currentWallet = {
    status: "disconnected",
    provider,
  };
  notify();
}

export function resetWallet() {
  currentWallet = {
    status: "disconnected",
    provider: DEFAULT_PROVIDER,
  };
  notify();
}
