import type { ReactElement, ReactNode } from "react";
import { render, type RenderOptions } from "@testing-library/react";
import i18next from "i18next";
import { I18nextProvider } from "react-i18next";
import { AppQueryProvider } from "../../app/providers/QueryProvider";
import { initI18n } from "../i18n/initI18n";

interface ProvidersProps {
  children: ReactNode;
}

function Providers({ children }: ProvidersProps): ReactElement {
  void initI18n();
  return (
    <I18nextProvider i18n={i18next}>
      <AppQueryProvider>{children}</AppQueryProvider>
    </I18nextProvider>
  );
}

export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, "wrapper">,
) {
  return render(ui, { wrapper: Providers, ...options });
}
