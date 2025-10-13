type SidebarSection = "tickets" | "draws" | "history" | "profile" | "settings";
interface DashboardSidebarProps {
    activeSection: SidebarSection;
    onSectionChange: (section: SidebarSection) => void;
}
export declare function DashboardSidebar({ activeSection, onSectionChange }: DashboardSidebarProps): import("react/jsx-runtime").JSX.Element;
export {};
