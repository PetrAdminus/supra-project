import { Trophy, Wallet, Clock } from "lucide-react";
import { Card } from "./ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "./ui/table";
import { DashboardSidebar } from "./DashboardSidebar";
import { useMemo, useState } from "react";
import { useLotteryMultiViews } from "../features/dashboard/hooks/useLotteryMultiViews";

const recentDraws = [
  { id: "#12345", date: "Oct 4, 2025", winner: "0x1a2b...3c4d", prize: "50,000 SUPRA", ticket: "789012" },
  { id: "#12344", date: "Oct 3, 2025", winner: "0x5e6f...7g8h", prize: "45,000 SUPRA", ticket: "456789" },
  { id: "#12343", date: "Oct 2, 2025", winner: "0x9i0j...1k2l", prize: "52,000 SUPRA", ticket: "123456" },
  { id: "#12342", date: "Oct 1, 2025", winner: "0xm3n4...5o6p", prize: "48,000 SUPRA", ticket: "345678" },
  { id: "#12341", date: "Sep 30, 2025", winner: "0xq7r8...9s0t", prize: "55,000 SUPRA", ticket: "901234" },
];

export function Dashboard() {
  const [activeSection, setActiveSection] = useState<"tickets" | "draws" | "history" | "profile" | "settings">("draws");
  const viewsQuery = useLotteryMultiViews();
  const statusOverview = viewsQuery.data?.statusOverview;
  const info = viewsQuery.data?.info;

  const numberFormatter = useMemo(() => new Intl.NumberFormat("ru-RU"), []);

  const displayValue = (value?: number) => {
    if (viewsQuery.isLoading) {
      return "…";
    }
    if (value === undefined || Number.isNaN(value)) {
      return "—";
    }
    return numberFormatter.format(value);
  };

  const updatedAtLabel = useMemo(() => {
    if (!info?.updatedAt) {
      return null;
    }
    const parsed = new Date(info.updatedAt);
    if (Number.isNaN(parsed.getTime())) {
      return info.updatedAt;
    }
    return parsed.toLocaleString("ru-RU");
  }, [info?.updatedAt]);

  const metrics = useMemo(
    () => [
      {
        key: "active",
        label: "Активные розыгрыши",
        primary: displayValue(statusOverview?.active),
        secondary:
          statusOverview && !viewsQuery.isLoading
            ? `${numberFormatter.format(statusOverview.closing)} готовятся к закрытию`
            : null,
        cardClass: "border-cyan-500/30 glow-cyan",
        gradientClass: "from-cyan-500 to-cyan-600",
        Icon: Trophy,
      },
      {
        key: "vrf",
        label: "VRF ожидание",
        primary: displayValue(statusOverview?.vrfRequested),
        secondary:
          statusOverview && !viewsQuery.isLoading
            ? `${numberFormatter.format(statusOverview.vrfRetryBlocked)} заблокировано retry`
            : null,
        cardClass: "border-purple-500/30 glow-purple",
        gradientClass: "from-purple-500 to-purple-600",
        Icon: Clock,
      },
      {
        key: "payout",
        label: "Очередь выплат",
        primary: displayValue(statusOverview?.payoutBacklog),
        secondary:
          statusOverview && !viewsQuery.isLoading
            ? `${numberFormatter.format(statusOverview.winnersPending)} победителей ждут выплаты`
            : null,
        cardClass: "border-pink-500/30 glow-pink",
        gradientClass: "from-pink-500 to-pink-600",
        Icon: Wallet,
      },
    ], [
      displayValue,
      numberFormatter,
      statusOverview?.active,
      statusOverview?.closing,
      statusOverview?.vrfRequested,
      statusOverview?.vrfRetryBlocked,
      statusOverview?.payoutBacklog,
      statusOverview?.winnersPending,
      viewsQuery.isLoading,
    ]);

  const lifecycleRows = useMemo(
    () => [
      { key: "total", label: "Всего розыгрышей", value: statusOverview?.total },
      { key: "draft", label: "Draft", value: statusOverview?.draft },
      { key: "active", label: "Active", value: statusOverview?.active },
      { key: "closing", label: "Closing", value: statusOverview?.closing },
      { key: "drawRequested", label: "DrawRequested", value: statusOverview?.drawRequested },
      { key: "drawn", label: "WinnerComputation", value: statusOverview?.drawn },
      { key: "payout", label: "Payout", value: statusOverview?.payout },
      { key: "finalized", label: "Finalized", value: statusOverview?.finalized },
      { key: "canceled", label: "Canceled", value: statusOverview?.canceled },
    ], [
      statusOverview?.active,
      statusOverview?.canceled,
      statusOverview?.closing,
      statusOverview?.drawRequested,
      statusOverview?.drawn,
      statusOverview?.draft,
      statusOverview?.finalized,
      statusOverview?.payout,
      statusOverview?.total,
    ]);

  const backlogRows = useMemo(
    () => [
      { key: "vrfRequested", label: "VRF: ожидают fulfill", value: statusOverview?.vrfRequested },
      { key: "vrfFulfilledPending", label: "VRF: готово к вычислению", value: statusOverview?.vrfFulfilledPending },
      { key: "vrfRetryBlocked", label: "VRF: блок retry", value: statusOverview?.vrfRetryBlocked },
      { key: "winnersPending", label: "Победители без выплат", value: statusOverview?.winnersPending },
      { key: "payoutBacklog", label: "Транши выплат в очереди", value: statusOverview?.payoutBacklog },
    ], [
      statusOverview?.payoutBacklog,
      statusOverview?.vrfFulfilledPending,
      statusOverview?.vrfRequested,
      statusOverview?.vrfRetryBlocked,
      statusOverview?.winnersPending,
    ]);

  return (
    <section id="dashboard" className="py-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="text-center mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Live Dashboard
          </h2>
          <p className="text-lg text-gray-400">Real-time lottery statistics and draw history</p>
        </div>

        {/* Dashboard Layout with Sidebar */}
        <div className="flex gap-6">
          {/* Left Sidebar */}
          <DashboardSidebar activeSection={activeSection} onSectionChange={setActiveSection} />

          {/* Main Content */}
          <div className="flex-1">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
              {metrics.map(({ key, label, primary, secondary, cardClass, gradientClass, Icon }) => (
                <Card key={key} className={`glass-strong p-8 rounded-2xl ${cardClass}`}>
                  <div className="flex items-center gap-4 mb-4">
                    <div className={`w-14 h-14 rounded-xl bg-gradient-to-br ${gradientClass} flex items-center justify-center`}>
                      <Icon className="w-7 h-7 text-white" />
                    </div>
                    <div>
                      <p className="text-sm text-gray-400">{label}</p>
                      <h3
                        className="text-3xl text-white"
                        style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
                      >
                        {primary}
                      </h3>
                      {secondary ? <p className="text-sm text-gray-300">{secondary}</p> : null}
                    </div>
                  </div>
                  {viewsQuery.isError ? (
                    <p className="text-xs text-red-400">Не удалось загрузить статус. Повторите попытку позже.</p>
                  ) : null}
                </Card>
              ))}
            </div>

            <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20 mb-12">
              <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between mb-6">
                <div>
                  <h3 className="text-2xl text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
                    Сводка статусов lottery_multi
                  </h3>
                  <p className="text-sm text-gray-400">
                    Карточки обновляются каждые 30 секунд с использованием `/lottery-multi/views`.
                  </p>
                </div>
                <div className="text-sm text-gray-400 text-left md:text-right">
                  {info?.version ? <div>Версия view: {info.version}</div> : null}
                  {updatedAtLabel ? <div>Обновлено: {updatedAtLabel}</div> : null}
                </div>
              </div>
              {viewsQuery.isError ? (
                <p className="text-red-400">Не удалось получить данные статуса. Проверьте подключение к Supra API.</p>
              ) : (
                <div className="grid gap-6 md:grid-cols-2">
                  <div>
                    <h4 className="text-lg text-cyan-300 mb-2" style={{ fontFamily: "Orbitron, sans-serif" }}>
                      Жизненный цикл
                    </h4>
                    <Table>
                      <TableHeader>
                        <TableRow className="border-gray-800">
                          <TableHead className="text-cyan-400">Статус</TableHead>
                          <TableHead className="text-cyan-400 text-right">Количество</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {lifecycleRows.map(({ key, label, value }) => (
                          <TableRow key={key} className="border-gray-800">
                            <TableCell className="text-gray-300">{label}</TableCell>
                            <TableCell className="text-right text-gray-100" style={{ fontFamily: "Orbitron, sans-serif" }}>
                              {displayValue(value)}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                  <div>
                    <h4 className="text-lg text-purple-300 mb-2" style={{ fontFamily: "Orbitron, sans-serif" }}>
                      Операционный бэклог
                    </h4>
                    <Table>
                      <TableHeader>
                        <TableRow className="border-gray-800">
                          <TableHead className="text-purple-400">Категория</TableHead>
                          <TableHead className="text-purple-400 text-right">Количество</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {backlogRows.map(({ key, label, value }) => (
                          <TableRow key={key} className="border-gray-800">
                            <TableCell className="text-gray-300">{label}</TableCell>
                            <TableCell className="text-right text-gray-100" style={{ fontFamily: "Orbitron, sans-serif" }}>
                              {displayValue(value)}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
              )}
            </Card>

            {/* Recent Draws Table */}
            <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
              <h3 className="text-2xl mb-6 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Recent Draw Results
              </h3>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="border-gray-700 hover:bg-transparent">
                      <TableHead className="text-cyan-400">Draw ID</TableHead>
                      <TableHead className="text-cyan-400">Date</TableHead>
                      <TableHead className="text-cyan-400">Winner</TableHead>
                      <TableHead className="text-cyan-400">Winning Ticket</TableHead>
                      <TableHead className="text-cyan-400 text-right">Prize</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {recentDraws.map((draw) => (
                      <TableRow key={draw.id} className="border-gray-800 hover:bg-white/5 transition-colors">
                        <TableCell className="text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                          {draw.id}
                        </TableCell>
                        <TableCell className="text-gray-300">{draw.date}</TableCell>
                        <TableCell>
                          <code className="text-cyan-400 bg-cyan-500/10 px-2 py-1 rounded text-sm">
                            {draw.winner}
                          </code>
                        </TableCell>
                        <TableCell className="text-gray-300">{draw.ticket}</TableCell>
                        <TableCell className="text-right">
                          <span className="text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 600 }}>
                            {draw.prize}
                          </span>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
}
