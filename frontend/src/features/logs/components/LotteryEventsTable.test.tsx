import { render, screen } from "@testing-library/react";
import { describe, expect, it, beforeEach } from "vitest";
import type { LotteryEvent } from "../../../api/types";
import { resetUiStore } from "../../../store/uiStore";
import { LotteryEventsTable } from "./LotteryEventsTable";

describe("LotteryEventsTable", () => {
  beforeEach(() => {
    resetUiStore();
  });

  const events: LotteryEvent[] = [
    {
      eventId: "EVT-001",
      type: "TicketBought",
      round: 18,
      timestamp: "2025-09-24T09:10:00Z",
      details: "Ошибка транзакции: недостаточно средств",
      txHash: "0xeee555",
      status: "failed",
    },
    {
      eventId: "EVT-002",
      type: "DrawHandled",
      round: 17,
      timestamp: "2025-09-23T08:00:00Z",
      details: "Результат подтверждён",
      txHash: "0xaaa111",
      status: "success",
    },
    {
      eventId: "EVT-003",
      type: "TicketRefunded",
      round: 17,
      timestamp: "2025-09-23T10:15:00Z",
      details: "Возврат средств",
      txHash: "0xccc222",
      status: "retry",
    },
  ];

  it("отображает строки таблицы с типом и статусом", () => {
    render(<LotteryEventsTable events={events} />);

    expect(screen.getByText("Покупка билета")).toBeInTheDocument();
    expect(screen.getByText("Результат обработан")).toBeInTheDocument();
    expect(screen.getByText("Возврат билета")).toBeInTheDocument();
    expect(screen.getAllByText("Ошибка")).toHaveLength(1);
    expect(screen.getAllByText("Успех")).toHaveLength(1);
    expect(screen.getAllByText("Повтор")).toHaveLength(1);
  });

  it("показывает детали и хеш транзакции", () => {
    render(<LotteryEventsTable events={events} />);

    expect(screen.getByText(/недостаточно средств/i)).toBeInTheDocument();
    expect(screen.getByText("0xeee555")).toBeInTheDocument();
    expect(screen.getByText("0xccc222")).toBeInTheDocument();
  });

  it("добавляет подписи data-label для мобильного представления", () => {
    render(<LotteryEventsTable events={events} />);

    const eventCell = screen.getByText("Покупка билета").closest("td");
    const roundCell = screen.getByText("18").closest("td");
    const statusCell = screen.getByText("Ошибка").closest("td");

    expect(eventCell).toHaveAttribute("data-label", "Событие");
    expect(roundCell).toHaveAttribute("data-label", "Раунд");
    expect(statusCell).toHaveAttribute("data-label", "Статус");
  });
});
