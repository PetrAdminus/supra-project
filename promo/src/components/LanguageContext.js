import { jsx as _jsx } from "react/jsx-runtime";
import { createContext, useContext, useState } from "react";
import { translations } from "./translations";
const LanguageContext = createContext(undefined);
function detectInitialLanguage() {
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
export function LanguageProvider({ children }) {
    const [language, setLanguageState] = useState(detectInitialLanguage);
    const setLanguage = (lang) => {
        setLanguageState(lang);
    };
    const t = (key) => {
        const dictionary = translations[language] ?? translations.en;
        return dictionary[key] ?? translations.en[key] ?? key;
    };
    return (_jsx(LanguageContext.Provider, { value: { language, setLanguage, t }, children: children }));
}
export function useLanguage() {
    const context = useContext(LanguageContext);
    if (!context) {
        throw new Error("useLanguage must be used within LanguageProvider");
    }
    return context;
}
