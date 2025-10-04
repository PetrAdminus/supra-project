import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { fetchLotteryStatus } from '../../../api/client';
import type { LotteryStatus } from '../../../api/types';

const QUERY_KEY = ['lottery', 'status'] as const;

export function useLotteryStatus(
  options?: Pick<UseQueryOptions<LotteryStatus>, 'enabled' | 'staleTime' | 'refetchInterval'>,
): UseQueryResult<LotteryStatus> {
  return useQuery({
    queryKey: QUERY_KEY,
    queryFn: fetchLotteryStatus,
    staleTime: 30_000,
    refetchInterval: 30_000,
    ...options,
  });
}
