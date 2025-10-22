/// Временная реализация ядра `lottery_core::rounds`.
///
/// Полный перенос логики из монолита (`lottery::rounds`) запланирован на шаг 5,
/// но уже сейчас требуется предоставить capability-доступ для поддержки. Этот
/// модуль отвечает только за хранение и выдачу `HistoryWriterCap`; остальные
/// функции розыгрышей появятся в следующих итерациях.
module lottery_core::rounds {
    use std::option;
    use std::signer;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_HISTORY_CAP_BORROWED: u64 = 4;
    const E_HISTORY_CAP_NOT_BORROWED: u64 = 5;
    const E_AUTOPURCHASE_CAP_BORROWED: u64 = 6;
    const E_AUTOPURCHASE_CAP_NOT_BORROWED: u64 = 7;

    /// Capability, подтверждающая право записи истории розыгрышей.
    ///
    /// Её должен получать модуль ядра (`lottery_core::rounds`) перед вызовом
    /// функций `lottery_support::history::record_*`. Хранится внутри
    /// `CoreControl` и выдаётся только администраторам аккаунта лотереи.
    public struct HistoryWriterCap has store {}

    public struct AutopurchaseRoundCap has store {}

    struct CoreControl has key {
        admin: address,
        history_cap: option::Option<HistoryWriterCap>,
        autopurchase_cap: option::Option<AutopurchaseRoundCap>,
    }

    /// Разворачивает `CoreControl` и подготавливает capability истории.
    public entry fun init(caller: &signer) {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<CoreControl>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };
        move_to(
            caller,
            CoreControl {
                admin: addr,
                history_cap: option::some(HistoryWriterCap {}),
                autopurchase_cap: option::some(AutopurchaseRoundCap {}),
            },
        );
    }

    // Проверяет, создан ли `CoreControl`.
    #[view]
    public fun is_core_control_initialized(): bool {
        exists<CoreControl>(@lottery)
    }

    // Возвращает `true`, если capability истории свободна и может быть выдана.
    #[view]
    public fun history_cap_available(): bool acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return false
        };
        let available = {
            let control = borrow_global<CoreControl>(@lottery);
            option::is_some(&control.history_cap)
        };
        available
    }

    // Проверяет, доступна ли capability автопокупок.
    #[view]
    public fun autopurchase_cap_available(): bool acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return false
        };
        let available = {
            let control = borrow_global<CoreControl>(@lottery);
            option::is_some(&control.autopurchase_cap)
        };
        available
    }

    /// Выдаёт capability истории для административной транзакции.
    ///
    /// Используется в entry-функциях ядра перед записью результата розыгрыша в
    /// `lottery_support::history`. Capability необходимо вернуть через
    /// `return_history_writer_cap`, как только запись завершена.
    public fun borrow_history_writer_cap(caller: &signer): HistoryWriterCap acquires CoreControl {
        let cap_opt = try_borrow_history_writer_cap(caller);
        if (!option::is_some(&cap_opt)) {
            abort E_HISTORY_CAP_BORROWED
        };
        let cap = option::extract(&mut cap_opt);
        option::destroy_none(cap_opt);
        cap
    }

    /// Пытается получить capability истории, возвращая `none`, если она уже занята
    /// или `CoreControl` ещё не развёрнут.
    public fun try_borrow_history_writer_cap(
        caller: &signer,
    ): option::Option<HistoryWriterCap> acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return option::none<HistoryWriterCap>()
        };

        let addr = signer::address_of(caller);
        let available = {
            let control = borrow_global<CoreControl>(@lottery);
            if (addr != control.admin) {
                abort E_NOT_AUTHORIZED
            };
            option::is_some(&control.history_cap)
        };

        if (!available) {
            return option::none<HistoryWriterCap>()
        };

        let control = borrow_global_mut<CoreControl>(@lottery);
        let cap = option::extract(&mut control.history_cap);
        option::some(cap)
    }

    /// Возвращает capability истории обратно в `CoreControl`.
    public fun return_history_writer_cap(
        caller: &signer,
        cap: HistoryWriterCap,
    ) acquires CoreControl {
        ensure_initialized();
        ensure_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (option::is_some(&control.history_cap)) {
            abort E_HISTORY_CAP_NOT_BORROWED
        };
        option::fill(&mut control.history_cap, cap);
    }

    /// Выдаёт capability автопокупок. Возвращает ошибку, если она уже занята.
    public fun borrow_autopurchase_round_cap(caller: &signer): AutopurchaseRoundCap
    acquires CoreControl {
        let cap_opt = try_borrow_autopurchase_round_cap(caller);
        if (!option::is_some(&cap_opt)) {
            abort E_AUTOPURCHASE_CAP_BORROWED
        };
        let cap = option::extract(&mut cap_opt);
        option::destroy_none(cap_opt);
        cap
    }

    /// Пытается получить capability автопокупок, возвращая `none`, если `CoreControl`
    /// ещё не развёрнут или ресурс уже выдан расширению.
    public fun try_borrow_autopurchase_round_cap(
        caller: &signer,
    ): option::Option<AutopurchaseRoundCap> acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return option::none<AutopurchaseRoundCap>()
        };

        let addr = signer::address_of(caller);
        let available = {
            let control = borrow_global<CoreControl>(@lottery);
            if (addr != control.admin) {
                abort E_NOT_AUTHORIZED
            };
            option::is_some(&control.autopurchase_cap)
        };

        if (!available) {
            return option::none<AutopurchaseRoundCap>()
        };

        let control = borrow_global_mut<CoreControl>(@lottery);
        let cap = option::extract(&mut control.autopurchase_cap);
        option::some(cap)
    }

    /// Возвращает capability автопокупок обратно в `CoreControl`.
    public fun return_autopurchase_round_cap(
        caller: &signer,
        cap: AutopurchaseRoundCap,
    ) acquires CoreControl {
        ensure_initialized();
        ensure_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (option::is_some(&control.autopurchase_cap)) {
            abort E_AUTOPURCHASE_CAP_NOT_BORROWED
        };
        option::fill(&mut control.autopurchase_cap, cap);
    }

    fun ensure_initialized() {
        if (!exists<CoreControl>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun ensure_admin(caller: &signer) acquires CoreControl {
        let addr = signer::address_of(caller);
        let control = borrow_global<CoreControl>(@lottery);
        if (addr != control.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    /// Заглушка импорта состояния раунда во время миграции.
    public fun migrate_import_round(
        _lottery_id: u64,
        _tickets: vector<address>,
        _effective_draw: bool,
        _next_ticket_id: u64,
        _pending_request: option::Option<u64>,
    ) {}
}
