import type { ReactElement } from "react";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useAdminConfig } from "../hooks/useAdminConfig";
import { useWhitelistStatus } from "../hooks/useWhitelistStatus";
import { useUiStore } from "../../../store/uiStore";
import { GasConfigForm } from "../components/GasConfigForm";
import { VrfConfigForm } from "../components/VrfConfigForm";
import { ClientWhitelistSnapshotForm } from "../components/ClientWhitelistSnapshotForm";
import { ConsumerWhitelistSnapshotForm } from "../components/ConsumerWhitelistSnapshotForm";
import { TreasuryControlsForm } from "../components/TreasuryControlsForm";
import { TreasuryDistributionForm } from "../components/TreasuryDistributionForm";
import { useI18n } from "../../../i18n/useI18n";

function formatTimestamp(value?: string | null): string {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString();
}

const planItemKeys = [
  "admin.plan.items.first",
  "admin.plan.items.second",
  "admin.plan.items.third",
] as const;

export function AdminPage(): ReactElement {
  const role = useUiStore((state) => state.role);
  const { data: whitelistStatus, isLoading: isWhitelistLoading, error: whitelistError } = useWhitelistStatus();
  const {
    data: adminConfig,
    isLoading: isAdminConfigLoading,
    error: adminConfigError,
  } = useAdminConfig();
  const { t } = useI18n();

  if (role !== "admin") {
    return (
      <section>
        <h1>{t("admin.title")}</h1>
        <GlassCard accent="neutral" title={t("admin.accessDenied.title")}>
          <p>{t("admin.accessDenied.description")}</p>
        </GlassCard>
      </section>
    );
  }

  const whitelistAccount = whitelistStatus?.account ?? "-";
  const whitelistProfile = whitelistStatus?.profile ?? "-";
  const whitelistValue = whitelistStatus?.isWhitelisted ? t("admin.whitelisting.statusYes") : t("admin.whitelisting.statusNo");

  return (
    <section>
      <h1>{t("admin.title")}</h1>
      <div className="glass-grid glass-grid--two">
        <GlassCard
          accent="secondary"
          title={t("admin.whitelisting.title")}
          subtitle={t("admin.whitelisting.subtitle")}
          footer={<span>{t("admin.whitelisting.lastCheck", { value: formatTimestamp(whitelistStatus?.checkedAt) })}</span>}
        >
          {isWhitelistLoading && <p>{t("admin.whitelisting.loading")}</p>}
          {whitelistError && <p>{t("admin.whitelisting.error")}</p>}
          {whitelistStatus && (
            <ul>
              <li>{t("admin.whitelisting.profile", { profile: whitelistProfile })}</li>
              <li>{t("admin.whitelisting.account", { account: whitelistAccount })}</li>
              <li>{t("admin.whitelisting.status", { value: whitelistValue })}</li>
            </ul>
          )}
          <p>{t("admin.whitelisting.hint")}</p>
        </GlassCard>

        <GlassCard accent="neutral" title={t("admin.plan.title")} subtitle={t("admin.plan.subtitle")}>
          <ul>
            {planItemKeys.map((key) => (
              <li key={key}>{t(key)}</li>
            ))}
          </ul>
        </GlassCard>
      </div>

      <div className="glass-grid glass-grid--two">
        <GlassCard accent="primary" title={t("admin.gas.title")} subtitle={t("admin.gas.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.gas.errorFallback")}</p>}
          {adminConfig && <GasConfigForm gasConfig={adminConfig.gas} />}
        </GlassCard>

        <GlassCard accent="primary" title={t("admin.vrf.title")} subtitle={t("admin.vrf.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.vrf.errorFallback")}</p>}
          {adminConfig && <VrfConfigForm vrfConfig={adminConfig.vrf} />}
        </GlassCard>
      </div>

      <div className="glass-grid glass-grid--two">
        <GlassCard accent="neutral" title={t("admin.clientSnapshot.title")} subtitle={t("admin.clientSnapshot.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.clientSnapshot.errorFallback")}</p>}
          {adminConfig && (
            <ClientWhitelistSnapshotForm
              configured={adminConfig.whitelist.clientConfigured}
              snapshot={adminConfig.whitelist.client}
            />
          )}
        </GlassCard>

        <GlassCard accent="neutral" title={t("admin.consumerSnapshot.title")} subtitle={t("admin.consumerSnapshot.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.consumerSnapshot.errorFallback")}</p>}
          {adminConfig && (
            <ConsumerWhitelistSnapshotForm
              configured={adminConfig.whitelist.consumerConfigured}
              snapshot={adminConfig.whitelist.consumer}
            />
          )}
        </GlassCard>
      </div>

      <div className="glass-grid glass-grid--two">
        <GlassCard accent="primary" title={t("admin.treasury.distribution.title")} subtitle={t("admin.treasury.distribution.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.treasury.distribution.errorFallback")}</p>}
          {adminConfig && <TreasuryDistributionForm config={adminConfig.treasury.config} />}
        </GlassCard>

        <GlassCard accent="primary" title={t("admin.treasury.controls.title")} subtitle={t("admin.treasury.controls.subtitle")}>
          {isAdminConfigLoading && <p>{t("admin.common.loading")}</p>}
          {adminConfigError && <p>{t("admin.treasury.controls.errorFallback")}</p>}
          {adminConfig && (
            <TreasuryControlsForm
              config={adminConfig.treasury.config}
              balances={adminConfig.treasury.balances}
            />
          )}
        </GlassCard>
      </div>

    </section>
  );
}

