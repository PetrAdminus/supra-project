import { useQuery, type UseQueryOptions, type UseQueryResult } from "@tanstack/react-query";
import { fetchLotteryEvents } from "../../../api/client";
import type { LotteryEvent } from "../../../api/types";

const QUERY_KEY = ["lottery", "events"] as const;

export function useLotteryEvents(
  options?: Pick<UseQueryOptions<LotteryEvent[]>, "enabled" | "staleTime" | "refetchInterval">,
): UseQueryResult<LotteryEvent[]> {
  return useQuery({
    queryKey: QUERY_KEY,
    queryFn: fetchLotteryEvents,
    staleTime: 15_000,
    refetchInterval: 60_000,
    ...options,
  });
}
