import { render, screen } from "@testing-library/react";
import { EventTable } from "./EventTable";

const events = [
  {
    eventId: "EVT-1",
    type: "DrawRequested" as const,
    round: 20,
    timestamp: "2025-09-24T09:00:00Z",
    details: "Создан запрос",
    txHash: "0xabc",
    status: "retry" as const,
  },
  {
    eventId: "EVT-2",
    type: "TicketBought" as const,
    round: 20,
    timestamp: "2025-09-24T10:00:00Z",
    details: "Покупка тестового билета",
    txHash: "0xdef",
    status: "failed" as const,
  },
];

describe("EventTable", () => {
  it("отображает события", () => {
    render(<EventTable events={events} />);

    expect(screen.getByText("Покупка билета")).toBeInTheDocument();
    expect(screen.getByText("Ошибка")).toBeInTheDocument();
  });

  it("показывает время и описание", () => {
    render(<EventTable events={events} />);

    expect(screen.getByText("Создан запрос")).toBeInTheDocument();
    expect(screen.getByText("Покупка тестового билета")).toBeInTheDocument();
  });
});
