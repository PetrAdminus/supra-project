import { useEffect } from "react";
import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseMutationResult,
  type UseQueryResult,
} from "@tanstack/react-query";
import {
  fetchAnnouncements,
  fetchChatMessages,
  postAnnouncement,
  postChatMessage,
} from "../../../api/client";
import type {
  Announcement,
  ChatMessage,
  PostAnnouncementInput,
  PostChatMessageInput,
} from "../../../api/types";
import { appConfig } from "../../../config/appConfig";
import { useUiStore } from "../../../store/uiStore";

const DEFAULT_MESSAGES_LIMIT = 50;
const DEFAULT_ANNOUNCEMENTS_LIMIT = 10;

function normalizeRoom(room: string | null | undefined): string {
  if (!room) {
    return "global";
  }
  const trimmed = room.trim();
  if (!trimmed) {
    return "global";
  }
  return trimmed.toLowerCase();
}

function ensureMetadata(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return { ...(value as Record<string, unknown>) };
  }
  return {};
}

function mapSocketPayload(payload: unknown): ChatMessage | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const record = payload as Record<string, unknown>;
  const idValue = record.id;
  const id =
    typeof idValue === "number"
      ? idValue
      : typeof idValue === "string"
      ? Number.parseInt(idValue, 10)
      : null;
  if (!Number.isFinite(id)) {
    return null;
  }

  const roomValue = (record.room ?? record["room"] ?? null) as string | null;
  const senderValue =
    (record.sender_address ?? record["senderAddress"] ?? record["sender_address"]) ?? "";
  const bodyValue = record.body ?? "";
  const createdAtValue =
    (record.created_at ?? record["createdAt"] ?? null) as string | null;

  return {
    id: Number(id),
    room: normalizeRoom(typeof roomValue === "string" ? roomValue : null),
    senderAddress: typeof senderValue === "string" ? senderValue : "",
    body: typeof bodyValue === "string" ? bodyValue : String(bodyValue),
    metadata: ensureMetadata(record.metadata),
    createdAt:
      typeof createdAtValue === "string" && createdAtValue.length
        ? createdAtValue
        : new Date().toISOString(),
  };
}

function toWebSocketUrl(httpUrl: string): string {
  if (httpUrl.startsWith("https://")) {
    return `wss://${httpUrl.slice(8)}`;
  }
  if (httpUrl.startsWith("http://")) {
    return `ws://${httpUrl.slice(7)}`;
  }
  return httpUrl.replace(/^http/i, "ws");
}

function buildMessagesKey(room: string, limit: number) {
  return ["chat", "messages", room, limit] as const;
}

function buildAnnouncementsKey(limit: number, lotteryId: string | null | undefined) {
  return ["chat", "announcements", limit, lotteryId ?? null] as const;
}

export function useChatMessages(
  room: string,
  limit: number = DEFAULT_MESSAGES_LIMIT,
): UseQueryResult<ChatMessage[]> {
  const normalizedRoom = normalizeRoom(room);
  return useQuery({
    queryKey: buildMessagesKey(normalizedRoom, limit),
    queryFn: () => fetchChatMessages(normalizedRoom, limit),
    staleTime: 5_000,
    gcTime: 60_000,
  });
}

export function useSendChatMessage(
  room: string,
  limit: number = DEFAULT_MESSAGES_LIMIT,
): UseMutationResult<ChatMessage, Error, PostChatMessageInput> {
  const queryClient = useQueryClient();
  const normalizedRoom = normalizeRoom(room);
  return useMutation({
    mutationFn: (input) => postChatMessage({ ...input, room: normalizedRoom }),
    onSuccess: (message) => {
      queryClient.setQueryData<ChatMessage[]>(
        buildMessagesKey(normalizedRoom, limit),
        (prev) => {
          const next = [...(prev ?? [])];
          const existingIndex = next.findIndex((item) => item.id === message.id);
          if (existingIndex >= 0) {
            next[existingIndex] = message;
          } else {
            next.push(message);
          }
          return next.slice(-limit);
        },
      );
    },
  });
}

export function useChatSubscription(room: string, limit: number = DEFAULT_MESSAGES_LIMIT): void {
  const apiMode = useUiStore((state) => state.apiMode);
  const queryClient = useQueryClient();
  const normalizedRoom = normalizeRoom(room);

  useEffect(() => {
    if (apiMode !== "supra") {
      return;
    }
    if (typeof window === "undefined" || typeof window.WebSocket !== "function") {
      return;
    }

    const wsUrl = `${toWebSocketUrl(appConfig.supraApiBaseUrl)}/chat/ws/${normalizedRoom}`;
    let socket: WebSocket | null = null;

    try {
      socket = new window.WebSocket(wsUrl);
    } catch (error) {
      if (import.meta.env.DEV) {
        console.warn("Не удалось подключиться к WebSocket чата:", error);
      }
      return;
    }

    const handleMessage = (event: MessageEvent) => {
      try {
        const parsed = JSON.parse(event.data);
        const message = mapSocketPayload(parsed);
        if (!message) {
          return;
        }
        queryClient.setQueryData<ChatMessage[]>(
          buildMessagesKey(normalizedRoom, limit),
          (prev) => {
            const next = [...(prev ?? [])];
            const existingIndex = next.findIndex((item) => item.id === message.id);
            if (existingIndex >= 0) {
              next[existingIndex] = message;
            } else {
              next.push(message);
            }
            return next.slice(-limit);
          },
        );
      } catch (error) {
        if (import.meta.env.DEV) {
          console.warn("Некорректное сообщение WebSocket:", error);
        }
      }
    };

    socket.addEventListener("message", handleMessage);

    return () => {
      socket?.removeEventListener("message", handleMessage);
      socket?.close();
    };
  }, [apiMode, normalizedRoom, limit, queryClient]);
}

export function useAnnouncements(
  limit: number = DEFAULT_ANNOUNCEMENTS_LIMIT,
  lotteryId?: string | null,
): UseQueryResult<Announcement[]> {
  return useQuery({
    queryKey: buildAnnouncementsKey(limit, lotteryId ?? null),
    queryFn: () => fetchAnnouncements(limit, lotteryId ?? null),
    staleTime: 30_000,
    gcTime: 120_000,
  });
}

export function usePostAnnouncement(): UseMutationResult<
  Announcement,
  Error,
  PostAnnouncementInput
> {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input) => postAnnouncement(input),
    onSuccess: (announcement) => {
      const keys = queryClient
        .getQueryCache()
        .findAll({ queryKey: ["chat", "announcements"] })
        .map((entry) => entry.queryKey);
      keys.forEach((key) => {
        queryClient.setQueryData<Announcement[]>(key, (prev) => {
          const next = [announcement, ...(prev ?? [])];
          return next.slice(0, (key?.[2] as number) ?? DEFAULT_ANNOUNCEMENTS_LIMIT);
        });
      });
    },
  });
}
