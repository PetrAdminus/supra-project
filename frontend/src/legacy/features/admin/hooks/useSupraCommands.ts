import { useQuery, type UseQueryOptions, type UseQueryResult } from "@tanstack/react-query";
import { listCommands } from "../../../api/client";
import type { SupraCommandInfo } from "../../../api/types";
import { useUiStore } from "../../../store/uiStore";

export const SUPRA_COMMANDS_QUERY_KEY = ["admin", "commands"] as const;

type QueryOptions = Pick<
  UseQueryOptions<SupraCommandInfo[]>,
  "enabled" | "staleTime" | "refetchInterval"
>;

export function useSupraCommands(options?: QueryOptions): UseQueryResult<SupraCommandInfo[]> {
  const apiMode = useUiStore((state) => state.apiMode);
  const enabled = apiMode === "supra" && (options?.enabled ?? true);

  return useQuery({
    queryKey: SUPRA_COMMANDS_QUERY_KEY,
    queryFn: listCommands,
    staleTime: options?.staleTime ?? 30_000,
    refetchInterval: enabled ? options?.refetchInterval ?? 30_000 : undefined,
    ...options,
    enabled,
  });
}
