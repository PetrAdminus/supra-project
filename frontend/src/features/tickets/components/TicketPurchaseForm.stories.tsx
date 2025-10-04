import type { Meta, StoryObj } from '@storybook/react-vite';
import { within, userEvent } from '@storybook/testing-library';
import { TicketPurchaseForm } from './TicketPurchaseForm';

const meta: Meta<typeof TicketPurchaseForm> = {
  component: TicketPurchaseForm,
  title: 'Tickets/TicketPurchaseForm',
  args: {
    round: 18,
    ticketPrice: '5.000',
  },
};

export default meta;

type Story = StoryObj<typeof TicketPurchaseForm>;

export const Default: Story = {};

export const FilledAndSubmitted: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const input = await canvas.findByLabelText('Числа билета');
    await userEvent.clear(input);
    await userEvent.type(input, '1, 8, 19, 27');
    const button = await canvas.findByRole('button', { name: /Купить билет/i });
    await userEvent.click(button);
  },
};
