import { Zap, Shield, Users, TrendingUp, Globe, Award } from "lucide-react";
import { Card } from "../ui/card";

export function AboutPage() {
  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10 max-w-6xl">
        {/* Header */}
        <div className="text-center mb-16">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            About ElyxS
          </h2>
          <p className="text-lg text-gray-400 max-w-3xl mx-auto">
            The future of decentralized lottery gaming on the Supra blockchain network
          </p>
        </div>

        {/* Mission Statement */}
        <Card className="glass-strong p-12 rounded-2xl border-cyan-500/30 glow-cyan mb-12 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_30px_rgba(6,182,212,0.3)]">
          <div className="flex items-start gap-6">
            <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center flex-shrink-0">
              <Zap className="w-8 h-8 text-white" />
            </div>
            <div>
              <h3 className="text-3xl text-white mb-4" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Our Mission
              </h3>
              <p className="text-lg text-gray-300 leading-relaxed mb-4">
                ElyxS is revolutionizing the lottery industry by bringing transparency, fairness, and instant payouts to players worldwide through blockchain technology. Built on the Supra network, we leverage cutting-edge cryptographic verification to ensure every draw is provably fair and tamper-proof.
              </p>
              <p className="text-lg text-gray-300 leading-relaxed">
                Our mission is to create a trustless, decentralized lottery platform where players can participate with confidence, knowing that every aspect of the game is transparent and verifiable on the blockchain.
              </p>
            </div>
          </div>
        </Card>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          <Card className="glass-strong p-8 rounded-2xl border-purple-500/20 hover:border-purple-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(168,85,247,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center mb-6">
              <Shield className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Provably Fair
            </h4>
            <p className="text-gray-400">
              Every draw is verifiable on-chain with cryptographic proof, ensuring complete transparency and fairness for all participants.
            </p>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20 hover:border-cyan-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-cyan-500 to-cyan-600 flex items-center justify-center mb-6">
              <TrendingUp className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Instant Payouts
            </h4>
            <p className="text-gray-400">
              Winners receive their prizes instantly through smart contracts, with no delays or manual processing required.
            </p>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-pink-500/20 hover:border-pink-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(236,72,153,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-pink-500 to-pink-600 flex items-center justify-center mb-6">
              <Globe className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Global Access
            </h4>
            <p className="text-gray-400">
              Participate from anywhere in the world with just a crypto wallet. No borders, no restrictions.
            </p>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-purple-500/20 hover:border-purple-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(168,85,247,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center mb-6">
              <Users className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Community Driven
            </h4>
            <p className="text-gray-400">
              Built by the community, for the community. Your voice matters in shaping the future of ElyxS.
            </p>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-cyan-500/20 hover:border-cyan-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center mb-6">
              <Award className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Big Prizes
            </h4>
            <p className="text-gray-400">
              Compete for substantial prize pools that grow with each participant. The more players, the bigger the rewards.
            </p>
          </Card>

          <Card className="glass-strong p-8 rounded-2xl border-pink-500/20 hover:border-pink-500/40 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(236,72,153,0.25)]">
            <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center mb-6">
              <Zap className="w-7 h-7 text-white" />
            </div>
            <h4 className="text-xl text-white mb-3" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Lightning Fast
            </h4>
            <p className="text-gray-400">
              Powered by the Supra network for ultra-fast transactions and near-instant draw results.
            </p>
          </Card>
        </div>

        {/* Stats Section */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20 text-center transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]">
            <p className="text-4xl text-cyan-400 mb-2" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              10,000+
            </p>
            <p className="text-sm text-gray-400">Total Players</p>
          </Card>

          <Card className="glass-strong p-6 rounded-2xl border-purple-500/20 text-center transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(168,85,247,0.25)]">
            <p className="text-4xl text-purple-400 mb-2" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              500+
            </p>
            <p className="text-sm text-gray-400">Draws Completed</p>
          </Card>

          <Card className="glass-strong p-6 rounded-2xl border-pink-500/20 text-center transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(236,72,153,0.25)]">
            <p className="text-4xl text-pink-400 mb-2" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              25M+
            </p>
            <p className="text-sm text-gray-400">SUPRA Distributed</p>
          </Card>

          <Card className="glass-strong p-6 rounded-2xl border-cyan-500/20 text-center transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]">
            <p className="text-4xl text-cyan-400 mb-2" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
              100%
            </p>
            <p className="text-sm text-gray-400">Transparent</p>
          </Card>
        </div>
      </div>
    </div>
  );
}
