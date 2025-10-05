import type { Meta, StoryObj } from "@storybook/react-vite";
import { within, userEvent } from "@storybook/testing-library";
import { WalletPanel } from "./WalletPanel";
import { resetUiStore, useUiStore } from "../../store/uiStore";
import { translate } from "../../i18n/messages";

const escapeForRegExp = (value: string): string => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const withSupraMode = (Story: () => JSX.Element) => {
  resetUiStore();
  useUiStore.getState().setApiMode("supra");
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

