import type { ReactElement } from "react";
import { CheckCircle2, Hourglass, Ticket, Trophy, XCircle } from "lucide-react";
import type { TicketPurchase, TicketStatus } from "../../../api/types";
import { useI18n } from "../../../i18n/useI18n";
import "./TicketList.css";

interface TicketListProps {
  tickets: TicketPurchase[];
}

const statusConfig: Record<
  TicketStatus,
  {
    labelKey: string;
    badgeClass: string;
    Icon: typeof Hourglass;
  }
> = {
  pending: {
    labelKey: "tickets.status.pending",
    badgeClass: "ticket-card__badge--pending",
    Icon: Hourglass,
  },
  confirmed: {
    labelKey: "tickets.status.confirmed",
    badgeClass: "ticket-card__badge--confirmed",
    Icon: CheckCircle2,
  },
  won: {
    labelKey: "tickets.status.won",
    badgeClass: "ticket-card__badge--won",
    Icon: Trophy,
  },
  lost: {
    labelKey: "tickets.status.lost",
    badgeClass: "ticket-card__badge--lost",
    Icon: XCircle,
  },
};

export function TicketList({ tickets }: TicketListProps): ReactElement {
  const { t } = useI18n();

  return (
    <ul className="ticket-list">
      {tickets.map((ticket) => {
        const status = statusConfig[ticket.status];
        const StatusIcon = status.Icon;
        const purchaseDate = new Date(ticket.purchaseTime);

        return (
          <li key={ticket.ticketId} className={`ticket-card glass-strong ticket-card--${ticket.status}`}>
            <div className="ticket-card__header">
              <div className="ticket-card__icon">
                <Ticket size={22} />
              </div>
              <div className="ticket-card__meta">
                <span className="ticket-card__id">#{ticket.ticketId}</span>
                <span className="ticket-card__info">
                  {t("tickets.historyCard.lotteryLabel", { id: ticket.lotteryId })}
                </span>
                <span className="ticket-card__info">
                  {t("tickets.purchaseCard.badgeRound", { round: ticket.round })}
                </span>
              </div>
              <span className={`ticket-card__badge ${status.badgeClass}`}>
                {t(status.labelKey)}
              </span>
            </div>

            <div className="ticket-card__numbers">
              {ticket.numbers.length > 0 ? (
                ticket.numbers.map((number) => (
                  <span key={number} className="ticket-card__number">
                    {number}
                  </span>
                ))
              ) : (
                <span className="ticket-card__numbers--empty">
                  {t("tickets.historyCard.numbersUnavailable")}
                </span>
              )}
            </div>

            <div className="ticket-card__footer">
              <div className="ticket-card__status">
                <StatusIcon size={16} />
                <span>{t(status.labelKey)}</span>
              </div>
              <time dateTime={ticket.purchaseTime}>
                {purchaseDate.toLocaleString()}
              </time>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
