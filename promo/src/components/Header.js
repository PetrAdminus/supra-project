import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Wallet, Globe, ChevronDown } from "lucide-react";
import { Button } from "./ui/button";
import { useState } from "react";
import logoImage from "../assets/ba8a84f656f04b98f69152f497e1e1a3743c7fc3.png";
import { useLanguage } from "./LanguageContext";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, } from "./ui/dropdown-menu";
export function Header({ currentPage, onNavigate }) {
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
    ];
    const languages = [
        { code: "en", name: "English", flag: "en", href: "/" },
        { code: "ru", name: "Русский", flag: "🇷🇺", href: "/ru/" },
    ];
    const currentLanguage = languages.find((lang) => lang.code === language) ?? languages[0];
    const handleLanguageSelect = (langCode) => {
        if (language === langCode.code) {
            return;
        }
        setLanguage(langCode.code);
        if (typeof window !== "undefined") {
            window.location.href = langCode.href;
        }
    };
    return (_jsx("header", { className: "fixed top-0 left-0 right-0 z-50 glass-strong", children: _jsx("div", { className: "container mx-auto px-6 py-4", children: _jsxs("div", { className: "flex items-center justify-between", children: [_jsxs("button", { type: "button", onClick: () => onNavigate("home"), className: "flex items-center gap-3 hover:opacity-80 transition-opacity", children: [_jsx("img", { src: logoImage, alt: "ElyxS Logo", className: "w-10 h-10" }), _jsx("span", { className: "text-4xl font-bold bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent", style: { fontFamily: "Orbitron, sans-serif" }, children: "ElyxS" })] }), _jsx("nav", { className: "hidden md:flex items-center gap-8", children: navItems.map((item) => {
                            const isActive = currentPage === item.id;
                            const baseStyles = item.disabled
                                ? "text-gray-500 cursor-not-allowed"
                                : "text-gray-300 hover:text-cyan-400 cursor-pointer";
                            return (_jsx("button", { type: "button", onClick: () => !item.disabled && onNavigate(item.id), className: `transition-colors ${isActive ? "text-cyan-400" : baseStyles}`, "aria-disabled": item.disabled, tabIndex: item.disabled ? -1 : 0, children: item.label }, item.id));
                        }) }), _jsxs("div", { className: "flex items-center gap-4", children: [_jsxs(DropdownMenu, { children: [_jsx(DropdownMenuTrigger, { asChild: true, children: _jsxs(Button, { variant: "ghost", className: "glass text-white border-cyan-500/30 hover:border-cyan-400/50 px-3 py-2 rounded-xl transition-all flex items-center gap-2", children: [_jsx(Globe, { className: "w-4 h-4 text-cyan-400" }), _jsx("span", { className: "text-sm", children: currentLanguage.flag }), _jsx(ChevronDown, { className: "w-3 h-3 text-gray-400" })] }) }), _jsx(DropdownMenuContent, { align: "end", className: "glass-strong border-cyan-500/30 rounded-xl p-2 min-w-[180px]", children: languages.map((lang) => (_jsxs(DropdownMenuItem, { onClick: () => handleLanguageSelect(lang), className: `flex items-center gap-3 px-4 py-2 rounded-lg transition-all ${language === lang.code
                                                ? "bg-cyan-500/20 text-cyan-400"
                                                : "text-gray-300 hover:bg-white/10 hover:text-white"}`, children: [_jsx("span", { className: "text-lg", children: lang.flag }), _jsx("span", { className: "text-sm", children: lang.name }), language === lang.code && (_jsx("span", { className: "ml-auto w-2 h-2 rounded-full bg-cyan-400 animate-pulse" }))] }, lang.code))) })] }), _jsxs(Button, { disabled: true, onClick: handleConnect, className: "bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-6 py-2 rounded-xl glow-cyan transition-all", "aria-disabled": "true", children: [_jsx(Wallet, { className: "w-4 h-4 mr-2" }), isConnected ? "0x1a2b...3c4d" : t("connectWallet")] })] })] }) }) }));
}
