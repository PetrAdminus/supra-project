import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { AdminConsumerWhitelistSnapshot } from "../../../api/types";
import { useRecordConsumerWhitelistMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";
import './AdminForm.css';

interface ConsumerWhitelistSnapshotFormProps {
  snapshot: AdminConsumerWhitelistSnapshot | null;
  configured: boolean;
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

export function ConsumerWhitelistSnapshotForm({
  snapshot,
  configured,
}: ConsumerWhitelistSnapshotFormProps): ReactElement {
  const mutation = useRecordConsumerWhitelistMutation();
  const [callbackGasPrice, setCallbackGasPrice] = useState("");
  const [callbackGasLimit, setCallbackGasLimit] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    if (snapshot) {
      setCallbackGasPrice(snapshot.callbackGasPrice);
      setCallbackGasLimit(snapshot.callbackGasLimit);
    }
  }, [snapshot?.callbackGasLimit, snapshot?.callbackGasPrice, snapshot?.updatedAt]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    mutation.mutate({
      callbackGasPrice,
      callbackGasLimit,
    });
  };

  const disableSubmit = useMemo(() => {
    return (
      mutation.isPending ||
      [callbackGasPrice, callbackGasLimit].some((value) => value.trim().length === 0)
    );
  }, [callbackGasLimit, callbackGasPrice, mutation.isPending]);

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.consumerSnapshot.errorFallback")
    : null;

  const submitLabel = mutation.isPending ? t("admin.consumerSnapshot.saving") : t("admin.consumerSnapshot.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__grid">
        <label htmlFor="consumer-callback-gas-price">{t("admin.consumerSnapshot.labels.callbackGasPrice")}</label>
        <input
          id="consumer-callback-gas-price"
          type="text"
          value={callbackGasPrice}
          onChange={(event) => setCallbackGasPrice(event.target.value)}
          disabled={mutation.isPending}
        />
        <label htmlFor="consumer-callback-gas-limit">{t("admin.consumerSnapshot.labels.callbackGasLimit")}</label>
        <input
          id="consumer-callback-gas-limit"
          type="text"
          value={callbackGasLimit}
          onChange={(event) => setCallbackGasLimit(event.target.value)}
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
          {t("admin.consumerSnapshot.success", {
            hash: mutation.data.txHash,
            time: formatTimestamp(mutation.data.submittedAt),
          })}
        </p>
      )}
    </form>
  );
}
