import { useMemo, useState, type ReactElement } from "react";
import { useWallet } from "./useWallet";
import { useUiStore } from "../../store/uiStore";
import { useI18n } from "../../i18n/useI18n";
import {
  WALLET_PROVIDER_METADATA,
  type WalletProvider,
} from "./walletSupra";
import './WalletPanel.css';

const providerLabels: Record<WalletProvider, string> = Object.fromEntries(
  Object.entries(WALLET_PROVIDER_METADATA).map(([value, meta]) => [value, meta.label]),
) as Record<WalletProvider, string>;

const statusKeyByState = {
  disconnected: "wallet.status.disconnected",
  connecting: "wallet.status.connecting",
  connected: "wallet.status.connected",
} as const;

const copyKeyByState = {
  idle: "wallet.copy.default",
  copied: "wallet.copy.copied",
  error: "wallet.copy.error",
} as const;

export function WalletPanel(): ReactElement {
  const { wallet, error, connect, disconnect, changeProvider, copyAddress, clearError } = useWallet();
  const apiMode = useUiStore((state) => state.apiMode);
  const isSupra = apiMode === "supra";
  const [copyState, setCopyState] = useState<"idle" | "copied" | "error">("idle");
  const { t } = useI18n();

  const providerMeta = WALLET_PROVIDER_METADATA[wallet.provider];
  const canConnect =
    isSupra &&
    wallet.status !== "connecting" &&
    providerMeta.supported &&
    (wallet.providerReady ?? true);

  const copyLabel = useMemo(() => t(copyKeyByState[copyState]), [copyState, t]);

  const handleConnect = async () => {
    await connect();
  };

  const handleDisconnect = async () => {
    await disconnect();
  };

  const handleProviderChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    changeProvider(event.target.value as WalletProvider);
    clearError();
  };

  const handleCopyAddress = async () => {
    const result = await copyAddress();
    setCopyState(result ? "copied" : "error");
    setTimeout(() => setCopyState("idle"), 2000);
  };

  return (
    <div className="wallet-panel">
      <div className="wallet-panel__status">
        <span className="wallet-panel__label">{t("wallet.statusLabel")}</span>
        <span className={`wallet-panel__badge wallet-panel__badge--${wallet.status}`}>
          {t(statusKeyByState[wallet.status])}
        </span>
        {wallet.address && (
          <span className="wallet-panel__address" title={wallet.address}>
            {wallet.address}
          </span>
        )}
      </div>

      <div className="wallet-panel__controls">
        <label className="wallet-panel__label" htmlFor="wallet-provider">
          {t("wallet.providerLabel")}
        </label>
        <select
          id="wallet-provider"
          className="app-shell__mode-select"
          value={wallet.provider}
          onChange={handleProviderChange}
          disabled={wallet.status === "connecting"}
        >
          {Object.entries(providerLabels).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>

      <div className="wallet-panel__controls">
        {wallet.status !== "connected" ? (
          <button
            type="button"
            className="button-secondary"
            onClick={handleConnect}
            disabled={!canConnect}
            data-testid="wallet-connect-button"
          >
            {t("wallet.connect")}
          </button>
        ) : (
          <button
            type="button"
            className="button-secondary"
            onClick={handleDisconnect}
            data-testid="wallet-disconnect-button"
          >
            {t("wallet.disconnect")}
          </button>
        )}
        {!isSupra && (
          <span className="wallet-panel__hint">{t("wallet.hint")}</span>
        )}
        {wallet.address && (
          <button
            type="button"
            className="button-secondary"
            onClick={handleCopyAddress}
            disabled={copyState === "copied"}
            data-testid="wallet-copy-button"
          >
            {copyLabel}
          </button>
        )}
      </div>

      {providerMeta && !providerMeta.supported && (
        <p className="wallet-panel__hint">{t("wallet.providerComingSoon", { provider: providerMeta.label })}</p>
      )}

      {providerMeta.supported && !wallet.providerReady && (
        <p className="wallet-panel__hint">
          {t("wallet.installHint", {
            provider: providerMeta.label,
          })}
        </p>
      )}

      {wallet.chainId && (
        <p className="wallet-panel__meta">{t("wallet.meta.chainId", { value: wallet.chainId })}</p>
      )}

      {wallet.lastConnectedAt && (
        <p className="wallet-panel__meta">
          {t("wallet.meta.lastConnected", { value: new Date(wallet.lastConnectedAt).toLocaleString() })}
        </p>
      )}

      {error && (
        <p className="wallet-panel__error">
          {error}
          <button type="button" className="button-link" onClick={clearError}>
            {t("wallet.error.dismiss")}
          </button>
        </p>
      )}
    </div>
  );
}

