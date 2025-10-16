import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Trophy, Wallet, Ticket, History, User } from "lucide-react";
import { useState } from "react";
import { WalletContent } from "./dashboard/WalletContent";
import { TicketsContent } from "./dashboard/TicketsContent";
import { DrawsContent } from "./dashboard/DrawsContent";
import { HistoryContent } from "./dashboard/HistoryContent";
import { ProfileContent } from "./dashboard/ProfileContent";
export function DashboardPage() {
    const [activeSection, setActiveSection] = useState("wallet");
    const menuItems = [
        {
            id: "wallet",
            label: "Account",
            icon: Wallet,
            color: "cyan",
        },
        {
            id: "tickets",
            label: "Tickets",
            icon: Ticket,
            color: "purple",
        },
        {
            id: "draws",
            label: "Draws",
            icon: Trophy,
            color: "pink",
        },
        {
            id: "history",
            label: "History",
            icon: History,
            color: "cyan",
        },
        {
            id: "profile",
            label: "Profile",
            icon: User,
            color: "purple",
        },
    ];
    const getColorClasses = (color, isActive) => {
        if (isActive) {
            switch (color) {
                case "cyan":
                    return "bg-cyan-500/20 border-cyan-400/50 text-cyan-400 glow-cyan";
                case "purple":
                    return "bg-purple-500/20 border-purple-400/50 text-purple-400 glow-purple";
                case "pink":
                    return "bg-pink-500/20 border-pink-400/50 text-pink-400 glow-pink";
                default:
                    return "bg-cyan-500/20 border-cyan-400/50 text-cyan-400";
            }
        }
        return "text-gray-400 hover:text-white hover:bg-white/5";
    };
    const getIconColorClass = (color, isActive) => {
        if (isActive) {
            switch (color) {
                case "cyan":
                    return "text-cyan-400";
                case "purple":
                    return "text-purple-400";
                case "pink":
                    return "text-pink-400";
                default:
                    return "text-cyan-400";
            }
        }
        return "text-gray-400 group-hover:text-white";
    };
    const renderContent = () => {
        switch (activeSection) {
            case "wallet":
                return _jsx(WalletContent, {});
            case "tickets":
                return _jsx(TicketsContent, {});
            case "draws":
                return _jsx(DrawsContent, {});
            case "history":
                return _jsx(HistoryContent, {});
            case "profile":
                return _jsx(ProfileContent, {});
            default:
                return _jsx(WalletContent, {});
        }
    };
    return (_jsxs("div", { className: "pt-20 pb-20 relative", children: [_jsx("div", { className: "absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl" }), _jsx("div", { className: "absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl" }), _jsxs("div", { className: "container mx-auto px-6 relative z-10", children: [_jsxs("div", { className: "text-center mb-12", children: [_jsx("h2", { className: "text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent", style: { fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }, children: "Dashboard" }), _jsx("p", { className: "text-lg text-gray-400", children: "Manage your lottery experience" })] }), _jsxs("div", { className: "flex gap-6", children: [_jsxs("aside", { className: "w-64 glass-strong rounded-2xl p-6 border-cyan-500/20 h-fit sticky top-24", children: [_jsxs("div", { className: "mb-8", children: [_jsx("h3", { className: "text-xl text-white mb-2", style: { fontFamily: 'Orbitron, sans-serif' }, children: "Menu" }), _jsx("p", { className: "text-sm text-gray-400", children: "Navigate dashboard sections" })] }), _jsx("nav", { className: "space-y-2", children: menuItems.map((item) => {
                                            const Icon = item.icon;
                                            const isActive = activeSection === item.id;
                                            return (_jsxs("button", { onClick: () => setActiveSection(item.id), className: `w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group border ${getColorClasses(item.color, isActive)}`, children: [_jsx(Icon, { className: `w-5 h-5 transition-colors ${getIconColorClass(item.color, isActive)}` }), _jsx("span", { className: "transition-colors", children: item.label })] }, item.id));
                                        }) }), _jsx("div", { className: "mt-8 pt-6 border-t border-gray-700", children: _jsxs("div", { className: "glass p-4 rounded-xl", children: [_jsx("p", { className: "text-xs text-gray-400 mb-2", children: "Need help?" }), _jsx("a", { href: "#support", className: "text-sm text-cyan-400 hover:text-cyan-300 transition-colors", children: "Visit Support Center" })] }) })] }), _jsx("div", { className: "flex-1", children: renderContent() })] })] })] }));
}
