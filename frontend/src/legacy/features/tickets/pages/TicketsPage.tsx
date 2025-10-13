import { useEffect, useMemo } from "react";
import type { ReactElement } from "react";
import { Ticket, Sparkles, Trophy } from "lucide-react";
import { TicketPurchaseForm } from "../components/TicketPurchaseForm";
import { TicketList } from "../components/TicketList";
import { useTicketHistory } from "../hooks/useTicketHistory";
import { useLotteryStatus } from "../../dashboard/hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";
import { useUiStore } from "../../../store/uiStore";
import { LotterySelector } from "../../lotteries/components/LotterySelector";
import { useLotterySelectionStore } from "../../../store/lotteryStore";

function formatSupra(value: string | number | null): string {
  if (value === null || value === undefined || value === "") {
    return "-";
  }
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return String(value);
  }
  return `${numeric} $SUPRA`;
}

export function TicketsPage(): ReactElement {
  const { data: tickets, isLoading, error } = useTicketHistory();
  const { data: status } = useLotteryStatus({ staleTime: 60_000 });
  const { t } = useI18n();
  const apiMode = useUiStore((state) => state.apiMode);
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);
  const isSupraMode = apiMode === "supra";
  const purchaseSubtitleKey = isSupraMode
    ? "tickets.purchaseCard.subtitleSupra"
    : "tickets.purchaseCard.subtitleMock";
  const purchaseHintKey = isSupraMode
    ? "tickets.purchaseCard.hintSupra"
    : "tickets.purchaseCard.hintMock";
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

  const selectedLottery = useMemo(() => {
    if (!lotteries.length) {
      return null;
    }
    return lotteries.find((lottery) => lottery.id === selectedLotteryId) ?? lotteries[0];
  }, [lotteries, selectedLotteryId]);

  const roundLabel =
    selectedLottery?.round.snapshot?.nextTicketId ?? selectedLottery?.round.snapshot?.ticketCount ?? null;
  const ticketPrice = selectedLottery?.factory?.blueprint?.ticketPriceSupra ?? null;
  const ticketPriceNumeric = ticketPrice !== null ? Number(ticketPrice) : null;
  const prizePool = selectedLottery?.stats?.jackpotAccumulatedSupra ?? null;

  const filteredTickets = useMemo(() => {
    if (!tickets) {
      return null;
    }
    if (selectedLottery) {
      return tickets.filter((ticket) => ticket.lotteryId === selectedLottery.id);
    }
    return tickets;
  }, [tickets, selectedLottery]);

  const hasTickets = Boolean(filteredTickets && filteredTickets.length > 0);
  const hasLotteries = lotteries.length > 0;

  const totalTickets = filteredTickets?.length ?? 0;
  const activeTickets =
    filteredTickets?.filter((ticket) => ticket.status === "pending" || ticket.status === "confirmed").length ?? 0;
  const wonTickets = filteredTickets?.filter((ticket) => ticket.status === "won").length ?? 0;
  const estimatedSpent =
    ticketPriceNumeric !== null && filteredTickets ? formatSupra(ticketPriceNumeric * filteredTickets.length) : "-";

  return (
    <section className="relative overflow-hidden pb-32 pt-28">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/3 top-10 h-72 w-72 rounded-full bg-cyan-500/12 blur-3xl" />
        <div className="absolute right-1/4 top-1/3 h-80 w-80 rounded-full bg-purple-500/16 blur-3xl" />
        <div className="absolute bottom-6 left-1/2 h-[420px] w-[420px] -translate-x-1/2 rounded-full bg-pink-500/10 blur-3xl" />
      </div>

      <div className="relative z-10 mx-auto max-w-6xl px-6">
        <div className="mb-16 text-center">
          <h1
            className="mb-4 text-5xl font-extrabold text-transparent md:text-6xl"
            style={{
              fontFamily: "Orbitron, sans-serif",
              backgroundImage: "linear-gradient(120deg, #22d3ee, #a855f7)",
              WebkitBackgroundClip: "text",
            }}
          >
            {t("tickets.title")}
          </h1>
          <p className="mx-auto max-w-2xl text-lg text-gray-400">
            {t("tickets.subtitle", {
              defaultValue: "Purchase entries, follow active draws and review your Supra lottery history.",
            })}
          </p>
        </div>

        <div className="mb-12 flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex-1">
            <LotterySelector
              lotteries={lotteries}
              selectedLotteryId={selectedLottery?.id ?? null}
              onSelect={setSelectedLotteryId}
            />
          </div>

          <div className="rounded-3xl border border-cyan-500/30 bg-cyan-500/10 px-6 py-4 text-sm text-cyan-100 shadow-[0_28px_65px_-35px_rgba(34,211,238,0.55)] backdrop-blur-2xl">
            <span className="block text-xs uppercase tracking-[0.28em] text-cyan-200">
              {selectedLottery
                ? t("tickets.purchaseCard.badgeLottery", { id: selectedLottery.id })
                : t("tickets.purchaseCard.badgeNoLotteries")}
            </span>
            <span className="block text-xs uppercase tracking-[0.28em] text-cyan-200">
              {selectedLottery
                ? t("tickets.purchaseCard.badgeRound", { round: roundLabel ?? "-" })
                : t("tickets.purchaseCard.badgeLoading")}
            </span>
            <span className="mt-2 block text-sm">
              {selectedLottery ? `${t("tickets.prizePool", { defaultValue: "Prize Pool" })}: ${formatSupra(prizePool)}` : ""}
            </span>
          </div>
        </div>

        <div className="grid gap-8 lg:grid-cols-[1.45fr_1fr]">
          <div className="glass-strong rounded-3xl border border-cyan-500/30 p-8 shadow-[0_35px_70px_-35px_rgba(34,211,238,0.45)]">
            <div className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
              <div className="flex items-center gap-4">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan-500 to-purple-600 text-white shadow-[0_25px_45px_-25px_rgba(34,211,238,0.6)]">
                  <Ticket size={32} />
                </div>
                <div>
                  <h2
                    className="text-2xl font-semibold text-white"
                    style={{ fontFamily: "Orbitron, sans-serif" }}
                  >
                    {t("tickets.purchaseCard.title")}
                  </h2>
                  <p className="text-sm text-gray-400">{t(purchaseSubtitleKey)}</p>
                </div>
              </div>
              <div className="rounded-full border border-cyan-400/40 px-4 py-1 text-xs uppercase tracking-[0.2em] text-cyan-300">
                {formatSupra(ticketPrice)}
              </div>
            </div>

            <div className="mt-6 space-y-6">
              {status && selectedLottery ? (
                <div className="rounded-3xl border border-cyan-500/25 bg-black/20 p-6">
                  <TicketPurchaseForm
                    lotteryId={selectedLottery.id}
                    round={roundLabel ?? null}
                    ticketPrice={ticketPrice ?? null}
                  />
                </div>
              ) : hasLotteries ? (
                <p className="text-gray-300">{t("tickets.purchaseCard.noLottery")}</p>
              ) : (
                <p className="text-gray-300">{t("tickets.purchaseCard.loading")}</p>
              )}

              <p className="rounded-2xl border border-cyan-500/20 bg-cyan-500/10 p-5 text-sm text-cyan-100">
                {t(purchaseHintKey)}
              </p>
            </div>
          </div>

          <div className="glass-strong flex h-full flex-col gap-6 rounded-3xl border border-purple-500/25 p-8 shadow-[0_35px_70px_-35px_rgba(168,85,247,0.45)]">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h2
                  className="text-2xl font-semibold text-white"
                  style={{ fontFamily: "Orbitron, sans-serif" }}
                >
                  {t("tickets.historyCard.title")}
                </h2>
                <p className="text-sm text-gray-400">{t("tickets.historyCard.subtitle")}</p>
              </div>
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 text-white shadow-[0_22px_45px_-22px_rgba(168,85,247,0.55)]">
                <Sparkles size={22} />
              </div>
            </div>

            <div className="flex-1 overflow-hidden rounded-2xl border border-purple-500/20 bg-black/15 p-4">
              {isLoading && <p className="text-gray-300">{t("tickets.historyCard.loading")}</p>}
              {error && <p className="text-pink-300">{t("tickets.historyCard.error")}</p>}
              {filteredTickets && hasTickets && <TicketList tickets={filteredTickets} />}
              {filteredTickets && !hasTickets && <p className="text-gray-300">{t("tickets.historyCard.empty")}</p>}
              {!filteredTickets && !isLoading && !error && (
                <p className="text-gray-300">{t("tickets.historyCard.noLotterySelected")}</p>
              )}
            </div>

            {isSupraMode && (
              <p className="rounded-2xl border border-purple-500/25 bg-purple-500/10 p-4 text-sm text-purple-100">
                {t("tickets.historyCard.supraReadonly")}
              </p>
            )}
          </div>
        </div>

        <div className="mt-12 grid gap-6 md:grid-cols-3">
          <TicketStatistic
            icon={<Ticket size={28} />}
            label={t("tickets.stats.total", { defaultValue: "Total tickets" })}
            value={totalTickets.toString()}
            accent="cyan"
          />
          <TicketStatistic
            icon={<Sparkles size={26} />}
            label={t("tickets.stats.active", { defaultValue: "Active tickets" })}
            value={activeTickets.toString()}
            accent="purple"
          />
          <TicketStatistic
            icon={<Trophy size={26} />}
            label={t("tickets.stats.won", { defaultValue: "Wins / Spent" })}
            value={`${wonTickets} / ${estimatedSpent}`}
            accent="pink"
          />
        </div>
      </div>
    </section>
  );
}

interface TicketStatisticProps {
  icon: ReactElement;
  label: string;
  value: string;
  accent: "cyan" | "purple" | "pink";
}

function TicketStatistic({ icon, label, value, accent }: TicketStatisticProps): ReactElement {
  const accentClass =
    accent === "cyan"
      ? "border-cyan-500/30 text-cyan-200 shadow-[0_28px_55px_-28px_rgba(34,211,238,0.55)]"
      : accent === "purple"
        ? "border-purple-500/30 text-purple-200 shadow-[0_28px_55px_-28px_rgba(168,85,247,0.55)]"
        : "border-pink-500/30 text-pink-200 shadow-[0_28px_55px_-28px_rgba(236,72,153,0.55)]";

  return (
    <div className={`glass-strong rounded-3xl border ${accentClass} bg-black/15 p-6`}>
      <div className="mb-4 inline-flex h-12 w-12 items-center justify-center rounded-xl bg-white/5 text-white">
        {icon}
      </div>
      <p className="text-sm text-gray-400">{label}</p>
      <p
        className="mt-3 text-3xl font-semibold text-white"
        style={{ fontFamily: "Orbitron, sans-serif" }}
      >
        {value}
      </p>
    </div>
  );
}
