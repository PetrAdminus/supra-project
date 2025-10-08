import { useCallback, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { useUiStore } from "../store/uiStore";
import type { Locale } from "./locales";

type TranslateParams = Record<string, string | number>;

type TranslateFn = (key: string, params?: TranslateParams) => string;

type UseI18nResult = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: TranslateFn;
};

export function useI18n(): UseI18nResult {
  const locale = useUiStore((state) => state.locale);
  const setLocaleStore = useUiStore((state) => state.setLocale);
  const { t, i18n } = useTranslation();

  useEffect(() => {
    if (i18n.language !== locale) {
      void i18n.changeLanguage(locale);
    }
  }, [i18n, locale]);

  const setLocale = useCallback(
    (nextLocale: Locale) => {
      setLocaleStore(nextLocale);
    },
    [setLocaleStore],
  );

  const translate = useCallback<TranslateFn>(
    (key, params) => t(key, params as Record<string, unknown>),
    [t],
  );

  return { locale, setLocale, t: translate };
}

