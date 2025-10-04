import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { fetchAdminConfig } from '../../../api/client';
import type { AdminConfig } from '../../../api/types';

export const ADMIN_CONFIG_QUERY_KEY = ['admin', 'config'] as const;

export function useAdminConfig(
  options?: Pick<UseQueryOptions<AdminConfig>, 'enabled' | 'staleTime' | 'refetchInterval'>,
): UseQueryResult<AdminConfig> {
  return useQuery({
    queryKey: ADMIN_CONFIG_QUERY_KEY,
    queryFn: fetchAdminConfig,
    staleTime: 30_000,
    refetchInterval: 30_000,
    ...options,
  });
}
