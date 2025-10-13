import { Trophy, Users, Clock, Sparkles } from "lucide-react";
import { Card } from "../ui/card";
import { Badge } from "../ui/badge";
import { Button } from "../ui/button";
import { Progress } from "../ui/progress";

const upcomingDraws = [
  { id: "#12345", prizePool: "125,000 SUPRA", participants: 1234, timeLeft: "23:45:12", status: "live" },
  { id: "#12346", prizePool: "150,000 SUPRA", participants: 856, timeLeft: "47:30:22", status: "upcoming" },
  { id: "#12347", prizePool: "200,000 SUPRA", participants: 432, timeLeft: "71:15:08", status: "upcoming" },
];

const completedDraws = [
  { id: "#12344", winner: "0x5e6f...7g8h", prize: "45,000 SUPRA", date: "Oct 3, 2025", participants: 1156 },
  { id: "#12343", winner: "0x9i0j...1k2l", prize: "52,000 SUPRA", date: "Oct 2, 2025", participants: 1089 },
  { id: "#12342", winner: "0xm3n4...5o6p", prize: "48,000 SUPRA", date: "Oct 1, 2025", participants: 997 },
];

export function DrawsPage() {
  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/3 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/3 w-96 h-96 bg-pink-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-purple-400 to-pink-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Lottery Draws
          </h2>
          <p className="text-lg text-gray-400">View upcoming and completed lottery draws</p>
        </div>

        {/* Upcoming Draws */}
        <div className="mb-12">
          <h3 className="text-3xl mb-6 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
            Upcoming Draws
          </h3>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {upcomingDraws.map((draw, index) => (
              <Card key={draw.id} className={`glass-strong p-6 rounded-2xl ${
                index === 0 ? "border-cyan-500/40 glow-cyan" : "border-purple-500/20"
              }`}>
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h4 className="text-2xl text-white mb-1" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      Draw {draw.id}
                    </h4>
                    {draw.status === "live" && (
                      <Badge className="bg-green-500/20 text-green-400 border-green-500/50">
                        <Sparkles className="w-3 h-3 mr-1" />
                        Live
                      </Badge>
                    )}
                  </div>
                  <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                    <Trophy className="w-6 h-6 text-white" />
                  </div>
                </div>

                <div className="space-y-4 mb-6">
                  <div>
                    <p className="text-sm text-gray-400 mb-1">Prize Pool</p>
                    <p className="text-2xl text-cyan-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
                      {draw.prizePool}
                    </p>
                  </div>

                  <div>
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-gray-400">Participants</span>
                      <span className="text-purple-400">{draw.participants}</span>
                    </div>
                    <Progress value={(draw.participants / 2000) * 100} className="h-2" />
                  </div>

                  <div className="flex items-center gap-2 text-sm">
                    <Clock className="w-4 h-4 text-pink-400" />
                    <span className="text-gray-400">Time Left:</span>
                    <span className="text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                      {draw.timeLeft}
                    </span>
                  </div>
                </div>

                <Button className="w-full bg-gradient-to-r from-purple-500 to-pink-600 hover:from-purple-600 hover:to-pink-700 text-white py-2 rounded-xl transition-all">
                  Buy Ticket
                </Button>
              </Card>
            ))}
          </div>
        </div>

        {/* Completed Draws */}
        <div>
          <h3 className="text-3xl mb-6 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
            Completed Draws
          </h3>
          <div className="space-y-4">
            {completedDraws.map((draw) => (
              <Card key={draw.id} className="glass-strong p-6 rounded-2xl border-purple-500/20">
                <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-gray-600 to-gray-700 flex items-center justify-center">
                      <Trophy className="w-6 h-6 text-white" />
                    </div>
                    <div>
                      <h4 className="text-xl text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                        Draw {draw.id}
                      </h4>
                      <p className="text-sm text-gray-400">{draw.date}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-8">
                    <div>
                      <p className="text-sm text-gray-400">Winner</p>
                      <code className="text-cyan-400 bg-cyan-500/10 px-2 py-1 rounded text-sm">
                        {draw.winner}
                      </code>
                    </div>
                    <div>
                      <p className="text-sm text-gray-400">Prize</p>
                      <p className="text-lg text-pink-400" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 600 }}>
                        {draw.prize}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-400">Participants</p>
                      <p className="text-lg text-purple-400" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                        {draw.participants}
                      </p>
                    </div>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
