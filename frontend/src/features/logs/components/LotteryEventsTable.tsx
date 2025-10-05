import type { ReactElement } from "react";
import type { LotteryEvent } from "../../../api/types";
import { useI18n } from "../../../i18n/useI18n";
import './LotteryEventsTable.css';

type TranslateFn = ReturnType<typeof useI18n>["t"];
type EventTypeKey = `logs.table.types.${LotteryEvent["type"]}`;
type EventStatusKey = `logs.table.status.${NonNullable<LotteryEvent["status"]>}`;

interface LotteryEventsTableProps {
  events: LotteryEvent[];
}

function formatTimestamp(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}

function getTypeLabel(t: TranslateFn, eventType: LotteryEvent["type"]): string {
  const key = `logs.table.types.${eventType}` as EventTypeKey;
  return t(key);
}

function getStatusLabel(t: TranslateFn, status: LotteryEvent["status"]): string {
  if (!status) {
    return "-";
  }

  const key = `logs.table.status.${status}` as EventStatusKey;
  return t(key);
}

export function LotteryEventsTable({ events }: LotteryEventsTableProps): ReactElement {
  const { t } = useI18n();
  const headers = {
    event: t("logs.table.headers.event"),
    round: t("logs.table.headers.round"),
    time: t("logs.table.headers.time"),
    details: t("logs.table.headers.details"),
    status: t("logs.table.headers.status"),
  } as const;

  return (
    <table className="event-table" data-testid="lottery-events-table">
      <thead>
        <tr>
          <th scope="col">{headers.event}</th>
          <th scope="col">{headers.round}</th>
          <th scope="col">{headers.time}</th>
          <th scope="col">{headers.details}</th>
          <th scope="col">{headers.status}</th>
        </tr>
      </thead>
      <tbody>
        {events.map((event) => {
          const typeClass = `event-table__type event-table__type--${event.type.toLowerCase()}`;
          const statusLabel = getStatusLabel(t, event.status);

          return (
            <tr key={event.eventId}>
              <td data-label={headers.event}>
                <span className={typeClass}>{getTypeLabel(t, event.type)}</span>
              </td>
              <td data-label={headers.round}>{event.round}</td>
              <td data-label={headers.time}>
                <time dateTime={event.timestamp}>{formatTimestamp(event.timestamp)}</time>
              </td>
              <td data-label={headers.details}>
                <div>{event.details}</div>
                {event.txHash && <div className="event-table__ticket-id">{event.txHash}</div>}
              </td>
              <td data-label={headers.status}>
                {event.status ? <span className="badge">{statusLabel}</span> : <span>{statusLabel}</span>}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
