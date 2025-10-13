import {
  useEffect,
  useMemo,
  useState,
  type ChangeEvent,
  type FormEvent,
} from "react";
import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { LotterySelector } from "../../lotteries/components/LotterySelector";
import { useLotterySelectionStore } from "../../../store/lotteryStore";
import { useLotteryStatus } from "../../dashboard/hooks/useLotteryStatus";
import { useLotteryVrfLog } from "../hooks/useLotteryVrfLog";
import { useI18n } from "../../../i18n/useI18n";
import type { LotterySummary, VrfLogEvent } from "../../../api/types";
import "./FairnessPage.css";

const LIMIT_OPTIONS = [10, 25, 50, 100];
const DEFAULT_EVENT_TYPE = "all";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toStringValue(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length ? trimmed : null;
  }
  if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") {
    return String(value);
  }
  return null;
}

function extractTimestamp(event: VrfLogEvent): string | null {
  const direct = toStringValue(event.timestamp);
  if (direct) {
    return direct;
  }
  if (isRecord(event.data)) {
    return toStringValue(event.data.timestamp);
  }
  return null;
}

function extractRequestId(event: VrfLogEvent): string | null {
  const direct = toStringValue(event.request_id ?? event.requestId ?? event.id);
  if (direct) {
    return direct;
  }
  if (isRecord(event.data)) {
    return toStringValue(event.data.request_id ?? event.data.requestId);
  }
  return null;
}

function extractRoundId(event: VrfLogEvent): string | null {
  const direct = toStringValue(event.round_id ?? event.roundId);
  if (direct) {
    return direct;
  }
  if (isRecord(event.data)) {
    return toStringValue(event.data.round_id ?? event.data.roundId);
  }
  return null;
}

function extractEventType(event: VrfLogEvent): string {
  return (
    toStringValue(event.event_type ?? event.type) ??
    (isRecord(event.data) ? toStringValue(event.data.event_type ?? event.data.type) : null) ??
    "event"
  );
}

function formatDate(value: string | null): string {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
}

function formatSnapshotValue(value: unknown): string {
  if (value === null || value === undefined) {
    return "-";
  }
  if (typeof value === "object") {
    try {
      return JSON.stringify(value, null, 2);
    } catch (error) {
      return String(value);
    }
  }
  return String(value);
}

function SnapshotView({ snapshot }: { snapshot: Record<string, unknown> | null }): ReactElement {
  if (!snapshot) {
    return <p>-</p>;
  }
  const entries = Object.entries(snapshot);
  if (!entries.length) {
    return <p>-</p>;
  }
  return (
    <dl className="fairness-snapshot">
      {entries.map(([key, value]) => (
        <div className="fairness-snapshot__row" key={key}>
          <dt>{key}</dt>
          <dd>{formatSnapshotValue(value)}</dd>
        </div>
      ))}
    </dl>
  );
}

function filterEvents(
  events: VrfLogEvent[],
  eventType: string,
  query: string,
): VrfLogEvent[] {
  const normalizedQuery = query.trim().toLowerCase();

  return events.filter((event) => {
    const matchesType =
      eventType === DEFAULT_EVENT_TYPE || extractEventType(event) === eventType;

    if (!matchesType) {
      return false;
    }

    if (!normalizedQuery) {
      return true;
    }

    const parts: Array<string | null> = [
      extractEventType(event),
      extractRequestId(event),
      extractRoundId(event),
      extractTimestamp(event),
    ];

    if (isRecord(event.data)) {
      try {
        parts.push(JSON.stringify(event.data));
      } catch (error) {
        parts.push(String(event.data));
      }
    }

    return parts.some((part) =>
      part ? part.toLowerCase().includes(normalizedQuery) : false,
    );
  });
}

interface EventListProps {
  title: string;
  emptyText: string;
  events: VrfLogEvent[];
  showRawLabel: string;
  timestampLabel: string;
  requestLabel: string;
  roundLabel: string;
}

