import { Wallet, Globe, ChevronDown } from "lucide-react";
import { Button } from "./ui/button";
import { useState } from "react";
import logoImage from "../assets/ba8a84f656f04b98f69152f497e1e1a3743c7fc3.png";
import { useLanguage } from "./LanguageContext";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";

interface HeaderProps {
  currentPage: string;
  onNavigate: (page: string) => void;
}

export function Header({ currentPage, onNavigate }: HeaderProps) {
  const [isConnected, setIsConnected] = useState(false);
  const { language, setLanguage, t } = useLanguage();

  const handleConnect = () => {
    setIsConnected(!isConnected);
  };

  const navItems = [
    { id: "home", label: t("home"), disabled: false },
    { id: "dashboard", label: t("dashboard"), disabled: true },
    { id: "about", label: t("about"), disabled: false },
    { id: "support", label: t("support"), disabled: true },
  ] as const;

  const languages = [
    { code: "en" as const, name: "English", flag: "en", href: "/" },
    { code: "ru" as const, name: "Русский", flag: "🇷🇺", href: "/ru/" },
  ];

  const currentLanguage =
    languages.find((lang) => lang.code === language) ?? languages[0];

  const handleLanguageSelect = (langCode: (typeof languages)[number]) => {
    if (language === langCode.code) {
      return;
    }

    setLanguage(langCode.code);
    if (typeof window !== "undefined") {
      window.location.href = langCode.href;
    }
  };

  return (
    <header className="fixed top-0 left-0 right-0 z-50 glass-strong">
      <div className="container mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <button
            type="button"
            onClick={() => onNavigate("home")}
            className="flex items-center gap-3 hover:opacity-80 transition-opacity"
          >
            <img src={logoImage} alt="ElyxS Logo" className="w-10 h-10" />
            <span
              className="text-4xl font-bold bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent"
              style={{ fontFamily: "Orbitron, sans-serif" }}
            >
              ElyxS
            </span>
          </button>

          {/* Navigation */}
          <nav className="hidden md:flex items-center gap-8">
            {navItems.map((item) => {
              const isActive = currentPage === item.id;
              const baseStyles = item.disabled
                ? "text-gray-500 cursor-not-allowed"
                : "text-gray-300 hover:text-cyan-400 cursor-pointer";

              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => !item.disabled && onNavigate(item.id)}
                  className={`transition-colors ${
                    isActive ? "text-cyan-400" : baseStyles
                  }`}
                  aria-disabled={item.disabled}
                  tabIndex={item.disabled ? -1 : 0}
                >
                  {item.label}
                </button>
              );
            })}
          </nav>

          {/* Right Side - Language Selector & Connect Wallet */}
          <div className="flex items-center gap-4">
            {/* Language Selector */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  className="glass text-white border-cyan-500/30 hover:border-cyan-400/50 px-3 py-2 rounded-xl transition-all flex items-center gap-2"
                >
                  <Globe className="w-4 h-4 text-cyan-400" />
                  <span className="text-sm">{currentLanguage.flag}</span>
                  <ChevronDown className="w-3 h-3 text-gray-400" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent
                align="end"
                className="glass-strong border-cyan-500/30 rounded-xl p-2 min-w-[180px]"
              >
                {languages.map((lang) => (
                  <DropdownMenuItem
                    key={lang.code}
                    onClick={() => handleLanguageSelect(lang)}
                    className={`flex items-center gap-3 px-4 py-2 rounded-lg transition-all ${
                      language === lang.code
                        ? "bg-cyan-500/20 text-cyan-400"
                        : "text-gray-300 hover:bg-white/10 hover:text-white"
                    }`}
                  >
                    <span className="text-lg">{lang.flag}</span>
                    <span className="text-sm">{lang.name}</span>
                    {language === lang.code && (
                      <span className="ml-auto w-2 h-2 rounded-full bg-cyan-400 animate-pulse"></span>
                    )}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Connect Wallet Button */}
            <Button
              disabled
              onClick={handleConnect}
              className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-6 py-2 rounded-xl glow-cyan transition-all"
              aria-disabled="true"
            >
              <Wallet className="w-4 h-4 mr-2" />
              {isConnected ? "0x1a2b...3c4d" : t("connectWallet")}
            </Button>
          </div>
        </div>
      </div>
    </header>
  );
}
