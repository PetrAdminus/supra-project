import type { ChangeEvent, ReactElement, ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { Wallet } from "lucide-react";
import clsx from "clsx";
import "./ElyxsLayout.css";
import { useUiStore, type LayoutVariant } from "../../store/uiStore";
import { WalletPanel } from "../../features/wallet/WalletPanel";
import { useI18n } from "../../i18n/useI18n";
import { locales, type Locale } from "../../i18n/locales";

const navItems = [
  { to: "/", role: "user" as const, labelKey: "layout.nav.dashboard" },
  { to: "/tickets", role: "user" as const, labelKey: "layout.nav.tickets" },
  { to: "/fairness", role: "user" as const, labelKey: "layout.nav.fairness" },
  { to: "/profile", role: "user" as const, labelKey: "layout.nav.profile" },
  { to: "/progress", role: "user" as const, labelKey: "layout.nav.progress" },
  { to: "/admin", role: "admin" as const, labelKey: "layout.nav.admin" },
  { to: "/logs", role: "user" as const, labelKey: "layout.nav.logs" },
] as const;

const layoutVariants: Record<LayoutVariant, string> = {
  classic: "Classic",
  elyxs: "ElyxS",
};

interface ElyxsLayoutProps {
  children: ReactNode;
}

export function ElyxsLayout({ children }: ElyxsLayoutProps): ReactElement {
  const apiMode = useUiStore((state) => state.apiMode);
  const setApiMode = useUiStore((state) => state.setApiMode);
  const role = useUiStore((state) => state.role);
  const setRole = useUiStore((state) => state.setRole);
  const layoutVariant = useUiStore((state) => state.layoutVariant);
  const setLayoutVariant = useUiStore((state) => state.setLayoutVariant);
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

  const handleVariantChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setLayoutVariant(event.target.value as LayoutVariant);
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
    <div className="elyx-layout">
      <div className="elyx-layout__background" />
      <header className="elyx-header">
        <div className="elyx-header__inner">
          <NavLink to="/" className="elyx-header__logo">
            <span className="elyx-header__logo-mark">
              <Wallet size={20} />
            </span>
            <span className="elyx-header__logo-text">ElyxS</span>
          </NavLink>

          <nav className="elyx-header__nav">
            {navItems
              .filter((item) => (item.role === "admin" ? role === "admin" : true))
              .map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end
                  className={({ isActive }) =>
                    clsx("elyx-header__nav-item", isActive && "elyx-header__nav-item--active")
                  }
                >
                  {t(item.labelKey)}
                </NavLink>
              ))}
          </nav>

          <div className="elyx-header__controls">
            <select
              aria-label={t("layout.modeLabel")}
              className="elyx-select"
              value={apiMode}
              onChange={handleModeChange}
            >
              {modeOptions.map(({ value, label }) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>

            <select
              aria-label={t("layout.roleLabel")}
              className="elyx-select"
              value={role}
              onChange={handleRoleChange}
            >
              {roleOptions.map(({ value, label }) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>

            <select
              aria-label={t("layout.localeLabel")}
              className="elyx-select"
              value={locale}
              onChange={handleLocaleChange}
            >
              {locales.map((value) => (
                <option key={value} value={value}>
                  {t(`layout.locale.${value}`)}
                </option>
              ))}
            </select>

            <select
              aria-label="Layout variant"
              className="elyx-select"
              value={layoutVariant}
              onChange={handleVariantChange}
            >
              {(Object.keys(layoutVariants) as LayoutVariant[]).map((variant) => (
                <option key={variant} value={variant}>
                  {layoutVariants[variant]}
                </option>
              ))}
            </select>

            <WalletPanel />
          </div>
        </div>
      </header>

      <main className="elyx-main">
        <div className="elyx-main__inner">{children}</div>
      </main>

      <footer className="elyx-footer">
        <div className="elyx-footer__inner">
          <span>© {new Date().getFullYear()} ElyxS on Supra Network</span>
          <span>{t("layout.subtitle")}</span>
        </div>
      </footer>
    </div>
  );
}
