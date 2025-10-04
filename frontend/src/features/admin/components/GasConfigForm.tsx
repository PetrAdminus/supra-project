import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { AdminGasConfig } from "../../../api/types";
import { useUpdateGasConfigMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";

interface GasConfigFormProps {
  gasConfig: AdminGasConfig | null;
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

export function GasConfigForm({ gasConfig }: GasConfigFormProps): ReactElement {
  const mutation = useUpdateGasConfigMutation();
  const [maxGasFee, setMaxGasFee] = useState("");
  const [minBalance, setMinBalance] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    if (gasConfig) {
      setMaxGasFee(gasConfig.maxGasFee.toString());
      setMinBalance(gasConfig.minBalance.toString());
    }
  }, [gasConfig?.maxGasFee, gasConfig?.minBalance, gasConfig?.updatedAt]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const parsedMaxGasFee = Number(maxGasFee);
    const parsedMinBalance = Number(minBalance);

    if (Number.isNaN(parsedMaxGasFee) || Number.isNaN(parsedMinBalance)) {
      return;
    }

    mutation.mutate({
      maxGasFee: parsedMaxGasFee,
      minBalance: parsedMinBalance,
    });
  };

  const disableSubmit = useMemo(() => {
    return (
      mutation.isPending ||
      maxGasFee.trim().length === 0 ||
      minBalance.trim().length === 0 ||
      Number.isNaN(Number(maxGasFee)) ||
      Number.isNaN(Number(minBalance))
    );
  }, [maxGasFee, minBalance, mutation.isPending]);

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.gas.errorFallback")
    : null;

  const submitLabel = mutation.isPending ? t("admin.gas.saving") : t("admin.gas.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__row">
        <label htmlFor="admin-max-gas-fee">{t("admin.gas.labels.maxGasFee")}</label>
        <input
          id="admin-max-gas-fee"
          type="number"
          min={0}
          step={1}
          value={maxGasFee}
          onChange={(event) => setMaxGasFee(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="admin-min-balance">{t("admin.gas.labels.minBalance")}</label>
        <input
          id="admin-min-balance"
          type="number"
          min={0}
          step={1}
          value={minBalance}
          onChange={(event) => setMinBalance(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__actions">
        <button className="button-primary" type="submit" disabled={disableSubmit}>
          {submitLabel}
        </button>
        <span className="admin-form__meta">
          {t("admin.gas.lastUpdate", { value: formatTimestamp(gasConfig?.updatedAt) })}
        </span>
      </div>
      {errorMessage && <p className="admin-form__error">{errorMessage}</p>}
      {mutation.isSuccess && mutation.data && (
        <p className="admin-form__success">
          {t("admin.gas.success", {
            hash: mutation.data.txHash,
            time: formatTimestamp(mutation.data.submittedAt),
          })}
        </p>
      )}
    </form>
  );
}
