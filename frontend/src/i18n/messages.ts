import type { Locale } from "./locales";

type Messages = typeof en;

type Params = Record<string, string | number>;

const en = {
  layout: {
    title: "Supra Lottery",
    subtitle: "Control panel for the lottery and dVRF before Supra testnet integration",
    modeLabel: "Mode",
    roleLabel: "Role",
    localeLabel: "Language",
    mode: {
      mock: "Mock",
      supra: "Supra testnet",
    },
    nav: {
      dashboard: "Dashboard",
      tickets: "Tickets",
      admin: "Administration",
      logs: "Logs",
    },
    role: {
      user: "User",
      admin: "Administrator",
    },
    locale: {
      ru: "Russian",
      en: "English",
    },
  },
  wallet: {
    statusLabel: "Status",
    status: {
      disconnected: "Not connected",
      connecting: "Connecting...",
      connected: "Connected",
    },
    providerLabel: "Provider",
    connect: "Connect",
    disconnect: "Disconnect",
    hint: "Switch to Supra testnet mode to connect.",
    installHint: "Install or unlock the {{provider}} wallet to continue.",
    providerComingSoon: "{{provider}} support will be available soon.",
    copy: {
      default: "Copy address",
      copied: "Copied",
      error: "Copy failed",
    },
    meta: {
      lastConnected: "Last connection: {{value}}",
      chainId: "Chain ID: {{value}}",
    },
    error: {
      dismiss: "Dismiss",
    },
  },
  dashboard: {
    title: "Lottery overview",
    loading: "Loading data...",
    error: {
      title: "No data",
      description: "Failed to fetch lottery state. Ensure the correct API mode is selected.",
    },
    card: {
      current: {
        title: "Current draw",
        subtitle: "Round {{round}}",
        badge: "VRF subscription: {{id}}",
        jackpotLabel: "Jackpot",
        ticketsSoldLabel: "Tickets sold",
        ticketPriceLabel: "Ticket price",
        nextDrawLabel: "Next processing",
      },
      vrf: {
        title: "VRF status",
        subtitlePending: "Request in progress",
        subtitleIdle: "No active request",
        lastRequestLabel: "Last request: {{value}}",
        pendingLabel: "VRF pending",
        pendingYes: "Yes",
        pendingNo: "No",
        lastFulfillmentLabel: "Last fulfillment: {{value}}",
        hint: "While we wait for whitelisting, VRF actions stay disabled. After Supra confirms access we will enable real calls.",
      },
    },
  },
  tickets: {
    title: "Tickets",
    purchaseCard: {
      title: "Buy ticket",
      subtitleMock: "Working in mock mode",
      subtitleSupra: "Supra mode (read-only)",
      badgeRound: "Round {{round}}",
      badgeLoading: "Round loading...",
      loading: "Loading current draw...",
      hintMock:
        "Until we get whitelisting we polish the UX in mock mode. Once Supra confirms access we will connect StarKey and real transactions.",
      hintSupra:
        "Supra API is connected in read-only mode. Ticket purchases will be enabled after wallet whitelisting is approved.",
    },
    historyCard: {
      title: "Ticket history",
      subtitle: "Recent operations",
      loading: "Loading history...",
      error: "Failed to load ticket history. Try again later.",
      empty: "No tickets yet. Add one in mock mode.",
      numbersUnavailable: "Ticket numbers are not exposed by the Supra API yet.",
      supraReadonly: "Supra mode currently shows registered ticket addresses only.",
    },
    form: {
      label: "Ticket numbers",
      placeholder: "e.g. 7, 11, 23, 45",
      priceLabel: "Price: {{value}} ",
      pending: "Submitting...",
      submit: "Buy ticket (mock)",
      errorInvalidNumbers: "Enter numbers separated by commas (e.g. 7, 11, 23, 45).",
      errorRoundUnavailable: "Current round is unknown. Refresh Supra status or try again later.",
      errorTicketPriceUnavailable: "Ticket price is unavailable in Supra mode. Check the monitoring API.",
      success: "Ticket {{ticketId}} added to history. After whitelisting we will switch to real transactions.",
      submitSupraDisabled: "Buy ticket (Supra disabled)",
      disabledSupra: "Ticket purchases are disabled in Supra mode. Complete wallet onboarding to enable them.",
    },
    status: {
      pending: "Pending",
      confirmed: "Confirmed",
      won: "Won",
      lost: "Lost",
    },
  },
  logs: {
    title: "Event log",
    card: {
      events: {
        title: "Mock events",
        subtitle: "History of actions",
        loading: "Loading events...",
        error: "Failed to fetch the log. Check the selected API mode.",
        hiddenErrors: "Errors are hidden ({{count}}). Change the filter to view all events.",
        empty: "No events yet. Data will appear after the Supra integration.",
        actionHide: "Hide errors",
        actionShow: "Show errors",
      },
      plan: {
        title: "Next steps",
        items: {
          first: "Update Storybook scenarios to cover cases.",
          second: "Prepare CLI export once whitelisting is granted.",
          third: "Plan how to import real logs (CSV/JSON) into the UI.",
        },
      },
    },
    table: {
      headers: {
        event: "Event",
        round: "Round",
        time: "Time",
        details: "Details",
        status: "Status",
      },
      types: {
        DrawRequested: "Draw requested",
        DrawHandled: "Draw handled",
        TicketBought: "Ticket purchased",
        TicketRefunded: "Ticket refunded",
      },
      status: {
        success: "Success",
        failed: "Failure",
        retry: "Retry",
      },
    },
  },
  admin: {
    title: "Administration",
    accessDenied: {
      title: "Access restricted",
      description: "This section is available only for administrators. Switch the role in the header.",
    },
    whitelisting: {
      title: "Whitelisting status",
      subtitle: "dVRF access configuration",
      loading: "Checking whitelisting...",
      error: "Failed to fetch whitelisting status. Try again later.",
      profile: "Profile: {{profile}}",
      account: "Account: {{account}}",
      status: "Whitelisted: {{value}}",
      statusYes: "Yes",
      statusNo: "No",
      lastCheck: "Last check: {{value}}",
      hint: "Wait for Supra confirmation before executing deposit or configure_vrf commands. After access arrives the forms below will submit real transactions through SupraClient.",
    },
    plan: {
      title: "Operational plan",
      subtitle: "Next actions after approval",
      items: {
        first: "Run the dVRF subscription flow (addContractToWhitelist, depositFundClient, configure_vrf_request).",
        second: "Replace mock SupraClient calls with real RPC/CLI requests.",
        third: "Connect StarKey and run end-to-end ticket purchase.",
      },
    },
    commands: {
      title: "Supra CLI commands",
      subtitle: "Helpers exposed via the REST API",
      loading: "Loading commands...",
      error: "Failed to load command list.",
      empty: "No CLI commands available for this mode.",
      moduleLabel: "Module",
      count: "Available commands: {{value}}",
    },
    gas: {
      title: "Gas configuration",
      subtitle: "Client parameters",
      labels: {
        maxGasFee: "Max gas fee",
        minBalance: "Min balance",
      },
      submit: "Save gas config",
      saving: "Saving...",
      lastUpdate: "Last update: {{value}}",
      errorFallback: "Failed to update gas config.",
      success: "Transaction {{hash}} submitted at {{time}}",
    },
    vrf: {
      title: "VRF configuration",
      subtitle: "Request limits",
      labels: {
        maxGasPrice: "Max gas price",
        maxGasLimit: "Max gas limit",
        callbackGasPrice: "Callback gas price",
        callbackGasLimit: "Callback gas limit",
        requestedRngCount: "Requested RNG count",
        clientSeed: "Client seed",
      },
      submit: "Save VRF config",
      saving: "Saving...",
      lastUpdate: "Last update: {{value}}",
      errorFallback: "Failed to update VRF config.",
      success: "Transaction {{hash}} submitted at {{time}}",
    },
    clientSnapshot: {
      title: "Client whitelist snapshot",
      subtitle: "maxGasPrice / maxGasLimit / minBalance",
      labels: {
        maxGasPrice: "Max gas price",
        maxGasLimit: "Max gas limit",
        minBalanceLimit: "Min balance limit snapshot",
      },
      submit: "Record client snapshot",
      saving: "Saving...",
      success: "Transaction {{hash}} submitted at {{time}}",
      errorFallback: "Failed to record client snapshot.",
    },
    consumerSnapshot: {
      title: "Consumer whitelist snapshot",
      subtitle: "Callback parameters",
      labels: {
        callbackGasPrice: "Callback gas price",
        callbackGasLimit: "Callback gas limit",
      },
      submit: "Record consumer snapshot",
      saving: "Saving...",
      success: "Transaction {{hash}} submitted at {{time}}",
      errorFallback: "Failed to record consumer snapshot.",
    },
    treasury: {
      distribution: {
        title: "Treasury distribution",
        subtitle: "Percent split in basis points",
        labels: {
          jackpot: "Jackpot share (bp)",
          prize: "Current prize share (bp)",
          treasury: "Treasury share (bp)",
          marketing: "Marketing share (bp)",
        },
        submit: "Update distribution",
        saving: "Saving...",
        success: "Transaction {{hash}} submitted at {{time}}",
        errorFallback: "Failed to update treasury distribution.",
        totalBp: "Total: {{value}} / 10000 bp",
        lastUpdate: "Last update: {{value}}",
      },
      controls: {
        title: "Treasury controls",
        subtitle: "Ticket price, wallet, and sales toggle",
        labels: {
          ticketPrice: "Ticket price (SUPRA)",
          treasuryAddress: "Treasury address",
          salesEnabled: "Ticket sales enabled",
        },
        submit: "Update treasury settings",
        saving: "Saving...",
        success: "Transaction {{hash}} submitted at {{time}}",
        errorFallback: "Failed to update treasury settings.",
        lastUpdate: "Last update: {{value}}",
        balances: {
          jackpot: "Jackpot balance: {{value}} SUPRA",
          prize: "Current prize balance: {{value}} SUPRA",
          treasury: "Treasury balance: {{value}} SUPRA",
          marketing: "Marketing balance: {{value}} SUPRA",
        },
      },
    },
    common: {
      configured: "Configured",
      notConfigured: "Not configured",
      lastUpdate: "Last update: {{value}}",
      loading: "Loading...",
    },
  },
} as const;

