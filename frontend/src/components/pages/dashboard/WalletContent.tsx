import { Wallet, Check, Copy, Send, MessageCircle, Bot } from "lucide-react";
import { Card } from "../../ui/card";
import { Button } from "../../ui/button";
import { useState, useRef, useEffect, useMemo } from "react";
import { Input } from "../../ui/input";
import { Avatar, AvatarFallback } from "../../ui/avatar";
import { useWallet } from "../../../features/wallet/useWallet";
import { useLotteryStatus } from "../../../features/dashboard/hooks/useLotteryStatus";

type Message = {
  id: number;
  text: string;
  sender: "user" | "support";
  timestamp: string;
};

const initialMessages: Message[] = [
  { id: 1, text: "Hello! How can I help you today?", sender: "support", timestamp: "10:00 AM" },
  { id: 2, text: "Hi! I have a question about withdrawals.", sender: "user", timestamp: "10:02 AM" },
  { id: 3, text: "I'd be happy to help! Withdrawals are processed instantly via smart contracts. What would you like to know?", sender: "support", timestamp: "10:02 AM" },
];

const statusText: Record<string, string> = {
  disconnected: "Disconnected",
  connecting: "Connecting…",
  connected: "Connected",
};

function formatDate(value?: string): string {
  if (!value) {
    return "—";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "—";
  }
  return parsed.toLocaleString();
}

function formatSupra(value?: string | number | null): string {
  if (value === null || value === undefined || value === "") {
    return "—";
  }
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return String(value);
  }
  return `${numeric} $SUPRA`;
}

export function WalletContent() {
  const [copied, setCopied] = useState(false);
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [inputMessage, setInputMessage] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);
  const { wallet, copyAddress, connect, disconnect } = useWallet();
  const { data: lotteryStatus } = useLotteryStatus();

  const walletAddress = wallet.address ?? "";
  const statusLabel = statusText[wallet.status] ?? wallet.status;
  const networkLabel = useMemo(() => {
    if (wallet.chainId) {
      return wallet.chainId;
    }
    return "Unknown network";
  }, [wallet.chainId]);
  const balanceLabel =
    lotteryStatus?.treasury?.jackpotBalance ?? lotteryStatus?.hub?.vrfBalance ?? null;

  const handleCopy = async () => {
    const success = await copyAddress();
    setCopied(success);
    if (success) {
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleConnect = async () => {
    if (wallet.status === "connected") {
      await disconnect();
    } else {
      await connect();
    }
  };

  const handleSendMessage = () => {
    if (!inputMessage.trim()) return;

    const newMessage: Message = {
      id: messages.length + 1,
      text: inputMessage,
      sender: "user",
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
    };

    setMessages((prev) => [...prev, newMessage]);
    setInputMessage("");

    // Simulate support response
    const nextId = newMessage.id + 1;
    setTimeout(() => {
      const supportMessage: Message = {
        id: nextId,
        text: "Thank you for your message! Our team will get back to you shortly.",
        sender: "support",
        timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
      };
      setMessages((prev) => [...prev, supportMessage]);
    }, 1000);
  };

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
          Account
        </h3>
        <p className="text-gray-400">Manage your account and chat with support</p>
      </div>

      {/* Account Overview */}
      <Card className="glass-strong p-8 rounded-2xl border-cyan-500/30 glow-cyan mb-8">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6 mb-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center">
              <Wallet className="w-8 h-8 text-white" />
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">{wallet.providerLabel}</p>
              <div className="flex items-center gap-2">
                <code className="text-lg text-cyan-400 bg-cyan-500/10 px-3 py-1 rounded">
                  {walletAddress
                    ? `${walletAddress.slice(0, 6)}...${walletAddress.slice(-4)}`
                    : "Not connected"}
                </code>
                {walletAddress && (
                  <Button
                    onClick={handleCopy}
                    variant="ghost"
                    size="sm"
                    className="text-gray-400 hover:text-cyan-400"
                  >
                    {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                  </Button>
                )}
              </div>
              <Button
                onClick={handleConnect}
                className="mt-3 bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-6 py-2 rounded-xl glow-cyan transition-all"
              >
                <Wallet className="w-4 h-4 mr-2" />
                {wallet.status === "connected" ? "Disconnect" : "Connect Wallet"}
              </Button>
            </div>
          </div>
          <div className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 px-4 py-2 text-sm text-cyan-100">
            Status: {statusLabel}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <p className="text-sm text-gray-400 mb-2">Balance</p>
            <p className="text-3xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              {formatSupra(balanceLabel)}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400 mb-2">Network</p>
            <div className="flex items-center gap-2">
              <div className={`w-3 h-3 rounded-full ${wallet.status === "connected" ? "bg-green-500 animate-pulse" : "bg-gray-500"}`}></div>
              <p className="text-lg text-white">{networkLabel}</p>
            </div>
          </div>
          <div>
            <p className="text-sm text-gray-400 mb-2">Gas Fee</p>
            <p className="text-lg text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              ~0.001 SUPRA
            </p>
          </div>
        </div>
      </Card>

      {/* Support Chat */}
      <Card className="glass-strong p-6 rounded-2xl border-cyan-500/30 glow-cyan flex flex-col">
        {/* Chat Header */}
        <div className="flex items-center gap-3 pb-4 border-b border-cyan-500/30 mb-4">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center">
            <Bot className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h4 className="text-xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Support Chat
            </h4>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
              <p className="text-sm text-gray-400">Online</p>
            </div>
          </div>
          <MessageCircle className="w-5 h-5 text-cyan-400" />
        </div>

        {/* Messages Area */}
        <div
          ref={scrollRef}
          className="flex-1 space-y-4 overflow-y-auto mb-4 pr-2"
          style={{ maxHeight: '500px' }}
        >
          {messages.map((message) => (
            <div
              key={message.id}
              className={`flex items-end gap-3 ${
                message.sender === "user" ? "flex-row-reverse" : "flex-row"
              }`}
            >
              {/* Avatar */}
              <Avatar className={`w-8 h-8 ${
                message.sender === "support"
                  ? "bg-gradient-to-br from-cyan-500 to-purple-600"
                  : "bg-gradient-to-br from-purple-500 to-pink-500"
              }`}>
                <AvatarFallback className="text-white text-xs">
                  {message.sender === "support" ? "AI" : "You"}
                </AvatarFallback>
              </Avatar>

              {/* Message Bubble */}
              <div
                className={`max-w-[75%] ${
                  message.sender === "user"
                    ? "bg-gradient-to-br from-purple-500/30 to-pink-500/30 border-purple-400/30"
                    : "glass border-cyan-500/30"
                } backdrop-blur-xl border rounded-2xl px-4 py-3`}
              >
                <p className="text-sm text-white leading-relaxed">
                  {message.text}
                </p>
                <p className="text-xs text-gray-400 mt-1">
                  {message.timestamp}
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Message Input */}
        <div className="flex items-center gap-3">
          <Input
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && handleSendMessage()}
            placeholder="Type your message..."
            className="flex-1 glass border-cyan-500/30 text-white placeholder:text-gray-500 focus:border-cyan-400 rounded-xl"
          />
          <Button
            onClick={handleSendMessage}
            className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white rounded-xl glow-cyan px-4"
          >
            <Send className="w-5 h-5" />
          </Button>
        </div>
      </Card>
    </div>
  );
}
