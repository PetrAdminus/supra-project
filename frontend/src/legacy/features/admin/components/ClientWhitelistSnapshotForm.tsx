import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { AdminWhitelistSnapshot } from "../../../api/types";
import { useRecordClientWhitelistMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";
import './AdminForm.css';

interface ClientWhitelistSnapshotFormProps {
  snapshot: AdminWhitelistSnapshot | null;
  configured: boolean;
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

export function ClientWhitelistSnapshotForm({
  snapshot,
  configured,
}: ClientWhitelistSnapshotFormProps): ReactElement {
  const mutation = useRecordClientWhitelistMutation();
  const [maxGasPrice, setMaxGasPrice] = useState("");
  const [maxGasLimit, setMaxGasLimit] = useState("");
  const [minBalanceLimit, setMinBalanceLimit] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    if (snapshot) {
      setMaxGasPrice(snapshot.maxGasPrice);
      setMaxGasLimit(snapshot.maxGasLimit);
      setMinBalanceLimit(snapshot.minBalanceLimit);
    }
  }, [snapshot?.maxGasLimit, snapshot?.maxGasPrice, snapshot?.minBalanceLimit, snapshot?.updatedAt]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    mutation.mutate({
      maxGasPrice,
      maxGasLimit,
      minBalanceLimit,
    });
  };

  const disableSubmit = useMemo(() => {
    return (
      mutation.isPending ||
      [maxGasPrice, maxGasLimit, minBalanceLimit].some((value) => value.trim().length === 0)
    );
  }, [maxGasLimit, maxGasPrice, minBalanceLimit, mutation.isPending]);

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.clientSnapshot.errorFallback")
    : null;

  const submitLabel = mutation.isPending ? t("admin.clientSnapshot.saving") : t("admin.clientSnapshot.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__grid">
        <label htmlFor="client-max-gas-price">{t("admin.clientSnapshot.labels.maxGasPrice")}</label>
        <input
          id="client-max-gas-price"
          type="text"
          value={maxGasPrice}
          onChange={(event) => setMaxGasPrice(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="client-max-gas-limit">{t("admin.clientSnapshot.labels.maxGasLimit")}</label>
        <input
          id="client-max-gas-limit"
          type="text"
          value={maxGasLimit}
          onChange={(event) => setMaxGasLimit(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="client-min-balance-limit">{t("admin.clientSnapshot.labels.minBalanceLimit")}</label>
        <input
          id="client-min-balance-limit"
          type="text"
          value={minBalanceLimit}
          onChange={(event) => setMinBalanceLimit(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__actions">
        <button className="button-primary" type="submit" disabled={disableSubmit}>
          {submitLabel}
        </button>
        <span className="admin-form__meta">
          {configured ? t("admin.common.configured") : t("admin.common.notConfigured")} |
          {t("admin.common.lastUpdate", { value: formatTimestamp(snapshot?.updatedAt) })}
        </span>
      </div>
      {errorMessage && <p className="admin-form__error">{errorMessage}</p>}
      {mutation.isSuccess && mutation.data && (
        <p className="admin-form__success">
          {t("admin.clientSnapshot.success", {
            hash: mutation.data.txHash,
            time: formatTimestamp(mutation.data.submittedAt),
          })}
        </p>
      )}
    </form>
  );
}
