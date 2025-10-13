import type { ReactElement } from 'react';
import { Route, Routes } from 'react-router-dom';
import { ElyxsLayout } from '../components/layout/ElyxsLayout';
import { DashboardPage } from '../features/dashboard/pages/DashboardPage';
import { TicketsPage } from '../features/tickets/pages/TicketsPage';
import { AdminPage } from '../features/admin/pages/AdminPage';
import { LogsPage } from '../features/logs/pages/LogsPage';
import { FairnessPage } from '../features/fairness/pages/FairnessPage';
import { ProgressPage } from '../features/progress/pages/ProgressPage';
import { ProfilePage } from '../features/profile/pages/ProfilePage';

export function AppRoutes(): ReactElement {
  return (
    <ElyxsLayout>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/tickets" element={<TicketsPage />} />
        <Route path="/progress" element={<ProgressPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/admin" element={<AdminPage />} />
        <Route path="/logs" element={<LogsPage />} />
        <Route path="/fairness" element={<FairnessPage />} />
      </Routes>
    </ElyxsLayout>
  );
}
