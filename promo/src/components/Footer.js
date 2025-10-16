import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { MessageCircle, Send, Twitter, Github } from "lucide-react";
import logoImage from "../assets/ba8a84f656f04b98f69152f497e1e1a3743c7fc3.png";
import { useLanguage } from "./LanguageContext";
const footerCopy = {
    en: {
        description: "Decentralized lottery powered by Supra Network. Fair, transparent, and secure.",
        communityHeading: "Join Our Community",
        rights: "Copyright 2025 ElyxS. All rights reserved.",
    },
    ru: {
        description: "Децентрализованная лотерея на Supra Network. Честно, прозрачно и безопасно.",
        communityHeading: "Присоединяйтесь к сообществу",
        rights: "Copyright 2025 ElyxS. Все права защищены.",
    },
};
export function Footer() {
    const { language } = useLanguage();
    const copy = footerCopy[language];
    return (_jsxs("footer", { className: "relative py-16 glass-strong border-t border-cyan-500/20", children: [_jsx("div", { className: "absolute bottom-0 left-1/2 -translate-x-1/2 transform w-96 h-32 bg-purple-500/10 rounded-full blur-3xl" }), _jsxs("div", { className: "container mx-auto px-6 relative z-10", children: [_jsxs("div", { className: "flex flex-col md:flex-row items-center justify-between gap-8", children: [_jsxs("div", { className: "flex flex-col items-center md:items-start", children: [_jsxs("div", { className: "flex items-center gap-3 mb-3", children: [_jsx("img", { src: logoImage, alt: "ElyxS Logo", className: "w-10 h-10" }), _jsx("span", { className: "text-2xl font-bold bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent", style: { fontFamily: "Orbitron, sans-serif" }, children: "ElyxS" })] }), _jsx("p", { className: "text-gray-400 text-sm max-w-xs text-center md:text-left", children: copy.description })] }), _jsxs("div", { className: "flex flex-col items-center md:items-end gap-4", children: [_jsx("h4", { className: "text-lg text-white", style: { fontFamily: "Orbitron, sans-serif" }, children: copy.communityHeading }), _jsxs("div", { className: "flex items-center gap-4", children: [_jsx("span", { "aria-disabled": "true", className: "glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none", children: _jsx(MessageCircle, { className: "w-5 h-5 text-cyan-400" }) }), _jsx("span", { "aria-disabled": "true", className: "glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none", children: _jsx(Send, { className: "w-5 h-5 text-purple-400" }) }), _jsx("a", { href: "https://x.com/elyxs_lottery", target: "_blank", rel: "noopener noreferrer", className: "glass w-12 h-12 rounded-xl flex items-center justify-center glow-pink promo-twitter-link", children: _jsx(Twitter, { className: "w-5 h-5 text-pink-400" }) }), _jsx("span", { "aria-disabled": "true", className: "glass w-12 h-12 rounded-xl flex items-center justify-center transition-all opacity-40 pointer-events-none", children: _jsx(Github, { className: "w-5 h-5 text-cyan-400" }) })] })] })] }), _jsxs("div", { className: "mt-12 pt-8 border-t border-gray-800 flex flex-col gap-4 min-[420px]:flex-row min-[420px]:items-center min-[420px]:justify-between", children: [_jsx("p", { className: "order-2 text-center text-gray-500 text-sm min-[420px]:order-1 min-[420px]:text-left", children: copy.rights }), _jsxs("div", { className: "order-1 flex flex-col items-center gap-3 text-sm opacity-60 min-[420px]:order-2 min-[420px]:flex-row min-[420px]:items-center min-[420px]:gap-6 min-[420px]:opacity-40", children: [_jsx("span", { "aria-disabled": "true", children: language === "en"
                                            ? "Privacy Policy"
                                            : "Политика конфиденциальности" }), _jsx("span", { "aria-disabled": "true", children: language === "en"
                                            ? "Terms of Service"
                                            : "Условия использования" }), _jsx("span", { "aria-disabled": "true", children: language === "en" ? "Documentation" : "Документация" })] })] })] })] }));
}
