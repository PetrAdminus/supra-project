import type { Meta, StoryObj } from "@storybook/react-vite";
import { within, userEvent } from "@storybook/testing-library";
import { WalletPanel } from "./WalletPanel";
import { resetUiStore, useUiStore } from "../../store/uiStore";
import { translate } from "../../i18n/messages";
import { resetWallet } from "./walletSupra";

class StorybookStarKeyProvider {
  private accounts = ["0xFAKE...STORYBOOK"];
  private listeners = new Map<string, Set<(...args: unknown[]) => void>>();
  public walletMeta = { name: "Storybook StarKey" };
  public isStarKey = true;

  async request({ method }: { method: string }): Promise<unknown> {
    switch (method) {
      case "eth_requestAccounts":
      case "eth_accounts":
        return this.accounts;
      case "eth_chainId":
        return "0x1a4"; // Supra testnet (decimal 420)
      default:
        return null;
    }
  }

  on(event: string, listener: (...args: unknown[]) => void) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(listener);
  }

  removeListener(event: string, listener: (...args: unknown[]) => void) {
    this.listeners.get(event)?.delete(listener);
  }
}

const ensureStorybookStarKey = () => {
  if (typeof window === "undefined") {
    return;
  }

  const globalAny = window as unknown as { starKey?: { provider: unknown } };
  if (!globalAny.starKey) {
    globalAny.starKey = { provider: new StorybookStarKeyProvider() };
  }

  resetWallet();
};

const escapeForRegExp = (value: string): string => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const withSupraMode = (Story: () => JSX.Element) => {
  resetUiStore();
  useUiStore.getState().setApiMode("supra");
  ensureStorybookStarKey();
  return <Story />;
};

const meta: Meta<typeof WalletPanel> = {
  component: WalletPanel,
  title: "Wallet/WalletPanel",
  decorators: [withSupraMode],
};

export default meta;

type Story = StoryObj<typeof WalletPanel>;

export const Default: Story = {};

export const Connected: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const locale = useUiStore.getState().locale;
    const label = translate(locale, "wallet.connect");
    const connectButton = await canvas.findByRole("button", {
      name: new RegExp(escapeForRegExp(label), "i"),
    });
    await userEvent.click(connectButton);
  },
};

