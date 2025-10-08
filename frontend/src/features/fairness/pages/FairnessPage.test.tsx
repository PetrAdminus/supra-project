import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, beforeEach } from "vitest";
import { act } from "react";
import { FairnessPage } from "./FairnessPage";
import { renderWithProviders } from "../../../testing/renderWithProviders";
import { resetUiStore } from "../../../store/uiStore";

describe("FairnessPage", () => {
  beforeEach(() => {
    act(() => {
      resetUiStore();
    });
  });

  it("отображает данные VRF из mock API", async () => {
    renderWithProviders(<FairnessPage />);

    expect(await screen.findByText(/Панель честности/)).toBeInTheDocument();
    expect(await screen.findByText(/Снепшот раунда/)).toBeInTheDocument();
    expect(await screen.findByText(/Запросы VRF-хаба/)).toBeInTheDocument();
    const events = await screen.findAllByText(/lottery::DrawRequestIssuedEvent/);
    expect(events.length).toBeGreaterThan(0);
  });

  it("позволяет фильтровать события по поиску и типу", async () => {
    const user = userEvent.setup();
    renderWithProviders(<FairnessPage />);

    const searchInput = await screen.findByLabelText(/Поиск/);
    await user.type(searchInput, "RandomnessRequested");

    const hubRequestsHeading = await screen.findByRole("heading", { name: /Запросы VRF-хаба/ });
    const hubRequestsSection = hubRequestsHeading.closest("section");
    expect(hubRequestsSection).not.toBeNull();
    expect(within(hubRequestsSection as HTMLElement).getAllByRole("listitem")).toHaveLength(1);

    const roundRequestsHeading = screen.getByRole("heading", { name: /Запросы случайности/ });
    const roundRequestsSection = roundRequestsHeading.closest("section");
    expect(roundRequestsSection).not.toBeNull();
    expect(
      within(roundRequestsSection as HTMLElement).getByText(/Событий пока нет\./),
    ).toBeInTheDocument();
    expect(
      within(hubRequestsSection as HTMLElement).queryByText(/lottery::DrawRequestIssuedEvent/),
    ).not.toBeInTheDocument();

    const resetButton = screen.getByRole("button", { name: /Очистить поиск/ });
    await user.click(resetButton);
    expect(searchInput).toHaveValue("");
    expect(within(roundRequestsSection as HTMLElement).getAllByRole("listitem")).toHaveLength(2);

    const eventTypeSelect = screen.getByLabelText(/Тип события/);
    await user.selectOptions(eventTypeSelect, "lottery::DrawFulfilledEvent");

    const roundFulfillmentsHeading = screen.getByRole("heading", { name: /Завершения раунда/ });
    const roundFulfillmentsSection = roundFulfillmentsHeading.closest("section");
    expect(roundFulfillmentsSection).not.toBeNull();
    expect(
      within(roundFulfillmentsSection as HTMLElement).getAllByRole("listitem"),
    ).toHaveLength(2);
    expect(within(hubRequestsSection as HTMLElement).queryByRole("listitem")).toBeNull();
  });
});
