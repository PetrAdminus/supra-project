import { MessageCircle, Send, Twitter, Github } from "lucide-react";
import logoImage from "figma:asset/ba8a84f656f04b98f69152f497e1e1a3743c7fc3.png";

export function Footer() {
  return (
    <footer className="relative py-16 glass-strong border-t border-cyan-500/20">
      {/* Background glow */}
      <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-96 h-32 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="flex flex-col md:flex-row items-center justify-between gap-8">
          {/* Logo and Description */}
          <div className="flex flex-col items-center md:items-start">
            <div className="flex items-center gap-3 mb-3">
              <img src={logoImage} alt="ElyxS Logo" className="w-10 h-10" />
              <span className="text-2xl font-bold bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                ElyxS
              </span>
            </div>
            <p className="text-gray-400 text-sm max-w-xs text-center md:text-left">
              Decentralized lottery powered by Supra Network. Fair, transparent, and secure.
            </p>
          </div>

          {/* Community Links */}
          <div className="flex flex-col items-center md:items-end gap-4">
            <h4 className="text-lg text-white" style={{ fontFamily: 'Orbitron, sans-serif' }}>
              Join Our Community
            </h4>
            <div className="flex items-center gap-4">
              <a
                href="https://discord.gg/supra"
                target="_blank"
                rel="noopener noreferrer"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center hover:bg-cyan-500/20 hover:border-cyan-400/50 transition-all glow-cyan"
              >
                <MessageCircle className="w-5 h-5 text-cyan-400" />
              </a>
              <a
                href="https://t.me/supra"
                target="_blank"
                rel="noopener noreferrer"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center hover:bg-purple-500/20 hover:border-purple-400/50 transition-all glow-purple"
              >
                <Send className="w-5 h-5 text-purple-400" />
              </a>
              <a
                href="https://twitter.com/supra"
                target="_blank"
                rel="noopener noreferrer"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center hover:bg-pink-500/20 hover:border-pink-400/50 transition-all glow-pink"
              >
                <Twitter className="w-5 h-5 text-pink-400" />
              </a>
              <a
                href="https://github.com/supra"
                target="_blank"
                rel="noopener noreferrer"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center hover:bg-cyan-500/20 hover:border-cyan-400/50 transition-all"
              >
                <Github className="w-5 h-5 text-cyan-400" />
              </a>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-12 pt-8 border-t border-gray-800 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-gray-500 text-sm">
            © 2025 ElyxS. All rights reserved.
          </p>
          <div className="flex items-center gap-6 text-sm">
            <a href="#privacy" className="text-gray-400 hover:text-cyan-400 transition-colors">
              Privacy Policy
            </a>
            <a href="#terms" className="text-gray-400 hover:text-cyan-400 transition-colors">
              Terms of Service
            </a>
            <a href="#docs" className="text-gray-400 hover:text-cyan-400 transition-colors">
              Documentation
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
