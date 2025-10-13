import { createContext, useContext, useState, ReactNode } from "react";
import { translations, TranslationKey } from "./translations";

type Language = "en" | "ru";

interface LanguageContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  t: (key: TranslationKey) => string;
}

const LanguageContext = createContext<LanguageContextType | undefined>(
  undefined,
);

function detectInitialLanguage(): Language {
  if (typeof window !== "undefined") {
    const pathSegment = window.location.pathname.split("/")[1];
    if (pathSegment === "ru") {
      return "ru";
    }
  }

  if (typeof document !== "undefined") {
    const langAttr = document.documentElement.lang;
    if (langAttr && langAttr.toLowerCase().startsWith("ru")) {
      return "ru";
    }
  }

  return "en";
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>(detectInitialLanguage);

  const setLanguage = (lang: Language) => {
    setLanguageState(lang);
  };

  const t = (key: TranslationKey): string => {
    const dictionary = translations[language] ?? translations.en;
    return dictionary[key] ?? translations.en[key] ?? key;
  };

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error("useLanguage must be used within LanguageProvider");
  }
  return context;
}
