import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { I18nextProvider } from "react-i18next";
import i18next from "i18next";
import "./index.css";
import App from "./App.tsx";
import { AppQueryProvider } from "./app/providers/QueryProvider.tsx";
import { initI18n } from "./i18n/initI18n";

void initI18n().then(() => {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <I18nextProvider i18n={i18next}>
        <AppQueryProvider>
          <App />
        </AppQueryProvider>
      </I18nextProvider>
    </StrictMode>,
  );
});
