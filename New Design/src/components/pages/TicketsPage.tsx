import { Ticket, Plus, CheckCircle2 } from "lucide-react";
import { Card } from "../ui/card";
import { Button } from "../ui/button";
import { Badge } from "../ui/badge";

const myTickets = [
  { id: "789012", draw: "#12345", status: "active", purchaseDate: "Oct 4, 2025", price: "100 SUPRA" },
  { id: "456789", draw: "#12345", status: "active", purchaseDate: "Oct 4, 2025", price: "100 SUPRA" },
  { id: "123456", draw: "#12345", status: "active", purchaseDate: "Oct 3, 2025", price: "100 SUPRA" },
  { id: "345678", draw: "#12344", status: "completed", purchaseDate: "Oct 2, 2025", price: "100 SUPRA" },
  { id: "901234", draw: "#12343", status: "completed", purchaseDate: "Oct 1, 2025", price: "100 SUPRA" },
];

export function TicketsPage() {
  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            My Tickets
          </h2>
          <p className="text-lg text-gray-400">Manage your lottery tickets and participate in draws</p>
        </div>

        {/* Purchase New Ticket Section */}
        <Card className="glass-strong p-8 rounded-2xl border-cyan-500/30 glow-cyan mb-8">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center">
                <Ticket className="w-8 h-8 text-white" />
              </div>
              <div>
                <h3 className="text-2xl text-white mb-1" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                  Next Draw: #12345
                </h3>
                <p className="text-gray-400">Prize Pool: 125,000 SUPRA</p>
              </div>
            </div>
            <Button className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl glow-cyan transition-all">
              <Plus className="w-5 h-5 mr-2" />
              Buy Ticket (100 SUPRA)
            </Button>
          </div>
        </Card>

        {/* Tickets Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {myTickets.map((ticket) => (
            <Card key={ticket.id} className="glass-strong p-6 rounded-2xl border-purple-500/20 hover:border-purple-500/40 transition-all">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                    <Ticket className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <h4 className="text-xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      #{ticket.id}
                    </h4>
                    <p className="text-sm text-gray-400">Draw {ticket.draw}</p>
                  </div>
                </div>
                {ticket.status === "active" ? (
                  <Badge className="bg-green-500/20 text-green-400 border-green-500/50">
                    Active
                  </Badge>
                ) : (
                  <Badge className="bg-gray-500/20 text-gray-400 border-gray-500/50">
                    Completed
                  </Badge>
                )}
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Purchase Date</span>
                  <span className="text-gray-300">{ticket.purchaseDate}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Price Paid</span>
                  <span className="text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                    {ticket.price}
                  </span>
                </div>
              </div>

              {ticket.status === "active" && (
                <div className="flex items-center gap-2 text-sm text-purple-400 bg-purple-500/10 px-3 py-2 rounded-lg">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Entered in upcoming draw</span>
                </div>
              )}
            </Card>
          ))}
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
          <Card className="glass p-6 rounded-2xl text-center">
            <p className="text-sm text-gray-400 mb-2">Total Tickets</p>
            <p className="text-3xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              {myTickets.length}
            </p>
          </Card>
          <Card className="glass p-6 rounded-2xl text-center">
            <p className="text-sm text-gray-400 mb-2">Active Tickets</p>
            <p className="text-3xl text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              {myTickets.filter(t => t.status === "active").length}
            </p>
          </Card>
          <Card className="glass p-6 rounded-2xl text-center">
            <p className="text-sm text-gray-400 mb-2">Total Spent</p>
            <p className="text-3xl text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              500 SUPRA
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}
