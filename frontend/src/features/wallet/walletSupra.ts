export type WalletStatus = "disconnected" | "connecting" | "connected";
export type WalletProvider = "starkey" | "walletconnect";

export interface WalletInfo {
  status: WalletStatus;
  provider: WalletProvider;
  providerLabel: string;
  providerReady: boolean;
  address?: string;
  chainId?: string;
  lastConnectedAt?: string;
}

export interface WalletProviderMeta {
  label: string;
  supported: boolean;
  installUrl?: string;
  instructions?: string;
}

export const WALLET_PROVIDER_METADATA: Record<WalletProvider, WalletProviderMeta> = {
  starkey: {
    label: "StarKey",
    supported: true,
    instructions:
      "Установите расширение Supra StarKey и убедитесь, что включён testnet.",
  },
  walletconnect: {
    label: "WalletConnect",
    supported: false,
    instructions:
      "Поддержка WalletConnect будет добавлена после появления публичного SDK Supra.",
  },
};

interface EIP1193Provider {
  request(args: { method: string; params?: unknown[] | Record<string, unknown> }): Promise<unknown>;
  on?(event: string, listener: (...args: unknown[]) => void): void;
  removeListener?(event: string, listener: (...args: unknown[]) => void): void;
  off?(event: string, listener: (...args: unknown[]) => void): void;
}

type WalletListener = (wallet: WalletInfo) => void;

type DetectedProvider = {
  provider: EIP1193Provider;
  label: string;
};

const DEFAULT_PROVIDER: WalletProvider = "starkey";

let currentProvider: EIP1193Provider | null = null;
let accountsChangedHandler: ((accounts: unknown) => void) | null = null;
let chainChangedHandler: ((chainId: unknown) => void) | null = null;
let disconnectHandler: (() => void) | null = null;

const listeners = new Set<WalletListener>();

let state: WalletInfo = {
  status: "disconnected",
  provider: DEFAULT_PROVIDER,
  providerLabel: WALLET_PROVIDER_METADATA[DEFAULT_PROVIDER].label,
  providerReady: detectProvider(DEFAULT_PROVIDER) !== null,
};

function getGlobalThis(): typeof globalThis | undefined {
  if (typeof window !== "undefined") {
    return window as typeof globalThis;
  }

  if (typeof global !== "undefined") {
    return global as unknown as typeof globalThis;
  }

  return undefined;
}

function clone(wallet: WalletInfo): WalletInfo {
  return { ...wallet };
}

function notify() {
  const snapshot = clone(state);
  listeners.forEach((listener) => listener(snapshot));
}

function setState(next: Partial<WalletInfo>) {
  state = { ...state, ...next };
  notify();
}

function removeListener(provider: EIP1193Provider, event: string, handler: (...args: unknown[]) => void) {
  if (typeof provider.removeListener === "function") {
    provider.removeListener(event, handler);
    return;
  }

  if (typeof provider.off === "function") {
    provider.off(event, handler);
  }
}

function detachProvider() {
  if (!currentProvider) {
    return;
  }

  if (accountsChangedHandler) {
    removeListener(currentProvider, "accountsChanged", accountsChangedHandler);
    accountsChangedHandler = null;
  }

  if (chainChangedHandler) {
    removeListener(currentProvider, "chainChanged", chainChangedHandler);
    chainChangedHandler = null;
  }

  if (disconnectHandler) {
    removeListener(currentProvider, "disconnect", disconnectHandler);
    disconnectHandler = null;
  }

  currentProvider = null;
}

function detectProvider(provider: WalletProvider): DetectedProvider | null {
  const globalObj = getGlobalThis() as unknown as Record<string, unknown> | undefined;
  if (!globalObj) {
    return null;
  }

  if (provider === "starkey") {
    const candidates: unknown[] = [];
    const possible = (globalObj as { [key: string]: unknown }).starKey as Record<string, unknown> | undefined;
    if (possible?.provider) {
      candidates.push(possible.provider);
    }
    if (possible) {
      candidates.push(possible);
    }

    const ethereum = (globalObj as { [key: string]: unknown }).ethereum as
      | { providers?: unknown[]; isStarKey?: boolean; isSupra?: boolean }
      | undefined;

    if (ethereum?.providers && Array.isArray(ethereum.providers)) {
      const match = ethereum.providers.find((item) => {
        const candidate = item as { isStarKey?: boolean; isSupra?: boolean };
        return Boolean(candidate?.isStarKey || candidate?.isSupra);
      });
      if (match) {
        candidates.push(match);
      }
    }

    if (ethereum?.isStarKey || ethereum?.isSupra) {
      candidates.push(ethereum);
    }

    const supraWallet = (globalObj as { [key: string]: unknown }).supraWallet;
    if (supraWallet) {
      candidates.push(supraWallet);
    }

    const providerCandidate = candidates.find((item) => typeof (item as EIP1193Provider | undefined)?.request === "function") as
      | EIP1193Provider
      | undefined;

    if (!providerCandidate) {
      return null;
    }

    const label =
      ((providerCandidate as unknown as { walletMeta?: { name?: string } }).walletMeta?.name ??
        (providerCandidate as unknown as { providerName?: string }).providerName ??
        WALLET_PROVIDER_METADATA.starkey.label);

    return {
      provider: providerCandidate,
      label,
    };
  }

  // WalletConnect пока не реализован
  return null;
}

