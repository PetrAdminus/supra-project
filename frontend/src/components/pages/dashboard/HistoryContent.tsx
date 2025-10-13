import { useMemo } from "react";
import { History, TrendingUp, TrendingDown, Award } from "lucide-react";
import { Card } from "../../ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "../../ui/table";
import { Badge } from "../../ui/badge";
import { useLotteryStatus } from "../../../features/dashboard/hooks/useLotteryStatus";
import { useTicketHistory } from "../../../features/tickets/hooks/useTicketHistory";
import { useLotterySelectionStore } from "../../../store/lotteryStore";

type TicketRow = {
  id: string;
  ticketId: string;
  round: number;
  status: string;
  amountLabel: string;
  amountSign: "positive" | "negative" | "neutral";
  dateLabel: string;
};

function formatSupra(value: number | null): string {
  if (value === null || Number.isNaN(value)) {
    return "—";
  }
  return `${value.toLocaleString("en-US", {
    maximumFractionDigits: 2,
  })} $SUPRA`;
}

function formatSupraWithSign(value: number | null): { label: string; signClass: string } {
  if (value === null || Number.isNaN(value) || value === 0) {
    return { label: "—", signClass: "text-gray-300" };
  }
  const sign = value > 0 ? "+" : "-";
  const className = value > 0 ? "text-green-400" : "text-red-400";
  return {
    label: `${sign}${formatSupra(Math.abs(value))}`,
    signClass: className,
  };
}

