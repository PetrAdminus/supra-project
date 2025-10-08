import { fireEvent, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";
import { renderWithProviders } from "../../../testing/renderWithProviders";
import { ProgressPage } from "./ProgressPage";

const fetchChecklistMock = vi.fn();
const fetchAchievementsMock = vi.fn();
const completeChecklistMock = vi.fn();

vi.mock("../../../api/client", () => ({
  fetchChecklist: (...args: unknown[]) => fetchChecklistMock(...args),
  fetchAchievements: (...args: unknown[]) => fetchAchievementsMock(...args),
  completeChecklist: (...args: unknown[]) => completeChecklistMock(...args),
}));

const walletState = {
  wallet: {
    address: null as string | null,
    status: "disconnected" as const,
    provider: "starkey" as const,
    providerReady: true,
  },
  error: null,
  connect: vi.fn(),
  disconnect: vi.fn(),
  changeProvider: vi.fn(),
  copyAddress: vi.fn(),
  clearError: vi.fn(),
};

vi.mock("../../wallet/useWallet", () => ({
  useWallet: () => walletState,
}));

const baseTask = {
  code: "day1",
  title: "Day 1",
  description: "Read the guide",
  dayIndex: 0,
  rewardKind: "ticket",
  rewardValue: { amount: 1 },
  metadata: null,
  isActive: true,
  createdAt: "2024-05-24T00:00:00Z",
  updatedAt: "2024-05-24T00:00:00Z",
};

const baseAchievement = {
  achievement: {
    code: "starter",
    title: "Starter",
    description: "Finish the checklist",
    points: 10,
    metadata: null,
    isActive: true,
    createdAt: "2024-05-24T00:00:00Z",
    updatedAt: "2024-05-24T00:00:00Z",
  },
  unlocked: false,
  unlockedAt: null,
  progressValue: 0,
  metadata: null,
};

describe("ProgressPage", () => {
  beforeEach(() => {
    walletState.wallet.address = null;
    walletState.wallet.status = "disconnected";
    fetchChecklistMock.mockResolvedValue({ address: "", tasks: [] });
    fetchAchievementsMock.mockResolvedValue({ address: "", achievements: [] });
    completeChecklistMock.mockReset();
  });

  it("показывает подсказку без подключённого кошелька", async () => {
    renderWithProviders(<ProgressPage />);

    const hints = await screen.findAllByText(/Подключите кошелёк Supra/i);
    expect(hints.length).toBeGreaterThanOrEqual(1);
  });

  it("отображает чек-лист и позволяет отметить задание", async () => {
    walletState.wallet.address = "0xabc";
    walletState.wallet.status = "connected";
    fetchChecklistMock.mockResolvedValueOnce({
      address: "0xabc",
      tasks: [
        {
          task: baseTask,
          completed: false,
          completedAt: null,
          rewardClaimed: false,
          metadata: null,
        },
      ],
    });
    fetchAchievementsMock.mockResolvedValueOnce({
      address: "0xabc",
      achievements: [baseAchievement],
    });
    completeChecklistMock.mockResolvedValue({
      task: baseTask,
      completed: true,
      completedAt: "2024-05-24T02:00:00Z",
      rewardClaimed: true,
      metadata: { source: "ui" },
    });

    renderWithProviders(<ProgressPage />);

    expect(await screen.findByText(/Day 1/i)).toBeInTheDocument();
    expect(screen.getByText(/Starter/i)).toBeInTheDocument();

    const button = screen.getByRole("button", { name: /Отметить выполненным/i });
    fireEvent.click(button);

    await waitFor(() => {
      expect(completeChecklistMock).toHaveBeenCalledWith("0xabc", "day1", {
        metadata: { source: "ui" },
      });
    });
  });
});