const ru: Messages = {
  layout: {
    title: "Supra Lottery",
    subtitle: "Панель управления лотереей и dVRF до интеграции с Supra testnet",
    modeLabel: "Режим",
    roleLabel: "Роль",
    localeLabel: "Язык",
    mode: {
      mock: "Mock",
      supra: "Supra testnet",
    },
    nav: {
      dashboard: "Главная",
      tickets: "Билеты",
      admin: "Администрирование",
      logs: "Логи",
    },
    role: {
      user: "Пользователь",
      admin: "Администратор",
    },
    locale: {
      ru: "Русский",
      en: "English",
    },
  },
  wallet: {
    statusLabel: "Статус",
    status: {
      disconnected: "Не подключён",
      connecting: "Подключение...",
      connected: "Подключён",
    },
    providerLabel: "Провайдер",
    connect: "Подключить",
    disconnect: "Отключить",
    hint: "Переключитесь в режим Supra testnet, чтобы подключиться.",
    installHint: "Установите или разблокируйте кошелёк {{provider}}, чтобы продолжить.",
    providerComingSoon: "Поддержка {{provider}} появится позднее.",
    copy: {
      default: "Скопировать адрес",
      copied: "Скопировано",
      error: "Не удалось скопировать",
    },
    meta: {
      lastConnected: "Последнее подключение: {{value}}",
      chainId: "ID сети: {{value}}",
    },
    error: {
      dismiss: "Скрыть",
    },
  },
  dashboard: {
    title: "Обзор лотереи",
    loading: "Загрузка данных...",
    error: {
      title: "Нет данных",
      description: "Не удалось получить состояние лотереи. Проверьте выбранный режим API.",
    },
    card: {
      current: {
        title: "Текущий розыгрыш",
        subtitle: "Раунд {{round}}",
        badge: "VRF подписка: {{id}}",
        jackpotLabel: "Джекпот",
        ticketsSoldLabel: "Продано билетов",
        ticketPriceLabel: "Цена билета",
        nextDrawLabel: "Следующая обработка",
      },
      vrf: {
        title: "Статус VRF",
        subtitlePending: "Запрос в обработке",
        subtitleIdle: "Запрос не активен",
        lastRequestLabel: "Последний запрос: {{value}}",
        pendingLabel: "VRF pending",
        pendingYes: "Да",
        pendingNo: "Нет",
        lastFulfillmentLabel: "Последнее выполнение: {{value}}",
        hint: "Пока ждём whitelisting, действия VRF отключены. После подтверждения Supra включим реальные вызовы.",
      },
    },
  },
  tickets: {
    title: "Билеты",
    purchaseCard: {
      title: "Покупка билета",
      subtitleMock: "Работаем в mock-режиме",
      subtitleSupra: "Supra-режим (только чтение)",
      badgeRound: "Раунд {{round}}",
      badgeLoading: "Раунд загружается...",
      loading: "Загрузка данных о текущем розыгрыше...",
      hintMock:
        "До получения whitelisting остаёмся на моках и оттачиваем UX. Как только Supra подтвердит доступ, подключим StarKey и реальные транзакции.",
      hintSupra:
        "Supra API подключён в режиме только чтения. Покупка билетов станет доступна после подтверждения whitelisting кошелька.",
    },
    historyCard: {
      title: "История билетов",
      subtitle: "Последние операции",
      loading: "Загрузка истории...",
      error: "Не удалось получить историю покупок. Попробуйте позже.",
      empty: "Пока нет билетов. Добавьте запись в mock-режиме.",
      numbersUnavailable: "Supra API пока не возвращает номера билетов.",
      supraReadonly: "В Supra-режиме отображаются только адреса зарегистрированных билетов.",
    },
    form: {
      label: "Номера билета",
      placeholder: "например, 7, 11, 23, 45",
      priceLabel: "Цена: {{value}} ",
      pending: "Отправка...",
      submit: "Купить билет (mock)",
      errorInvalidNumbers: "Введите номера через запятую (например, 7, 11, 23, 45).",
      errorRoundUnavailable: "Текущий раунд неизвестен. Обновите статус Supra или повторите позже.",
      errorTicketPriceUnavailable: "Цена билета недоступна в Supra-режиме. Проверьте мониторинговый API.",
      success: "Билет {{ticketId}} добавлен в историю. После whitelisting переключим форму на реальные транзакции.",
      submitSupraDisabled: "Купить билет (Supra отключено)",
      disabledSupra: "Покупка билетов в Supra-режиме отключена. Завершите онбординг кошелька, чтобы включить её.",
    },
    status: {
      pending: "В обработке",
      confirmed: "Подтверждён",
      won: "Выигрыш",
      lost: "Проигрыш",
    },
  },
  logs: {
    title: "Журнал событий",
    card: {
      events: {
        title: "Mock-события",
        subtitle: "История обращений",
        loading: "Загрузка событий...",
        error: "Не удалось получить журнал. Проверьте выбранный режим API.",
        hiddenErrors: "Ошибки скрыты ({{count}}). Измените фильтр, чтобы увидеть все события.",
        empty: "Событий пока нет. Данные появятся после интеграции с Supra.",
        actionHide: "Скрывать ошибки",
        actionShow: "Показывать ошибки",
      },
      plan: {
        title: "Следующие шаги",
        items: {
          first: "Обновляем Storybook-сценарии для кейсов.",
          second: "Готовим экспорт событий из CLI после whitelisting.",
          third: "Продумываем импорт реальных логов (CSV/JSON) в интерфейс.",
        },
      },
    },
    table: {
      headers: {
        event: "Событие",
        round: "Раунд",
        time: "Время",
        details: "Описание",
        status: "Статус",
      },
      types: {
        DrawRequested: "Запрошен розыгрыш",
        DrawHandled: "Результат обработан",
        TicketBought: "Покупка билета",
        TicketRefunded: "Возврат билета",
      },
      status: {
        success: "Успех",
        failed: "Ошибка",
        retry: "Повтор",
      },
    },
  },
  admin: {
    title: "Администрирование",
    accessDenied: {
      title: "Доступ ограничен",
      description: "Раздел доступен только администраторам. Переключите роль в шапке.",
    },
    whitelisting: {
      title: "Статус whitelisting",
      subtitle: "Настройки доступа к dVRF",
      loading: "Проверяем whitelisting...",
      error: "Не удалось получить статус whitelisting. Повторите позже.",
      profile: "Профиль: {{profile}}",
      account: "Аккаунт: {{account}}",
      status: "В белом списке: {{value}}",
      statusYes: "Да",
      statusNo: "Нет",
      lastCheck: "Последняя проверка: {{value}}",
      hint: "Ждём подтверждения Supra, прежде чем отправлять deposit или configure_vrf_request. После доступа формы ниже будут слать реальные транзакции через SupraClient.",
    },
    plan: {
      title: "Операционный план",
      subtitle: "Шаги после подтверждения",
      items: {
        first: "Пройти сценарий dVRF (addContractToWhitelist, depositFundClient, configure_vrf_request).",
        second: "Заменить mock SupraClient на реальные RPC/CLI вызовы.",
        third: "Подключить StarKey и прогнать покупку билета end-to-end.",
      },
    },
    commands: {
      title: "Команды Supra CLI",
      subtitle: "Скрипты, доступные через REST API",
      loading: "Загрузка списка команд...",
      error: "Не удалось получить список команд.",
      empty: "Команды недоступны. Проверьте API.",
      moduleLabel: "Модуль",
      count: "Доступно команд: {{value}}",
    },
    gas: {
      title: "Настройка газа",
      subtitle: "Параметры клиента",
      labels: {
        maxGasFee: "Max gas fee",
        minBalance: "Min balance",
      },
      submit: "Сохранить конфигурацию газа",
      saving: "Сохранение...",
      lastUpdate: "Последнее обновление: {{value}}",
      errorFallback: "Не удалось обновить конфигурацию газа.",
      success: "Транзакция {{hash}} отправлена в {{time}}",
    },
    vrf: {
      title: "Настройка VRF",
      subtitle: "Лимиты на запрос",
      labels: {
        maxGasPrice: "Max gas price",
        maxGasLimit: "Max gas limit",
        callbackGasPrice: "Callback gas price",
        callbackGasLimit: "Callback gas limit",
        requestedRngCount: "Requested RNG count",
        clientSeed: "Client seed",
      },
      submit: "Сохранить конфигурацию VRF",
      saving: "Сохранение...",
      lastUpdate: "Последнее обновление: {{value}}",
      errorFallback: "Не удалось обновить конфигурацию VRF.",
      success: "Транзакция {{hash}} отправлена в {{time}}",
    },
    clientSnapshot: {
      title: "Снимок client whitelist",
      subtitle: "maxGasPrice / maxGasLimit / minBalance",
      labels: {
        maxGasPrice: "Max gas price",
        maxGasLimit: "Max gas limit",
        minBalanceLimit: "Min balance limit snapshot",
      },
      submit: "Зафиксировать client snapshot",
      saving: "Сохранение...",
      success: "Транзакция {{hash}} отправлена в {{time}}",
      errorFallback: "Не удалось зафиксировать client snapshot.",
    },
    consumerSnapshot: {
      title: "Снимок consumer whitelist",
      subtitle: "Параметры callback",
      labels: {
        callbackGasPrice: "Callback gas price",
        callbackGasLimit: "Callback gas limit",
      },
      submit: "Зафиксировать consumer snapshot",
      saving: "Сохранение...",
      success: "Транзакция {{hash}} отправлена в {{time}}",
      errorFallback: "Не удалось зафиксировать consumer snapshot.",
    },
    treasury: {
      distribution: {
        title: "Распределение казны",
        subtitle: "Доли в базисных пунктах",
        labels: {
          jackpot: "Доля джекпота (bp)",
          prize: "Доля текущего приза (bp)",
          treasury: "Доля казны (bp)",
          marketing: "Доля маркетинга (bp)",
        },
        submit: "Обновить распределение",
        saving: "Сохраняем...",
        success: "Транзакция {{hash}} отправлена {{time}}",
        errorFallback: "Не удалось обновить распределение казны.",
        totalBp: "Итого: {{value}} / 10000 bp",
        lastUpdate: "Последнее обновление: {{value}}",
      },
      controls: {
        title: "Настройки казны",
        subtitle: "Цена билета, кошелёк и переключатель продаж",
        labels: {
          ticketPrice: "Цена билета (SUPRA)",
          treasuryAddress: "Адрес казны",
          salesEnabled: "Продажи билетов включены",
        },
        submit: "Обновить настройки казны",
        saving: "Сохраняем...",
        success: "Транзакция {{hash}} отправлена {{time}}",
        errorFallback: "Не удалось обновить настройки казны.",
        lastUpdate: "Последнее обновление: {{value}}",
        balances: {
          jackpot: "Баланс джекпота: {{value}} SUPRA",
          prize: "Баланс текущего приза: {{value}} SUPRA",
          treasury: "Баланс казны: {{value}} SUPRA",
          marketing: "Баланс маркетинга: {{value}} SUPRA",
        },
      },
    },
    common: {
      configured: "Настроено",
      notConfigured: "Не настроено",
      lastUpdate: "Последнее обновление: {{value}}",
      loading: "Загрузка...",
    },
  },
} as const;

const messages: Record<Locale, Messages> = {
  en,
  ru,
};

function getMessage(dictionary: Messages, key: string): unknown {
  return key.split('.').reduce<unknown>((value, segment) => {
    if (value && typeof value === 'object') {
      return (value as Record<string, unknown>)[segment];
    }
    return undefined;
  }, dictionary);
}

export function translate(locale: Locale, key: string, params?: Params): string {
  const template = getMessage(messages[locale], key) ?? getMessage(messages.en, key) ?? key;
  if (typeof template !== 'string') {
    return key;
  }

  if (!params) {
    return template;
  }

  return template.replace(/\{\{(\w+)\}\}/g, (_, token) => {
    const replacement = params[token];
    return replacement !== undefined ? String(replacement) : '';
  });
}

