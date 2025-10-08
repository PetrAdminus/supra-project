import i18next from "i18next";
import { initReactI18next } from "react-i18next";
import type { i18n } from "i18next";
import { fallbackLocale, locales, defaultLocale } from "./locales";
import { resources } from "./messages";

let initPromise: Promise<i18n> | null = null;

export function initI18n(): Promise<i18n> {
  if (!initPromise) {
    initPromise = i18next
      .use(initReactI18next)
      .init({
        resources,
        lng: defaultLocale,
        fallbackLng: fallbackLocale,
        supportedLngs: [...locales],
        defaultNS: "translation",
        interpolation: { escapeValue: false },
        initImmediate: false,
        react: { useSuspense: false },
      });
  }

  return initPromise;
}
