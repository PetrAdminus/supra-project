import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { TreasuryBalances, TreasuryConfig } from "../../../api/types";
import { useUpdateTreasuryControlsMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";

interface TreasuryControlsFormProps {
  config: TreasuryConfig;
  balances: TreasuryBalances;
}

export function TreasuryControlsForm({ config, balances }: TreasuryControlsFormProps): ReactElement {
  const mutation = useUpdateTreasuryControlsMutation();
  const [ticketPrice, setTicketPrice] = useState("");
  const [treasuryAddress, setTreasuryAddress] = useState("");
  const [salesEnabled, setSalesEnabled] = useState(false);
  const { t } = useI18n();

  useEffect(() => {
    setTicketPrice(config.ticketPriceSupra);
    setTreasuryAddress(config.treasuryAddress);
    setSalesEnabled(config.salesEnabled);
  }, [config.ticketPriceSupra, config.treasuryAddress, config.salesEnabled, config.updatedAt]);

  const disableSubmit = useMemo(() => {
    return (
      mutation.isPending ||
      ticketPrice.trim().length === 0 ||
      treasuryAddress.trim().length === 0
    );
  }, [mutation.isPending, ticketPrice, treasuryAddress]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (disableSubmit) {
      return;
    }

    mutation.mutate({
      ticketPriceSupra: ticketPrice,
      treasuryAddress,
      salesEnabled,
    });
  };

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.treasury.controls.errorFallback")
    : null;

  const submitLabel = mutation.isPending
    ? t("admin.treasury.controls.saving")
    : t("admin.treasury.controls.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__row">
        <label htmlFor="treasury-ticket-price">{t("admin.treasury.controls.labels.ticketPrice")}</label>
        <input
          id="treasury-ticket-price"
          type="text"
          value={ticketPrice}
          onChange={(event) => setTicketPrice(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="treasury-address">{t("admin.treasury.controls.labels.treasuryAddress")}</label>
        <input
          id="treasury-address"
          type="text"
          value={treasuryAddress}
          onChange={(event) => setTreasuryAddress(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="treasury-sales-enabled">{t("admin.treasury.controls.labels.salesEnabled")}</label>
        <input
          id="treasury-sales-enabled"
          type="checkbox"
          checked={salesEnabled}
          onChange={(event) => setSalesEnabled(event.target.checked)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__actions">
        <button className="button-primary" type="submit" disabled={disableSubmit}>
          {submitLabel}
        </button>
        <span className="admin-form__meta">
          {t("admin.treasury.controls.lastUpdate", { value: new Date(config.updatedAt).toLocaleString() })}
        </span>
      </div>
      <div className="admin-form__meta">
        {t("admin.treasury.controls.balances.jackpot", { value: balances.jackpotSupra })}
      </div>
      <div className="admin-form__meta">
        {t("admin.treasury.controls.balances.prize", { value: balances.prizeSupra })}
      </div>
      <div className="admin-form__meta">
        {t("admin.treasury.controls.balances.treasury", { value: balances.treasurySupra })}
      </div>
      <div className="admin-form__meta">
        {t("admin.treasury.controls.balances.marketing", { value: balances.marketingSupra })}
      </div>
      {errorMessage && <p className="admin-form__error">{errorMessage}</p>}
      {mutation.isSuccess && mutation.data && (
        <p className="admin-form__success">
          {t("admin.treasury.controls.success", {
            hash: mutation.data.txHash,
            time: new Date(mutation.data.submittedAt).toLocaleString(),
          })}
        </p>
      )}
    </form>
  );
}
