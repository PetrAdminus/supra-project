import { useEffect, useMemo, useState, type FormEvent, type ReactElement } from "react";
import type { TreasuryConfig } from "../../../api/types";
import { useUpdateTreasuryDistributionMutation } from "../hooks/useAdminMutations";
import { useI18n } from "../../../i18n/useI18n";

interface TreasuryDistributionFormProps {
  config: TreasuryConfig;
}

function parseBp(value: string): number | null {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return Math.trunc(parsed);
}

export function TreasuryDistributionForm({ config }: TreasuryDistributionFormProps): ReactElement {
  const mutation = useUpdateTreasuryDistributionMutation();
  const [jackpotBp, setJackpotBp] = useState("");
  const [prizeBp, setPrizeBp] = useState("");
  const [treasuryBp, setTreasuryBp] = useState("");
  const [marketingBp, setMarketingBp] = useState("");
  const { t } = useI18n();

  useEffect(() => {
    setJackpotBp(config.distributionBp.jackpot.toString());
    setPrizeBp(config.distributionBp.prize.toString());
    setTreasuryBp(config.distributionBp.treasury.toString());
    setMarketingBp(config.distributionBp.marketing.toString());
  }, [config.distributionBp.jackpot, config.distributionBp.prize, config.distributionBp.treasury, config.distributionBp.marketing, config.updatedAt]);

  const total = useMemo(() => {
    const parts = [jackpotBp, prizeBp, treasuryBp, marketingBp].map(parseBp);
    if (parts.some((value) => value === null)) {
      return null;
    }
    return (parts[0] as number) + (parts[1] as number) + (parts[2] as number) + (parts[3] as number);
  }, [jackpotBp, prizeBp, treasuryBp, marketingBp]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const parsedJackpot = parseBp(jackpotBp);
    const parsedPrize = parseBp(prizeBp);
    const parsedTreasury = parseBp(treasuryBp);
    const parsedMarketing = parseBp(marketingBp);

    if (
      parsedJackpot === null ||
      parsedPrize === null ||
      parsedTreasury === null ||
      parsedMarketing === null ||
      parsedJackpot + parsedPrize + parsedTreasury + parsedMarketing !== 10_000
    ) {
      return;
    }

    mutation.mutate({
      jackpotBp: parsedJackpot,
      prizeBp: parsedPrize,
      treasuryBp: parsedTreasury,
      marketingBp: parsedMarketing,
    });
  };

  const disableSubmit =
    mutation.isPending ||
    jackpotBp.trim().length === 0 ||
    prizeBp.trim().length === 0 ||
    treasuryBp.trim().length === 0 ||
    marketingBp.trim().length === 0 ||
    total === null ||
    total !== 10_000;

  const errorMessage = mutation.isError
    ? mutation.error instanceof Error
      ? mutation.error.message
      : t("admin.treasury.distribution.errorFallback")
    : null;

  const submitLabel = mutation.isPending
    ? t("admin.treasury.distribution.saving")
    : t("admin.treasury.distribution.submit");

  return (
    <form className="admin-form" onSubmit={handleSubmit}>
      <div className="admin-form__row">
        <label htmlFor="treasury-bp-jackpot">{t("admin.treasury.distribution.labels.jackpot")}</label>
        <input
          id="treasury-bp-jackpot"
          type="number"
          min={0}
          max={10_000}
          step={1}
          value={jackpotBp}
          onChange={(event) => setJackpotBp(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="treasury-bp-prize">{t("admin.treasury.distribution.labels.prize")}</label>
        <input
          id="treasury-bp-prize"
          type="number"
          min={0}
          max={10_000}
          step={1}
          value={prizeBp}
          onChange={(event) => setPrizeBp(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="treasury-bp-treasury">{t("admin.treasury.distribution.labels.treasury")}</label>
        <input
          id="treasury-bp-treasury"
          type="number"
          min={0}
          max={10_000}
          step={1}
          value={treasuryBp}
          onChange={(event) => setTreasuryBp(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__row">
        <label htmlFor="treasury-bp-marketing">{t("admin.treasury.distribution.labels.marketing")}</label>
        <input
          id="treasury-bp-marketing"
          type="number"
          min={0}
          max={10_000}
          step={1}
          value={marketingBp}
          onChange={(event) => setMarketingBp(event.target.value)}
          disabled={mutation.isPending}
        />
      </div>
      <div className="admin-form__meta">{t("admin.treasury.distribution.totalBp", { value: total ?? "-" })}</div>
      <div className="admin-form__actions">
        <button className="button-primary" type="submit" disabled={disableSubmit}>
          {submitLabel}
        </button>
        <span className="admin-form__meta">
          {t("admin.treasury.distribution.lastUpdate", { value: new Date(config.updatedAt).toLocaleString() })}
        </span>
      </div>
      {errorMessage && <p className="admin-form__error">{errorMessage}</p>}
      {mutation.isSuccess && mutation.data && (
        <p className="admin-form__success">
          {t("admin.treasury.distribution.success", {
            hash: mutation.data.txHash,
            time: new Date(mutation.data.submittedAt).toLocaleString(),
          })}
        </p>
      )}
    </form>
  );
}
