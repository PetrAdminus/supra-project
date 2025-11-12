import {
  useQuery,
  type UseQueryOptions,
  type UseQueryResult,
} from "@tanstack/react-query";

import { fetchLotteryMultiViews } from "../../../api/client";
import type {
  LotteryMultiViews,
  LotteryMultiViewsOptions,
} from "../../../api/types";

type QueryOptionKeys = "enabled" | "staleTime" | "refetchInterval";

const QUERY_KEY_PREFIX = ["lottery", "multi", "views"] as const;

function buildQueryKey(options?: LotteryMultiViewsOptions) {
  return [
    ...QUERY_KEY_PREFIX,
    options?.nowTs ?? null,
    options?.limit ?? null,
    options?.primaryType ?? null,
    options?.tagMask ?? null,
  ] as const;
}

export function useLotteryMultiViews(
  options?: LotteryMultiViewsOptions,
  queryOptions?: Pick<UseQueryOptions<LotteryMultiViews>, QueryOptionKeys>,
): UseQueryResult<LotteryMultiViews> {
  return useQuery({
    queryKey: buildQueryKey(options),
    queryFn: () => fetchLotteryMultiViews(options),
    staleTime: 30_000,
    refetchInterval: 30_000,
    ...queryOptions,
  });
}
