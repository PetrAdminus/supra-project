import { useCallback } from 'react';
import { useUiStore } from '../store/uiStore';
import { translate } from './messages';
import type { Locale } from './locales';

type TranslateParams = Record<string, string | number>;

type TranslateFn = (key: string, params?: TranslateParams) => string;

type UseI18nResult = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: TranslateFn;
};

export function useI18n(): UseI18nResult {
  const locale = useUiStore((state) => state.locale);
  const setLocale = useUiStore((state) => state.setLocale);

  const t = useCallback<TranslateFn>(
    (key, params) => translate(locale, key, params),
    [locale],
  );

  return { locale, setLocale, t };
}

