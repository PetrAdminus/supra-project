import React from "react";
import type { Preview } from "@storybook/react-vite";
import i18next from "i18next";
import { I18nextProvider } from "react-i18next";
import { AppQueryProvider } from "../src/app/providers/QueryProvider";
import { resetUiStore, useUiStore } from "../src/store/uiStore";
import { locales, type Locale } from "../src/i18n/locales";
import { initI18n } from "../src/i18n/initI18n";
import "../src/index.css";

void initI18n();

function StoreInitializer({ locale, children }: { locale: Locale; children: React.ReactNode }) {
  const initializedRef = React.useRef(false);

  React.useEffect(() => {
    if (!initializedRef.current) {
      initializedRef.current = true;
      resetUiStore();
    }

    const { setLocale, setApiMode } = useUiStore.getState();
    setLocale(locale);
    setApiMode('mock');
  }, [locale]);

  return <>{children}</>;
}

const preview: Preview = {
  globalTypes: {
    locale: {
      name: 'Locale',
      description: 'Interface language',
      defaultValue: 'ru',
      toolbar: {
        icon: 'globe',
        items: locales.map((value) => ({
          value,
          title: value === 'ru' ? 'Russian' : 'English',
        })),
        showName: true,
        dynamicTitle: true,
      },
    },
  },
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    viewport: {
      viewports: {},
    },
  },
  decorators: [
    (Story, context) => {
      const locale = (context.globals.locale ?? 'ru') as Locale;
      return (
        <AppQueryProvider>
          <I18nextProvider i18n={i18next}>
            <StoreInitializer locale={locale}>
              <Story />
            </StoreInitializer>
          </I18nextProvider>
        </AppQueryProvider>
      );
    },
  ],
};

export default preview;
