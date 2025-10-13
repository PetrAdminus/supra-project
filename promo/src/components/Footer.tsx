import { MessageCircle, Send, Twitter, Github } from "lucide-react";
import logoImage from "../assets/ba8a84f656f04b98f69152f497e1e1a3743c7fc3.png";
import { useLanguage } from "./LanguageContext";

const footerCopy = {
  en: {
    description:
      "Decentralized lottery powered by Supra Network. Fair, transparent, and secure.",
    communityHeading: "Join Our Community",
    rights: "© 2025 ElyxS. All rights reserved.",
  },
  ru: {
    description:
      "Децентрализованная лотерея на Supra Network. Честно, прозрачно и безопасно.",
    communityHeading: "Присоединяйтесь к сообществу",
    rights: "© 2025 ElyxS. Все права защищены.",
  },
} as const;

export function Footer() {
  const { language } = useLanguage();
  const copy = footerCopy[language];

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
              <span
                className="text-2xl font-bold bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent"
                style={{ fontFamily: "Orbitron, sans-serif" }}
              >
                ElyxS
              </span>
            </div>
            <p className="text-gray-400 text-sm max-w-xs text-center md:text-left">
              {copy.description}
            </p>
          </div>

          {/* Community Links */}
          <div className="flex flex-col items-center md:items-end gap-4">
            <h4
              className="text-lg text-white"
              style={{ fontFamily: "Orbitron, sans-serif" }}
            >
              {copy.communityHeading}
            </h4>
            <div className="flex items-center gap-4">
              <span
                aria-disabled="true"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none"
              >
                <MessageCircle className="w-5 h-5 text-cyan-400" />
              </span>
              <span
                aria-disabled="true"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none"
              >
                <Send className="w-5 h-5 text-purple-400" />
              </span>
              <a
                href="https://twitter.com/supra"
                target="_blank"
                rel="noopener noreferrer"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center glow-pink promo-twitter-link"
              >
                <Twitter className="w-5 h-5 text-pink-400" />
              </a>
              <span
                aria-disabled="true"
                className="glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none"
              >
                <Github className="w-5 h-5 text-cyan-400" />
              </span>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-12 pt-8 border-t border-gray-800 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-gray-500 text-sm">{copy.rights}</p>
          <div className="flex items-center gap-6 text-sm opacity-40">
            <span aria-disabled="true">
              {language === "en"
                ? "Privacy Policy"
                : "Политика конфиденциальности"}
            </span>
            <span aria-disabled="true">
              {language === "en" ? "Terms of Service" : "Условия использования"}
            </span>
            <span aria-disabled="true">
              {language === "en" ? "Documentation" : "Документация"}
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}
