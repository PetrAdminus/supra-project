import type { Meta, StoryObj } from '@storybook/react-vite';
import { EventTable } from './EventTable';

const meta: Meta<typeof EventTable> = {
  component: EventTable,
  title: 'Logs/EventTable',
};

export default meta;

type Story = StoryObj<typeof EventTable>;

const baseEvents = [
  {
    eventId: 'EVT-001',
    type: 'DrawRequested',
    round: 17,
    timestamp: '2025-09-22T14:00:00Z',
    details: 'Запрошена случайность для розыгрыша 17',
    txHash: '0xaaa111',
    status: 'success' as const,
  },
  {
    eventId: 'EVT-002',
    type: 'TicketBought',
    round: 18,
    timestamp: '2025-09-24T09:10:00Z',
    details: 'Ошибка транзакции: недостаточно средств',
    txHash: '0xeee555',
    status: 'failed' as const,
  },
  {
    eventId: 'EVT-003',
    type: 'DrawRequested',
    round: 18,
    timestamp: '2025-09-24T09:05:00Z',
    details: 'Повторный запрос из-за превышения timeout',
    txHash: '0xddd444',
    status: 'retry' as const,
  },
];

export const Default: Story = {
  args: {
    events: baseEvents,
  },
};

export const Empty: Story = {
  args: {
    events: [],
  },
};
