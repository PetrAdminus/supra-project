import type { Meta, StoryObj } from "@storybook/react-vite";
import { resetUiStore, useUiStore } from "../../../store/uiStore";
import { DashboardPage } from "./DashboardPage";

const baseDecorator = (Story: () => JSX.Element) => {
  resetUiStore();
  useUiStore.getState().setRole("admin");
  return <Story />;
};

const meta: Meta<typeof DashboardPage> = {
  component: DashboardPage,
  title: "Pages/DashboardPage",
  decorators: [baseDecorator],
};

export default meta;

type Story = StoryObj<typeof DashboardPage>;

export const Default: Story = {};

export const EmptyState: Story = {
  parameters: {
    mockData: {
      lotteryStatus: "round19-empty",
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