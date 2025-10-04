import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { vi } from "vitest";
import { TicketPurchaseForm } from "./TicketPurchaseForm";

const mutateMock = vi.fn();

vi.mock("../hooks/usePurchaseTicket", () => ({
  usePurchaseTicket: () => ({
    mutate: mutateMock,
    isPending: false,
    isError: false,
    isSuccess: false,
    data: undefined,
    error: undefined,
  }),
}));

describe("TicketPurchaseForm", () => {
  beforeEach(() => {
    mutateMock.mockReset();
  });

  it("показывает ошибку при пустом вводе", async () => {
    const user = userEvent.setup();
    render(<TicketPurchaseForm round={17} ticketPrice="5.000" />);

    const input = screen.getByLabelText("Номера билета");
    await user.clear(input);
    const button = screen.getByRole("button", { name: /Купить билет/i });
    await user.click(button);

    expect(screen.getByText(/Введите номера/i)).toBeInTheDocument();
    expect(mutateMock).not.toHaveBeenCalled();
  });

  it("отправляет корректные номера", async () => {
    const user = userEvent.setup();
    render(<TicketPurchaseForm round={18} ticketPrice="10.000" />);

    const input = screen.getByLabelText("Номера билета");
    await user.clear(input);
    await user.type(input, "1, 5, 9");
    const button = screen.getByRole("button", { name: /Купить билет/i });
    await user.click(button);

    expect(mutateMock).toHaveBeenCalledWith(
      { round: 18, numbers: [1, 5, 9] },
      expect.objectContaining({ onSuccess: expect.any(Function) }),
    );
  });
});
