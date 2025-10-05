import { useCallback, useEffect, useState } from "react";
import {
  connectWallet,
  disconnectWallet,
  getWallet,
  resetWallet,
  setWalletProvider,
  subscribeWallet,
  type WalletInfo,
  type WalletProvider,
} from "./walletSupra";

interface UseWalletResult {
  wallet: WalletInfo;
  error: string | null;
  connect: (provider?: WalletProvider) => Promise<void>;
  disconnect: () => Promise<void>;
  changeProvider: (provider: WalletProvider) => void;
  copyAddress: () => Promise<boolean>;
  clearError: () => void;
}

export function useWallet(): UseWalletResult {
  const [wallet, setWalletState] = useState<WalletInfo>(getWallet());
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = subscribeWallet(setWalletState);
    return () => {
      unsubscribe();
      resetWallet();
    };
  }, []);

  const connect = useCallback(async (provider?: WalletProvider) => {
    try {
      setError(null);
      await connectWallet(provider ?? wallet.provider);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Не удалось подключить кошелёк";
      setError(message);
      setWalletState(getWallet());
    }
  }, [wallet.provider]);

  const disconnect = useCallback(async () => {
    try {
      await disconnectWallet();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Ошибка при отключении";
      setError(message);
    }
  }, []);

  const changeProvider = useCallback((provider: WalletProvider) => {
    setError(null);
    setWalletProvider(provider);
  }, []);

  const copyAddress = useCallback(async () => {
    if (!wallet.address) {
      return false;
    }

    try {
      if (typeof navigator !== "undefined" && navigator.clipboard) {
        await navigator.clipboard.writeText(wallet.address);
        return true;
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : "Не удалось скопировать адрес";
      setError(message);
    }

    return false;
  }, [wallet.address]);

  const clearError = useCallback(() => setError(null), []);

  return {
    wallet,
    error,
    connect,
    disconnect,
    changeProvider,
    copyAddress,
    clearError,
  };
}
