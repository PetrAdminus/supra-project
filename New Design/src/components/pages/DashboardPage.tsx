import { Trophy, Wallet, Ticket, History, User } from "lucide-react";
import { useState } from "react";
import { WalletContent } from "./dashboard/WalletContent";
import { TicketsContent } from "./dashboard/TicketsContent";
import { DrawsContent } from "./dashboard/DrawsContent";
import { HistoryContent } from "./dashboard/HistoryContent";
import { ProfileContent } from "./dashboard/ProfileContent";

type DashboardSection = "wallet" | "tickets" | "draws" | "history" | "profile";

export function DashboardPage() {
  const [activeSection, setActiveSection] = useState<DashboardSection>("wallet");

  const menuItems = [
    {
      id: "wallet" as DashboardSection,
      label: "Account",
      icon: Wallet,
      color: "cyan",
    },
    {
      id: "tickets" as DashboardSection,
      label: "Tickets",
      icon: Ticket,
      color: "purple",
    },
    {
      id: "draws" as DashboardSection,
      label: "Draws",
      icon: Trophy,
      color: "pink",
    },
    {
      id: "history" as DashboardSection,
      label: "History",
      icon: History,
      color: "cyan",
    },
    {
      id: "profile" as DashboardSection,
      label: "Profile",
      icon: User,
      color: "purple",
    },
  ];

  const getColorClasses = (color: string, isActive: boolean) => {
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

  const getIconColorClass = (color: string, isActive: boolean) => {
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
        return <WalletContent />;
      case "tickets":
        return <TicketsContent />;
      case "draws":
        return <DrawsContent />;
      case "history":
        return <HistoryContent />;
      case "profile":
        return <ProfileContent />;
      default:
        return <WalletContent />;
    }
  };

  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="text-center mb-12">
          <h2 className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent" style={{ fontFamily: 'Orbitron, sans-serif', fontWeight: 700 }}>
            Dashboard
          </h2>
          <p className="text-lg text-gray-400">Manage your lottery experience</p>
        </div>

        {/* Dashboard Layout with Sidebar */}
        <div className="flex gap-6">
          {/* Left Sidebar */}
          <aside className="w-64 glass-strong rounded-2xl p-6 border-cyan-500/20 h-fit sticky top-24">
            {/* Sidebar Header */}
            <div className="mb-8">
              <h3 className="text-xl text-white mb-2" style={{ fontFamily: 'Orbitron, sans-serif' }}>
                Menu
              </h3>
              <p className="text-sm text-gray-400">Navigate dashboard sections</p>
            </div>

            {/* Menu Items */}
            <nav className="space-y-2">
              {menuItems.map((item) => {
                const Icon = item.icon;
                const isActive = activeSection === item.id;
                
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveSection(item.id)}
                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group border ${getColorClasses(
                      item.color,
                      isActive
                    )}`}
                  >
                    <Icon className={`w-5 h-5 transition-colors ${getIconColorClass(item.color, isActive)}`} />
                    <span className="transition-colors">{item.label}</span>
                  </button>
                );
              })}
            </nav>

            {/* Sidebar Footer */}
            <div className="mt-8 pt-6 border-t border-gray-700">
              <div className="glass p-4 rounded-xl">
                <p className="text-xs text-gray-400 mb-2">Need help?</p>
                <a
                  href="#support"
                  className="text-sm text-cyan-400 hover:text-cyan-300 transition-colors"
                >
                  Visit Support Center
                </a>
              </div>
            </div>
          </aside>

          {/* Main Content */}
          <div className="flex-1">
            {renderContent()}
          </div>
        </div>
      </div>
    </div>
  );
}
