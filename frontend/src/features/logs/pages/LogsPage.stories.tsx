import type { Meta, StoryObj } from "@storybook/react-vite";
import { resetUiStore, useUiStore } from "../../../store/uiStore";
import { LogsPage } from "./LogsPage";

const baseDecorator = (Story: () => JSX.Element) => {
  resetUiStore();
  useUiStore.getState().setRole("admin");
  return <Story />;
};

const meta: Meta<typeof LogsPage> = {
  component: LogsPage,
  title: "Pages/LogsPage",
  decorators: [baseDecorator],
};

export default meta;

type Story = StoryObj<typeof LogsPage>;

export const Default: Story = {};

export const HideErrors: Story = {
  render: () => {
    resetUiStore();
    const store = useUiStore.getState();
    store.setRole("admin");
    store.toggleEventErrors();
    return <LogsPage />;
  },
};

export const Empty: Story = {
  parameters: {
    mockData: {
      events: "empty",
    },
  },
};

export const ErrorState: Story = {
  parameters: {
    reactQuery: {
      globalClient: {
        defaultOptions: {
          queries: {
            enabled: false,
            staleTime: 0,
          },
        },
      },
    },
  },
};
