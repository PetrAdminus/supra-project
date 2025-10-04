import type { ReactElement } from 'react';
import { Route, Routes } from 'react-router-dom';
import { ShellLayout } from '../components/layout/ShellLayout';
import { DashboardPage } from '../features/dashboard/pages/DashboardPage';
import { TicketsPage } from '../features/tickets/pages/TicketsPage';
import { AdminPage } from '../features/admin/pages/AdminPage';
import { LogsPage } from '../features/logs/pages/LogsPage';

export function AppRoutes(): ReactElement {
  return (
    <ShellLayout>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/tickets" element={<TicketsPage />} />
        <Route path="/admin" element={<AdminPage />} />
        <Route path="/logs" element={<LogsPage />} />
      </Routes>
    </ShellLayout>
  );
}
