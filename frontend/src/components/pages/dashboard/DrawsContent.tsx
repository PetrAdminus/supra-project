import { useMemo } from "react";
import { Trophy, Clock, Sparkles } from "lucide-react";
import { Card } from "../../ui/card";
import { Badge } from "../../ui/badge";
import { Button } from "../../ui/button";
import { Progress } from "../../ui/progress";
import { useLotteryStatus } from "../../../features/dashboard/hooks/useLotteryStatus";
import { useTicketHistory } from "../../../features/tickets/hooks/useTicketHistory";

import { EMPTY_VALUE, formatDateTime, formatSupraValue, parseSupraValue } from "../../../utils/format";

export function DrawsContent() {
  const { data: statusData } = useLotteryStatus();
  const { data: tickets } = useTicketHistory();

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

  const upcoming = useMemo(() => {
    return lotteries.slice(0, 3).map((lottery, index) => {
      const prizePool = formatSupraValue(lottery.stats?.jackpotAccumulatedSupra ?? null);
      const participants = lottery.stats?.ticketsSold ?? 0;
      const statusLabel =
        lottery.round.pendingRequestId !== null || lottery.round.snapshot?.hasPendingRequest
          ? "live"
          : "upcoming";
      return {
        id: `#${lottery.id}`,
        prizePool,
        participants,
        statusLabel,
        highlight: index === 0,
      };
    });
  }, [lotteries]);

  const winners = useMemo(() => {
    if (!tickets) {
      return [];
    }
    return tickets
      .filter((ticket) => ticket.status === "won")
      .slice(0, 3)
      .map((ticket) => {
        const prizeAmount = priceByLottery[ticket.lotteryId] ?? null;
        const participants =
          lotteries.find((lottery) => lottery.id === ticket.lotteryId)?.stats?.ticketsSold ?? EMPTY_VALUE;
        return {
          id: `#${ticket.round}`,
          ticketId: ticket.ticketId,
          date: formatDateTime(ticket.purchaseTime),
          prize: formatSupraValue(prizeAmount),
          participants,
        };
      });
  }, [tickets, lotteries]);

  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          Lottery Draws
        </h3>
        <p className="text-gray-400">View upcoming and completed lottery draws</p>
      </div>

      <div className="mb-12">
        <h4 className="text-2xl mb-6 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          Upcoming Draws
        </h4>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {upcoming.length === 0 && (
            <Card className="glass-strong p-6 rounded-2xl border-cyan-500/30 text-gray-300">
              No draws scheduled right now.
            </Card>
          )}
          {upcoming.map((draw) => (
            <Card
              key={draw.id}
              className={`glass-strong p-6 rounded-2xl ${
                draw.highlight ? "border-cyan-500/40 glow-cyan" : "border-purple-500/20"
              }`}
            >
              <div className="flex items-start justify-between mb-4">
                <div>
                  <h5
                    className="text-2xl text-white mb-1"
                    style={{ fontFamily: "Orbitron, sans-serif" }}
                  >
                    Draw {draw.id}
                  </h5>
                  {draw.statusLabel === "live" && (
                    <Badge className="bg-green-500/20 text-green-400 border-green-500/50">
                      <Sparkles className="w-3 h-3 mr-1" />
                      Live
                    </Badge>
                  )}
                </div>
                <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                  <Trophy className="w-6 h-6 text-white" />
                </div>
              </div>

              <div className="space-y-4 mb-6">
                <div>
                  <p className="text-sm text-gray-400 mb-1">Prize Pool</p>
                  <p
                    className="text-2xl text-cyan-400"
                    style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
                  >
                    {draw.prizePool}
                  </p>
                </div>

                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-400">Participants</span>
                    <span className="text-purple-400">{draw.participants}</span>
                  </div>
                  <Progress value={Math.min((draw.participants / 2000) * 100, 100)} className="h-2" />
                </div>

                <div className="flex items-center gap-2 text-sm">
                  <Clock className="w-4 h-4 text-pink-400" />
                  <span className="text-gray-400">
                    {draw.statusLabel === "live" ? "Currently drawing" : "Scheduled"}
                  </span>
                </div>
              </div>

              <Button className="w-full bg-gradient-to-r from-purple-500 to-pink-600 hover:from-purple-600 hover:to-pink-700 text-white py-2 rounded-xl transition-all">
                Buy Ticket
              </Button>
            </Card>
          ))}
        </div>
      </div>

      <div>
        <h4 className="text-2xl mb-6 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          Completed Draws
        </h4>
        <div className="space-y-4">
          {winners.length === 0 && (
            <Card className="glass-strong p-6 rounded-2xl border-purple-500/20 text-gray-300">
              No completed draws with winners yet.
            </Card>
          )}
          {winners.map((draw) => (
            <Card key={draw.id} className="glass-strong p-6 rounded-2xl border-purple-500/20">
              <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-gray-600 to-gray-700 flex items-center justify-center">
                    <Trophy className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <h5
                      className="text-xl text-white"
                      style={{ fontFamily: "Orbitron, sans-serif" }}
                    >
                      Draw {draw.id}
                    </h5>
                    <p className="text-sm text-gray-400">{draw.date}</p>
                  </div>
                </div>

                <div className="flex items-center gap-8">
                  <div>
                    <p className="text-sm text-gray-400">Winner Ticket</p>
                    <code className="text-cyan-400 bg-cyan-500/10 px-2 py-1 rounded text-sm">
                      #{draw.ticketId}
                    </code>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Prize</p>
                    <p
                      className="text-lg text-pink-400"
                      style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 600 }}
                    >
                      {draw.prize}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Participants</p>
                    <p
                      className="text-lg text-purple-400"
                      style={{ fontFamily: "Orbitron, sans-serif" }}
                    >
                      {draw.participants}
                    </p>
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
