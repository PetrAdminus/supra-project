import { useEffect, useMemo } from "react";
import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { TicketPurchaseForm } from "../components/TicketPurchaseForm";
import { TicketList } from "../components/TicketList";
import { useTicketHistory } from "../hooks/useTicketHistory";
import { useLotteryStatus } from "../../dashboard/hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";
import { useUiStore } from "../../../store/uiStore";
import { LotterySelector } from "../../lotteries/components/LotterySelector";
import { useLotterySelectionStore } from "../../../store/lotteryStore";
import "./TicketsPage.css";

export function TicketsPage(): ReactElement {
  const { data: tickets, isLoading, error } = useTicketHistory();
  const { data: status } = useLotteryStatus({ staleTime: 60_000 });
  const { t } = useI18n();
  const apiMode = useUiStore((state) => state.apiMode);
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);
  const isSupraMode = apiMode === "supra";
  const purchaseSubtitleKey = isSupraMode
    ? "tickets.purchaseCard.subtitleSupra"
    : "tickets.purchaseCard.subtitleMock";
  const purchaseHintKey = isSupraMode
    ? "tickets.purchaseCard.hintSupra"
    : "tickets.purchaseCard.hintMock";
  const lotteries = status?.lotteries ?? [];

  useEffect(() => {
    if (!lotteries.length) {
      resetSelection();
      return;
    }
    if (!lotteries.some((lottery) => lottery.id === selectedLotteryId)) {
      setSelectedLotteryId(lotteries[0].id);
    }
  }, [lotteries, selectedLotteryId, setSelectedLotteryId, resetSelection]);

  const selectedLottery = useMemo(() => {
    if (!lotteries.length) {
      return null;
    }
    return lotteries.find((lottery) => lottery.id === selectedLotteryId) ?? lotteries[0];
  }, [lotteries, selectedLotteryId]);

  const roundLabel =
    selectedLottery?.round.snapshot?.nextTicketId ?? selectedLottery?.round.snapshot?.ticketCount ?? null;
  const ticketPrice = selectedLottery?.factory?.blueprint?.ticketPriceSupra ?? null;
  const filteredTickets = useMemo(() => {
    if (!tickets) {
      return null;
    }
    if (selectedLottery) {
      return tickets.filter((ticket) => ticket.lotteryId === selectedLottery.id);
    }
    return tickets;
  }, [tickets, selectedLottery]);

  const hasTickets = Boolean(filteredTickets && filteredTickets.length > 0);
  const hasLotteries = lotteries.length > 0;

  return (
    <section>
      <h1>{t("tickets.title")}</h1>
      <LotterySelector
        lotteries={lotteries}
        selectedLotteryId={selectedLottery?.id ?? null}
        onSelect={setSelectedLotteryId}
      />
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="primary"
          title={t("tickets.purchaseCard.title")}
          subtitle={t(purchaseSubtitleKey)}
          footer={
            hasLotteries && selectedLottery ? (
              <div className="badge-group">
                <span className="badge">{t("tickets.purchaseCard.badgeLottery", { id: selectedLottery.id })}</span>
                <span className="badge">{t("tickets.purchaseCard.badgeRound", { round: roundLabel ?? "-" })}</span>
              </div>
            ) : status ? (
              <span className="badge">{t("tickets.purchaseCard.badgeNoLotteries")}</span>
            ) : (
              <span className="badge">{t("tickets.purchaseCard.badgeLoading")}</span>
            )
          }
        >
          {status && selectedLottery ? (
            <TicketPurchaseForm
              lotteryId={selectedLottery.id}
              round={roundLabel ?? null}
              ticketPrice={ticketPrice ?? null}
            />
          ) : hasLotteries ? (
            <p>{t("tickets.purchaseCard.noLottery")}</p>
          ) : (
            <p>{t("tickets.purchaseCard.loading")}</p>
          )}
          <p>{t(purchaseHintKey)}</p>
        </GlassCard>

        <GlassCard accent="neutral" title={t("tickets.historyCard.title")} subtitle={t("tickets.historyCard.subtitle")}>
          {isLoading && <p>{t("tickets.historyCard.loading")}</p>}
          {error && <p>{t("tickets.historyCard.error")}</p>}
          {filteredTickets && hasTickets && <TicketList tickets={filteredTickets} />}
          {filteredTickets && !hasTickets && <p>{t("tickets.historyCard.empty")}</p>}
          {!filteredTickets && !isLoading && !error && (
            <p>{t("tickets.historyCard.noLotterySelected")}</p>
          )}
          {isSupraMode && <p className="ticket-history__hint">{t("tickets.historyCard.supraReadonly")}</p>}
        </GlassCard>
      </div>
    </section>
  );
}
