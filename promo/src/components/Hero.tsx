import { Button } from "./ui/button";
import { Sparkles, TrendingUp, Shield } from "lucide-react";
import { useLanguage } from "./LanguageContext";

const heroCopy = {
  en: {
    badge: "Powered by Supra Network",
    titleTop: "Win with",
    titleBottom: "ElyxS",
    tagline:
      "Join decentralized draws and win Supra tokens. Transparent, fair, and powered by blockchain technology.",
    primaryCta: "Buy Ticket Now",
    secondaryCta: "View Draws",
    features: [
      {
        title: "High Returns",
        description: "Win big with growing prize pools",
      },
      {
        title: "Secure & Fair",
        description: "Blockchain-verified randomness",
      },
      {
        title: "Instant Payout",
        description: "Automatic winner distribution",
      },
    ],
  },
  ru: {
    badge: "На базе Supra Network",
    titleTop: "Выигрывай с",
    titleBottom: "ElyxS",
    tagline:
      "Участвуйте в децентрализованных розыгрышах и выигрывайте токены Supra. Прозрачность, честность и технологии блокчейна.",
    primaryCta: "Купить билет",
    secondaryCta: "Смотреть розыгрыши",
    features: [
      {
        title: "Высокие призы",
        description: "Крупные пуллы наград, растущие с каждым участником",
      },
      {
        title: "Безопасно и честно",
        description: "Случайность подтверждается блокчейном",
      },
      {
        title: "Мгновенные выплаты",
        description: "Выигрыши распределяются автоматически",
      },
    ],
  },
} as const;

const featureIcons = [TrendingUp, Shield, Sparkles] as const;

export function Hero() {
  const { language } = useLanguage();
  const copy = heroCopy[language];

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-20 overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-20 left-10 w-72 h-72 bg-cyan-500/20 rounded-full blur-3xl animate-pulse"></div>
        <div
          className="absolute bottom-20 right-10 w-96 h-96 bg-purple-600/20 rounded-full blur-3xl animate-pulse"
          style={{ animationDelay: "1s" }}
        ></div>
        <div
          className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-pink-500/10 rounded-full blur-3xl animate-pulse"
          style={{ animationDelay: "2s" }}
        ></div>
      </div>

      <div className="container mx-auto px-6 relative z-10">
        <div className="max-w-4xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 glass px-4 py-2 rounded-full mb-6 glow-purple">
            <Sparkles className="w-4 h-4 text-cyan-400" />
            <span className="text-sm text-gray-300">{copy.badge}</span>
          </div>

          {/* Main Headline */}
          <h1
            className="text-6xl md:text-8xl mb-6 bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 bg-clip-text text-transparent"
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 800 }}
          >
            {copy.titleTop}
            <br />
            {copy.titleBottom}
          </h1>

          {/* Tagline */}
          <p className="text-xl md:text-2xl text-gray-300 mb-12 max-w-2xl mx-auto">
            {copy.tagline}
          </p>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
            <Button
              disabled
              className="bg-gradient-to-r from-cyan-500 to-purple-600 hover:from-cyan-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl glow-cyan transition-all"
              aria-disabled="true"
            >
              <Sparkles className="w-5 h-5 mr-2" />
              {copy.primaryCta}
            </Button>
            <Button
              disabled
              variant="outline"
              className="glass text-white border-cyan-400/50 hover:border-cyan-400 px-8 py-6 text-lg rounded-xl transition-all"
              aria-disabled="true"
            >
              {copy.secondaryCta}
            </Button>
          </div>

          {/* Features */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-3xl mx-auto">
            {copy.features.map((feature, index) => {
              const Icon = featureIcons[index];
              return (
                <div key={feature.title} className="glass-strong p-6 rounded-2xl">
                  <Icon className="w-8 h-8 text-cyan-400 mb-3 mx-auto" />
                  <h3
                    className="text-lg mb-2 text-white"
                    style={{ fontFamily: "Orbitron, sans-serif" }}
                  >
                    {feature.title}
                  </h3>
                  <p className="text-sm text-gray-400">{feature.description}</p>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
