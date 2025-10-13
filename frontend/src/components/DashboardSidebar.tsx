import { Ticket, Trophy, History, User, Settings } from "lucide-react";

type SidebarSection = "tickets" | "draws" | "history" | "profile" | "settings";

interface DashboardSidebarProps {
  activeSection: SidebarSection;
  onSectionChange: (section: SidebarSection) => void;
}

export function DashboardSidebar({ activeSection, onSectionChange }: DashboardSidebarProps) {
  const menuItems = [
    {
      id: "tickets" as SidebarSection,
      label: "Tickets",
      icon: Ticket,
      color: "cyan",
    },
    {
      id: "draws" as SidebarSection,
      label: "Draws",
      icon: Trophy,
      color: "purple",
    },
    {
      id: "history" as SidebarSection,
      label: "History",
      icon: History,
      color: "pink",
    },
    {
      id: "profile" as SidebarSection,
      label: "Profile",
      icon: User,
      color: "cyan",
    },
    {
      id: "settings" as SidebarSection,
      label: "Settings",
      icon: Settings,
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

  return (
    <aside className="w-64 glass-strong rounded-2xl p-6 border-cyan-500/20 h-fit sticky top-24">
      {/* Sidebar Header */}
      <div className="mb-8">
        <h3 className="text-xl text-white mb-2" style={{ fontFamily: 'Orbitron, sans-serif' }}>
          Dashboard
        </h3>
        <p className="text-sm text-gray-400">Manage your lottery experience</p>
      </div>

      {/* Menu Items */}
      <nav className="space-y-2">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeSection === item.id;
          
          return (
            <button
              key={item.id}
              onClick={() => onSectionChange(item.id)}
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
  );
}
