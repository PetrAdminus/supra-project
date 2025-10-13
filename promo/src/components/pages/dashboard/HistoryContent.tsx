import { History, TrendingUp, TrendingDown, Award } from "lucide-react";
import { Card } from "../../ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "../../ui/table";
import { Badge } from "../../ui/badge";

const transactionHistory = [
  { id: 1, type: "purchase", ticket: "789012", draw: "#12345", amount: "-100 SUPRA", date: "Oct 4, 2025 14:30", status: "completed" },
  { id: 2, type: "purchase", ticket: "456789", draw: "#12345", amount: "-100 SUPRA", date: "Oct 4, 2025 12:15", status: "completed" },
  { id: 3, type: "purchase", ticket: "123456", draw: "#12345", amount: "-100 SUPRA", date: "Oct 3, 2025 18:45", status: "completed" },
  { id: 4, type: "purchase", ticket: "345678", draw: "#12344", amount: "-100 SUPRA", date: "Oct 2, 2025 09:20", status: "completed" },
  { id: 5, type: "purchase", ticket: "901234", draw: "#12343", amount: "-100 SUPRA", date: "Oct 1, 2025 16:55", status: "completed" },
  { id: 6, type: "prize", ticket: "567890", draw: "#12340", amount: "+5,000 SUPRA", date: "Sep 28, 2025 20:00", status: "claimed" },
];

export function HistoryContent() {
  return (
    <div>
      <div className="mb-8">
        <h3 className="text-3xl mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
          Transaction History
        </h3>
        <p className="text-gray-400">View all your lottery transactions and winnings</p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-12">
        <Card className="glass-strong p-6 rounded-2xl border-cyan-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-cyan-500/20 flex items-center justify-center">
              <History className="w-5 h-5 text-cyan-400" />
            </div>
            <p className="text-sm text-gray-400">Total Transactions</p>
          </div>
          <p className="text-3xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            {transactionHistory.length}
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-red-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-red-500/20 flex items-center justify-center">
              <TrendingDown className="w-5 h-5 text-red-400" />
            </div>
            <p className="text-sm text-gray-400">Total Spent</p>
          </div>
          <p className="text-3xl text-red-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            500 SUPRA
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-green-500/30">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-green-400" />
            </div>
            <p className="text-sm text-gray-400">Total Won</p>
          </div>
          <p className="text-3xl text-green-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            5,000 SUPRA
          </p>
        </Card>

        <Card className="glass-strong p-6 rounded-2xl border-purple-500/30 glow-purple">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-purple-500/20 flex items-center justify-center">
              <Award className="w-5 h-5 text-purple-400" />
            </div>
            <p className="text-sm text-gray-400">Net Profit</p>
          </div>
          <p className="text-3xl text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            +4,500 SUPRA
          </p>
        </Card>
      </div>

      {/* Transaction Table */}
      <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20">
        <h4 className="text-2xl mb-6 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
          All Transactions
        </h4>
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="border-gray-700 hover:bg-transparent">
                <TableHead className="text-cyan-400">Type</TableHead>
                <TableHead className="text-cyan-400">Ticket</TableHead>
                <TableHead className="text-cyan-400">Draw</TableHead>
                <TableHead className="text-cyan-400">Amount</TableHead>
                <TableHead className="text-cyan-400">Date</TableHead>
                <TableHead className="text-cyan-400">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {transactionHistory.map((tx) => (
                <TableRow key={tx.id} className="border-gray-800 hover:bg-white/5 transition-colors">
                  <TableCell>
                    {tx.type === "purchase" ? (
                      <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/50">
                        Purchase
                      </Badge>
                    ) : (
                      <Badge className="bg-green-500/20 text-green-400 border-green-500/50">
                        Prize Won
                      </Badge>
                    )}
                  </TableCell>
                  <TableCell>
                    <code className="text-purple-400 bg-purple-500/10 px-2 py-1 rounded text-sm">
                      #{tx.ticket}
                    </code>
                  </TableCell>
                  <TableCell className="text-gray-300">{tx.draw}</TableCell>
                  <TableCell>
                    <span className={`${
                      tx.type === "purchase" ? "text-red-400" : "text-green-400"
                    }`} style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 600 }}>
                      {tx.amount}
                    </span>
                  </TableCell>
                  <TableCell className="text-gray-300">{tx.date}</TableCell>
                  <TableCell>
                    {tx.status === "completed" ? (
                      <Badge className="bg-gray-500/20 text-gray-400 border-gray-500/50">
                        Completed
                      </Badge>
                    ) : (
                      <Badge className="bg-cyan-500/20 text-cyan-400 border-cyan-500/50">
                        Claimed
                      </Badge>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}
