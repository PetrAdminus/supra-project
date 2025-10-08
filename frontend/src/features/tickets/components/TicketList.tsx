import type { ReactElement } from "react";
import type { TicketPurchase } from "../../../api/types";
import { useI18n } from "../../../i18n/useI18n";
import './TicketList.css';

interface TicketListProps {
  tickets: TicketPurchase[];
}

const statusKeyByState = {
  pending: "tickets.status.pending",
  confirmed: "tickets.status.confirmed",
  won: "tickets.status.won",
  lost: "tickets.status.lost",
} as const;

export function TicketList({ tickets }: TicketListProps): ReactElement {
  const { t } = useI18n();

  return (
    <ul className="ticket-list">
      {tickets.map((ticket) => (
        <li key={ticket.ticketId} className={`ticket-list__item ticket-list__item--${ticket.status}`}>
          <div>
            <span className="ticket-list__id">{ticket.ticketId}</span>
            <span className="ticket-list__meta">{t("tickets.historyCard.lotteryLabel", { id: ticket.lotteryId })}</span>
            <span className="ticket-list__meta">{t("tickets.purchaseCard.badgeRound", { round: ticket.round })}</span>
          </div>
          <div className="ticket-list__numbers">
            {ticket.numbers.length > 0 ? (
              ticket.numbers.map((num) => <span key={num}>{num}</span>)
            ) : (
              <span className="ticket-list__numbers--empty">{t("tickets.historyCard.numbersUnavailable")}</span>
            )}
          </div>
          <div className="ticket-list__status">
            <span>{t(statusKeyByState[ticket.status])}</span>
            <time dateTime={ticket.purchaseTime}>{new Date(ticket.purchaseTime).toLocaleString()}</time>
          </div>
        </li>
      ))}
    </ul>
  );
}
