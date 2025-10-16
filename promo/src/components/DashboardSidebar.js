import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Ticket, Trophy, History, User, Settings } from "lucide-react";
export function DashboardSidebar({ activeSection, onSectionChange }) {
    const menuItems = [
        {
            id: "tickets",
            label: "Tickets",
            icon: Ticket,
            color: "cyan",
        },
        {
            id: "draws",
            label: "Draws",
            icon: Trophy,
            color: "purple",
        },
        {
            id: "history",
            label: "History",
            icon: History,
            color: "pink",
        },
        {
            id: "profile",
            label: "Profile",
            icon: User,
            color: "cyan",
        },
        {
            id: "settings",
            label: "Settings",
            icon: Settings,
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
    return (_jsxs("aside", { className: "w-64 glass-strong rounded-2xl p-6 border-cyan-500/20 h-fit sticky top-24", children: [_jsxs("div", { className: "mb-8", children: [_jsx("h3", { className: "text-xl text-white mb-2", style: { fontFamily: 'Orbitron, sans-serif' }, children: "Dashboard" }), _jsx("p", { className: "text-sm text-gray-400", children: "Manage your lottery experience" })] }), _jsx("nav", { className: "space-y-2", children: menuItems.map((item) => {
                    const Icon = item.icon;
                    const isActive = activeSection === item.id;
                    return (_jsxs("button", { onClick: () => onSectionChange(item.id), className: `w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group border ${getColorClasses(item.color, isActive)}`, children: [_jsx(Icon, { className: `w-5 h-5 transition-colors ${getIconColorClass(item.color, isActive)}` }), _jsx("span", { className: "transition-colors", children: item.label })] }, item.id));
                }) }), _jsx("div", { className: "mt-8 pt-6 border-t border-gray-700", children: _jsxs("div", { className: "glass p-4 rounded-xl", children: [_jsx("p", { className: "text-xs text-gray-400 mb-2", children: "Need help?" }), _jsx("a", { href: "#support", className: "text-sm text-cyan-400 hover:text-cyan-300 transition-colors", children: "Visit Support Center" })] }) })] }));
}
