import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { act } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ChatPanel } from "./ChatPanel";
import { renderWithProviders } from "../../../testing/renderWithProviders";
import { resetUiStore } from "../../../store/uiStore";
import type { Announcement, ChatMessage } from "../../../api/types";
import { fetchAnnouncements, fetchChatMessages, postChatMessage } from "../../../api/client";
import { useWallet } from "../../wallet/useWallet";

vi.mock("../../../api/client", () => ({
  fetchChatMessages: vi.fn<(
    room?: string,
    limit?: number,
  ) => Promise<ChatMessage[]>>().mockResolvedValue([]),
  fetchAnnouncements: vi.fn<(
    limit?: number,
    lotteryId?: string | null,
  ) => Promise<Announcement[]>>().mockResolvedValue([]),
  postChatMessage: vi
    .fn<(input: { address: string; body: string; room?: string | null }) => Promise<ChatMessage>>()
    .mockResolvedValue({
      id: 999,
      room: "global",
      senderAddress: "0xabc",
      body: "ok",
      metadata: {},
      createdAt: new Date().toISOString(),
    }),
  postAnnouncement: vi.fn(),
}));

vi.mock("../../wallet/useWallet", () => ({
  useWallet: vi.fn(),
}));

describe("ChatPanel", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    act(() => {
      resetUiStore();
    });
  });

  it("показывает объявления и сообщения из API", async () => {
    vi.mocked(fetchChatMessages).mockResolvedValueOnce([
      {
        id: 1,
        room: "global",
        senderAddress: "0x123456",
        body: "Привет из теста",
        metadata: {},
        createdAt: "2024-05-24T10:00:00Z",
      },
    ]);
    vi.mocked(fetchAnnouncements).mockResolvedValueOnce([
      {
        id: 7,
        title: "Анонс",
        body: "Сегодня запускаем быстрые розыгрыши",
        lotteryId: "speed",
        metadata: {},
        createdAt: "2024-05-24T09:00:00Z",
      },
    ]);
    vi.mocked(useWallet).mockReturnValue({
      wallet: { address: null },
    });

    renderWithProviders(<ChatPanel room="global" lotteryId={7} />);

    expect(await screen.findByText(/Анонс/)).toBeInTheDocument();
    expect(await screen.findByText(/Привет из теста/)).toBeInTheDocument();
    const button = await screen.findByRole("button", { name: /Отправить/ });
    expect(button).toBeDisabled();
  });

  it("отправляет сообщение при подключенном кошельке", async () => {
    vi.mocked(fetchChatMessages).mockResolvedValueOnce([]);
    vi.mocked(fetchAnnouncements).mockResolvedValueOnce([]);
    vi.mocked(useWallet).mockReturnValue({
      wallet: { address: "0xABCDEF", provider: "starkey" },
    });

    const user = userEvent.setup();
    renderWithProviders(<ChatPanel room="global" lotteryId={null} />);

    const input = await screen.findByLabelText(/Напишите сообщение/);
    await user.type(input, "Тест");
    const button = await screen.findByRole("button", { name: /Отправить/ });
    await user.click(button);

    expect(postChatMessage).toHaveBeenCalledWith({ address: "0xABCDEF", body: "Тест", room: "global" });
  });
});
