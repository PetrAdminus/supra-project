import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Header } from "./Header";
import { Footer } from "./Footer";
export function Layout({ children, currentPage, onNavigate }) {
    return (_jsxs("div", { className: "min-h-screen bg-gradient-to-br from-[#0a0118] via-[#1a0b2e] to-[#0f0520] text-white overflow-x-hidden", children: [_jsx("div", { className: "fixed inset-0 z-0 opacity-20", children: _jsx("div", { className: "absolute inset-0", style: {
                        backgroundImage: `
            linear-gradient(rgba(0, 255, 255, 0.1) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0, 255, 255, 0.1) 1px, transparent 1px)
          `,
                        backgroundSize: '50px 50px'
                    } }) }), _jsxs("div", { className: "relative z-10", children: [_jsx(Header, { currentPage: currentPage, onNavigate: onNavigate }), _jsx("main", { className: "min-h-screen pb-24 md:pb-32 pt-24 md:pt-28", children: children }), _jsx(Footer, {})] })] }));
}
