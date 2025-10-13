import { Header } from "./Header";
import { Footer } from "./Footer";

interface LayoutProps {
  children: React.ReactNode;
  currentPage: string;
  onNavigate: (page: string) => void;
}

export function Layout({ children, currentPage, onNavigate }: LayoutProps) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0a0118] via-[#1a0b2e] to-[#0f0520] text-white overflow-x-hidden">
      {/* Animated grid background */}
      <div className="fixed inset-0 z-0 opacity-20">
        <div className="absolute inset-0" style={{
          backgroundImage: `
            linear-gradient(rgba(0, 255, 255, 0.1) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0, 255, 255, 0.1) 1px, transparent 1px)
          `,
          backgroundSize: '50px 50px'
        }}></div>
      </div>

      {/* Main content */}
      <div className="relative z-10">
        <Header currentPage={currentPage} onNavigate={onNavigate} />
        <main className="min-h-screen">
          {children}
        </main>
        <Footer />
      </div>
    </div>
  );
}
