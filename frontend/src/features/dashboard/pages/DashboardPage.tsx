import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useLotteryStatus } from "../hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";

function formatDate(value: string | null): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

function formatSupra(value: string | number): string {
  return `${value} $SUPRA`;
}

export function DashboardPage(): ReactElement {
  const { data, isLoading, error } = useLotteryStatus();
  const { t } = useI18n();

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

  const vrfPendingLabel = data.vrf.requestPending
    ? t("dashboard.card.vrf.pendingYes")
    : t("dashboard.card.vrf.pendingNo");

  return (
    <section>
      <h1>{t("dashboard.title")}</h1>
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="primary"
          title={t("dashboard.card.current.title")}
          subtitle={t("dashboard.card.current.subtitle", { round: data.round })}
          footer={<span className="badge">{t("dashboard.card.current.badge", { id: data.vrf.subscriptionId })}</span>}
        >
          <div className="glass-card__metric">
            <span className="stat-label">{t("dashboard.card.current.jackpotLabel")}</span>
            <span className="stat-value">{formatSupra(data.jackpotSupra)}</span>
          </div>
          <div className="glass-grid glass-grid--three">
            <div className="glass-card__metric">
              <span className="stat-label">{t("dashboard.card.current.ticketsSoldLabel")}</span>
              <span className="stat-value" style={{ fontSize: "1.9rem" }}>{data.ticketsSold}</span>
            </div>
            <div className="glass-card__metric">
              <span className="stat-label">{t("dashboard.card.current.ticketPriceLabel")}</span>
              <span className="stat-value" style={{ fontSize: "1.6rem" }}>{formatSupra(data.ticketPriceSupra)}</span>
            </div>
            <div className="glass-card__metric">
              <span className="stat-label">{t("dashboard.card.current.nextDrawLabel")}</span>
              <span className="stat-value" style={{ fontSize: "1.1rem" }}>
                {formatDate(data.nextDrawTime)}
              </span>
            </div>
          </div>
        </GlassCard>

        <GlassCard
          accent="secondary"
          title={t("dashboard.card.vrf.title")}
          subtitle={data.vrf.requestPending ? t("dashboard.card.vrf.subtitlePending") : t("dashboard.card.vrf.subtitleIdle")}
          footer={<span>{t("dashboard.card.vrf.lastRequestLabel", { value: formatDate(data.vrf.lastRequestTime) })}</span>}
        >
          <ul>
            <li>
              <strong>Subscription ID:</strong> {data.vrf.subscriptionId}
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
    </section>
  );
}

