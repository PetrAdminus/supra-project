import { create } from "zustand";
import { persist } from "zustand/middleware";
import { appConfig } from "../config/appConfig";
import type { ApiMode } from "../config/appConfig";
import type { Locale } from "../i18n/locales";

type UserRole = "user" | "admin";

const initialState = {
  apiMode: appConfig.apiMode,
  showEventErrors: true,
  role: "user" as UserRole,
  locale: "ru" as Locale,
};

interface UiState {
  apiMode: ApiMode;
  setApiMode: (mode: ApiMode) => void;
  showEventErrors: boolean;
  toggleEventErrors: () => void;
  role: UserRole;
  setRole: (role: UserRole) => void;
  locale: Locale;
  setLocale: (locale: Locale) => void;
  reset: () => void;
}

export const useUiStore = create<UiState>()(
  persist(
    (set, get) => ({
      ...initialState,
      setApiMode: (mode) => set({ apiMode: mode }),
      toggleEventErrors: () => set({ showEventErrors: !get().showEventErrors }),
      setRole: (role) => set({ role }),
      setLocale: (locale) => set({ locale }),
      reset: () => set({ ...initialState }),
    }),
    {
      name: "supra-ui",
      partialize: ({ apiMode, showEventErrors, role, locale }) => ({
        apiMode,
        showEventErrors,
        role,
        locale,
      }),
    }
  )
);

export const resetUiStore = () => {
  useUiStore.getState().reset();
  const persistApi = (useUiStore as typeof useUiStore & {
    persist?: {
      clearStorage?: () => void;
    };
  }).persist;
  persistApi?.clearStorage?.();
};
