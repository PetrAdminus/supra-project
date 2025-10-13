import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ChangeEvent,
  type FormEvent,
  type ReactElement,
} from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { GlassCard } from "../../../components/layout/GlassCard";
import { useI18n } from "../../../i18n/useI18n";
import { useWallet } from "../../wallet/useWallet";
import {
  fetchAccountProfile,
  upsertAccountProfile,
} from "../../../api/client";
import type { AccountProfile, AccountProfileUpdate } from "../../../api/types";
import "./ProfilePage.css";

const PROFILE_QUERY_KEY = ["profile", "details"] as const;

type AvatarKindOption = "none" | "external" | "crystara";

interface FormState {
  nickname: string;
  avatarKind: AvatarKindOption;
  avatarValue: string;
  telegram: string;
  twitter: string;
  settings: string;
}

const EMPTY_FORM: FormState = {
  nickname: "",
  avatarKind: "none",
  avatarValue: "",
  telegram: "",
  twitter: "",
  settings: "",
};

function toAvatarKind(kind: string | null | undefined): AvatarKindOption {
  if (kind === "external" || kind === "crystara") {
    return kind;
  }
  return "none";
}

function formatSettings(settings: Record<string, unknown> | undefined): string {
  if (!settings || Object.keys(settings).length === 0) {
    return "";
  }

  try {
    return JSON.stringify(settings, null, 2);
  } catch (error) {
    console.error(error);
    return "";
  }
}

function buildFormState(profile: AccountProfile | null | undefined): FormState {
  if (!profile) {
    return { ...EMPTY_FORM };
  }

  return {
    nickname: profile.nickname ?? "",
    avatarKind: toAvatarKind(profile.avatar?.kind),
    avatarValue: profile.avatar?.value ?? "",
    telegram: profile.telegram ?? "",
    twitter: profile.twitter ?? "",
    settings: formatSettings(profile.settings),
  };
}

function normalizeAddress(address: string | null): string | null {
  if (!address) {
    return null;
  }
  return address.trim().toLowerCase();
}

function parseSettings(value: string): Record<string, unknown> {
  const trimmed = value.trim();
  if (!trimmed) {
    return {};
  }

  const parsed = JSON.parse(trimmed);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }

  return parsed as Record<string, unknown>;
}

