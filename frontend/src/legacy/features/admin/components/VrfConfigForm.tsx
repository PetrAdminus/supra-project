import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { AdminVrfConfig } from "../../../api/types";
import { useUpdateVrfConfigMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";
import './AdminForm.css';

interface VrfConfigFormProps {
  vrfConfig: AdminVrfConfig | null;
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

export function VrfConfigForm({ vrfConfig }: VrfConfigFormProps): ReactElement {
  const mutation = useUpdateVrfConfigMutation();
  const [maxGasPrice, setMaxGasPrice] = useState("");
  const [maxGasLimit, setMaxGasLimit] = useState("");
  const [callbackGasPrice, setCallbackGasPrice] = useState("");
  const [callbackGasLimit, setCallbackGasLimit] = useState("");
  const [requestedRngCount, setRequestedRngCount] = useState("");
  const [clientSeed, setClientSeed] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    if (vrfConfig) {
      setMaxGasPrice(vrfConfig.maxGasPrice);
      setMaxGasLimit(vrfConfig.maxGasLimit);
      setCallbackGasPrice(vrfConfig.callbackGasPrice);
      setCallbackGasLimit(vrfConfig.callbackGasLimit);
      setRequestedRngCount(vrfConfig.requestedRngCount.toString());
      setClientSeed(vrfConfig.clientSeed.toString());
    }
  }, [
    vrfConfig?.callbackGasLimit,
    vrfConfig?.callbackGasPrice,
    vrfConfig?.clientSeed,
    vrfConfig?.lastConfiguredAt,
    vrfConfig?.maxGasLimit,
    vrfConfig?.maxGasPrice,
    vrfConfig?.requestedRngCount,
  ]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const parsedRngCount = Number(requestedRngCount);
    const parsedClientSeed = Number(clientSeed);

    if (Number.isNaN(parsedRngCount) || Number.isNaN(parsedClientSeed)) {
      return;
    }

    mutation.mutate({
      maxGasPrice,
      maxGasLimit,
      callbackGasPrice,
      callbackGasLimit,
      requestedRngCount: parsedRngCount,
      clientSeed: parsedClientSeed,
    });
  };

  const disableSubmit = useMemo(() => {
    return (
      mutation.isPending ||
      [maxGasPrice, maxGasLimit, callbackGasPrice, callbackGasLimit, requestedRngCount, clientSeed].some(
        (value) => value.trim().length === 0,
      ) ||
      Number.isNaN(Number(requestedRngCount)) ||
      Number.isNaN(Number(clientSeed))
    );
  }, [
    callbackGasLimit,
    callbackGasPrice,
    clientSeed,
    maxGasLimit,
    maxGasPrice,
    mutation.isPending,
    requestedRngCount,
  ]);

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.vrf.errorFallback")
    : null;

  const submitLabel = mutation.isPending ? t("admin.vrf.saving") : t("admin.vrf.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__grid">
        <label htmlFor="admin-max-gas-price">{t("admin.vrf.labels.maxGasPrice")}</label>
        <input
          id="admin-max-gas-price"
          type="text"
          value={maxGasPrice}
          onChange={(event) => setMaxGasPrice(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="admin-max-gas-limit">{t("admin.vrf.labels.maxGasLimit")}</label>
        <input
          id="admin-max-gas-limit"
          type="text"
          value={maxGasLimit}
          onChange={(event) => setMaxGasLimit(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="admin-callback-gas-price">{t("admin.vrf.labels.callbackGasPrice")}</label>
        <input
          id="admin-callback-gas-price"
          type="text"
          value={callbackGasPrice}
          onChange={(event) => setCallbackGasPrice(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="admin-callback-gas-limit">{t("admin.vrf.labels.callbackGasLimit")}</label>
        <input
          id="admin-callback-gas-limit"
          type="text"
          value={callbackGasLimit}
          onChange={(event) => setCallbackGasLimit(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="admin-rng-count">{t("admin.vrf.labels.requestedRngCount")}</label>
        <input
          id="admin-rng-count"
          type="number"
          min={1}
          step={1}
          value={requestedRngCount}
          onChange={(event) => setRequestedRngCount(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="admin-client-seed">{t("admin.vrf.labels.clientSeed")}</label>
        <input
          id="admin-client-seed"
          type="number"
          step={1}
          value={clientSeed}
          onChange={(event) => setClientSeed(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__actions">
        <button className="button-primary" type="submit" disabled={disableSubmit}>
          {submitLabel}
        </button>
        <span className="admin-form__meta">
          {t("admin.vrf.lastUpdate", { value: formatTimestamp(vrfConfig?.lastConfiguredAt) })}
        </span>
      </div>
      {errorMessage && <p className="admin-form__error">{errorMessage}</p>}
      {mutation.isSuccess && mutation.data && (
        <p className="admin-form__success">
          {t("admin.vrf.success", {
            hash: mutation.data.txHash,
            time: formatTimestamp(mutation.data.submittedAt),
          })}
        </p>
      )}
    </form>
  );
}