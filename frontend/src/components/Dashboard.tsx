import { Trophy, Wallet, Clock, TrendingUp } from "lucide-react";
import { Card } from "./ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "./ui/table";
import { DashboardSidebar } from "./DashboardSidebar";
import { useState } from "react";

const recentDraws = [
  { id: "#12345", date: "Oct 4, 2025", winner: "0x1a2b...3c4d", prize: "50,000 SUPRA", ticket: "789012" },
  { id: "#12344", date: "Oct 3, 2025", winner: "0x5e6f...7g8h", prize: "45,000 SUPRA", ticket: "456789" },
  { id: "#12343", date: "Oct 2, 2025", winner: "0x9i0j...1k2l", prize: "52,000 SUPRA", ticket: "123456" },
  { id: "#12342", date: "Oct 1, 2025", winner: "0xm3n4...5o6p", prize: "48,000 SUPRA", ticket: "345678" },
  { id: "#12341", date: "Sep 30, 2025", winner: "0xq7r8...9s0t", prize: "55,000 SUPRA", ticket: "901234" },
];

export function Dashboard() {
  const [activeSection, setActiveSection] = useState<"tickets" | "draws" | "history" | "profile" | "settings">("draws");

  return (
    <section id="dashboard" className="py-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="text-center mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Live Dashboard
          </h2>
          <p className="text-lg text-gray-400">Real-time lottery statistics and draw history</p>
        </div>

        {/* Dashboard Layout with Sidebar */}
        <div className="flex gap-6">
          {/* Left Sidebar */}
          <DashboardSidebar activeSection={activeSection} onSectionChange={setActiveSection} />

          {/* Main Content */}
          <div className="flex-1">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {/* Prize Pool */}
          <Card className="glass-strong p-8 rounded-2xl border-cyan-500/30 glow-cyan">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-cyan-500 to-cyan-600 flex items-center justify-center">
                <Trophy className="w-7 h-7 text-white" />
              </div>
              <div>
                <p className="text-sm text-gray-400">Current Prize Pool</p>
                <h3 className="text-3xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
                  125,000
                </h3>
                <p className="text-sm text-gray-300">SUPRA</p>
              </div>
            </div>
            <div className="flex items-center gap-2 text-sm text-green-400">
              <TrendingUp className="w-4 h-4" />
              <span>+12.5% from last draw</span>
            </div>
          </Card>

          {/* User Balance */}
          <Card className="glass-strong p-8 rounded-2xl border-purple-500/30 glow-purple">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center">
                <Wallet className="w-7 h-7 text-white" />
              </div>
              <div>
                <p className="text-sm text-gray-400">Your Balance</p>
                <h3 className="text-3xl text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
                  2,450
                </h3>
                <p className="text-sm text-gray-300">SUPRA</p>
              </div>
            </div>
            <div className="flex items-center gap-2 text-sm text-gray-400">
              <span>3 active tickets</span>
            </div>
          </Card>

          {/* Next Draw */}
          <Card className="glass-strong p-8 rounded-2xl border-pink-500/30 glow-pink">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-pink-500 to-pink-600 flex items-center justify-center">
                <Clock className="w-7 h-7 text-white" />
              </div>
              <div>
                <p className="text-sm text-gray-400">Next Draw In</p>
                <h3 className="text-3xl text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
                  23:45:12
                </h3>
                <p className="text-sm text-gray-300">Hours</p>
              </div>
            </div>
            <div className="flex items-center gap-2 text-sm text-gray-400">
              <span>1,234 participants</span>
            </div>
          </Card>
        </div>

            {/* Recent Draws Table */}
            <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
              <h3 className="text-2xl mb-6 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Recent Draw Results
              </h3>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="border-gray-700 hover:bg-transparent">
                      <TableHead className="text-cyan-400">Draw ID</TableHead>
                      <TableHead className="text-cyan-400">Date</TableHead>
                      <TableHead className="text-cyan-400">Winner</TableHead>
                      <TableHead className="text-cyan-400">Winning Ticket</TableHead>
                      <TableHead className="text-cyan-400 text-right">Prize</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {recentDraws.map((draw) => (
                      <TableRow key={draw.id} className="border-gray-800 hover:bg-white/5 transition-colors">
                        <TableCell className="text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                          {draw.id}
                        </TableCell>
                        <TableCell className="text-gray-300">{draw.date}</TableCell>
                        <TableCell>
                          <code className="text-cyan-400 bg-cyan-500/10 px-2 py-1 rounded text-sm">
                            {draw.winner}
                          </code>
                        </TableCell>
                        <TableCell className="text-gray-300">{draw.ticket}</TableCell>
                        <TableCell className="text-right">
                          <span className="text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 600 }}>
                            {draw.prize}
                          </span>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
}
