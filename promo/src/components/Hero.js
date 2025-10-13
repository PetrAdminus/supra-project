import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Button } from "./ui/button";
import { Sparkles, TrendingUp, Shield } from "lucide-react";
import { useLanguage } from "./LanguageContext";
const heroCopy = {
    en: {
        badge: "Powered by Supra Network",
        titleTop: "Win with",
        titleBottom: "ElyxS",
        tagline: "Join decentralized draws and win Supra tokens. Transparent, fair, and powered by blockchain technology.",
        primaryCta: "Buy Ticket Now",
        secondaryCta: "View Draws",
        features: [
            {
                title: "High Returns",
                description: "Win big with growing prize pools",
            },
            {
                title: "Secure & Fair",
                description: "Blockchain-verified randomness",
            },
            {
                title: "Instant Payout",
                description: "Automatic winner distribution",
            },
        ],
    },
    ru: {
        badge: "На базе Supra Network",
        titleTop: "Выигрывай с",
        titleBottom: "ElyxS",
        tagline: "Участвуйте в децентрализованных розыгрышах и выигрывайте токены Supra. Прозрачность, честность и технологии блокчейна.",
        primaryCta: "Купить билет",
        secondaryCta: "Смотреть розыгрыши",
        features: [
            {
                title: "Высокие призы",
                description: "Крупные пуллы наград, растущие с каждым участником",
            },
            {
                title: "Безопасно и честно",
                description: "Случайность подтверждается блокчейном",
            },
            {
                title: "Мгновенные выплаты",
                description: "Выигрыши распределяются автоматически",
            },
        ],
    },
};
const featureIcons = [TrendingUp, Shield, Sparkles];
export function Hero() {
    const { language } = useLanguage();
    const copy = heroCopy[language];
    return (_jsxs("section", { className: "relative min-h-screen flex items-center justify-center pt-20 overflow-hidden", children: [_jsxs("div", { className: "absolute inset-0 overflow-hidden", children: [_jsx("div", { className: "absolute top-20 left-10 w-72 h-72 bg-cyan-500/20 rounded-full blur-3xl animate-pulse" }), _jsx("div", { className: "absolute bottom-20 right-10 w-96 h-96 bg-purple-600/20 rounded-full blur-3xl animate-pulse", style: { animationDelay: "1s" } }), _jsx("div", { className: "absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-pink-500/10 rounded-full blur-3xl animate-pulse", style: { animationDelay: "2s" } })] }), _jsx("div", { className: "container mx-auto px-6 relative z-10", children: _jsxs("div", { className: "max-w-4xl mx-auto text-center", children: [_jsxs("div", { className: "inline-flex items-center gap-2 glass px-4 py-2 rounded-full mb-6 glow-purple", children: [_jsx(Sparkles, { className: "w-4 h-4 text-cyan-400" }), _jsx("span", { className: "text-sm text-gray-300", children: copy.badge })] }), _jsxs("h1", { className: "text-6xl md:text-8xl mb-6 bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 bg-clip-text text-transparent", style: { fontFamily: "Orbitron, sans-serif", fontWeight: 800 }, children: [copy.titleTop, _jsx("br", {}), copy.titleBottom] }), _jsx("p", { className: "text-xl md:text-2xl text-gray-300 mb-12 max-w-2xl mx-auto", children: copy.tagline }), _jsxs("div", { className: "flex flex-col sm:flex-row items-center justify-center gap-4 mb-16", children: [_jsxs(Button, { disabled: true, className: "bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl glow-cyan transition-all", "aria-disabled": "true", children: [_jsx(Sparkles, { className: "w-5 h-5 mr-2" }), copy.primaryCta] }), _jsx(Button, { disabled: true, variant: "outline", className: "glass text-white border-cyan-400/50 hover:border-cyan-400 px-8 py-6 text-lg rounded-xl transition-all", "aria-disabled": "true", children: copy.secondaryCta })] }), _jsx("div", { className: "grid grid-cols-1 md:grid-cols-3 gap-6 max-w-3xl mx-auto", children: copy.features.map((feature, index) => {
                                const Icon = featureIcons[index];
                                return (_jsxs("div", { className: "glass-strong p-6 rounded-2xl", children: [_jsx(Icon, { className: "w-8 h-8 text-cyan-400 mb-3 mx-auto" }), _jsx("h3", { className: "text-lg mb-2 text-white", style: { fontFamily: "Orbitron, sans-serif" }, children: feature.title }), _jsx("p", { className: "text-sm text-gray-400", children: feature.description })] }, feature.title));
                            }) })] }) })] }));
}
