import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { TicketPurchaseForm } from "../components/TicketPurchaseForm";
import { TicketList } from "../components/TicketList";
import { useTicketHistory } from "../hooks/useTicketHistory";
import { useLotteryStatus } from "../../dashboard/hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";

export function TicketsPage(): ReactElement {
  const { data: tickets, isLoading, error } = useTicketHistory();
  const { data: status } = useLotteryStatus({ staleTime: 60_000 });
  const { t } = useI18n();

  return (
    <section>
      <h1>{t("tickets.title")}</h1>
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="primary"
          title={t("tickets.purchaseCard.title")}
          subtitle={t("tickets.purchaseCard.subtitle")}
          footer={
            status ? (
              <span className="badge">{t("tickets.purchaseCard.badgeRound", { round: status.round })}</span>
            ) : (
              <span className="badge">{t("tickets.purchaseCard.badgeLoading")}</span>
            )
          }
        >
          {status ? (
            <TicketPurchaseForm round={status.round} ticketPrice={status.ticketPriceSupra} />
          ) : (
            <p>{t("tickets.purchaseCard.loading")}</p>
          )}
          <p>{t("tickets.purchaseCard.hint")}</p>
        </GlassCard>

        <GlassCard accent="neutral" title={t("tickets.historyCard.title")} subtitle={t("tickets.historyCard.subtitle")}>
          {isLoading && <p>{t("tickets.historyCard.loading")}</p>}
          {error && <p>{t("tickets.historyCard.error")}</p>}
          {tickets && tickets.length > 0 && <TicketList tickets={tickets} />}
          {tickets && tickets.length === 0 && <p>{t("tickets.historyCard.empty")}</p>}
        </GlassCard>
      </div>
    </section>
  );
}
