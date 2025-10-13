import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { vi } from "vitest";
import { act } from "react";
import { TicketPurchaseForm } from "./TicketPurchaseForm";
import { resetUiStore, useUiStore } from "../../../store/uiStore";
import { renderWithProviders } from "../../../testing/renderWithProviders";

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
    act(() => {
      resetUiStore();
    });
  });

  it("показывает ошибку при пустом вводе", async () => {
    const user = userEvent.setup();
    renderWithProviders(<TicketPurchaseForm lotteryId={0} round={17} ticketPrice="5.000" />);

    const input = screen.getByLabelText("Номера билета");
    await user.clear(input);
    const button = screen.getByRole("button", { name: /Купить билет/i });
    await user.click(button);

    expect(screen.getByText(/Введите номера/i)).toBeInTheDocument();
    expect(mutateMock).not.toHaveBeenCalled();
  });

  it("отправляет корректные номера", async () => {
    const user = userEvent.setup();
    renderWithProviders(<TicketPurchaseForm lotteryId={1} round={18} ticketPrice="10.000" />);

    const input = screen.getByLabelText("Номера билета");
    await user.clear(input);
    await user.type(input, "1, 5, 9");
    const button = screen.getByRole("button", { name: /Купить билет/i });
    await user.click(button);

    expect(mutateMock).toHaveBeenCalledWith(
      { lotteryId: 1, round: 18, numbers: [1, 5, 9] },
      expect.objectContaining({ onSuccess: expect.any(Function) }),
    );
  });

  it("блокирует отправку в Supra-режиме", async () => {
    const user = userEvent.setup();
    act(() => {
      useUiStore.getState().setApiMode("supra");
    });

    renderWithProviders(<TicketPurchaseForm lotteryId={2} round={19} ticketPrice="10.000" />);

    const button = screen.getByRole("button", { name: /Supra отключено/i });
    expect(button).toBeDisabled();

    expect(screen.getByText(/Покупка билетов в Supra-режиме отключена/i)).toBeInTheDocument();

    await user.click(button);
    expect(mutateMock).not.toHaveBeenCalled();
  });
});
