import type { ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { Layout } from "./components/Layout";
import { HomePage } from "./components/pages/HomePage";
import { DashboardPage } from "./components/pages/DashboardPage";
import { AboutPage } from "./components/pages/AboutPage";
import { SupportPage } from "./components/pages/SupportPage";
import { LanguageProvider } from "./components/LanguageContext";
import { AppQueryProvider } from "./app/providers/QueryProvider";

const pagePathMap = {
  home: "/",
  dashboard: "/dashboard",
  about: "/about",
  support: "/support",
} as const;

type PageKey = keyof typeof pagePathMap;

function LayoutRoute({ page, children }: { page: PageKey; children: ReactNode }) {
  const navigate = useNavigate();
  const location = useLocation();

  const handleNavigate = (target: string) => {
    const targetPath = pagePathMap[target as PageKey] ?? pagePathMap.home;
    if (location.pathname !== targetPath) {
      navigate(targetPath);
    }
  };

  return (
    <Layout currentPage={page} onNavigate={handleNavigate}>
      {children}
    </Layout>
  );
}

export default function App() {
  return (
    <AppQueryProvider>
      <LanguageProvider>
        <BrowserRouter>
          <Routes>
            <Route
              path={pagePathMap.home}
              element={
                <LayoutRoute page="home">
                  <HomePage />
                </LayoutRoute>
              }
            />
            <Route
              path={pagePathMap.dashboard}
              element={
                <LayoutRoute page="dashboard">
                  <DashboardPage />
                </LayoutRoute>
              }
            />
            <Route
              path={pagePathMap.about}
              element={
                <LayoutRoute page="about">
                  <AboutPage />
                </LayoutRoute>
              }
            />
            <Route
              path={pagePathMap.support}
              element={
                <LayoutRoute page="support">
                  <SupportPage />
                </LayoutRoute>
              }
            />
            <Route path="*" element={<Navigate to={pagePathMap.home} replace />} />
          </Routes>
        </BrowserRouter>
      </LanguageProvider>
    </AppQueryProvider>
  );
}
