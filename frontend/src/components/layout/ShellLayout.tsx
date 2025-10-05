import type { ChangeEvent, ReactElement, ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { useUiStore } from "../../store/uiStore";
import { WalletPanel } from "../../features/wallet/WalletPanel";
import { useI18n } from "../../i18n/useI18n";
import { locales, type Locale } from "../../i18n/locales";
import "./ShellLayout.css";

const navItems = [
  { to: "/", role: "user" as const, labelKey: "layout.nav.dashboard" },
  { to: "/tickets", role: "user" as const, labelKey: "layout.nav.tickets" },
  { to: "/admin", role: "admin" as const, labelKey: "layout.nav.admin" },
  { to: "/logs", role: "user" as const, labelKey: "layout.nav.logs" },
] as const;

interface ShellLayoutProps {
  children: ReactNode;
}

export function ShellLayout({ children }: ShellLayoutProps): ReactElement {
  const apiMode = useUiStore((state) => state.apiMode);
  const setApiMode = useUiStore((state) => state.setApiMode);
  const role = useUiStore((state) => state.role);
  const setRole = useUiStore((state) => state.setRole);
  const { t, locale, setLocale } = useI18n();

  const handleModeChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setApiMode(event.target.value as typeof apiMode);
  };

  const handleRoleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setRole(event.target.value as typeof role);
  };

  const handleLocaleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setLocale(event.target.value as Locale);
  };

  const modeOptions = [
    { value: "mock" as const, label: t("layout.mode.mock") },
    { value: "supra" as const, label: t("layout.mode.supra") },
  ];

  const roleOptions = [
    { value: "user" as const, label: t("layout.role.user") },
    { value: "admin" as const, label: t("layout.role.admin") },
  ];

  return (
    <div className="app-shell">
      <header className="app-shell__header">
        <div>
          <h2>{t("layout.title")}</h2>
          <p>{t("layout.subtitle")}</p>
        </div>
        <div className="app-shell__right">
          <div className="app-shell__controls">
            <label className="app-shell__mode-label" htmlFor="app-mode">
              {t("layout.modeLabel")}
            </label>
            <select
              id="app-mode"
              className="app-shell__mode-select"
              value={apiMode}
              onChange={handleModeChange}
            >
              {modeOptions.map(({ value, label }) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="app-shell__controls">
            <label className="app-shell__mode-label" htmlFor="app-role">
              {t("layout.roleLabel")}
            </label>
            <select
              id="app-role"
              className="app-shell__mode-select"
              value={role}
              onChange={handleRoleChange}
            >
              {roleOptions.map(({ value, label }) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="app-shell__controls">
            <label className="app-shell__mode-label" htmlFor="app-locale">
              {t("layout.localeLabel")}
            </label>
            <select
              id="app-locale"
              className="app-shell__mode-select"
              value={locale}
              onChange={handleLocaleChange}
            >
              {locales.map((value) => (
                <option key={value} value={value}>
                  {t(`layout.locale.${value}`)}
                </option>
              ))}
            </select>
          </div>
          <WalletPanel />
        </div>
      </header>
      <div className="app-shell__body">
        <nav className="app-shell__nav">
          <ul>
            {navItems
              .filter((item) => (item.role === "admin" ? role === "admin" : true))
              .map((item) => (
                <li key={item.to}>
                  <NavLink
                    to={item.to}
                    className={({ isActive }) =>
                      isActive ? "nav-link nav-link--active" : "nav-link"
                    }
                    end
                  >
                    {t(item.labelKey)}
                  </NavLink>
                </li>
              ))}
          </ul>
        </nav>
        <main className="app-shell__content">{children}</main>
      </div>
    </div>
  );
}
