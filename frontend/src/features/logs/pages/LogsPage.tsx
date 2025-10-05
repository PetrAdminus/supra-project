import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useI18n } from "../../../i18n/useI18n";
import { useLotteryEvents } from "../hooks/useLotteryEvents";
import { useUiStore } from "../../../store/uiStore";
import { LotteryEventsTable } from "../components/LotteryEventsTable";
import './LogsPage.css';

export function LogsPage(): ReactElement {
  const { data: events, isLoading, error } = useLotteryEvents();
  const { t } = useI18n();
  const showEventErrors = useUiStore((state) => state.showEventErrors);
  const toggleEventErrors = useUiStore((state) => state.toggleEventErrors);

  const resolvedEvents = events ?? [];
  const filteredEvents = showEventErrors
    ? resolvedEvents
    : resolvedEvents.filter((event) => event.status !== "failed");
  const hiddenErrorsCount = showEventErrors
    ? 0
    : resolvedEvents.filter((event) => event.status === "failed").length;

  const hasEvents = resolvedEvents.length > 0;
  const hasVisibleEvents = filteredEvents.length > 0;

  return (
    <section>
      <h1>{t("logs.title")}</h1>
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="primary"
          title={t("logs.card.events.title")}
          subtitle={t("logs.card.events.subtitle")}
        >
          {isLoading && <p>{t("logs.card.events.loading")}</p>}
          {error && (
            <p className="logs-page__error-message">{t("logs.card.events.error")}</p>
          )}

          {!hasEvents && !isLoading && (
            <p>{t("logs.card.events.empty")}</p>
          )}

          {hasEvents && (
            <>
              <div className="logs-page__actions">
                <button
                  type="button"
                  className="button-link"
                  onClick={toggleEventErrors}
                >
                  {showEventErrors
                    ? t("logs.card.events.actionHide")
                    : t("logs.card.events.actionShow")}
                </button>
              </div>

              {hasVisibleEvents && <LotteryEventsTable events={filteredEvents} />}

              {hiddenErrorsCount > 0 && (
                <p className="logs-page__hidden-message">
                  {t("logs.card.events.hiddenErrors", { count: hiddenErrorsCount })}
                </p>
              )}
            </>
          )}
        </GlassCard>

        <GlassCard accent="neutral" title={t("logs.card.plan.title")}>
          <ul className="logs-plan__list">
            <li>{t("logs.card.plan.items.first")}</li>
            <li>{t("logs.card.plan.items.second")}</li>
            <li>{t("logs.card.plan.items.third")}</li>
          </ul>
        </GlassCard>
      </div>
    </section>
  );
}