function computeProviderReady(provider: WalletProvider): boolean {
  const meta = WALLET_PROVIDER_METADATA[provider];
  if (!meta.supported) {
    return false;
  }
  return detectProvider(provider) !== null;
}

async function resolveChainId(provider: EIP1193Provider): Promise<string | undefined> {
  try {
    const result = await provider.request({ method: "eth_chainId" });
    if (typeof result === "number") {
      return `0x${result.toString(16)}`;
    }
    if (typeof result === "string") {
      return result;
    }
  } catch (error) {
    console.warn("Не удалось получить chainId от Supra кошелька", error);
  }
  return undefined;
}

function handleAccountsChanged(accounts: unknown) {
  if (!Array.isArray(accounts) || accounts.length === 0) {
    setState({
      status: "disconnected",
      address: undefined,
      chainId: undefined,
      providerReady: computeProviderReady(state.provider),
    });
    return;
  }

  const [account] = accounts;
  setState({
    status: "connected",
    address: typeof account === "string" ? account : String(account),
  });
}

function handleChainChanged(chainId: unknown) {
  if (typeof chainId === "string") {
    setState({ chainId });
    return;
  }

  if (typeof chainId === "number") {
    setState({ chainId: `0x${chainId.toString(16)}` });
  }
}

function handleDisconnect() {
  detachProvider();
  setState({
    status: "disconnected",
    address: undefined,
    chainId: undefined,
    providerReady: computeProviderReady(state.provider),
  });
}

function attachProvider(detected: DetectedProvider) {
  if (currentProvider === detected.provider) {
    return;
  }

  detachProvider();
  currentProvider = detected.provider;

  accountsChangedHandler = handleAccountsChanged;
  chainChangedHandler = handleChainChanged;
  disconnectHandler = handleDisconnect;

  currentProvider.on?.("accountsChanged", accountsChangedHandler);
  currentProvider.on?.("chainChanged", chainChangedHandler);
  currentProvider.on?.("disconnect", disconnectHandler);
}

export function subscribeWallet(listener: WalletListener): () => void {
  listeners.add(listener);
  listener(clone(state));
  return () => {
    listeners.delete(listener);
  };
}

export function getWallet(): WalletInfo {
  return clone(state);
}

export async function connectWallet(provider: WalletProvider = state.provider): Promise<WalletInfo> {
  const meta = WALLET_PROVIDER_METADATA[provider];
  setState({ status: "connecting", provider, providerLabel: meta.label });

  if (!meta.supported) {
    setState({
      status: "disconnected",
      providerReady: false,
      providerLabel: meta.label,
    });
    throw new Error(meta.instructions ?? "Данный провайдер пока не поддерживается");
  }

  const detected = detectProvider(provider);
  if (!detected) {
    setState({ status: "disconnected", providerReady: false });
    throw new Error(
      provider === "starkey"
        ? "Кошелёк StarKey не найден. Установите расширение Supra StarKey и разблокируйте его."
        : "Провайдер кошелька не найден",
    );
  }

  attachProvider(detected);

  try {
    const accounts = (await detected.provider.request({ method: "eth_requestAccounts" })) as unknown;
    const addressValue = Array.isArray(accounts) ? accounts[0] : undefined;
    const address =
      typeof addressValue === "string"
        ? addressValue
        : addressValue != null
          ? String(addressValue)
          : undefined;
    const chainId = await resolveChainId(detected.provider);

    setState({
      status: "connected",
      provider,
      providerLabel: detected.label,
      providerReady: true,
      address: address,
      chainId,
      lastConnectedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Ошибка подключения Supra кошелька", error);
    detachProvider();
    setState({
      status: "disconnected",
      providerReady: computeProviderReady(provider),
      address: undefined,
      chainId: undefined,
    });
    throw error instanceof Error ? error : new Error("Не удалось подключить кошелёк");
  }

  return getWallet();
}

export async function disconnectWallet(): Promise<void> {
  detachProvider();
  setState({
    status: "disconnected",
    address: undefined,
    chainId: undefined,
    providerReady: computeProviderReady(state.provider),
  });
}

export function setWalletProvider(provider: WalletProvider) {
  const meta = WALLET_PROVIDER_METADATA[provider];
  detachProvider();
  setState({
    provider,
    providerLabel: meta.label,
    status: "disconnected",
    address: undefined,
    chainId: undefined,
    providerReady: computeProviderReady(provider),
  });
}

export function resetWallet() {
  detachProvider();
  const meta = WALLET_PROVIDER_METADATA[DEFAULT_PROVIDER];
  state = {
    status: "disconnected",
    provider: DEFAULT_PROVIDER,
    providerLabel: meta.label,
    providerReady: computeProviderReady(DEFAULT_PROVIDER),
  };
  notify();
}

// Попытка восстановить сессию при загрузке страницы
if (typeof window !== "undefined") {
  void (async () => {
    const detected = detectProvider(state.provider);
    if (!detected) {
      return;
    }
    const accounts = (await detected.provider.request({ method: "eth_accounts" })) as unknown;
    if (!Array.isArray(accounts) || accounts.length === 0) {
      setState({ providerReady: true });
      return;
    }
    attachProvider(detected);
    const chainId = await resolveChainId(detected.provider);
    const rawAddress = accounts[0];
    const address =
      typeof rawAddress === "string"
        ? rawAddress
        : rawAddress != null
          ? String(rawAddress)
          : undefined;
    setState({
      status: "connected",
      providerReady: true,
      providerLabel: detected.label,
      address,
      chainId,
    });
  })();
}
