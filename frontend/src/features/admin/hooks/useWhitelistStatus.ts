import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { fetchWhitelistStatus } from '../../../api/client';
import type { WhitelistStatus } from '../../../api/types';

export const WHITELIST_STATUS_QUERY_KEY = ['vrf', 'whitelist-status'] as const;

export function useWhitelistStatus(
  options?: Pick<UseQueryOptions<WhitelistStatus>, 'enabled' | 'staleTime' | 'refetchInterval'>,
): UseQueryResult<WhitelistStatus> {
  return useQuery({
    queryKey: WHITELIST_STATUS_QUERY_KEY,
    queryFn: fetchWhitelistStatus,
    staleTime: 60_000,
    refetchInterval: 60_000,
    ...options,
  });
}
