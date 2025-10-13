import type { Meta, StoryObj } from "@storybook/react-vite";
import { within, userEvent } from "@storybook/testing-library";
import { TicketPurchaseForm } from "./TicketPurchaseForm";
import { useUiStore } from "../../../store/uiStore";
import { translate } from "../../../i18n/messages";

const escapeForRegExp = (value: string): string => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const meta: Meta<typeof TicketPurchaseForm> = {
  component: TicketPurchaseForm,
  title: "Tickets/TicketPurchaseForm",
  args: {
    round: 18,
    ticketPrice: "5.000",
  },
};

export default meta;

type Story = StoryObj<typeof TicketPurchaseForm>;

export const Default: Story = {};

export const FilledAndSubmitted: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const locale = useUiStore.getState().locale;
    const numbersLabel = translate(locale, "tickets.form.label");
    const submitLabel = translate(locale, "tickets.form.submit");

    const input = await canvas.findByLabelText(new RegExp(escapeForRegExp(numbersLabel), "i"));
    await userEvent.clear(input);
    await userEvent.type(input, "1, 8, 19, 27");

    const button = await canvas.findByRole("button", {
      name: new RegExp(escapeForRegExp(submitLabel), "i"),
    });
    await userEvent.click(button);
  },
};

