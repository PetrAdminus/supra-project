import { useEffect, useMemo } from "react";
import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useLotteryStatus } from "../hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";
import { LotterySelector } from "../../lotteries/components/LotterySelector";
import { ChatPanel } from "../../chat/components/ChatPanel";
import { useLotterySelectionStore } from "../../../store/lotteryStore";

function formatDate(value?: string | null): string {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return date.toLocaleString();
}

function formatSupra(value?: string | number | null): string {
  if (value === null || value === undefined) {
    return "-";
  }

  return `${value} $SUPRA`;
}

export function DashboardPage(): ReactElement {
  const { data, isLoading, error } = useLotteryStatus();
  const { t } = useI18n();
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);

  const lotteries = data?.lotteries ?? [];

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

  if (isLoading) {
    return (
      <section>
        <h1>{t("dashboard.title")}</h1>
        <p>{t("dashboard.loading")}</p>
      </section>
    );
  }

  if (error || !data) {
    return (
      <section>
        <h1>{t("dashboard.title")}</h1>
        <GlassCard accent="secondary" title={t("dashboard.error.title")}
        >
          <p>{t("dashboard.error.description")}</p>
        </GlassCard>
      </section>
    );
  }

  const roundSnapshot = selectedLottery?.round.snapshot ?? null;
  const vrfPendingLabel = data.vrf.pendingRequestId
    ? t("dashboard.card.vrf.pendingYes")
    : t("dashboard.card.vrf.pendingNo");
  const jackpotValue =
    data.treasury.jackpotBalance ?? selectedLottery?.stats?.jackpotAccumulatedSupra;
  const ticketsSold = selectedLottery?.stats?.ticketsSold ?? roundSnapshot?.ticketCount ?? null;
  const ticketPrice = selectedLottery?.factory?.blueprint?.ticketPriceSupra ?? null;
  const nextDrawTime = null;
  const currentRoundLabel = roundSnapshot?.nextTicketId ?? roundSnapshot?.ticketCount ?? null;
  const hasLotteries = lotteries.length > 0;

  return (
    <section>
      <h1>{t("dashboard.title")}</h1>
      <LotterySelector
        lotteries={lotteries}
        selectedLotteryId={selectedLottery?.id ?? null}
        onSelect={setSelectedLotteryId}
      />
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="primary"
          title={t("dashboard.card.current.title")}
          subtitle={t("dashboard.card.current.subtitle", { round: currentRoundLabel ?? "-" })}
          footer={<span className="badge">{t("dashboard.card.current.badge", { id: data.vrf.subscriptionId ?? "-" })}</span>}
        >
          {hasLotteries ? (
            <>
              <div className="glass-card__metric">
                <span className="stat-label">{t("dashboard.card.current.jackpotLabel")}</span>
                <span className="stat-value">{formatSupra(jackpotValue)}</span>
              </div>
              <div className="glass-grid glass-grid--three">
                <div className="glass-card__metric">
                  <span className="stat-label">{t("dashboard.card.current.ticketsSoldLabel")}</span>
                  <span className="stat-value" style={{ fontSize: "1.9rem" }}>{ticketsSold ?? "-"}</span>
                </div>
                <div className="glass-card__metric">
                  <span className="stat-label">{t("dashboard.card.current.ticketPriceLabel")}</span>
                  <span className="stat-value" style={{ fontSize: "1.6rem" }}>{formatSupra(ticketPrice)}</span>
                </div>
                <div className="glass-card__metric">
                  <span className="stat-label">{t("dashboard.card.current.nextDrawLabel")}</span>
                  <span className="stat-value" style={{ fontSize: "1.1rem" }}>
                    {formatDate(nextDrawTime)}
                  </span>
                </div>
              </div>
            </>
          ) : (
            <p>{t("dashboard.card.current.empty")}</p>
          )}
        </GlassCard>

        <GlassCard
          accent="secondary"
          title={t("dashboard.card.vrf.title")}
          subtitle={data.vrf.pendingRequestId ? t("dashboard.card.vrf.subtitlePending") : t("dashboard.card.vrf.subtitleIdle")}
          footer={<span>{t("dashboard.card.vrf.lastRequestLabel", { value: formatDate(data.vrf.lastRequestTime) })}</span>}
        >
          <ul>
            <li>
              <strong>Subscription ID:</strong> {data.vrf.subscriptionId ?? "-"}
            </li>
            <li>
              <strong>{t("dashboard.card.vrf.pendingLabel")}:</strong> {vrfPendingLabel}
            </li>
            <li>
              <strong>{t("dashboard.card.vrf.lastFulfillmentLabel", { value: formatDate(data.vrf.lastFulfillmentTime) })}</strong>
            </li>
          </ul>
          <p>{t("dashboard.card.vrf.hint")}</p>
        </GlassCard>
      </div>
      <GlassCard
        accent="neutral"
        title={t("chat.panel.title")}
        subtitle={t("chat.panel.subtitle")}
        className="dashboard-chat-card"
      >
        <ChatPanel room="global" lotteryId={selectedLottery?.id ?? null} />
      </GlassCard>
    </section>
  );
}

