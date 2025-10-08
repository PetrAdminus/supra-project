import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { UseQueryResult } from "@tanstack/react-query";
import { describe, expect, it, beforeEach, vi } from "vitest";
import type { LotteryEvent } from "../../../api/types";
import { resetUiStore } from "../../../store/uiStore";
import { LogsPage } from "./LogsPage";
import { useLotteryEvents } from "../hooks/useLotteryEvents";
import { renderWithProviders } from "../../../testing/renderWithProviders";

vi.mock("../hooks/useLotteryEvents");

const useLotteryEventsMock = vi.mocked(useLotteryEvents);

describe("LogsPage", () => {
  beforeEach(() => {
    resetUiStore();
    vi.resetAllMocks();
  });

  it("показывает состояние загрузки", () => {
    useLotteryEventsMock.mockReturnValue({
      data: undefined,
      isLoading: true,
      isError: false,
      error: null,
      status: "pending",
      fetchStatus: "fetching",
    } as unknown as UseQueryResult<LotteryEvent[]>);

    renderWithProviders(<LogsPage />);

    expect(screen.getByText("Загрузка событий...")).toBeInTheDocument();
  });

  it("отображает сообщение об ошибке", () => {
    useLotteryEventsMock.mockReturnValue({
      data: undefined,
      isLoading: false,
      isError: true,
      error: new Error("network"),
      status: "error",
      fetchStatus: "idle",
    } as unknown as UseQueryResult<LotteryEvent[]>);

    renderWithProviders(<LogsPage />);

    expect(screen.getByText("Не удалось получить журнал. Проверьте выбранный режим API.")).toBeInTheDocument();
  });

  it("фильтрует ошибки и показывает счётчик скрытых", async () => {
    const user = userEvent.setup();

    const events: LotteryEvent[] = [
      {
        eventId: "EVT-001",
        type: "TicketBought",
        round: 18,
        timestamp: "2025-09-24T09:10:00Z",
        details: "Ошибка транзакции",
        txHash: "0xeee555",
        status: "failed",
      },
      {
        eventId: "EVT-002",
        type: "DrawHandled",
        round: 17,
        timestamp: "2025-09-23T08:00:00Z",
        details: "Подтверждение результата",
        txHash: "0xaaa111",
        status: "success",
      },
    ];

    useLotteryEventsMock.mockReturnValue({
      data: events,
      isLoading: false,
      isError: false,
      error: null,
      status: "success",
      fetchStatus: "idle",
    } as unknown as UseQueryResult<LotteryEvent[]>);

    renderWithProviders(<LogsPage />);

    expect(screen.getByText("Скрывать ошибки")).toBeInTheDocument();
    expect(screen.getByText(/Ошибка транзакции/)).toBeInTheDocument();

    await user.click(screen.getByText("Скрывать ошибки"));

    expect(screen.getByText("Показывать ошибки")).toBeInTheDocument();
    expect(screen.queryByText(/Ошибка транзакции/)).not.toBeInTheDocument();
    expect(screen.getByText(/Ошибки скрыты \(1\)/)).toBeInTheDocument();
  });

  it("оставляет переключатель и подсказку, когда скрыты все события", async () => {
    const user = userEvent.setup();

    const events: LotteryEvent[] = [
      {
        eventId: "EVT-003",
        type: "TicketRefunded",
        round: 21,
        timestamp: "2025-09-25T11:30:00Z",
        details: "Неудачная транзакция",
        txHash: "0xbbbb22",
        status: "failed",
      },
    ];

    useLotteryEventsMock.mockReturnValue({
      data: events,
      isLoading: false,
      isError: false,
      error: null,
      status: "success",
      fetchStatus: "idle",
    } as unknown as UseQueryResult<LotteryEvent[]>);

    renderWithProviders(<LogsPage />);

    expect(screen.getByText("Скрывать ошибки")).toBeInTheDocument();
    expect(screen.getByText("Возврат билета")).toBeInTheDocument();

    await user.click(screen.getByText("Скрывать ошибки"));

    expect(screen.getByText("Показывать ошибки")).toBeInTheDocument();
    expect(screen.getByText(/Ошибки скрыты \(1\)/)).toBeInTheDocument();
    expect(screen.queryByText("Событий пока нет")).not.toBeInTheDocument();
  });

  it("показывает кэшированные события при ошибке загрузки", () => {
    const events: LotteryEvent[] = [
      {
        eventId: "EVT-010",
        type: "TicketBought",
        round: 12,
        timestamp: "2025-07-12T10:00:00Z",
        details: "Участник приобрёл билет",
        txHash: "0xfeed1",
        status: "success",
      },
    ];

    useLotteryEventsMock.mockReturnValue({
      data: events,
      isLoading: false,
      isError: true,
      error: new Error("network"),
      status: "error",
      fetchStatus: "idle",
    } as unknown as UseQueryResult<LotteryEvent[]>);

    renderWithProviders(<LogsPage />);

    expect(
      screen.getByText("Не удалось получить журнал. Проверьте выбранный режим API."),
    ).toBeInTheDocument();
    expect(screen.getByTestId("lottery-events-table")).toBeInTheDocument();
  });
});
