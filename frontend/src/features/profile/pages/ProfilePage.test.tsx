import { fireEvent, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderWithProviders } from "../../../testing/renderWithProviders";
import { ProfilePage } from "./ProfilePage";

const fetchAccountProfileMock = vi.fn();
const upsertAccountProfileMock = vi.fn();

vi.mock("../../../api/client", () => ({
  fetchAccountProfile: (...args: unknown[]) => fetchAccountProfileMock(...args),
  upsertAccountProfile: (...args: unknown[]) => upsertAccountProfileMock(...args),
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

const baseProfile = {
  address: "0xabc",
  nickname: "Player",
  avatar: { kind: "external", value: "ipfs://hash" },
  telegram: "@player",
  twitter: "player",
  settings: { theme: "dark" },
  createdAt: "2024-05-24T00:00:00Z",
  updatedAt: "2024-05-25T00:00:00Z",
};

describe("ProfilePage", () => {
  beforeEach(() => {
    walletState.wallet.address = null;
    walletState.wallet.status = "disconnected";
    fetchAccountProfileMock.mockReset();
    upsertAccountProfileMock.mockReset();
  });

  it("показывает подсказку без подключённого кошелька", async () => {
    renderWithProviders(<ProfilePage />);

    expect(await screen.findByText(/Подключите Supra-кошелёк/i)).toBeInTheDocument();
    expect(fetchAccountProfileMock).not.toHaveBeenCalled();
  });

  it("загружает и обновляет профиль пользователя", async () => {
    walletState.wallet.address = "0xAbC";
    walletState.wallet.status = "connected";
    fetchAccountProfileMock.mockResolvedValueOnce(baseProfile);

    const updatedProfile = {
      ...baseProfile,
      nickname: "Игрок",
      avatar: { kind: "crystara", value: "nft-777" },
      telegram: "@new_player",
      settings: { autoBuy: true },
      updatedAt: "2024-05-26T00:00:00Z",
    };
    upsertAccountProfileMock.mockResolvedValue(updatedProfile);

    renderWithProviders(<ProfilePage />);

    const nicknameInput = await screen.findByLabelText(/Никнейм/i);
    expect(nicknameInput).toHaveValue("Player");

    fireEvent.change(nicknameInput, { target: { value: " Игрок " } });
    fireEvent.change(screen.getByLabelText(/Telegram/i), { target: { value: "@new_player" } });
    fireEvent.change(screen.getByLabelText(/Тип аватара/i), { target: { value: "crystara" } });

    const avatarValueInput = screen.getByLabelText(/Идентификатор аватара/i);
    fireEvent.change(avatarValueInput, { target: { value: " nft-777 " } });

    const settingsArea = screen.getByLabelText(/Дополнительные настройки/i);
    fireEvent.change(settingsArea, { target: { value: '{"autoBuy": true}' } });

    const submitButton = screen.getByRole("button", { name: /Сохранить профиль/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(upsertAccountProfileMock).toHaveBeenCalledWith("0xabc", {
        nickname: "Игрок",
        telegram: "@new_player",
        twitter: "player",
        settings: { autoBuy: true },
        avatar: { kind: "crystara", value: "nft-777" },
      });
    });

    expect(await screen.findByText(/Профиль обновлён/i)).toBeInTheDocument();
  });

  it("отображает ошибку при некорректном JSON настроек", async () => {
    walletState.wallet.address = "0xabc";
    walletState.wallet.status = "connected";
    fetchAccountProfileMock.mockResolvedValueOnce(baseProfile);

    renderWithProviders(<ProfilePage />);

    const settingsArea = await screen.findByLabelText(/Дополнительные настройки/i);
    fireEvent.change(settingsArea, { target: { value: '{"invalid"' } });

    const submitButton = screen.getByRole("button", { name: /Сохранить профиль/i });
    fireEvent.click(submitButton);

    expect(await screen.findByText(/Введите корректный JSON/i)).toBeInTheDocument();
    expect(upsertAccountProfileMock).not.toHaveBeenCalled();
  });
});
