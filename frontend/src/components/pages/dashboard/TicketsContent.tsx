import { useEffect, useMemo } from "react";
import { Ticket, Plus, CheckCircle2 } from "lucide-react";
import { Card } from "../../ui/card";
import { Button } from "../../ui/button";
import { Badge } from "../../ui/badge";
import { useLotteryStatus } from "../../../features/dashboard/hooks/useLotteryStatus";
import { useTicketHistory } from "../../../features/tickets/hooks/useTicketHistory";
import { useUiStore } from "../../../store/uiStore";
import { useLotterySelectionStore } from "../../../store/lotteryStore";
import type { TicketStatus } from "../../../api/types";

const statusMeta: Record<
  TicketStatus,
  {
    label: string;
    badgeClass: string;
    showActiveHint: boolean;
  }
> = {
  pending: {
    label: "Active",
    badgeClass: "bg-green-500/20 text-green-400 border-green-500/50",
    showActiveHint: true,
  },
  confirmed: {
    label: "Active",
    badgeClass: "bg-green-500/20 text-green-400 border-green-500/50",
    showActiveHint: true,
  },
  won: {
    label: "Won",
    badgeClass: "bg-purple-500/20 text-purple-300 border-purple-500/50",
    showActiveHint: false,
  },
  lost: {
    label: "Completed",
    badgeClass: "bg-gray-500/20 text-gray-400 border-gray-500/50",
    showActiveHint: false,
  },
};

function formatSupra(value?: string | number | null): string {
  if (value === null || value === undefined || value === "") {
    return "—";
  }
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return String(value);
  }
  return `${numeric} $SUPRA`;
}

function formatDate(value?: string | null): string {
  if (!value) {
    return "—";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "—";
  }
  return parsed.toLocaleString();
}

export function TicketsContent() {
  const { data: lotteryStatus } = useLotteryStatus({ staleTime: 60_000 });
  const { data: ticketHistory, isLoading, error } = useTicketHistory();
  const apiMode = useUiStore((state) => state.apiMode);

  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);

  const lotteries = lotteryStatus?.lotteries ?? [];

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

  const filteredTickets = useMemo(() => {
    if (!ticketHistory) {
      return [];
    }
    if (!selectedLottery) {
      return ticketHistory;
    }
    return ticketHistory.filter((ticket) => ticket.lotteryId === selectedLottery.id);
  }, [ticketHistory, selectedLottery]);

  const ticketPrice = selectedLottery?.factory?.blueprint?.ticketPriceSupra ?? null;
  const ticketPriceNumeric = ticketPrice !== null ? Number(ticketPrice) : null;
  const prizePool = selectedLottery?.stats?.jackpotAccumulatedSupra ?? null;
  const totalTickets = filteredTickets.length;
  const activeTickets = filteredTickets.filter(
    (ticket) => ticket.status === "pending" || ticket.status === "confirmed"
  ).length;
  const totalSpent =
    ticketPriceNumeric !== null ? formatSupra(ticketPriceNumeric * totalTickets) : "—";

  const showReadonly = apiMode === "supra";
  const ticketsToDisplay = filteredTickets.slice(0, 6);

  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
          My Tickets
        </h3>
        <p className="text-gray-400">Manage your lottery tickets and participate in draws</p>
      </div>

      {/* Purchase New Ticket Section */}
      <Card className="glass-strong p-8 rounded-2xl border-cyan-500/30 glow-cyan mb-8">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center">
              <Ticket className="w-8 h-8 text-white" />
            </div>
            <div>
              <h4 className="text-2xl text-white mb-1" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Next Draw: {selectedLottery ? `#${selectedLottery.id}` : "—"}
              </h4>
              <p className="text-gray-400">Prize Pool: {formatSupra(prizePool)}</p>
            </div>
          </div>
          <Button
            className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl glow-cyan transition-all disabled:opacity-60 disabled:cursor-not-allowed"
            disabled={!selectedLottery || showReadonly}
          >
            <Plus className="w-5 h-5 mr-2" />
            Buy Ticket ({formatSupra(ticketPrice)})
          </Button>
        </div>
        {showReadonly && (
          <p className="mt-4 text-sm text-cyan-200/70">
            Supra mode is read-only while wallet whitelisting is pending.
          </p>
        )}
        {!selectedLottery && !showReadonly && (
          <p className="mt-4 text-sm text-cyan-200/70">
            No active lotteries available at the moment.
          </p>
        )}
      </Card>

      {/* Tickets Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {error && (
          <Card className="glass-strong p-6 rounded-2xl border-pink-500/20 text-pink-200">
            Unable to load ticket history right now.
          </Card>
        )}

        {isLoading && !filteredTickets.length && !error && (
          <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20 text-cyan-100">
            Loading tickets...
          </Card>
        )}

        {!isLoading && !error && ticketsToDisplay.length === 0 && (
          <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20 text-gray-300">
            You have no tickets yet. Make your first purchase to join the next draw.
          </Card>
        )}

        {ticketsToDisplay.map((ticket) => {
          const meta = statusMeta[ticket.status];
          return (
            <Card key={ticket.ticketId} className="glass-strong p-6 rounded-2xl border-purple-500/20 hover:border-purple-500/40 transition-all">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                    <Ticket className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <h4 className="text-xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      #{ticket.ticketId}
                    </h4>
                    <p className="text-sm text-gray-400">Draw #{ticket.round}</p>
                  </div>
                </div>
                <Badge className={meta.badgeClass}>{meta.label}</Badge>
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Purchase Date</span>
                  <span className="text-gray-300">{formatDate(ticket.purchaseTime)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Price Paid</span>
                  <span className="text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                    {formatSupra(ticketPrice)}
                  </span>
                </div>
              </div>

              {meta.showActiveHint && (
                <div className="flex items-center gap-2 text-sm text-purple-400 bg-purple-500/10 px-3 py-2 rounded-lg">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Entered in upcoming draw</span>
                </div>
              )}
            </Card>
          );
        })}
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <Card className="glass p-6 rounded-2xl text-center">
          <p className="text-sm text-gray-400 mb-2">Total Tickets</p>
          <p className="text-3xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            {totalTickets}
          </p>
        </Card>
        <Card className="glass p-6 rounded-2xl text-center">
          <p className="text-sm text-gray-400 mb-2">Active Tickets</p>
          <p className="text-3xl text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            {activeTickets}
          </p>
        </Card>
        <Card className="glass p-6 rounded-2xl text-center">
          <p className="text-sm text-gray-400 mb-2">Total Spent</p>
          <p className="text-3xl text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            {totalSpent}
          </p>
        </Card>
      </div>
    </div>
  );
}
