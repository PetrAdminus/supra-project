import { screen } from "@testing-library/react";
import type { TicketPurchase } from "../../../api/types";
import { TicketList } from "./TicketList";
import { renderWithProviders } from "../../../testing/renderWithProviders";

describe("TicketList", () => {
  const tickets: TicketPurchase[] = [
    {
      ticketId: "TICK-TEST-001",
      round: 42,
      numbers: [1, 2, 3, 4],
      purchaseTime: "2025-09-25T12:00:00Z",
      status: "confirmed",
      txHash: "0xabc",
    },
    {
      ticketId: "TICK-TEST-002",
      round: 43,
      numbers: [5, 6, 7, 8],
      purchaseTime: "2025-09-25T13:00:00Z",
      status: "pending",
      txHash: null,
    },
  ];

  it("показывает билеты и статусы", () => {
    renderWithProviders(<TicketList tickets={tickets} />);

    expect(screen.getByText("TICK-TEST-001")).toBeInTheDocument();
    expect(screen.getByText("Подтверждён")).toBeInTheDocument();
    expect(screen.getByText("TICK-TEST-002")).toBeInTheDocument();
    expect(screen.getByText("В обработке")).toBeInTheDocument();
  });

  it("отображает номера билета", () => {
    renderWithProviders(<TicketList tickets={tickets} />);

    expect(screen.getAllByText("2")).not.toHaveLength(0);
    expect(screen.getAllByText("7")).not.toHaveLength(0);
  });

  it("показывает заглушку, если Supra API не вернул номера", () => {
    const withoutNumbers: TicketPurchase[] = [
      {
        ticketId: "0xabc",
        round: 44,
        numbers: [],
        purchaseTime: "2025-09-25T14:00:00Z",
        status: "confirmed",
        txHash: null,
      },
    ];

    renderWithProviders(<TicketList tickets={withoutNumbers} />);

    expect(screen.getByText("Supra API пока не возвращает номера билетов.")).toBeInTheDocument();
  });
});
