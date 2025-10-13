import { useMemo, useState, useCallback } from "react";
import { Wallet, Trophy, Settings, Shield } from "lucide-react";
import { Card } from "../../ui/card";
import { Button } from "../../ui/button";
import { Input } from "../../ui/input";
import { Label } from "../../ui/label";
import { Avatar, AvatarFallback } from "../../ui/avatar";
import { useWallet } from "../../../features/wallet/useWallet";
import { useTicketHistory } from "../../../features/tickets/hooks/useTicketHistory";
import { useLotteryStatus } from "../../../features/dashboard/hooks/useLotteryStatus";
import { EMPTY_VALUE, formatDateTime, formatSupraValue } from "../../../utils/format";


export function ProfileContent() {
  const { wallet, copyAddress, connect, disconnect } = useWallet();
  const { data: tickets } = useTicketHistory();
  const { data: status } = useLotteryStatus();
  const [copied, setCopied] = useState(false);

  const address = wallet.address ?? "";
  const addressDisplay = address
    ? `${address.slice(0, 6)}...${address.slice(-4)}`
    : "Not connected";

  const avatarInitials = useMemo(() => {
    if (!address) {
      return "SL";
    }
    return address.slice(2, 4).toUpperCase();
  }, [address]);

  const totalTickets = tickets?.length ?? 0;
  const totalWins = tickets?.filter((ticket) => ticket.status === "won").length ?? 0;
  const firstTicketDate = tickets?.[tickets.length - 1]?.purchaseTime ?? null;
  const memberSince = firstTicketDate ? formatDateTime(firstTicketDate) : EMPTY_VALUE;

  const balance =
    status?.treasury?.jackpotBalance ??
    status?.hub?.vrfBalance ??
    status?.treasury?.pendingPayouts ??
    null;

  const handleCopy = useCallback(async () => {
    const ok = await copyAddress();
    setCopied(ok);
    if (ok) {
      setTimeout(() => setCopied(false), 2000);
    }
  }, [copyAddress]);

  const handleConnect = useCallback(async () => {
    if (wallet.status === "connected") {
      await disconnect();
    } else {
      await connect();
    }
  }, [wallet.status, connect, disconnect]);

  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: "Orbitron, sans-serif" }}>
          Profile
        </h3>
        <p className="text-gray-400">Manage your account settings and preferences</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left Column - Profile Info */}
        <div className="lg:col-span-1 space-y-6">
          <Card className="glass-strong p-6 rounded-2xl border-purple-500/30 glow-purple">
            <div className="flex flex-col items-center text-center">
              <Avatar className="w-24 h-24 mb-4 bg-gradient-to-br from-cyan-500 to-purple-600">
                <AvatarFallback
                  className="text-2xl text-white"
                  style={{ fontFamily: "Orbitron, sans-serif" }}
                >
                  {avatarInitials}
                </AvatarFallback>
              </Avatar>
              <h4 className="text-2xl text-white mb-1" style={{ fontFamily: "Orbitron, sans-serif" }}>
                Supra User
              </h4>
              <code className="text-sm text-cyan-400 bg-cyan-500/10 px-3 py-1 rounded mb-4">
                {addressDisplay}
              </code>
              <Button
                variant="outline"
                className="glass text-white border-cyan-400/50 hover:border-cyan-400 w-full rounded-xl"
                onClick={handleConnect}
              >
                <Settings className="w-4 h-4 mr-2" />
                {wallet.status === "connected" ? "Disconnect Wallet" : "Connect Wallet"}
              </Button>
            </div>
          </Card>

          <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20">
            <h4 className="text-lg text-white mb-4" style={{ fontFamily: "Orbitron, sans-serif" }}>
              Quick Stats
            </h4>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Trophy className="w-4 h-4 text-purple-400" />
                  <span className="text-sm text-gray-400">Total Wins</span>
                </div>
                <span className="text-purple-400" style={{ fontFamily: "Orbitron, sans-serif" }}>
                  {totalWins}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Wallet className="w-4 h-4 text-cyan-400" />
                  <span className="text-sm text-gray-400">Total Tickets</span>
                </div>
                <span className="text-cyan-400" style={{ fontFamily: "Orbitron, sans-serif" }}>
                  {totalTickets}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-pink-400" />
                  <span className="text-sm text-gray-400">Member Since</span>
                </div>
                <span className="text-pink-400">{memberSince}</span>
              </div>
            </div>
          </Card>
        </div>

        {/* Right Column - Settings */}
        <div className="lg:col-span-2 space-y-6">
          <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
            <h4 className="text-2xl text-white mb-6" style={{ fontFamily: "Orbitron, sans-serif" }}>
              Wallet Information
            </h4>
            <div className="space-y-4">
              <div>
                <Label className="text-gray-400 mb-2 block">Wallet Address</Label>
                <div className="flex gap-3">
                  <Input
                    value={address || ""}
                    readOnly
                    className="glass text-gray-300 border-gray-700"
                    placeholder="Not connected"
                  />
                  <Button
                    onClick={handleCopy}
                    className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white rounded-xl"
                    disabled={!address}
                  >
                    {copied ? "Copied" : "Copy"}
                  </Button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label className="text-gray-400 mb-2 block">Balance</Label>
                  <div className="glass p-4 rounded-xl border-purple-500/30">
                    <p
                      className="text-2xl text-purple-400"
                      style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
                    >
                      {formatSupraValue(balance)}
                    </p>
                  </div>
                </div>
                <div>
                  <Label className="text-gray-400 mb-2 block">Network</Label>
                  <div className="glass p-4 rounded-xl border-cyan-500/30">
                    <p className="text-lg text-cyan-400" style={{ fontFamily: "Orbitron, sans-serif" }}>
                      {wallet.chainId ?? "Unknown"}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-purple-500/20">
            <h4 className="text-2xl text-white mb-6" style={{ fontFamily: "Orbitron, sans-serif" }}>
              Notification Preferences
            </h4>
            <div className="space-y-4">
              <div className="flex items-center justify-between glass p-4 rounded-xl">
                <div>
                  <p className="text-white">Draw Results</p>
                  <p className="text-sm text-gray-400">Get notified when draw results are announced</p>
                </div>
                <input type="checkbox" defaultChecked className="w-5 h-5" />
              </div>
              <div className="flex items-center justify-between glass p-4 rounded-xl">
                <div>
                  <p className="text-white">Winning Alerts</p>
                  <p className="text-sm text-gray-400">Instant notification when you win</p>
                </div>
                <input type="checkbox" defaultChecked className="w-5 h-5" />
              </div>
              <div className="flex items-center justify-between glass p-4 rounded-xl">
                <div>
                  <p className="text-white">New Draws</p>
                  <p className="text-sm text-gray-400">Alert when new draws are available</p>
                </div>
                <input type="checkbox" className="w-5 h-5" />
              </div>
            </div>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-pink-500/20">
            <h4 className="text-2xl text-white mb-6" style={{ fontFamily: "Orbitron, sans-serif" }}>
              Security
            </h4>
            <div className="space-y-4">
              <Button
                variant="outline"
                className="w-full glass text-white border-cyan-400/50 hover:border-cyan-400 rounded-xl justify-start"
              >
                <Shield className="w-4 h-4 mr-2" />
                Enable Two-Factor Authentication
              </Button>
              <Button
                variant="outline"
                className="w-full glass text-white border-purple-400/50 hover:border-purple-400 rounded-xl justify-start"
                disabled={wallet.status !== "connected"}
                onClick={disconnect}
              >
                <Wallet className="w-4 h-4 mr-2" />
                Disconnect Wallet
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
