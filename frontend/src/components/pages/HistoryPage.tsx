import { useMemo } from "react";
import { History, TrendingUp, TrendingDown, Award } from "lucide-react";
import { Card } from "../ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "../ui/table";
import { Badge } from "../ui/badge";
import { useLotteryStatus } from "../../features/dashboard/hooks/useLotteryStatus";
import { useTicketHistory } from "../../features/tickets/hooks/useTicketHistory";

import { EMPTY_VALUE, formatDateTime, formatSupraValue, parseSupraValue } from "../../utils/format";

function formatSupraWithSign(value: number | null): { label: string; className: string } {
  if (value === null || Number.isNaN(value) || value === 0) {
    return { label: EMPTY_VALUE, className: "text-gray-300" };
  }
  const sign = value > 0 ? "+" : "-";
  const className = value > 0 ? "text-green-400" : "text-red-400";
  return {
    label: `${sign}${formatSupraValue(Math.abs(value))}`,
    className,
  };
}

export function HistoryPage() {
  const { data: statusData } = useLotteryStatus({ staleTime: 60_000 });
  const { data: ticketHistory, isLoading, error } = useTicketHistory();

  const lotteries = statusData?.lotteries ?? [];
  const priceByLottery = useMemo(() => {
    return lotteries.reduce<Record<number, number>>((acc, lottery) => {
      const price = parseSupraValue(lottery.factory?.blueprint?.ticketPriceSupra ?? null);
      if (price !== null) {
        acc[lottery.id] = price;
      }
      return acc;
    }, {});
  }, [lotteries]);

  const sortedTickets = useMemo(() => {
    if (!ticketHistory) {
      return [];
    }
    return [...ticketHistory].sort(
      (a, b) => new Date(b.purchaseTime).getTime() - new Date(a.purchaseTime).getTime(),
    );
  }, [ticketHistory]);

  const totals = useMemo(() => {
    let spent = 0;
    let won = 0;

    sortedTickets.forEach((ticket) => {
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
      transactions: sortedTickets.length,
      totalSpent: spent || null,
      totalWon: won || null,
      netProfit: won - spent || null,
    };
  }, [sortedTickets, priceByLottery]);

  const rows = useMemo(() => {
    return sortedTickets.map((ticket) => {
      const price = priceByLottery[ticket.lotteryId] ?? null;
      const isPrize = ticket.status === "won";
      const amountLabel =
        price === null ? EMPTY_VALUE : `${isPrize ? "+" : "-"}${formatSupraValue(price)}`;
      return {
        id: `${ticket.ticketId}-${ticket.purchaseTime}`,
        type: ticket.status === "won" ? "Prize Won" : "Purchase",
        ticket: ticket.ticketId,
        draw: ticket.round,
        amountLabel,
        amountClass:
          price === null
            ? "text-gray-300"
            : isPrize
              ? "text-green-400"
              : "text-red-400",
        dateLabel: formatDateTime(ticket.purchaseTime),
        status: ticket.status === "won" ? "Claimed" : "Completed",
      };
    });
  }, [sortedTickets, priceByLottery]);

  const totalSpentDisplay = formatSupraWithSign(
    totals.totalSpent !== null ? -totals.totalSpent : null,
  );
  const totalWonDisplay = formatSupraWithSign(totals.totalWon ?? null);
  const netProfitDisplay = formatSupraWithSign(totals.netProfit ?? null);

  return (
    <div className="pt-20 pb-20 relative">
      <div className="absolute top-0 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 left-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="mb-12">
          <h2
            className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent"
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            Transaction History
          </h2>
          <p className="text-lg text-gray-400">
            View all your lottery transactions and winnings
          </p>
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
              className={`text-3xl ${totalSpentDisplay.className}`}
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
              className={`text-3xl ${totalWonDisplay.className}`}
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
              className={`text-3xl ${netProfitDisplay.className}`}
              style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
            >
              {netProfitDisplay.label}
            </p>
          </Card>
        </div>

        <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
          <h3
            className="text-2xl mb-6 text-white"
            style={{ fontFamily: "Orbitron, sans-serif" }}
          >
            All Transactions
          </h3>
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
                            row.type === "Prize Won"
                              ? "bg-green-500/20 text-green-400 border-green-500/50"
                              : "bg-blue-500/20 text-blue-400 border-blue-500/50"
                          }
                        >
                          {row.type}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <code className="text-purple-400 bg-purple-500/10 px-2 py-1 rounded text-sm">
                          #{row.ticket}
                        </code>
                      </TableCell>
                      <TableCell className="text-gray-300">#{row.draw}</TableCell>
                      <TableCell>
                        <span
                          className={row.amountClass}
                          style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 600 }}
                        >
                          {row.amountLabel}
                        </span>
                      </TableCell>
                      <TableCell className="text-gray-300">{row.dateLabel}</TableCell>
                      <TableCell>
                        <Badge className="bg-gray-500/20 text-gray-400 border-gray-500/50">
                          {row.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
              </TableBody>
            </Table>
          </div>
        </Card>
      </div>
    </div>
  );
}
