import type { Meta, StoryObj } from "@storybook/react-vite";
import { resetUiStore, useUiStore } from "../../../store/uiStore";
import { TicketsPage } from "./TicketsPage";

const baseDecorator = (Story: () => JSX.Element) => {
  resetUiStore();
  useUiStore.getState().setRole("user");
  return <Story />;
};

const meta: Meta<typeof TicketsPage> = {
  component: TicketsPage,
  title: "Pages/TicketsPage",
  decorators: [baseDecorator],
};

export default meta;

type Story = StoryObj<typeof TicketsPage>;

export const Default: Story = {};

export const NoTickets: Story = {
  parameters: {
    mockData: {
      tickets: "round19-empty",
    },
  },
};

export const SupraMode: Story = {
  render: () => {
    resetUiStore();
    const store = useUiStore.getState();
    store.setApiMode("supra");
    store.setRole("user");
    return <TicketsPage />;
  },
};