function EventList({
  title,
  emptyText,
  events,
  showRawLabel,
  timestampLabel,
  requestLabel,
  roundLabel,
}: EventListProps): ReactElement {
  return (
    <section className="fairness-events">
      <h3>{title}</h3>
      {events.length === 0 ? (
        <p>{emptyText}</p>
      ) : (
        <ol className="fairness-events__list">
          {events.map((event, index) => {
            const eventType = extractEventType(event);
            const timestamp = formatDate(extractTimestamp(event));
            const requestId = extractRequestId(event) ?? "-";
            const roundId = extractRoundId(event) ?? "-";
            return (
              <li className="fairness-event" key={`${eventType}-${index}`}>
                <header className="fairness-event__header">
                  <span className="fairness-event__type">{eventType}</span>
                  <span className="fairness-event__meta">{timestampLabel}: {timestamp}</span>
                </header>
                <div className="fairness-event__body">
                  <div className="fairness-event__meta-row">
                    <span>{requestLabel}: {requestId}</span>
                    <span>{roundLabel}: {roundId}</span>
                  </div>
                  <details className="fairness-event__details">
                    <summary>{showRawLabel}</summary>
                    <pre>{JSON.stringify(event, null, 2)}</pre>
                  </details>
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

export function FairnessPage(): ReactElement {
  const { t } = useI18n();
  const [limit, setLimit] = useState<number>(25);
  const [eventTypeFilter, setEventTypeFilter] = useState<string>(DEFAULT_EVENT_TYPE);
  const [searchQuery, setSearchQuery] = useState<string>("");
  const { data: status, isLoading: statusLoading, error: statusError } = useLotteryStatus();
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);

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

  const selectedLottery: LotterySummary | null = useMemo(() => {
    if (!lotteries.length) {
      return null;
    }
    return lotteries.find((lottery) => lottery.id === selectedLotteryId) ?? lotteries[0];
  }, [lotteries, selectedLotteryId]);

  const {
    data: vrfLog,
    isLoading: vrfLoading,
    error: vrfError,
  } = useLotteryVrfLog(selectedLottery?.id ?? null, limit, { enabled: lotteries.length > 0 });

  const availableEventTypes = useMemo(() => {
    if (!vrfLog) {
      return [] as string[];
    }
    const allEvents = [
      ...vrfLog.round.requests,
      ...vrfLog.round.fulfillments,
      ...vrfLog.hub.requests,
      ...vrfLog.hub.fulfillments,
    ];
    const unique = new Set<string>();
    for (const event of allEvents) {
      unique.add(extractEventType(event));
    }
    return Array.from(unique).sort((a, b) => a.localeCompare(b));
  }, [vrfLog]);

  useEffect(() => {
    if (
      eventTypeFilter !== DEFAULT_EVENT_TYPE &&
      availableEventTypes.length > 0 &&
      !availableEventTypes.includes(eventTypeFilter)
    ) {
      setEventTypeFilter(DEFAULT_EVENT_TYPE);
    }
  }, [availableEventTypes, eventTypeFilter]);

  const filteredRoundRequests = useMemo(
    () =>
      vrfLog
        ? filterEvents(vrfLog.round.requests, eventTypeFilter, searchQuery)
        : [],
    [eventTypeFilter, searchQuery, vrfLog],
  );

  const filteredRoundFulfillments = useMemo(
    () =>
      vrfLog
        ? filterEvents(vrfLog.round.fulfillments, eventTypeFilter, searchQuery)
        : [],
    [eventTypeFilter, searchQuery, vrfLog],
  );

  const filteredHubRequests = useMemo(
    () => (vrfLog ? filterEvents(vrfLog.hub.requests, eventTypeFilter, searchQuery) : []),
    [eventTypeFilter, searchQuery, vrfLog],
  );

  const filteredHubFulfillments = useMemo(
    () =>
      vrfLog ? filterEvents(vrfLog.hub.fulfillments, eventTypeFilter, searchQuery) : [],
    [eventTypeFilter, searchQuery, vrfLog],
  );

  const handleLimitChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = Number(event.target.value);
    if (!Number.isNaN(nextValue)) {
      setLimit(nextValue);
    }
  };

  const handleEventTypeChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setEventTypeFilter(event.target.value);
  };

  const handleSearchChange = (event: ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(event.target.value);
  };

  const handleSearchReset = (event: FormEvent<HTMLButtonElement>) => {
    event.preventDefault();
    setSearchQuery("");
  };

  return (
    <section className="fairness-page">
      <h1>{t("fairness.title")}</h1>
      <p className="fairness-page__subtitle">{t("fairness.subtitle")}</p>

      <LotterySelector
        lotteries={lotteries}
        selectedLotteryId={selectedLottery?.id ?? null}
        onSelect={setSelectedLotteryId}
      />

      <form className="fairness-page__controls" aria-label={t("fairness.filters.title")}>
        <label className="fairness-page__control" htmlFor="fairness-limit">
          <span>{t("fairness.limitLabel")}</span>
          <select id="fairness-limit" value={limit} onChange={handleLimitChange}>
            {LIMIT_OPTIONS.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>

        <label className="fairness-page__control" htmlFor="fairness-event-type">
          <span>{t("fairness.filters.eventType")}</span>
          <select id="fairness-event-type" value={eventTypeFilter} onChange={handleEventTypeChange}>
            <option value={DEFAULT_EVENT_TYPE}>{t("fairness.filters.eventTypeAll")}</option>
            {availableEventTypes.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </label>

        <label
          className="fairness-page__control fairness-page__control--search"
          htmlFor="fairness-search"
        >
          <span>{t("fairness.filters.searchLabel")}</span>
          <div className="fairness-page__search-wrapper">
            <input
              id="fairness-search"
              type="search"
              value={searchQuery}
              onChange={handleSearchChange}
              placeholder={t("fairness.filters.searchPlaceholder")}
            />
            {searchQuery && (
              <button
                type="button"
                onClick={handleSearchReset}
                aria-label={t("fairness.filters.reset")}
              >
                {t("fairness.filters.resetShort")}
              </button>
            )}
          </div>
        </label>
      </form>

      {statusLoading ? (
        <GlassCard accent="neutral" title={t("fairness.loading.title")}> 
          <p>{t("fairness.loading.body")}</p>
        </GlassCard>
      ) : statusError ? (
        <GlassCard accent="secondary" title={t("fairness.error.statusTitle")}> 
          <p>{t("fairness.error.statusBody")}</p>
        </GlassCard>
      ) : !selectedLottery ? (
        <GlassCard accent="neutral" title={t("fairness.empty.title")}> 
          <p>{t("fairness.empty.body")}</p>
        </GlassCard>
      ) : vrfError ? (
        <GlassCard accent="secondary" title={t("fairness.error.logTitle")}> 
          <p>{t("fairness.error.logBody")}</p>
        </GlassCard>
      ) : (
        <div className="fairness-page__grid">
          <GlassCard
            accent="primary"
            title={t("fairness.round.title")}
            subtitle={t("fairness.round.subtitle", { id: selectedLottery.id })}
            footer={
              <span className="badge">
                {t("fairness.round.pending", {
                  value: vrfLog?.round.pendingRequestId
                    ? vrfLog.round.pendingRequestId
                    : t("fairness.round.pendingNone"),
                })}
              </span>
            }
          >
            {vrfLoading || !vrfLog ? (
              <p>{t("fairness.loading.body")}</p>
            ) : (
              <>
                <h3>{t("fairness.round.snapshotTitle")}</h3>
                <SnapshotView snapshot={vrfLog.round.snapshot} />
                <EventList
                  title={t("fairness.round.requests")}
                  emptyText={t("fairness.events.empty")}
                  events={filteredRoundRequests}
                  showRawLabel={t("fairness.events.showRaw")}
                  timestampLabel={t("fairness.events.timestamp")}
                  requestLabel={t("fairness.events.requestId")}
                  roundLabel={t("fairness.events.roundId")}
                />
                <EventList
                  title={t("fairness.round.fulfillments")}
                  emptyText={t("fairness.events.empty")}
                  events={filteredRoundFulfillments}
                  showRawLabel={t("fairness.events.showRaw")}
                  timestampLabel={t("fairness.events.timestamp")}
                  requestLabel={t("fairness.events.requestId")}
                  roundLabel={t("fairness.events.roundId")}
                />
              </>
            )}
          </GlassCard>

          <GlassCard
            accent="secondary"
            title={t("fairness.hub.title")}
            subtitle={t("fairness.hub.subtitle")}
          >
            {vrfLoading || !vrfLog ? (
              <p>{t("fairness.loading.body")}</p>
            ) : (
              <>
                <EventList
                  title={t("fairness.hub.requests")}
                  emptyText={t("fairness.events.empty")}
                  events={filteredHubRequests}
                  showRawLabel={t("fairness.events.showRaw")}
                  timestampLabel={t("fairness.events.timestamp")}
                  requestLabel={t("fairness.events.requestId")}
                  roundLabel={t("fairness.events.roundId")}
                />
                <EventList
                  title={t("fairness.hub.fulfillments")}
                  emptyText={t("fairness.events.empty")}
                  events={filteredHubFulfillments}
                  showRawLabel={t("fairness.events.showRaw")}
                  timestampLabel={t("fairness.events.timestamp")}
                  requestLabel={t("fairness.events.requestId")}
                  roundLabel={t("fairness.events.roundId")}
                />
              </>
            )}
          </GlassCard>
        </div>
      )}
    </section>
  );
}
