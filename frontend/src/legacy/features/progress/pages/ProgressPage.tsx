import { useMemo, type ReactElement } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useI18n } from "../../../i18n/useI18n";
import { useWallet } from "../../wallet/useWallet";
import {
  completeChecklist,
  fetchAchievements,
  fetchChecklist,
} from "../../../api/client";
import type {
  AchievementStatus,
  ChecklistStatus,
} from "../../../api/types";
import "./ProgressPage.css";

const CHECKLIST_QUERY_KEY = ["progress", "checklist"] as const;
const ACHIEVEMENTS_QUERY_KEY = ["progress", "achievements"] as const;

function formatDate(value: string | null, fallback: string): string {
  if (!value) {
    return fallback;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return fallback;
  }
  return date.toLocaleString();
}

function stringifyMetadata(metadata: Record<string, unknown> | null): string | null {
  if (!metadata || Object.keys(metadata).length === 0) {
    return null;
  }
  try {
    return JSON.stringify(metadata);
  } catch (error) {
    console.error(error);
    return String(metadata);
  }
}

export function ProgressPage(): ReactElement {
  const { t } = useI18n();
  const { wallet } = useWallet();
  const queryClient = useQueryClient();
  const walletAddress = wallet.address ? wallet.address.trim().toLowerCase() : null;

  const checklistQuery = useQuery<ChecklistStatus>({
    queryKey: [...CHECKLIST_QUERY_KEY, walletAddress],
    queryFn: () => fetchChecklist(walletAddress!),
    enabled: Boolean(walletAddress),
    staleTime: 30_000,
  });

  const achievementsQuery = useQuery<AchievementStatus>({
    queryKey: [...ACHIEVEMENTS_QUERY_KEY, walletAddress],
    queryFn: () => fetchAchievements(walletAddress!),
    enabled: Boolean(walletAddress),
    staleTime: 60_000,
  });

  const completeMutation = useMutation({
    mutationFn: (code: string) => {
      if (!walletAddress) {
        throw new Error("address-required");
      }
      return completeChecklist(walletAddress, code, { metadata: { source: "ui" } });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [...CHECKLIST_QUERY_KEY, walletAddress] });
      void queryClient.invalidateQueries({ queryKey: [...ACHIEVEMENTS_QUERY_KEY, walletAddress] });
    },
  });

  const checklistTasks = checklistQuery.data?.tasks ?? [];
  const achievements = achievementsQuery.data?.achievements ?? [];
  const isLoading = checklistQuery.isLoading || achievementsQuery.isLoading;
  const hasWallet = Boolean(walletAddress);

  const checklistContent = useMemo(() => {
    if (!hasWallet) {
      return <p>{t("progress.connectHint")}</p>;
    }
    if (checklistQuery.isLoading) {
      return <p>{t("progress.checklist.loading")}</p>;
    }
    if (checklistQuery.isError) {
      return <p className="progress-error">{t("progress.checklist.error")}</p>;
    }
    if (!checklistTasks.length) {
      return <p>{t("progress.checklist.empty")}</p>;
    }

    return (
      <ol className="progress-list">
        {checklistTasks.map((entry) => {
          const rewardLabel = entry.task.rewardKind
            ? t("progress.checklist.reward.kind", { kind: entry.task.rewardKind })
            : t("progress.checklist.reward.none");
          const rewardDetails = stringifyMetadata(entry.task.rewardValue);
          const metadataDetails = stringifyMetadata(entry.metadata);
          const isCompleted = entry.completed;
          return (
            <li
              key={entry.task.code}
              className={
                isCompleted ? "progress-task progress-task--completed" : "progress-task"
              }
            >
              <header className="progress-task__header">
                <div>
                  <h3>{entry.task.title}</h3>
                  <p className="progress-task__subtitle">
                    {t("progress.checklist.dayLabel", { index: entry.task.dayIndex + 1 })}
                  </p>
                </div>
                <span className="badge">
                  {t("progress.checklist.rewardLabel", {
                    label: rewardLabel,
                  })}
                </span>
              </header>
              <p className="progress-task__description">{entry.task.description}</p>
              {rewardDetails && (
                <p className="progress-task__meta">{t("progress.checklist.rewardValue", { value: rewardDetails })}</p>
              )}
              {metadataDetails && (
                <p className="progress-task__meta">{t("progress.checklist.metadata", { value: metadataDetails })}</p>
              )}
              <footer className="progress-task__footer">
                {isCompleted ? (
                  <span className="progress-task__status">
                    {t("progress.checklist.completedAt", {
                      date: formatDate(entry.completedAt, t("progress.generic.unknownDate")),
                    })}
                  </span>
                ) : (
                  <button
                    type="button"
                    className="button-primary"
                    onClick={() => completeMutation.mutate(entry.task.code)}
                    disabled={completeMutation.isPending}
                  >
                    {t("progress.checklist.completeAction")}
                  </button>
                )}
              </footer>
            </li>
          );
        })}
      </ol>
    );
  }, [
    hasWallet,
    checklistQuery.isLoading,
    checklistQuery.isError,
    checklistTasks,
    t,
    completeMutation,
  ]);

  const achievementsContent = useMemo(() => {
    if (!hasWallet) {
      return <p>{t("progress.connectHint")}</p>;
    }
    if (achievementsQuery.isLoading) {
      return <p>{t("progress.achievements.loading")}</p>;
    }
    if (achievementsQuery.isError) {
      return <p className="progress-error">{t("progress.achievements.error")}</p>;
    }
    if (!achievements.length) {
      return <p>{t("progress.achievements.empty")}</p>;
    }

    return (
      <ul className="progress-achievements">
        {achievements.map((entry) => {
          const metadataDetails = stringifyMetadata(entry.metadata);
          return (
            <li
              key={entry.achievement.code}
              className={
                entry.unlocked
                  ? "progress-achievement progress-achievement--unlocked"
                  : "progress-achievement"
              }
            >
              <header className="progress-achievement__header">
                <div>
                  <h3>{entry.achievement.title}</h3>
                  <p className="progress-achievement__description">
                    {entry.achievement.description}
                  </p>
                </div>
                <span className="badge">+{entry.achievement.points}</span>
              </header>
              <p className="progress-achievement__status">
                {entry.unlocked
                  ? t("progress.achievements.unlockedAt", {
                      date: formatDate(
                        entry.unlockedAt,
                        t("progress.generic.unknownDate"),
                      ),
                    })
                  : t("progress.achievements.locked")}
              </p>
              {entry.progressValue > 0 && (
                <p className="progress-achievement__meta">
                  {t("progress.achievements.progressValue", { value: entry.progressValue })}
                </p>
              )}
              {metadataDetails && (
                <p className="progress-achievement__meta">
                  {t("progress.achievements.metadata", { value: metadataDetails })}
                </p>
              )}
            </li>
          );
        })}
      </ul>
    );
  }, [hasWallet, achievementsQuery.isLoading, achievementsQuery.isError, achievements, t]);

  return (
    <section className="progress-section">
      <h1>{t("progress.title")}</h1>
      <p className="progress-subtitle">{t("progress.subtitle")}</p>

      {!hasWallet && !isLoading && (
        <GlassCard accent="secondary" title={t("progress.wallet.title")}>
          <p>{t("progress.wallet.hint")}</p>
        </GlassCard>
      )}

      <div className="glass-grid glass-grid--two progress-grid">
        <GlassCard accent="primary" title={t("progress.checklist.title")}>
          {checklistContent}
        </GlassCard>
        <GlassCard accent="secondary" title={t("progress.achievements.title")}>
          {achievementsContent}
        </GlassCard>
      </div>
    </section>
  );
}
