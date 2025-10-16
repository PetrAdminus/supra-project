import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Wallet, Check, Copy, Send, MessageCircle, Bot } from "lucide-react";
import { Card } from "../../ui/card";
import { Button } from "../../ui/button";
import { useState, useRef, useEffect } from "react";
import { Input } from "../../ui/input";
import { Avatar, AvatarFallback } from "../../ui/avatar";
const initialMessages = [
    { id: 1, text: "Hello! How can I help you today?", sender: "support", timestamp: "10:00 AM" },
    { id: 2, text: "Hi! I have a question about withdrawals.", sender: "user", timestamp: "10:02 AM" },
    { id: 3, text: "I'd be happy to help! Withdrawals are processed instantly via smart contracts. What would you like to know?", sender: "support", timestamp: "10:02 AM" },
];
export function WalletContent() {
    const [copied, setCopied] = useState(false);
    const [messages, setMessages] = useState(initialMessages);
    const [inputMessage, setInputMessage] = useState("");
    const scrollRef = useRef(null);
    const walletAddress = "0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r";
    const handleCopy = () => {
        navigator.clipboard.writeText(walletAddress);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };
    const handleSendMessage = () => {
        if (!inputMessage.trim())
            return;
        const newMessage = {
            id: messages.length + 1,
            text: inputMessage,
            sender: "user",
            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        };
        setMessages([...messages, newMessage]);
        setInputMessage("");
        // Simulate support response
        setTimeout(() => {
            const supportMessage = {
                id: messages.length + 2,
                text: "Thank you for your message! Our team will get back to you shortly.",
                sender: "support",
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            };
            setMessages((prev) => [...prev, supportMessage]);
        }, 1000);
    };
    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [messages]);
    return (_jsxs("div", { children: [_jsxs("div", { className: "mb-8", children: [_jsx("h3", { className: "text-3xl mb-2 text-white", style: { fontFamily: 'Orbitron, sans-serif' }, children: "Account" }), _jsx("p", { className: "text-gray-400", children: "Manage your account and chat with support" })] }), _jsxs(Card, { className: "glass-strong p-8 rounded-2xl border-cyan-500/30 glow-cyan mb-8", children: [_jsx("div", { className: "flex flex-col md:flex-row items-start md:items-center justify-between gap-6 mb-6", children: _jsxs("div", { className: "flex items-center gap-4", children: [_jsx("div", { className: "w-16 h-16 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center", children: _jsx(Wallet, { className: "w-8 h-8 text-white" }) }), _jsxs("div", { children: [_jsx("p", { className: "text-sm text-gray-400 mb-1", children: "Wallet Connected" }), _jsxs("div", { className: "flex items-center gap-2", children: [_jsxs("code", { className: "text-lg text-cyan-400 bg-cyan-500/10 px-3 py-1 rounded", children: [walletAddress.substring(0, 10), "...", walletAddress.substring(walletAddress.length - 8)] }), _jsx(Button, { onClick: handleCopy, variant: "ghost", size: "sm", className: "text-gray-400 hover:text-cyan-400", children: copied ? _jsx(Check, { className: "w-4 h-4" }) : _jsx(Copy, { className: "w-4 h-4" }) })] })] })] }) }), _jsxs("div", { className: "grid grid-cols-1 md:grid-cols-3 gap-6", children: [_jsxs("div", { children: [_jsx("p", { className: "text-sm text-gray-400 mb-2", children: "Balance" }), _jsx("p", { className: "text-3xl text-cyan-400", style: { fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }, children: "2,450 SUPRA" })] }), _jsxs("div", { children: [_jsx("p", { className: "text-sm text-gray-400 mb-2", children: "Network" }), _jsxs("div", { className: "flex items-center gap-2", children: [_jsx("div", { className: "w-3 h-3 rounded-full bg-green-500 animate-pulse" }), _jsx("p", { className: "text-lg text-white", children: "Supra Mainnet" })] })] }), _jsxs("div", { children: [_jsx("p", { className: "text-sm text-gray-400 mb-2", children: "Gas Fee" }), _jsx("p", { className: "text-lg text-purple-400", style: { fontFamily: 'Orbitron, sans-serif' }, children: "~0.001 SUPRA" })] })] })] }), _jsxs(Card, { className: "glass-strong p-6 rounded-2xl border-cyan-500/30 glow-cyan flex flex-col", children: [_jsxs("div", { className: "flex items-center gap-3 pb-4 border-b border-cyan-500/30 mb-4", children: [_jsx("div", { className: "w-12 h-12 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center", children: _jsx(Bot, { className: "w-6 h-6 text-white" }) }), _jsxs("div", { className: "flex-1", children: [_jsx("h4", { className: "text-xl text-white", style: { fontFamily: 'Orbitron, sans-serif' }, children: "Support Chat" }), _jsxs("div", { className: "flex items-center gap-2", children: [_jsx("div", { className: "w-2 h-2 rounded-full bg-green-500 animate-pulse" }), _jsx("p", { className: "text-sm text-gray-400", children: "Online" })] })] }), _jsx(MessageCircle, { className: "w-5 h-5 text-cyan-400" })] }), _jsx("div", { ref: scrollRef, className: "flex-1 space-y-4 overflow-y-auto mb-4 pr-2", style: { maxHeight: '500px' }, children: messages.map((message) => (_jsxs("div", { className: `flex items-end gap-3 ${message.sender === "user" ? "flex-row-reverse" : "flex-row"}`, children: [_jsx(Avatar, { className: `w-8 h-8 ${message.sender === "support"
                                        ? "bg-gradient-to-br from-cyan-500 to-purple-600"
                                        : "bg-gradient-to-br from-purple-500 to-pink-500"}`, children: _jsx(AvatarFallback, { className: "text-white text-xs", children: message.sender === "support" ? "AI" : "You" }) }), _jsxs("div", { className: `max-w-[75%] ${message.sender === "user"
                                        ? "bg-gradient-to-br from-purple-500/30 to-pink-500/30 border-purple-400/30"
                                        : "glass border-cyan-500/30"} backdrop-blur-xl border rounded-2xl px-4 py-3`, children: [_jsx("p", { className: "text-sm text-white leading-relaxed", children: message.text }), _jsx("p", { className: "text-xs text-gray-400 mt-1", children: message.timestamp })] })] }, message.id))) }), _jsxs("div", { className: "flex items-center gap-3", children: [_jsx(Input, { value: inputMessage, onChange: (e) => setInputMessage(e.target.value), onKeyPress: (e) => e.key === "Enter" && handleSendMessage(), placeholder: "Type your message...", className: "flex-1 glass border-cyan-500/30 text-white placeholder:text-gray-500 focus:border-cyan-400 rounded-xl" }), _jsx(Button, { onClick: handleSendMessage, className: "bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white rounded-xl glow-cyan px-4", children: _jsx(Send, { className: "w-5 h-5" }) })] })] })] }));
}
