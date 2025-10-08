import type { ReactElement } from "react";
import type { LotterySummary } from "../../../api/types";
import { useI18n } from "../../../i18n/useI18n";
import "./LotterySelector.css";

interface LotterySelectorProps {
  lotteries: LotterySummary[];
  selectedLotteryId: number | null;
  onSelect: (lotteryId: number) => void;
}

function formatTicketPrice(value?: string | null): string {
  if (!value) {
    return "-";
  }
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return value;
  }
  return `${numeric.toFixed(2)} $SUPRA`;
}

export function LotterySelector({
  lotteries,
  selectedLotteryId,
  onSelect,
}: LotterySelectorProps): ReactElement | null {
  const { t } = useI18n();

  if (!lotteries.length) {
    return (
      <div className="lottery-selector lottery-selector--empty">
        <span className="lottery-selector__label">{t("dashboard.selector.label")}</span>
        <p className="lottery-selector__empty">{t("dashboard.selector.empty")}</p>
      </div>
    );
  }

  return (
    <div className="lottery-selector">
      <span className="lottery-selector__label">{t("dashboard.selector.label")}</span>
      <div className="lottery-selector__list">
        {lotteries.map((lottery) => {
          const isActive = lottery.id === selectedLotteryId;
          const ticketPrice = lottery.factory?.blueprint?.ticketPriceSupra ?? null;
          return (
            <button
              type="button"
              key={lottery.id}
              className={`lottery-selector__item${isActive ? " lottery-selector__item--active" : ""}`}
              onClick={() => onSelect(lottery.id)}
            >
              <span className="lottery-selector__name">
                {t("dashboard.selector.lotteryName", { id: lottery.id })}
              </span>
              <span className="lottery-selector__meta">
                {t("dashboard.selector.ticketPrice", { value: formatTicketPrice(ticketPrice) })}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