function parseSupra(value: string | number | null | undefined): number | null {
  if (value === null || value === undefined) {
    return null;
  }
  const numeric = Number(value);
  return Number.isNaN(numeric) ? null : numeric;
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

const statusLabels: Record<string, string> = {
  pending: "Pending",
  confirmed: "Confirmed",
  won: "Prize Won",
  lost: "Completed",
};

export function HistoryContent() {
  const { data: statusData } = useLotteryStatus();
  const { data: ticketHistory, isLoading, error } = useTicketHistory();
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);

  const lotteries = statusData?.lotteries ?? [];

  const tickets = useMemo(() => {
    if (!ticketHistory) {
      return [];
    }
    if (!selectedLotteryId) {
      return [...ticketHistory].sort(
        (a, b) => new Date(b.purchaseTime).getTime() - new Date(a.purchaseTime).getTime(),
      );
    }
    return ticketHistory
      .filter((ticket) => ticket.lotteryId === selectedLotteryId)
      .sort((a, b) => new Date(b.purchaseTime).getTime() - new Date(a.purchaseTime).getTime());
  }, [ticketHistory, selectedLotteryId]);

  const priceByLottery = useMemo(() => {
    return lotteries.reduce<Record<number, number>>((acc, lottery) => {
      const price = parseSupra(lottery.factory?.blueprint?.ticketPriceSupra ?? null);
      if (price !== null) {
        acc[lottery.id] = price;
      }
      return acc;
    }, {});
  }, [lotteries]);

  const totals = useMemo(() => {
    let spent = 0;
    let won = 0;

    tickets.forEach((ticket) => {
      const price = priceByLottery[ticket.lotteryId] ?? null;
      if (price === null) {
        return;
      }
      if (ticket.status === "won") {
        won += price;
      } else {
        spent += price;
      }
    });

    return {
      transactions: tickets.length,
      totalSpent: spent || null,
      totalWon: won || null,
      netProfit: won - spent || null,
    };
  }, [tickets, priceByLottery]);

  const rows: TicketRow[] = useMemo(() => {
    return tickets.map((ticket) => {
      const price = priceByLottery[ticket.lotteryId] ?? null;
      const isPrize = ticket.status === "won";
      const amountValue = price === null ? null : price;
      const amountLabel =
        amountValue === null ? "—" : `${isPrize ? "+" : "-"}${formatSupra(amountValue)}`;
      return {
        id: `${ticket.ticketId}-${ticket.purchaseTime}`,
        ticketId: ticket.ticketId,
        round: ticket.round,
        status: ticket.status,
        amountLabel,
        amountSign: amountValue === null ? "neutral" : isPrize ? "positive" : "negative",
        dateLabel: formatDate(ticket.purchaseTime),
      };
    });
  }, [tickets, priceByLottery]);

  const totalSpentDisplay = formatSupraWithSign(
    totals.totalSpent !== null ? -totals.totalSpent : null,
  );
  const totalWonDisplay = formatSupraWithSign(totals.totalWon ?? null);
  const netProfitDisplay = formatSupraWithSign(totals.netProfit ?? null);

  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          Transaction History
        </h3>
        <p className="text-gray-400">View all your lottery transactions and winnings</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-12">
        <Card className="glass-strong p-6 rounded-2xl border-cyan-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-cyan-500/20 flex items-center justify-center">
              <History className="w-5 h-5 text-cyan-400" />
            </div>
            <p className="text-sm text-gray-400">Total Transactions</p>
          </div>
          <p
            className="text-3xl text-cyan-400"
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            {totals.transactions}
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-red-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-red-500/20 flex items-center justify-center">
              <TrendingDown className="w-5 h-5 text-red-400" />
            </div>
            <p className="text-sm text-gray-400">Total Spent</p>
          </div>
          <p
            className={`text-3xl ${totalSpentDisplay.signClass}`}
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            {totalSpentDisplay.label}
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-green-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-green-400" />
            </div>
            <p className="text-sm text-gray-400">Total Won</p>
          </div>
          <p
            className={`text-3xl ${totalWonDisplay.signClass}`}
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            {totalWonDisplay.label}
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-purple-500/30 glow-purple">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-purple-500/20 flex items-center justify-center">
              <Award className="w-5 h-5 text-purple-400" />
            </div>
            <p className="text-sm text-gray-400">Net Profit</p>
          </div>
          <p
            className={`text-3xl ${netProfitDisplay.signClass}`}
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            {netProfitDisplay.label}
          </p>
        </Card>
      </div>

      <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
        <h4 className="text-2xl mb-6 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          All Transactions
        </h4>
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="border-gray-700 hover:bg-transparent">
                <TableHead className="text-cyan-400">Type</TableHead>
                <TableHead className="text-cyan-400">Ticket</TableHead>
                <TableHead className="text-cyan-400">Draw</TableHead>
                <TableHead className="text-cyan-400">Amount</TableHead>
                <TableHead className="text-cyan-400">Date</TableHead>
                <TableHead className="text-cyan-400">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && (
                <TableRow className="border-gray-800 hover:bg-transparent">
                  <TableCell colSpan={6} className="text-center text-gray-300">
                    Loading transactions...
                  </TableCell>
                </TableRow>
              )}

              {error && (
                <TableRow className="border-gray-800 hover:bg-transparent">
                  <TableCell colSpan={6} className="text-center text-pink-300">
                    Unable to load history right now.
                  </TableCell>
                </TableRow>
              )}

              {!isLoading && !error && rows.length === 0 && (
                <TableRow className="border-gray-800 hover:bg-transparent">
                  <TableCell colSpan={6} className="text-center text-gray-300">
                    You have no transactions yet.
                  </TableCell>
                </TableRow>
              )}

              {!isLoading &&
                !error &&
                rows.map((row) => (
                  <TableRow key={row.id} className="border-gray-800 hover:bg-white/5 transition-colors">
                    <TableCell>
                      <Badge
                        className={
                          row.status === "won"
                            ? "bg-green-500/20 text-green-400 border-green-500/50"
                            : "bg-blue-500/20 text-blue-400 border-blue-500/50"
                        }
                      >
                        {row.status === "won" ? "Prize Won" : "Purchase"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <code className="text-purple-400 bg-purple-500/10 px-2 py-1 rounded text-sm">
                        #{row.ticketId}
                      </code>
                    </TableCell>
                    <TableCell className="text-gray-300">#{row.round}</TableCell>
                    <TableCell>
                      <span
                        className={
                          row.amountSign === "positive"
                            ? "text-green-400"
                            : row.amountSign === "negative"
                              ? "text-red-400"
                              : "text-gray-300"
                        }
                        style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 600 }}
                      >
                        {row.amountLabel}
                      </span>
                    </TableCell>
                    <TableCell className="text-gray-300">{row.dateLabel}</TableCell>
                    <TableCell>
                      <Badge className="bg-gray-500/20 text-gray-400 border-gray-500/50">
                        {statusLabels[row.status] ?? row.status}
                      </Badge>
                    </TableCell>
                  </TableRow>
                ))}
            </TableBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}
