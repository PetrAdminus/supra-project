import { ReactNode } from "react";
import { TranslationKey } from "./translations";
type Language = "en" | "ru";
interface LanguageContextType {
    language: Language;
    setLanguage: (lang: Language) => void;
    t: (key: TranslationKey) => string;
}
export declare function LanguageProvider({ children }: {
    children: ReactNode;
}): import("react/jsx-runtime").JSX.Element;
export declare function useLanguage(): LanguageContextType;
export {};
