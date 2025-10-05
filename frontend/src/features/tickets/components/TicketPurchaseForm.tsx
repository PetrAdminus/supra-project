import type { FormEvent, ReactElement } from "react";
import { useState } from "react";
import { usePurchaseTicket } from "../hooks/usePurchaseTicket";
import { useI18n } from "../../../i18n/useI18n";
import { useUiStore } from "../../../store/uiStore";
import './TicketPurchaseForm.css';

interface TicketPurchaseFormProps {
  round: number | null;
  ticketPrice: string | null;
}

function parseNumbers(raw: string): number[] | null {
  const parts = raw
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);

  if (parts.length === 0) {
    return null;
  }

  const numbers = parts.map((part) => Number(part));

  if (numbers.some((value) => Number.isNaN(value) || value < 0)) {
    return null;
  }

  return numbers;
}

export function TicketPurchaseForm({ round, ticketPrice }: TicketPurchaseFormProps): ReactElement {
  const mutation = usePurchaseTicket();
  const [numbersInput, setNumbersInput] = useState("7, 11, 23, 45");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const { t } = useI18n();
  const apiMode = useUiStore((state) => state.apiMode);
  const isSupraMode = apiMode === "supra";
  const readonlyMessage = isSupraMode ? t("tickets.form.disabledSupra") : null;

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (isSupraMode) {
      return;
    }
    if (round === null) {
      setErrorMessage(t("tickets.form.errorRoundUnavailable"));
      return;
    }
    if (ticketPrice === null) {
      setErrorMessage(t("tickets.form.errorTicketPriceUnavailable"));
      return;
    }
    const parsed = parseNumbers(numbersInput);

    if (!parsed || parsed.length === 0) {
      setErrorMessage(t("tickets.form.errorInvalidNumbers"));
      return;
    }

    setErrorMessage(null);
    mutation.mutate(
      { round, numbers: parsed },
      {
        onSuccess: () => {
          setNumbersInput("");
        },
      },
    );
  };

  const priceLabel = t("tickets.form.priceLabel", { value: ticketPrice ?? "-" });
  const submitLabel = isSupraMode
    ? t("tickets.form.submitSupraDisabled")
    : mutation.isPending
      ? t("tickets.form.pending")
      : t("tickets.form.submit");
  const submitDisabled =
    isSupraMode || mutation.isPending || round === null || ticketPrice === null;

  return (
    <form className="ticket-form" onSubmit={handleSubmit}>
      <div className="ticket-form__row">
        <label htmlFor="ticket-numbers">{t("tickets.form.label")}</label>
        <input
          id="ticket-numbers"
          type="text"
          value={numbersInput}
          onChange={(event) => setNumbersInput(event.target.value)}
          placeholder={t("tickets.form.placeholder")}
          disabled={mutation.isPending || isSupraMode}
        />
      </div>
      <div className="ticket-form__row">
        <span className="ticket-form__price">{priceLabel}</span>
        <button className="button-primary" type="submit" disabled={submitDisabled}>
          {submitLabel}
        </button>
      </div>
      {(errorMessage ?? readonlyMessage) && (
        <p className="ticket-form__error">{errorMessage ?? readonlyMessage}</p>
      )}
      {mutation.isError && <p className="ticket-form__error">{mutation.error instanceof Error ? mutation.error.message : t("tickets.form.errorInvalidNumbers")}</p>}
      {mutation.isSuccess && !mutation.isPending && mutation.data && (
        <p className="ticket-form__success">
          {t("tickets.form.success", { ticketId: mutation.data.ticketId })}
        </p>
      )}
    </form>
  );
}
