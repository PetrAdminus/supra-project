import type { Meta, StoryObj } from '@storybook/react-vite';
import { TicketList } from './TicketList';
import type { TicketPurchase } from '../../../api/types';

const sampleTickets: TicketPurchase[] = [
  {
    ticketId: 'TICK-17-001',
    round: 17,
    numbers: [7, 11, 23, 45],
    purchaseTime: '2025-09-22T11:10:00Z',
    status: 'confirmed',
    txHash: '0x123',
  },
  {
    ticketId: 'TICK-17-002',
    round: 17,
    numbers: [3, 9, 15, 27],
    purchaseTime: '2025-09-22T12:05:00Z',
    status: 'pending',
    txHash: '0x456',
  },
  {
    ticketId: 'TICK-16-003',
    round: 16,
    numbers: [5, 19, 31, 40],
    purchaseTime: '2025-09-15T10:15:00Z',
    status: 'won',
    txHash: '0x789',
  },
];

const meta: Meta<typeof TicketList> = {
  component: TicketList,
  title: 'Tickets/TicketList',
  args: {
    tickets: sampleTickets,
  },
};

export default meta;

type Story = StoryObj<typeof TicketList>;

export const Default: Story = {};

export const EmptyList: Story = {
  args: {
    tickets: [],
  },
};
