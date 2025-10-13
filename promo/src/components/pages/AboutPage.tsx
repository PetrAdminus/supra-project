import { Zap, Shield, Users, TrendingUp, Globe, Award } from "lucide-react";
import { Card } from "../ui/card";
import { useLanguage } from "../LanguageContext";

const aboutCopy = {
  en: {
    title: "About ElyxS",
    subtitle:
      "The future of decentralized lottery gaming on the Supra blockchain network",
    missionTitle: "Our Mission",
    missionParagraphs: [
      "ElyxS is revolutionizing the lottery industry by bringing transparency, fairness, and instant payouts to players worldwide through blockchain technology. Built on the Supra network, we leverage cutting-edge cryptographic verification to ensure every draw is provably fair and tamper-proof.",
      "Our mission is to create a trustless, decentralized lottery platform where players can participate with confidence, knowing that every aspect of the game is transparent and verifiable on the blockchain.",
    ],
  },
  ru: {
    title: "О проекте ElyxS",
    subtitle:
      "Будущее децентрализованных лотерей на блокчейне Supra",
    missionTitle: "Наша миссия",
    missionParagraphs: [
      "ElyxS меняет индустрию лотерей, даря игрокам по всему миру прозрачность, честность и мгновенные выплаты благодаря блокчейну. Платформа построена на сети Supra и использует передовую криптографическую проверку, чтобы каждый розыгрыш был доказуемо честным и защищённым от вмешательства.",
      "Наша цель — создать децентрализованную платформу без доверия, где каждый участник уверен в игре, потому что все процессы прозрачны и проверяемы в блокчейне.",
    ],
  },
} as const;

const featureItems = [
  {
    icon: Shield,
    accentClass: "from-purple-500 to-purple-600",
    cardClass:
      "border-purple-500/20 hover:border-purple-500/40 hover:shadow-[0_0_25px_rgba(168,85,247,0.25)]",
    text: {
      en: {
        title: "Provably Fair",
        description:
          "Every draw is verifiable on-chain with cryptographic proof, ensuring complete transparency and fairness for all participants.",
      },
      ru: {
        title: "Доказуемая честность",
        description:
          "Каждый розыгрыш подтверждается в блокчейне криптографическим доказательством, поэтому процесс полностью прозрачен.",
      },
    },
  },
  {
    icon: TrendingUp,
    accentClass: "from-cyan-500 to-cyan-600",
    cardClass:
      "border-cyan-500/20 hover:border-cyan-500/40 hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]",
    text: {
      en: {
        title: "Instant Payouts",
        description:
          "Winners receive their prizes instantly through smart contracts, with no delays or manual processing required.",
      },
      ru: {
        title: "Мгновенные выплаты",
        description:
          "Смарт-контракты отправляют призы сразу после розыгрыша, без задержек и ручной обработки.",
      },
    },
  },
  {
    icon: Globe,
    accentClass: "from-pink-500 to-pink-600",
    cardClass:
      "border-pink-500/20 hover:border-pink-500/40 hover:shadow-[0_0_25px_rgba(236,72,153,0.25)]",
    text: {
      en: {
        title: "Global Access",
        description:
          "Participate from anywhere in the world with just a crypto wallet. No borders, no restrictions.",
      },
      ru: {
        title: "Глобальный доступ",
        description:
          "Участвуйте из любой точки мира, нужен лишь криптовалютный кошелёк. Никаких границ и ограничений.",
      },
    },
  },
  {
    icon: Users,
    accentClass: "from-purple-500 to-pink-500",
    cardClass:
      "border-purple-500/20 hover:border-purple-500/40 hover:shadow-[0_0_25px_rgba(168,85,247,0.25)]",
    text: {
      en: {
        title: "Community Driven",
        description:
          "Built by the community, for the community. Your voice matters in shaping the future of ElyxS.",
      },
      ru: {
        title: "Сообщество в центре",
        description:
          "Платформа создаётся вместе с сообществом. Ваш голос влияет на развитие ElyxS.",
      },
    },
  },
  {
    icon: Award,
    accentClass: "from-cyan-500 to-purple-600",
    cardClass:
      "border-cyan-500/20 hover:border-cyan-500/40 hover:shadow-[0_0_25px_rgba(6,182,212,0.25)]",
    text: {
      en: {
        title: "Big Prizes",
        description:
          "Compete for substantial prize pools that grow with each participant. The more players, the bigger the rewards.",
      },
      ru: {
        title: "Крупные призы",
        description:
          "Размер призовых пулов растёт с каждым участником. Чем больше игроков, тем весомее награды.",
      },
    },
  },
  {
    icon: Zap,
    accentClass: "from-pink-500 to-purple-600",
    cardClass:
      "border-pink-500/20 hover:border-pink-500/40 hover:shadow-[0_0_25px_rgba(236,72,153,0.25)]",
    text: {
      en: {
        title: "Lightning Fast",
        description:
          "Powered by the Supra network for ultra-fast transactions and near-instant draw results.",
      },
      ru: {
        title: "Молниеносная скорость",
        description:
          "Сеть Supra обеспечивает сверхбыстрые транзакции и мгновенные результаты розыгрышей.",
      },
    },
  },
] as const;

export function AboutPage() {
  const { language } = useLanguage();
  const copy = aboutCopy[language];

  return (
    <div className="pt-20 pb-20 relative">
      {/* Background glow */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl"></div>

      <div className="container mx-auto px-6 relative z-10 max-w-6xl">
        {/* Header */}
        <div className="text-center mb-16">
          <h2
            className="text-5xl md:text-6xl mb-4 bg-gradient-to-r from-cyan-400 to-purple-500 bg-clip-text text-transparent"
            style={{ fontFamily: "Orbitron, sans-serif", fontWeight: 700 }}
          >
            {copy.title}
          </h2>
          <p className="text-lg text-gray-400 max-w-3xl mx-auto">
            {copy.subtitle}
          </p>
        </div>

        {/* Mission Statement */}
        <Card className="glass-strong p-12 rounded-2xl border-cyan-500/30 glow-cyan mb-12 transition-all duration-300 hover:scale-[1.02] hover:shadow-[0_0_30px_rgba(6,182,212,0.3)]">
          <div className="flex items-start gap-6">
            <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center flex-shrink-0">
              <Zap className="w-8 h-8 text-white" />
            </div>
            <div>
              <h3
                className="text-3xl text-white mb-4"
                style={{ fontFamily: "Orbitron, sans-serif" }}
              >
                {copy.missionTitle}
              </h3>
              {copy.missionParagraphs.map((paragraph) => (
                <p
                  key={paragraph}
                  className="text-lg text-gray-300 leading-relaxed mb-4 last:mb-0"
                >
                  {paragraph}
                </p>
              ))}
            </div>
          </div>
        </Card>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          {featureItems.map(({ icon: Icon, text, accentClass, cardClass }) => {
            const item = text[language];
            return (
              <Card
                key={item.title}
                className={`glass-strong p-8 rounded-2xl transition-all duration-300 hover:scale-[1.02] ${cardClass}`}
              >
                <div
                  className={`w-14 h-14 rounded-xl bg-gradient-to-br ${accentClass} flex items-center justify-center mb-6`}
                >
                  <Icon className="w-7 h-7 text-white" />
                </div>
                <h4
                  className="text-xl text-white mb-3"
                  style={{ fontFamily: "Orbitron, sans-serif" }}
                >
                  {item.title}
                </h4>
                <p className="text-gray-400">{item.description}</p>
              </Card>
            );
          })}
        </div>

      </div>
    </div>
  );
}