export function ProfilePage(): ReactElement {
  const { t } = useI18n();
  const { wallet } = useWallet();
  const queryClient = useQueryClient();
  const walletAddress = normalizeAddress(wallet.address);

  const [formState, setFormState] = useState<FormState>({ ...EMPTY_FORM });
  const [settingsError, setSettingsError] = useState<string | null>(null);
  const [showSuccess, setShowSuccess] = useState(false);

  const profileQuery = useQuery<AccountProfile | null>({
    queryKey: [...PROFILE_QUERY_KEY, walletAddress],
    queryFn: () => fetchAccountProfile(walletAddress!),
    enabled: Boolean(walletAddress),
    staleTime: 30_000,
  });

  const mutation = useMutation({
    mutationFn: async (input: AccountProfileUpdate) => {
      if (!walletAddress) {
        throw new Error("address-required");
      }
      return upsertAccountProfile(walletAddress, input);
    },
    onSuccess: (profile) => {
      queryClient.setQueryData([...PROFILE_QUERY_KEY, walletAddress], profile);
      setFormState(buildFormState(profile));
      setSettingsError(null);
      setShowSuccess(true);
    },
  });

  useEffect(() => {
    if (!profileQuery.isSuccess) {
      return;
    }
    setFormState(buildFormState(profileQuery.data));
  }, [profileQuery.data, profileQuery.isSuccess]);

  useEffect(() => {
    if (!showSuccess) {
      return;
    }
    const timer = window.setTimeout(() => setShowSuccess(false), 3_000);
    return () => window.clearTimeout(timer);
  }, [showSuccess]);

  const handleInputChange = useCallback((event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = event.target;
    setFormState((prev) => ({
      ...prev,
      [name]: value,
    }));
    if (name === "settings" && settingsError) {
      setSettingsError(null);
    }
  }, [settingsError]);

  const handleAvatarKindChange = useCallback((event: ChangeEvent<HTMLSelectElement>) => {
    const nextKind = event.target.value as AvatarKindOption;
    setFormState((prev) => ({
      ...prev,
      avatarKind: nextKind,
      avatarValue: nextKind === "none" ? "" : prev.avatarValue,
    }));
  }, []);

  const handleReset = useCallback(() => {
    setFormState(buildFormState(profileQuery.data));
    setSettingsError(null);
  }, [profileQuery.data]);

  const handleSubmit = useCallback((event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!walletAddress) {
      return;
    }

    let parsedSettings: Record<string, unknown> = {};
    try {
      parsedSettings = parseSettings(formState.settings);
    } catch (error) {
      console.error(error);
      setSettingsError(t("profile.form.settingsError"));
      return;
    }

    const trimmedNickname = formState.nickname.trim();
    const trimmedTelegram = formState.telegram.trim();
    const trimmedTwitter = formState.twitter.trim();
    const trimmedAvatarValue = formState.avatarValue.trim();

    const update: AccountProfileUpdate = {
      nickname: trimmedNickname ? trimmedNickname : null,
      telegram: trimmedTelegram ? trimmedTelegram : null,
      twitter: trimmedTwitter ? trimmedTwitter : null,
      settings: parsedSettings,
      avatar:
        formState.avatarKind === "none"
          ? { kind: "none", value: null }
          : { kind: formState.avatarKind, value: trimmedAvatarValue || null },
    };

    mutation.mutate(update);
  }, [formState, mutation, t, walletAddress]);

  const hasWallet = Boolean(walletAddress);
  const isLoading = profileQuery.isLoading;
  const loadError = profileQuery.isError ? profileQuery.error : null;

  const metadata = useMemo(() => {
    const profile = profileQuery.data;
    if (!profile) {
      return null;
    }
    return {
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      address: profile.address,
      avatarKind: profile.avatar?.kind ?? "none",
      avatarValue: profile.avatar?.value ?? null,
    };
  }, [profileQuery.data]);

  return (
    <div className="profile-page">
      <header className="profile-page__header">
        <h1>{t("profile.title")}</h1>
        <p>{t("profile.subtitle")}</p>
      </header>

      {!hasWallet && (
        <GlassCard title={t("profile.status.connectTitle")} subtitle={t("profile.status.connectSubtitle")}> 
          <p>{t("profile.status.connectHint")}</p>
        </GlassCard>
      )}

      {hasWallet && (
        <div className="profile-page__grid">
          <GlassCard
            title={t("profile.form.title")}
            subtitle={t("profile.form.subtitle")}
            accent="primary"
            className="profile-card"
          >
            {isLoading ? (
              <p>{t("profile.status.loading")}</p>
            ) : loadError ? (
              <p className="profile-error">{t("profile.status.error")}</p>
            ) : (
              <form className="profile-form" onSubmit={handleSubmit}>
                <div className="profile-form__group">
                  <label htmlFor="profile-nickname">{t("profile.form.nickname")}</label>
                  <input
                    id="profile-nickname"
                    name="nickname"
                    type="text"
                    value={formState.nickname}
                    onChange={handleInputChange}
                    placeholder={t("profile.form.nicknamePlaceholder")}
                  />
                </div>

                <div className="profile-form__group">
                  <label htmlFor="profile-telegram">{t("profile.form.telegram")}</label>
                  <input
                    id="profile-telegram"
                    name="telegram"
                    type="text"
                    value={formState.telegram}
                    onChange={handleInputChange}
                    placeholder="@username"
                  />
                </div>

                <div className="profile-form__group">
                  <label htmlFor="profile-twitter">{t("profile.form.twitter")}</label>
                  <input
                    id="profile-twitter"
                    name="twitter"
                    type="text"
                    value={formState.twitter}
                    onChange={handleInputChange}
                    placeholder="@username"
                  />
                </div>

                <fieldset className="profile-form__fieldset">
                  <legend>{t("profile.form.avatar.title")}</legend>
                  <div className="profile-form__group">
                    <label htmlFor="profile-avatar-kind">{t("profile.form.avatar.kindLabel")}</label>
                    <select
                      id="profile-avatar-kind"
                      name="avatarKind"
                      value={formState.avatarKind}
                      onChange={handleAvatarKindChange}
                    >
                      <option value="none">{t("profile.form.avatar.kind.none")}</option>
                      <option value="external">{t("profile.form.avatar.kind.external")}</option>
                      <option value="crystara">{t("profile.form.avatar.kind.crystara")}</option>
                    </select>
                  </div>
                  {formState.avatarKind !== "none" && (
                    <div className="profile-form__group">
                      <label htmlFor="profile-avatar-value">{t("profile.form.avatar.valueLabel")}</label>
                      <input
                        id="profile-avatar-value"
                        name="avatarValue"
                        type="text"
                        value={formState.avatarValue}
                        onChange={handleInputChange}
                        placeholder={t("profile.form.avatar.valuePlaceholder")}
                      />
                    </div>
                  )}
                  <p className="profile-form__hint">{t("profile.form.avatar.hint")}</p>
                </fieldset>

                <div className="profile-form__group">
                  <label htmlFor="profile-settings">{t("profile.form.settingsLabel")}</label>
                  <textarea
                    id="profile-settings"
                    name="settings"
                    value={formState.settings}
                    onChange={handleInputChange}
                    placeholder={t("profile.form.settingsPlaceholder")}
                    rows={6}
                  />
                  <p className="profile-form__hint">{t("profile.form.settingsHint")}</p>
                  {settingsError && <p className="profile-error">{settingsError}</p>}
                </div>

                <div className="profile-form__actions">
                  <button
                    type="submit"
                    className="button-primary"
                    disabled={mutation.isPending}
                  >
                    {mutation.isPending ? t("profile.form.saving") : t("profile.form.submit")}
                  </button>
                  <button
                    type="button"
                    className="button-secondary"
                    onClick={handleReset}
                    disabled={mutation.isPending}
                  >
                    {t("profile.form.reset")}
                  </button>
                </div>

                {mutation.isError && (
                  <p className="profile-error">{t("profile.form.submitError")}</p>
                )}
                {showSuccess && !mutation.isPending && (
                  <p className="profile-success">{t("profile.form.submitSuccess")}</p>
                )}
              </form>
            )}
          </GlassCard>

          <GlassCard
            title={t("profile.meta.title")}
            subtitle={t("profile.meta.subtitle")}
            accent="secondary"
            className="profile-card"
          >
            {metadata ? (
              <dl className="profile-meta">
                <div>
                  <dt>{t("profile.meta.address")}</dt>
                  <dd>{metadata.address}</dd>
                </div>
                <div>
                  <dt>{t("profile.meta.created")}</dt>
                  <dd>{new Date(metadata.createdAt).toLocaleString()}</dd>
                </div>
                <div>
                  <dt>{t("profile.meta.updated")}</dt>
                  <dd>{new Date(metadata.updatedAt).toLocaleString()}</dd>
                </div>
                <div>
                  <dt>{t("profile.meta.avatarKind")}</dt>
                  <dd>{metadata.avatarKind}</dd>
                </div>
                <div>
                  <dt>{t("profile.meta.avatarValue")}</dt>
                  <dd>{metadata.avatarValue ?? t("profile.meta.avatarEmpty")}</dd>
                </div>
              </dl>
            ) : (
              <p>{t("profile.meta.empty")}</p>
            )}
          </GlassCard>
        </div>
      )}
    </div>
  );
}
