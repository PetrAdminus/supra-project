import { useEffect, useMemo } from "react";
import type { ReactElement } from "react";
import { useLotteryStatus } from "../hooks/useLotteryStatus";
import { useI18n } from "../../../i18n/useI18n";
import { LotterySelector } from "../../lotteries/components/LotterySelector";
import { ChatPanel } from "../../chat/components/ChatPanel";
import { useLotterySelectionStore } from "../../../store/lotteryStore";

function formatDate(value?: string | null): string {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return date.toLocaleString();
}

function formatSupra(value?: string | number | null): string {
  if (value === null || value === undefined) {
    return "-";
  }

  return `${value} $SUPRA`;
}

export function DashboardPage(): ReactElement {
  const { data, isLoading, error } = useLotteryStatus();
  const { t } = useI18n();
  const selectedLotteryId = useLotterySelectionStore((state) => state.selectedLotteryId);
  const setSelectedLotteryId = useLotterySelectionStore((state) => state.setSelectedLotteryId);
  const resetSelection = useLotterySelectionStore((state) => state.resetSelection);

  const lotteries = data?.lotteries ?? [];

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

  if (isLoading) {
    return (
      <section className="relative overflow-hidden pt-28 pb-24">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute -top-10 left-1/4 h-64 w-64 rounded-full bg-cyan-500/20 blur-3xl" />
          <div className="absolute bottom-0 right-1/4 h-72 w-72 rounded-full bg-purple-500/20 blur-3xl" />
        </div>
        <div className="relative z-10 mx-auto max-w-5xl px-6 text-center">
          <h1 className="text-4xl font-semibold tracking-wide text-gray-300">
            {t("dashboard.loading")}
          </h1>
        </div>
      </section>
    );
  }

  if (error || !data) {
    return (
      <section className="relative overflow-hidden pt-28 pb-24">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute -top-10 left-1/4 h-64 w-64 rounded-full bg-pink-500/20 blur-3xl" />
        </div>
        <div className="relative z-10 mx-auto max-w-3xl px-6 text-center">
          <h1 className="mb-6 text-5xl font-bold text-transparent md:text-6xl" style={{ fontFamily: "Orbitron, sans-serif", backgroundImage: "linear-gradient(120deg, #22d3ee, #a855f7)", WebkitBackgroundClip: "text" }}>
            {t("dashboard.title")}
          </h1>
          <div className="glass-strong rounded-2xl border border-pink-500/30 p-8 text-left shadow-lg shadow-pink-500/20">
            <h2 className="mb-2 text-2xl font-semibold text-pink-400">
              {t("dashboard.error.title")}
            </h2>
            <p className="text-gray-300">{t("dashboard.error.description")}</p>
          </div>
        </div>
      </section>
    );
  }

  const roundSnapshot = selectedLottery?.round.snapshot ?? null;
  const vrfPendingLabel = data.vrf.pendingRequestId
    ? t("dashboard.card.vrf.pendingYes")
    : t("dashboard.card.vrf.pendingNo");
  const jackpotValue =
    data.treasury.jackpotBalance ?? selectedLottery?.stats?.jackpotAccumulatedSupra;
  const ticketsSold = selectedLottery?.stats?.ticketsSold ?? roundSnapshot?.ticketCount ?? null;
  const ticketPrice = selectedLottery?.factory?.blueprint?.ticketPriceSupra ?? null;
  const nextDrawTime = null;
  const currentRoundLabel = roundSnapshot?.nextTicketId ?? roundSnapshot?.ticketCount ?? null;
  const hasLotteries = lotteries.length > 0;

  return (
    <section className="relative overflow-hidden pt-28 pb-32">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/4 top-8 h-80 w-80 rounded-full bg-cyan-500/15 blur-3xl" />
        <div className="absolute bottom-10 right-1/5 h-96 w-96 rounded-full bg-purple-500/20 blur-3xl" />
        <div className="absolute left-1/2 top-1/2 h-[480px] w-[480px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-pink-500/10 blur-3xl" />
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
            {t("dashboard.title")}
          </h1>
          <p className="mx-auto max-w-2xl text-lg text-gray-400">
            {t("dashboard.subtitle", { defaultValue: "Track live Supra draws, jackpots and VRF activity in real-time." })}
          </p>
        </div>

        <div className="mb-10 flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex-1">
            <LotterySelector
              lotteries={lotteries}
              selectedLotteryId={selectedLottery?.id ?? null}
              onSelect={setSelectedLotteryId}
            />
          </div>
          <div className="glass rounded-2xl border border-cyan-500/30 px-6 py-4 text-sm text-gray-300">
            <div className="flex items-center gap-3">
              <span className="flex h-2 w-2 items-center justify-center">
                <span className="h-2 w-2 rounded-full bg-cyan-400 shadow-[0_0_12px_rgba(34,211,238,0.6)] animate-pulse" />
              </span>
              <span>{t("dashboard.card.current.badge", { id: data.vrf.subscriptionId ?? "-" })}</span>
            </div>
          </div>
        </div>

        <div className="grid gap-8 lg:grid-cols-[1.65fr_1fr]">
          <div className="glass-strong rounded-3xl border border-cyan-500/30 p-8 shadow-[0_35px_70px_-35px_rgba(34,211,238,0.45)]">
            <div className="mb-8 flex flex-col gap-2 md:flex-row md:items-start md:justify-between">
              <div>
                <h2
                  className="text-2xl font-semibold text-white"
                  style={{ fontFamily: "Orbitron, sans-serif" }}
                >
                  {t("dashboard.card.current.title")}
                </h2>
                <p className="text-sm text-gray-400">
                  {t("dashboard.card.current.subtitle", { round: currentRoundLabel ?? "-" })}
                </p>
              </div>
              <div className="rounded-full border border-cyan-400/40 px-4 py-1 text-xs uppercase tracking-[0.2em] text-cyan-300">
                {t("dashboard.card.current.badge", { id: data.vrf.subscriptionId ?? "-" })}
              </div>
            </div>

            {hasLotteries ? (
              <>
                <div className="mb-8 rounded-2xl bg-gradient-to-r from-cyan-500/15 via-purple-500/15 to-pink-500/10 p-6">
                  <span className="text-sm uppercase tracking-widest text-gray-400">
                    {t("dashboard.card.current.jackpotLabel")}
                  </span>
                  <p
                    className="mt-2 text-5xl font-extrabold text-white"
                    style={{ fontFamily: "Orbitron, sans-serif" }}
                  >
                    {formatSupra(jackpotValue)}
                  </p>
                </div>

                <div className="grid gap-6 md:grid-cols-3">
                  <MetricCard
                    label={t("dashboard.card.current.ticketsSoldLabel")}
                    value={ticketsSold ?? "-"}
                    emphasis="large"
                  />
                  <MetricCard
                    label={t("dashboard.card.current.ticketPriceLabel")}
                    value={formatSupra(ticketPrice)}
                    emphasis="medium"
                  />
                  <MetricCard
                    label={t("dashboard.card.current.nextDrawLabel")}
                    value={formatDate(nextDrawTime)}
                    emphasis="small"
                  />
                </div>
              </>
            ) : (
              <p className="text-gray-400">{t("dashboard.card.current.empty")}</p>
            )}
          </div>

          <div className="glass-strong flex h-full flex-col gap-6 rounded-3xl border border-purple-500/30 p-8 shadow-[0_35px_70px_-35px_rgba(168,85,247,0.45)]">
            <div>
              <h2
                className="text-2xl font-semibold text-white"
                style={{ fontFamily: "Orbitron, sans-serif" }}
              >
                {t("dashboard.card.vrf.title")}
              </h2>
              <p className="text-sm text-gray-400">
                {data.vrf.pendingRequestId
                  ? t("dashboard.card.vrf.subtitlePending")
                  : t("dashboard.card.vrf.subtitleIdle")}
              </p>
            </div>

            <ul className="space-y-3 text-sm text-gray-200">
              <li className="flex justify-between gap-3">
                <span className="text-gray-400">Subscription ID</span>
                <span className="font-medium text-cyan-300">{data.vrf.subscriptionId ?? "-"}</span>
              </li>
              <li className="flex justify-between gap-3">
                <span className="text-gray-400">{t("dashboard.card.vrf.pendingLabel")}</span>
                <span className="font-medium text-white">{vrfPendingLabel}</span>
              </li>
              <li className="flex justify-between gap-3">
                <span className="text-gray-400">
                  {t("dashboard.card.vrf.lastRequestLabel", { value: "" })}
                </span>
                <span className="font-medium text-white">
                  {formatDate(data.vrf.lastRequestTime)}
                </span>
              </li>
              <li className="flex justify-between gap-3">
                <span className="text-gray-400">
                  {t("dashboard.card.vrf.lastFulfillmentLabel", { value: "" })}
                </span>
                <span className="font-medium text-white">
                  {formatDate(data.vrf.lastFulfillmentTime)}
                </span>
              </li>
            </ul>

            <p className="rounded-2xl bg-purple-500/10 p-4 text-xs text-purple-200">
              {t("dashboard.card.vrf.hint")}
            </p>
          </div>
        </div>

        <div className="mt-10 rounded-3xl border border-gray-700/30 bg-white/5 p-0 backdrop-blur-xl">
          <div className="border-b border-gray-600/40 px-6 py-4">
            <h2
              className="text-xl font-semibold text-white"
              style={{ fontFamily: "Orbitron, sans-serif" }}
            >
              {t("chat.panel.title")}
            </h2>
            <p className="text-sm text-gray-400">{t("chat.panel.subtitle")}</p>
          </div>
          <div className="p-4 sm:p-6">
            <ChatPanel room="global" lotteryId={selectedLottery?.id ?? null} />
          </div>
        </div>
      </div>
    </section>
  );
}

interface MetricCardProps {
  label: string;
  value: string | number | null;
  emphasis: "large" | "medium" | "small";
}

function MetricCard({ label, value, emphasis }: MetricCardProps): ReactElement {
  const sizing =
    emphasis === "large"
      ? "text-4xl md:text-5xl"
      : emphasis === "medium"
        ? "text-3xl"
        : "text-xl";

  return (
    <div className="rounded-2xl border border-cyan-500/20 bg-white/5 p-5 text-center shadow-inner shadow-cyan-500/10">
      <span className="text-xs uppercase tracking-[0.35em] text-gray-400">{label}</span>
      <p
        className={`mt-3 font-semibold text-white ${sizing}`}
        style={{ fontFamily: "Orbitron, sans-serif" }}
      >
        {value ?? "-"}
      </p>
    </div>
  );
}

