import type { ReactElement, ReactNode } from "react";
import type { LotteryEvent } from "../../../api/types";
import { useI18n } from "../../../i18n/useI18n";

interface EventTableProps {
  events: LotteryEvent[];
}

const typeKeyByEvent = {
  DrawRequested: "logs.table.types.DrawRequested",
  DrawHandled: "logs.table.types.DrawHandled",
  TicketBought: "logs.table.types.TicketBought",
} as const;

const statusKeyByState = {
  success: "logs.table.status.success",
  failed: "logs.table.status.failed",
  retry: "logs.table.status.retry",
} as const;

function renderDetails(details: string): ReactNode {
  const match = details.match(/TICK-[\w-]+/);
  if (!match) {
    return details;
  }

  const [ticketId] = match;
  const [prefix, suffix] = details.split(ticketId);

  return (
    <>
      {prefix}
      <span className="event-table__ticket-id">{ticketId}</span>
      {suffix}
    </>
  );
}

export function EventTable({ events }: EventTableProps): ReactElement {
  const { t } = useI18n();

  return (
    <table className="event-table">
      <thead>
        <tr>
          <th>{t("logs.table.headers.event")}</th>
          <th>{t("logs.table.headers.round")}</th>
          <th>{t("logs.table.headers.time")}</th>
          <th>{t("logs.table.headers.details")}</th>
          <th>{t("logs.table.headers.status")}</th>
        </tr>
      </thead>
      <tbody>
        {events.map((event) => (
          <tr key={event.eventId}>
            <td data-label={t("logs.table.headers.event")}>
              <span className={`event-table__type event-table__type--${event.type.toLowerCase()}`}>
                {t(typeKeyByEvent[event.type])}
              </span>
            </td>
            <td data-label={t("logs.table.headers.round")}>{event.round}</td>
            <td data-label={t("logs.table.headers.time")}>
              <time dateTime={event.timestamp}>{new Date(event.timestamp).toLocaleString()}</time>
            </td>
            <td data-label={t("logs.table.headers.details")}>{renderDetails(event.details)}</td>
            <td data-label={t("logs.table.headers.status")}>
              {event.status ? (
                <span className={`event-status event-status--${event.status}`}>
                  {t(statusKeyByState[event.status])}
                </span>
              ) : (
                <span className="event-status event-status--success">{t("logs.table.status.success")}</span>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

