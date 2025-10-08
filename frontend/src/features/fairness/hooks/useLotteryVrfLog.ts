import { useQuery, type UseQueryOptions, type UseQueryResult } from "@tanstack/react-query";
import { fetchLotteryVrfLog } from "../../../api/client";
import type { LotteryVrfLog } from "../../../api/types";

const QUERY_KEY = ["lottery", "vrf-log"] as const;

export function useLotteryVrfLog(
  lotteryId: number | null,
  limit: number,
  options?: Pick<UseQueryOptions<LotteryVrfLog>, "enabled" | "staleTime" | "refetchInterval">,
): UseQueryResult<LotteryVrfLog> {
  const queryEnabled = lotteryId !== null && (options?.enabled ?? true);

  return useQuery({
    queryKey: [...QUERY_KEY, lotteryId, limit],
    queryFn: () => {
      if (lotteryId === null) {
        throw new Error("lotteryId is required");
      }
      return fetchLotteryVrfLog(lotteryId, limit);
    },
    staleTime: 60_000,
    refetchInterval: 120_000,
    keepPreviousData: true,
    ...options,
    enabled: queryEnabled,
  });
}
