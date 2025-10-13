import { Button } from "./ui/button";
import { Sparkles, TrendingUp, Shield } from "lucide-react";

export function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center pt-20 overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-20 left-10 w-72 h-72 bg-cyan-500/20 rounded-full blur-3xl animate-pulse"></div>
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-purple-600/20 rounded-full blur-3xl animate-pulse" style={{ animationDelay: '1s' }}></div>
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-pink-500/10 rounded-full blur-3xl animate-pulse" style={{ animationDelay: '2s' }}></div>
      </div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="max-w-4xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 glass px-4 py-2 rounded-full mb-6 glow-purple">
            <Sparkles className="w-4 h-4 text-cyan-400" />
            <span className="text-sm text-gray-300">Powered by Supra Network</span>
          </div>

          {/* Main Headline */}
          <h1 className="text-6xl md:text-8xl mb-6 bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 800 }}>
            Win with
            <br />
            ElyxS
          </h1>

          {/* Tagline */}
          <p className="text-xl md:text-2xl text-gray-300 mb-12 max-w-2xl mx-auto">
            Join decentralized draws and win Supra tokens. Transparent, fair, and powered by blockchain technology.
          </p>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
            <Button className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl glow-cyan transition-all">
              <Sparkles className="w-5 h-5 mr-2" />
              Buy Ticket Now
            </Button>
            <Button variant="outline" className="glass text-white border-cyan-400/50 hover:border-cyan-400 px-8 py-6 text-lg rounded-xl transition-all">
              View Draws
            </Button>
          </div>

          {/* Features */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-3xl mx-auto">
            <div className="glass-strong p-6 rounded-2xl">
              <TrendingUp className="w-8 h-8 text-cyan-400 mb-3 mx-auto" />
              <h3 className="text-lg mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>High Returns</h3>
              <p className="text-sm text-gray-400">Win big with growing prize pools</p>
            </div>
            <div className="glass-strong p-6 rounded-2xl">
              <Shield className="w-8 h-8 text-purple-400 mb-3 mx-auto" />
              <h3 className="text-lg mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>Secure & Fair</h3>
              <p className="text-sm text-gray-400">Blockchain-verified randomness</p>
            </div>
            <div className="glass-strong p-6 rounded-2xl">
              <Sparkles className="w-8 h-8 text-pink-400 mb-3 mx-auto" />
              <h3 className="text-lg mb-2 text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>Instant Payout</h3>
              <p className="text-sm text-gray-400">Automatic winner distribution</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
