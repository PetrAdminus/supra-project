import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { WalletPanel } from "./WalletPanel";
import { resetUiStore, useUiStore } from "../../store/uiStore";
import type { WalletInfo } from "./walletSupra";

const connectMock = vi.fn(() => Promise.resolve());
const disconnectMock = vi.fn(() => Promise.resolve());
const changeProviderMock = vi.fn();
const copyAddressMock = vi.fn(() => Promise.resolve(true));
const clearErrorMock = vi.fn();

const useWalletMock = vi.fn();

vi.mock("./useWallet", () => ({
  useWallet: () => useWalletMock(),
}));

const user = userEvent.setup();

describe("WalletPanel", () => {
  const baseWallet: WalletInfo = {
    status: "disconnected",
    provider: "starkey",
    providerLabel: "StarKey",
    providerReady: true,
  };

  beforeEach(() => {
    resetUiStore();
    connectMock.mockClear();
    disconnectMock.mockClear();
    changeProviderMock.mockClear();
    copyAddressMock.mockClear();
    clearErrorMock.mockClear();
    useWalletMock.mockReturnValue({
      wallet: baseWallet,
      error: null,
      connect: connectMock,
      disconnect: disconnectMock,
      changeProvider: changeProviderMock,
      copyAddress: copyAddressMock,
      clearError: clearErrorMock,
    });
  });

  it("disables connect when Supra mode is inactive", async () => {
    useUiStore.getState().setApiMode("mock");

    render(<WalletPanel />);

    const connectButton = screen.getByTestId("wallet-connect-button");
    expect(connectButton).toBeDisabled();
  });

  it("allows connection in Supra mode", async () => {
    useUiStore.getState().setApiMode("supra");

    render(<WalletPanel />);

    const connectButton = screen.getByTestId("wallet-connect-button");
    expect(connectButton).toBeEnabled();
    await user.click(connectButton);
    expect(connectMock).toHaveBeenCalled();
  });

  it("renders address and copy action when connected", async () => {
    useUiStore.getState().setApiMode("supra");
    useWalletMock.mockReturnValue({
      wallet: {
        status: "connected",
        provider: "starkey",
        providerLabel: "StarKey",
        providerReady: true,
        address: "0x1234",
        lastConnectedAt: "2025-09-25T10:00:00Z",
      },
      error: null,
      connect: connectMock,
      disconnect: disconnectMock,
      changeProvider: changeProviderMock,
      copyAddress: copyAddressMock,
      clearError: clearErrorMock,
    });

    render(<WalletPanel />);

    expect(screen.getByText(/0x1234/)).toBeInTheDocument();
    const copyButton = screen.getByTestId("wallet-copy-button");
    await user.click(copyButton);
    expect(copyAddressMock).toHaveBeenCalled();
  });
});
