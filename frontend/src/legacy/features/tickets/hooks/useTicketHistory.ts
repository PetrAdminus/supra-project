import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { fetchTickets } from '../../../api/client';
import type { TicketPurchase } from '../../../api/types';

const QUERY_KEY = ['lottery', 'tickets'] as const;

export function useTicketHistory(
  options?: Pick<UseQueryOptions<TicketPurchase[]>, 'enabled' | 'staleTime' | 'refetchInterval'>,
): UseQueryResult<TicketPurchase[]> {
  return useQuery({
    queryKey: QUERY_KEY,
    queryFn: fetchTickets,
    staleTime: 30_000,
    refetchInterval: 60_000,
    ...options,
  });
}
