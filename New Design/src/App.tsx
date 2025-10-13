import { useState } from "react";
import { Layout } from "./components/Layout";
import { HomePage } from "./components/pages/HomePage";
import { DashboardPage } from "./components/pages/DashboardPage";
import { AboutPage } from "./components/pages/AboutPage";
import { SupportPage } from "./components/pages/SupportPage";
import { LanguageProvider } from "./components/LanguageContext";

export default function App() {
  const [currentPage, setCurrentPage] = useState("home");

  const renderPage = () => {
    switch (currentPage) {
      case "home":
        return <HomePage />;
      case "dashboard":
        return <DashboardPage />;
      case "about":
        return <AboutPage />;
      case "support":
        return <SupportPage />;
      default:
        return <HomePage />;
    }
  };

  return (
    <LanguageProvider>
      <Layout
        currentPage={currentPage}
        onNavigate={setCurrentPage}
      >
        {renderPage()}
      </Layout>
    </LanguageProvider>
  );
}