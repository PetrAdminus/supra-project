import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AdminPage } from "./AdminPage";
import { resetUiStore, useUiStore } from "../../../store/uiStore";

vi.mock("../hooks/useWhitelistStatus", () => ({
  useWhitelistStatus: () => ({
    data: {
      profile: "lottery_v3",
      account: "0xaccount",
      isWhitelisted: true,
      checkedAt: "2025-09-25T10:00:00Z",
    },
    isLoading: false,
    error: null,
  }),
}));

vi.mock("../hooks/useAdminConfig", () => ({
  useAdminConfig: () => ({
    data: {
      gas: {
        maxGasFee: 200000,
        minBalance: 6000000,
        updatedAt: "2025-09-21T12:00:00Z",
      },
      vrf: {
        maxGasPrice: "100",
        maxGasLimit: "200000",
        callbackGasPrice: "10",
        callbackGasLimit: "50000",
        requestedRngCount: 1,
        clientSeed: 42,
        lastConfiguredAt: "2025-09-22T10:30:00Z",
      },
      whitelist: {
        clientConfigured: true,
        consumerConfigured: false,
        client: {
          maxGasPrice: "100",
          maxGasLimit: "200000",
          minBalanceLimit: "5000000000",
          updatedAt: "2025-09-20T09:00:00Z",
        },
        consumer: null,
      },
    },
    isLoading: false,
    error: null,
  }),
}));

const renderPage = () => {
  const queryClient = new QueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      <AdminPage />
    </QueryClientProvider>,
  );
};

describe("AdminPage", () => {
  it("renders access guard for non-admin role", () => {
    resetUiStore();
    useUiStore.getState().setRole("user");

    renderPage();

    expect(screen.getByText(/Доступ ограничен/)).toBeInTheDocument();
    expect(screen.queryByText(/Статус whitelisting/)).not.toBeInTheDocument();
  });

  it("shows whitelisting summary and forms for admin", () => {
    resetUiStore();
    useUiStore.getState().setRole("admin");

    renderPage();

    expect(screen.getByText(/Статус whitelisting/)).toBeInTheDocument();
    expect(screen.getByText(/Профиль: lottery_v3/)).toBeInTheDocument();
    expect(screen.getByLabelText(/Max gas fee/)).toHaveValue(200000);
    expect(screen.getAllByLabelText(/Callback gas price/)[0]).toHaveValue("10");
  });
});
