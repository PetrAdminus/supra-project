import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { Layout } from "./components/Layout";
import { HomePage } from "./components/pages/HomePage";
import { AboutPage } from "./components/pages/AboutPage";
import { LanguageProvider, useLanguage } from "./components/LanguageContext";
const seoContent = {
    en: {
        title: "ElyxS | Supra Network Lottery Promo",
        description: "Discover ElyxS — the Supra Network-powered blockchain lottery that delivers provably fair draws, instant payouts, and a community-first experience.",
        keywords: "ElyxS, Supra Network, blockchain lottery, crypto lottery, decentralized raffle, provably fair draws, SUPRA tokens",
        ogTitle: "ElyxS Lottery | Supra Network Promo",
        ogDescription: "Join ElyxS to experience decentralized lottery draws with verified fairness, instant SUPRA payouts, and a vibrant community.",
        ogLocale: "en_US",
        twitterTitle: "ElyxS Lottery | Supra Network Promo",
        twitterDescription: "Experience the future of blockchain lottery with ElyxS on Supra Network. Fair draws, instant payouts, global access.",
        structuredDataDescription: "ElyxS is a blockchain lottery experience powered by Supra Network, offering provably fair draws, instant payouts, and global access.",
    },
    ru: {
        title: "ElyxS | Лотерея на сети Supra",
        description: "ElyxS — децентрализованная лотерея на сети Supra: прозрачные розыгрыши, мгновенные выплаты в SUPRA и активное сообщество участников.",
        keywords: "ElyxS, Supra Network, блокчейн лотерея, крипто лотерея, децентрализованный розыгрыш, честные розыгрыши, токены SUPRA",
        ogTitle: "ElyxS | Промо лотереи на Supra Network",
        ogDescription: "Присоединяйтесь к ElyxS: децентрализованные розыгрыши с подтверждённой честностью, моментальные выплаты SUPRA и мировое сообщество.",
        ogLocale: "ru_RU",
        twitterTitle: "ElyxS | Лотерея на Supra Network",
        twitterDescription: "Ощутите будущее блокчейн-лотереи с ElyxS на Supra Network. Честные розыгрыши, мгновенные выплаты и доступ по всему миру.",
        structuredDataDescription: "ElyxS — блокчейн-лотерея на сети Supra с доказуемо честными розыгрышами, мгновенными выплатами и глобальным доступом.",
    },
};
function SeoManager() {
    const { language } = useLanguage();
    useEffect(() => {
        const content = seoContent[language];
        document.title = content.title;
        document.documentElement.lang = language;
        const updateMeta = (id, value) => {
            const element = document.getElementById(id);
            if (element) {
                element.setAttribute("content", value);
            }
        };
        const updateTitleTag = (id, value) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value;
            }
        };
        updateTitleTag("meta-title", content.title);
        updateMeta("meta-description", content.description);
        updateMeta("meta-keywords", content.keywords);
        updateMeta("meta-og-title", content.ogTitle);
        updateMeta("meta-og-description", content.ogDescription);
        updateMeta("meta-og-locale", content.ogLocale);
        updateMeta("meta-twitter-title", content.twitterTitle);
        updateMeta("meta-twitter-description", content.twitterDescription);
        updateMeta("meta-og-url", language === "ru" ? "https://elyxs.com/ru/" : "https://elyxs.com/");
        const structuredData = document.getElementById("meta-structured-data");
        if (structuredData) {
            const data = {
                "@context": "https://schema.org",
                "@type": "Organization",
                name: "ElyxS Lottery",
                url: language === "ru" ? "https://elyxs.com/ru/" : "https://elyxs.com/",
                logo: "https://elyxs.com/elyxs-og.png",
                sameAs: ["https://x.com/elyxs_lottery"],
                description: content.structuredDataDescription,
                inLanguage: language === "ru" ? "ru-RU" : "en-US",
            };
            structuredData.textContent = JSON.stringify(data);
        }
        const canonical = document.getElementById("meta-canonical");
        if (canonical) {
            canonical.setAttribute("href", language === "ru" ? "https://elyxs.com/ru/" : "https://elyxs.com/");
        }
    }, [language]);
    return null;
}
export default function App() {
    const [currentPage, setCurrentPage] = useState("home");
    const allowedPages = new Set(["home", "about"]);
    const handleNavigate = (page) => {
        if (allowedPages.has(page)) {
            setCurrentPage(page);
        }
    };
    const renderPage = () => {
        switch (currentPage) {
            case "home":
                return _jsx(HomePage, {});
            case "about":
                return _jsx(AboutPage, {});
            default:
                return _jsx(HomePage, {});
        }
    };
    return (_jsxs(LanguageProvider, { children: [_jsx(SeoManager, {}), _jsx(Layout, { currentPage: currentPage, onNavigate: handleNavigate, children: renderPage() })] }));
}
