import { useMemo, useState, type FormEvent, type ReactElement } from "react";
import { useI18n } from "../../../i18n/useI18n";
import { useWallet } from "../../wallet/useWallet";
import {
  useAnnouncements,
  useChatMessages,
  useChatSubscription,
  useSendChatMessage,
} from "../hooks/useChatMessages";
import type { ChatMessage } from "../../../api/types";
import "./ChatPanel.css";

interface ChatPanelProps {
  room?: string;
  lotteryId?: number | null;
  limit?: number;
}

function formatTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function shortenAddress(address: string, fallback: string): string {
  if (!address) {
    return fallback;
  }
  if (address.length <= 12) {
    return address;
  }
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function ChatPanel({ room = "global", lotteryId = null, limit = 50 }: ChatPanelProps): ReactElement {
  const normalizedRoom = room ?? "global";
  const { t } = useI18n();
  const { wallet } = useWallet();
  const [message, setMessage] = useState("");

  const messagesQuery = useChatMessages(normalizedRoom, limit);
  useChatSubscription(normalizedRoom, limit);
  const sendMutation = useSendChatMessage(normalizedRoom, limit);
  const announcementsQuery = useAnnouncements(5, lotteryId !== null ? String(lotteryId) : null);

  const messages = messagesQuery.data ?? [];
  const announcements = announcementsQuery.data ?? [];
  const hasWallet = Boolean(wallet.address);
  const isSending = sendMutation.isPending;
  const canSubmit = hasWallet && message.trim().length > 0 && !isSending;
  const walletAddress = wallet.address ?? "";

  const statusMessage = useMemo(() => {
    if (messagesQuery.isLoading) {
      return t("chat.panel.loading");
    }
    if (messagesQuery.isError) {
      return t("chat.panel.error");
    }
    if (messages.length === 0) {
      return t("chat.panel.empty");
    }
    return null;
  }, [messagesQuery.isLoading, messagesQuery.isError, messages.length, t]);

  const announcementStatus = useMemo(() => {
    if (announcementsQuery.isLoading) {
      return t("chat.announcements.loading");
    }
    if (announcements.length === 0) {
      return t("chat.announcements.empty");
    }
    return null;
  }, [announcementsQuery.isLoading, announcements.length, t]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canSubmit) {
      return;
    }
    try {
      await sendMutation.mutateAsync({ address: walletAddress, body: message.trim() });
      setMessage("");
    } catch (error) {
      console.error("Не удалось отправить сообщение", error);
    }
  }

  return (
    <div className="chat-panel">
      <section className="chat-panel__announcements" aria-live="polite">
        <header className="chat-panel__section-header">
          <h3>{t("chat.announcements.title")}</h3>
        </header>
        {announcementStatus ? (
          <p className="chat-panel__status">{announcementStatus}</p>
        ) : (
          <ul className="chat-panel__announcement-list">
            {announcements.map((announcement) => (
              <li key={announcement.id} className="chat-panel__announcement">
                <div className="chat-panel__announcement-header">
                  <h4>{announcement.title}</h4>
                  <time dateTime={announcement.createdAt}>{formatTime(announcement.createdAt)}</time>
                </div>
                <p>{announcement.body}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="chat-panel__messages" aria-live="polite">
        <header className="chat-panel__section-header">
          <h3>{t("chat.panel.messagesTitle")}</h3>
        </header>
        {statusMessage ? (
          <p className="chat-panel__status">{statusMessage}</p>
        ) : (
          <ul className="chat-panel__message-list">
            {messages.map((item: ChatMessage) => (
              <li key={item.id} className="chat-panel__message">
                <div className="chat-panel__message-meta">
                  <span className="chat-panel__message-address">
                    {shortenAddress(item.senderAddress, t("chat.panel.unknownUser"))}
                  </span>
                  <time dateTime={item.createdAt}>{formatTime(item.createdAt)}</time>
                </div>
                <p className="chat-panel__message-body">{item.body}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <form className="chat-panel__form" onSubmit={handleSubmit}>
        <textarea
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          placeholder={t("chat.panel.sendPlaceholder")}
          aria-label={t("chat.panel.sendPlaceholder")}
          disabled={!hasWallet || isSending}
          rows={2}
        />
        <button type="submit" disabled={!canSubmit}>
          {isSending ? t("chat.panel.sending") : t("chat.panel.sendButton")}
        </button>
      </form>
      {!hasWallet && <p className="chat-panel__hint">{t("chat.panel.connectHint")}</p>}
      {sendMutation.isError && (
        <p className="chat-panel__error" role="status">
          {t("chat.panel.sendError")}
        </p>
      )}
    </div>
  );
}
