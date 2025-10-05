import React from 'react';
import type { Preview } from '@storybook/react-vite';
import { AppQueryProvider } from '../src/app/providers/QueryProvider';
import { resetUiStore, useUiStore } from '../src/store/uiStore';
import { locales, type Locale } from '../src/i18n/locales';
import '../src/index.css';

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
          <StoreInitializer locale={locale}>
            <Story />
          </StoreInitializer>
        </AppQueryProvider>
      );
    },
  ],
};

export default preview;
