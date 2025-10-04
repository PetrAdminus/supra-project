import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ShellLayout } from "./ShellLayout";
import { resetUiStore, useUiStore } from "../../store/uiStore";

vi.mock("../../features/wallet/useWallet", () => ({
  useWallet: () => ({
    wallet: { status: "disconnected", provider: "starkey" },
    error: null,
    connect: vi.fn(),
    disconnect: vi.fn(),
  }),
}));

function renderShell(path = "/") {
  const queryClient = new QueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[path]}>
        <ShellLayout>
          <div data-testid="layout-child">Child</div>
        </ShellLayout>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("ShellLayout", () => {
  const user = userEvent.setup();

  beforeEach(() => {
    act(() => resetUiStore());
  });

  afterEach(() => {
    act(() => resetUiStore());
  });

  it("скрывает ссылку Администрирование для роли user", () => {
    renderShell("/tickets");
    expect(screen.getByText("Билеты")).toHaveClass("nav-link--active", { exact: false });
    expect(screen.queryByText("Администрирование")).not.toBeInTheDocument();
  });

  it("показывает ссылку Администрирование после смены роли", async () => {
    renderShell();
    const roleSelect = screen.getByLabelText(/Роль/i);

    await act(async () => {
      await user.selectOptions(roleSelect, "admin");
    });

    expect(useUiStore.getState().role).toBe("admin");
    expect(screen.getByText("Администрирование")).toBeInTheDocument();
  });

  it("переключает режим API", async () => {
    renderShell();
    const modeSelect = screen.getByLabelText(/Режим/i);

    await act(async () => {
      await user.selectOptions(modeSelect, "supra");
    });

    expect(useUiStore.getState().apiMode).toBe("supra");
  });
});
