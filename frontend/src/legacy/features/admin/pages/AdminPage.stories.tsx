import type { Meta, StoryObj } from "@storybook/react-vite";
import { resetUiStore, useUiStore } from "../../../store/uiStore";
import { AdminPage } from "./AdminPage";

type StoryRender = () => JSX.Element;

const withRoleAdmin = (Story: StoryRender) => {
  resetUiStore();
  useUiStore.getState().setRole("admin");
  return <Story />;
};

const meta: Meta<typeof AdminPage> = {
  component: AdminPage,
  title: "Pages/AdminPage",
  decorators: [withRoleAdmin],
};

export default meta;

type Story = StoryObj<typeof AdminPage>;

export const Default: Story = {};

export const Whitelisted: Story = {
  parameters: {
    mockData: {
      whitelistStatus: "whitelisted",
    },
  },
};

export const Loading: Story = {
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

export const ErrorState: Story = {
  parameters: {
    mockError: "whitelistStatus",
  },
};

export const UserRole: Story = {
  decorators: [
    (Story: StoryRender) => {
      resetUiStore();
      useUiStore.getState().setRole("user");
      return <Story />;
    },
  ],
};