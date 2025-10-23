module lottery_core::rounds {
    use lottery_core::instances;
    use lottery_core::treasury_multi;
    use lottery_core::treasury_v1;
    use lottery_factory::registry;
    use std::option;
    use std::signer;
    use std::vector;
    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::hub;
    use vrf_hub::table;

    const BASIS_POINT_DENOMINATOR: u64 = 10_000;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INSTANCE_MISSING: u64 = 4;
    const E_DRAW_ALREADY_SCHEDULED: u64 = 5;
    const E_REQUEST_PENDING: u64 = 6;
    const E_NO_TICKETS: u64 = 7;
    const E_DRAW_NOT_SCHEDULED: u64 = 8;
    const E_NO_PENDING_REQUEST: u64 = 9;
    const E_RANDOM_BYTES_TOO_SHORT: u64 = 10;
    const E_REQUEST_MISMATCH: u64 = 11;
    const E_INSTANCE_INACTIVE: u64 = 12;
    const E_INVALID_TICKET_COUNT: u64 = 13;

    const E_HISTORY_CAP_BORROWED: u64 = 100;
    const E_HISTORY_CAP_NOT_BORROWED: u64 = 101;
    const E_AUTOPURCHASE_CAP_BORROWED: u64 = 102;
    const E_AUTOPURCHASE_CAP_NOT_BORROWED: u64 = 103;
    const E_HISTORY_QUEUE_MISSING: u64 = 104;
    const E_PURCHASE_QUEUE_MISSING: u64 = 105;

    /// Capability, подтверждающая право записи истории розыгрышей.
    public struct HistoryWriterCap has store {}

    /// Capability, выдаваемая модулю автопокупок для записи билетов раундов.
    public struct AutopurchaseRoundCap has store {}

    struct RoundState has store {
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    }

    struct RoundCollection has key {
        admin: address,
        rounds: table::Table<u64, RoundState>,
        lottery_ids: vector<u64>,
        ticket_events: event::EventHandle<TicketPurchasedEvent>,
        schedule_events: event::EventHandle<DrawScheduleUpdatedEvent>,
        reset_events: event::EventHandle<RoundResetEvent>,
        request_events: event::EventHandle<DrawRequestIssuedEvent>,
        fulfill_events: event::EventHandle<DrawFulfilledEvent>,
        snapshot_events: event::EventHandle<RoundSnapshotUpdatedEvent>,
    }

    #[event]
    struct TicketPurchasedEvent has drop, store, copy {
        lottery_id: u64,
        ticket_id: u64,
        buyer: address,
        amount: u64,
    }

    #[event]
    struct DrawScheduleUpdatedEvent has drop, store, copy {
        lottery_id: u64,
        draw_scheduled: bool,
    }

    #[event]
    struct RoundResetEvent has drop, store, copy {
        lottery_id: u64,
        tickets_cleared: u64,
    }

    #[event]
    struct DrawRequestIssuedEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
    }

    #[event]
    struct DrawFulfilledEvent has drop, store, copy {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        random_bytes: vector<u8>,
        prize_amount: u64,
        payload: vector<u8>,
    }

    struct RoundSnapshot has copy, drop, store {
        ticket_count: u64,
        draw_scheduled: bool,
        has_pending_request: bool,
        next_ticket_id: u64,
        pending_request_id: option::Option<u64>,
    }

    #[event]
    struct RoundSnapshotUpdatedEvent has copy, drop, store {
        lottery_id: u64,
        snapshot: RoundSnapshot,
    }

    public struct PendingHistoryRecord has drop, store {
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    }

    struct HistoryQueue has key {
        pending: vector<PendingHistoryRecord>,
    }

    public struct PendingPurchaseRecord has drop, store {
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        paid_amount: u64,
    }

    struct PurchaseQueue has key {
        pending: vector<PendingPurchaseRecord>,
    }

    struct CoreControl has key {
        admin: address,
        history_cap: option::Option<HistoryWriterCap>,
        autopurchase_cap: option::Option<AutopurchaseRoundCap>,
    }

    /// Разворачивает коллекцию раундов и capability-контроллер.
    public entry fun init(caller: &signer) acquires CoreControl, RoundCollection {
        let addr = signer::address_of(caller);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<RoundCollection>(@lottery)) {
            abort E_ALREADY_INITIALIZED
        };

        move_to(
            caller,
            RoundCollection {
                admin: addr,
                rounds: table::new(),
                lottery_ids: vector::empty<u64>(),
                ticket_events: account::new_event_handle<TicketPurchasedEvent>(caller),
                schedule_events: account::new_event_handle<DrawScheduleUpdatedEvent>(caller),
                reset_events: account::new_event_handle<RoundResetEvent>(caller),
                request_events: account::new_event_handle<DrawRequestIssuedEvent>(caller),
                fulfill_events: account::new_event_handle<DrawFulfilledEvent>(caller),
                snapshot_events: account::new_event_handle<RoundSnapshotUpdatedEvent>(caller),
            },
        );
        {
            let state = borrow_global_mut<RoundCollection>(@lottery);
            emit_all_snapshots(state);
        };

        if (!exists<CoreControl>(@lottery)) {
            move_to(
                caller,
                CoreControl {
                    admin: addr,
                    history_cap: option::some(HistoryWriterCap {}),
                    autopurchase_cap: option::some(AutopurchaseRoundCap {}),
                },
            );
        } else {
            let control = borrow_global_mut<CoreControl>(@lottery);
            control.admin = addr;
            if (!option::is_some(&control.history_cap)) {
                option::fill(&mut control.history_cap, HistoryWriterCap {});
            };
            if (!option::is_some(&control.autopurchase_cap)) {
                option::fill(&mut control.autopurchase_cap, AutopurchaseRoundCap {});
            };
        };
        if (!exists<HistoryQueue>(@lottery)) {
            move_to(
                caller,
                HistoryQueue { pending: vector::empty<PendingHistoryRecord>() },
            );
        };
        if (!exists<PurchaseQueue>(@lottery)) {
            move_to(
                caller,
                PurchaseQueue { pending: vector::empty<PendingPurchaseRecord>() },
            );
        };
    }

    /// Проверяет, развёрнут ли модуль раундов.
    #[view]
    public fun is_initialized(): bool {
        exists<RoundCollection>(@lottery)
    }

    /// Возвращает текущего администратора коллекции раундов.
    #[view]
    public fun admin(): address acquires RoundCollection {
        ensure_initialized();
        let state = borrow_global<RoundCollection>(@lottery);
        state.admin
    }

    /// Обновляет администратора раундов (а также capability-контроллера, если он существует).
    public entry fun set_admin(caller: &signer, new_admin: address)
    acquires CoreControl, RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        state.admin = new_admin;
        if (exists<CoreControl>(@lottery)) {
            let control = borrow_global_mut<CoreControl>(@lottery);
            control.admin = new_admin;
        };
    }

    /// Покупка билета пользователем.
    public entry fun buy_ticket(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        let buyer = signer::address_of(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let blueprint = prepare_purchase(state, lottery_id);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);

        treasury_v1::deposit_from_user(caller, ticket_price);
        let _ = complete_purchase(
            state,
            lottery_id,
            buyer,
            ticket_price,
            jackpot_share_bps,
            1,
        );
    }

    /// Регистрирует покупку билетов автопокупками через capability.
    public fun record_prepaid_purchase(
        _cap: &AutopurchaseRoundCap,
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
    ): u64 acquires RoundCollection {
        if (ticket_count == 0) {
            abort E_INVALID_TICKET_COUNT
        };
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let blueprint = prepare_purchase(state, lottery_id);
        let ticket_price = registry::blueprint_ticket_price(&blueprint);
        let jackpot_share_bps = registry::blueprint_jackpot_share_bps(&blueprint);
        complete_purchase(state, lottery_id, buyer, ticket_price, jackpot_share_bps, ticket_count)
    }

    /// Планирование розыгрыша администратором.
    public entry fun schedule_draw(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let (snapshot, schedule_event) = {
            let round = ensure_round(state, lottery_id);
            if (vector::length(&round.tickets) == 0) {
                abort E_NO_TICKETS
            };
            if (!instances::is_instance_active(lottery_id)) {
                abort E_INSTANCE_INACTIVE
            };
            if (option::is_some(&round.pending_request)) {
                abort E_REQUEST_PENDING
            };
            round.draw_scheduled = true;
            let snapshot = snapshot_from_round_mut(round);
            (
                snapshot,
                DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: true },
            )
        };
        event::emit_event(&mut state.schedule_events, schedule_event);
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    /// Сбрасывает состояние раунда.
    public entry fun reset_round(caller: &signer, lottery_id: u64)
    acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let (snapshot, schedule_event, reset_event) = {
            let round = ensure_round(state, lottery_id);
            let cleared = vector::length(&round.tickets);
            clear_tickets(&mut round.tickets);
            round.draw_scheduled = false;
            round.next_ticket_id = 0;
            round.pending_request = option::none<u64>();
            let snapshot = snapshot_from_round_mut(round);
            (
                snapshot,
                DrawScheduleUpdatedEvent { lottery_id, draw_scheduled: false },
                RoundResetEvent { lottery_id, tickets_cleared: cleared },
            )
        };
        event::emit_event(&mut state.schedule_events, schedule_event);
        event::emit_event(&mut state.reset_events, reset_event);
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    /// Отправляет запрос случайности в VRF-хаб.
    public entry fun request_randomness(
        caller: &signer,
        lottery_id: u64,
        payload: vector<u8>,
    ) acquires RoundCollection {
        ensure_admin(caller);
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let (request_event, snapshot) = {
            let round = ensure_round(state, lottery_id);
            if (!round.draw_scheduled) {
                abort E_DRAW_NOT_SCHEDULED
            };
            if (!instances::is_instance_active(lottery_id)) {
                abort E_INSTANCE_INACTIVE
            };
            if (option::is_some(&round.pending_request)) {
                abort E_REQUEST_PENDING
            };
            if (vector::length(&round.tickets) == 0) {
                abort E_NO_TICKETS
            };

            let request_id_inner = hub::request_randomness(lottery_id, payload);
            round.pending_request = option::some(request_id_inner);
            (
                DrawRequestIssuedEvent { lottery_id, request_id: request_id_inner },
                snapshot_from_round_mut(round),
            )
        };
        event::emit_event(&mut state.request_events, request_event);
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    /// Обрабатывает ответ VRF и завершает розыгрыш.
    public entry fun fulfill_draw(
        caller: &signer,
        request_id: u64,
        randomness: vector<u8>,
    ) acquires CoreControl, RoundCollection {
        hub::ensure_callback_sender(caller);
        let record = hub::consume_request(request_id);
        let lottery_id = hub::request_record_lottery_id(&record);
        let payload = hub::request_record_payload(&record);

        let state = borrow_global_mut<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            abort E_NO_PENDING_REQUEST
        };
        let (winner, winner_index, snapshot) = {
            let round = table::borrow_mut(&mut state.rounds, lottery_id);
            if (!option::is_some(&round.pending_request)) {
                abort E_NO_PENDING_REQUEST
            };
            let expected_id = *option::borrow(&round.pending_request);
            if (expected_id != request_id) {
                abort E_REQUEST_MISMATCH
            };
            let ticket_count = vector::length(&round.tickets);
            if (ticket_count == 0) {
                abort E_NO_TICKETS
            };
            let random_value = randomness_to_u64(&randomness);
            let winner_index_inner = random_value % ticket_count;
            let winner_addr = *vector::borrow(&round.tickets, winner_index_inner);
            round.draw_scheduled = false;
            round.next_ticket_id = 0;
            round.pending_request = option::none<u64>();
            clear_tickets(&mut round.tickets);
            (winner_addr, winner_index_inner, snapshot_from_round_mut(round))
        };
        emit_snapshot_event(state, lottery_id, snapshot);

        let prize_amount = treasury_multi::distribute_prize_internal(lottery_id, winner);
        let randomness_for_hub = clone_bytes(&randomness);
        hub::record_fulfillment(request_id, lottery_id, randomness_for_hub);
        let random_for_event = copy randomness;
        let payload_for_event = copy payload;
        event::emit_event(
            &mut state.fulfill_events,
            DrawFulfilledEvent {
                lottery_id,
                request_id,
                winner,
                ticket_index: winner_index,
                random_bytes: random_for_event,
                prize_amount,
                payload: payload_for_event,
            },
        );
        enqueue_history_record(
            lottery_id,
            request_id,
            winner,
            winner_index,
            prize_amount,
            clone_bytes(&randomness),
            clone_bytes(&payload),
        );
    }

    /// Возвращает список всех идентификаторов лотерей, для которых создан раунд.
    #[view]
    public fun list_lottery_ids(): vector<u64> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return vector::empty<u64>()
        };
        let state = borrow_global<RoundCollection>(@lottery);
        clone_u64_vector(&state.lottery_ids)
    }

    /// Возвращает снимок состояния раунда, если он существует.
    #[view]
    public fun get_round_snapshot(
        lottery_id: u64,
    ): option::Option<RoundSnapshot> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return option::none<RoundSnapshot>()
        };
        let state = borrow_global<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<RoundSnapshot>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            option::some(snapshot_from_round(round))
        }
    }

    #[test_only]
    public fun round_snapshot_fields_for_test(
        snapshot: &RoundSnapshot
    ): (u64, bool, bool, u64, option::Option<u64>) {
        (
            snapshot.ticket_count,
            snapshot.draw_scheduled,
            snapshot.has_pending_request,
            snapshot.next_ticket_id,
            copy_option_u64(&snapshot.pending_request_id),
        )
    }

    #[test_only]
    public fun round_snapshot_event_fields_for_test(
        event: &RoundSnapshotUpdatedEvent
    ): (u64, RoundSnapshot) {
        (event.lottery_id, event.snapshot)
    }

    /// Возвращает ID ожидающего VRF-запроса (если он есть) для указанной лотереи.
    #[view]
    public fun pending_request_id(
        lottery_id: u64,
    ): option::Option<u64> acquires RoundCollection {
        if (!exists<RoundCollection>(@lottery)) {
            return option::none<u64>()
        };
        let state = borrow_global<RoundCollection>(@lottery);
        if (!table::contains(&state.rounds, lottery_id)) {
            option::none<u64>()
        } else {
            let round = table::borrow(&state.rounds, lottery_id);
            copy_option_u64(&round.pending_request)
        }
    }

    /// Импортирует состояние раунда из монолита во время миграции.
    public fun migrate_import_round(
        caller: &signer,
        lottery_id: u64,
        tickets: vector<address>,
        draw_scheduled: bool,
        next_ticket_id: u64,
        pending_request: option::Option<u64>,
    ) acquires RoundCollection {
        ensure_initialized();
        ensure_admin(caller);
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };

        let state = borrow_global_mut<RoundCollection>(@lottery);
        if (table::contains(&state.rounds, lottery_id)) {
            let snapshot = {
                let round = table::borrow_mut(&mut state.rounds, lottery_id);
                round.tickets = tickets;
                round.draw_scheduled = draw_scheduled;
                round.next_ticket_id = next_ticket_id;
                round.pending_request = pending_request;
                snapshot_from_round_mut(round)
            };
            emit_snapshot_event(state, lottery_id, snapshot);
            return
        };

        record_lottery_id(&mut state.lottery_ids, lottery_id);
        table::add(
            &mut state.rounds,
            lottery_id,
            RoundState {
                tickets,
                draw_scheduled,
                next_ticket_id,
                pending_request,
            },
        );
        let snapshot = {
            let round = table::borrow(&state.rounds, lottery_id);
            snapshot_from_round(round)
        };
        emit_snapshot_event(state, lottery_id, snapshot);
    }

    /// Проверяет, создан ли `CoreControl`.
    #[view]
    public fun is_core_control_initialized(): bool {
        exists<CoreControl>(@lottery)
    }

    #[view]
    public fun history_queue_length(): u64 acquires HistoryQueue {
        if (!exists<HistoryQueue>(@lottery)) {
            return 0
        };
        let queue = borrow_global<HistoryQueue>(@lottery);
        vector::length(&queue.pending)
    }

    #[view]
    public fun purchase_queue_length(): u64 acquires PurchaseQueue {
        if (!exists<PurchaseQueue>(@lottery)) {
            return 0
        };
        let queue = borrow_global<PurchaseQueue>(@lottery);
        vector::length(&queue.pending)
    }

    public fun drain_history_queue(
        _cap: &HistoryWriterCap,
        limit: u64,
    ): vector<PendingHistoryRecord> acquires HistoryQueue {
        if (!exists<HistoryQueue>(@lottery)) {
            abort E_HISTORY_QUEUE_MISSING
        };
        let queue = borrow_global_mut<HistoryQueue>(@lottery);
        drain_history_records(&mut queue.pending, limit)
    }

    public fun drain_purchase_queue_admin(
        admin: &signer,
        limit: u64,
    ): vector<PendingPurchaseRecord> acquires PurchaseQueue {
        ensure_lottery_signer(admin);
        if (!exists<PurchaseQueue>(@lottery)) {
            abort E_PURCHASE_QUEUE_MISSING
        };
        let queue = borrow_global_mut<PurchaseQueue>(@lottery);
        drain_purchase_records(&mut queue.pending, limit)
    }

    public fun grant_bonus_tickets_admin(
        admin: &signer,
        lottery_id: u64,
        player: address,
        bonus_tickets: u64,
    ) acquires RoundCollection {
        ensure_lottery_signer(admin);
        if (bonus_tickets == 0) {
            return
        };
        let state = borrow_global_mut<RoundCollection>(@lottery);
        let issued = 0;
        while (issued < bonus_tickets) {
            issue_ticket_with_amount(&mut state, lottery_id, player, 0, 0);
            issued = issued + 1;
        };
        let snapshot = {
            let round = ensure_round(&mut state, lottery_id);
            snapshot_from_round_mut(round)
        };
        emit_snapshot_event(&mut state, lottery_id, snapshot);
    }

    /// Возвращает `true`, если capability истории свободна и может быть выдана.
    #[view]
    public fun history_cap_available(): bool acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return false
        };
        let control = borrow_global<CoreControl>(@lottery);
        option::is_some(&control.history_cap)
    }

    /// Возвращает `true`, если capability автопокупок свободна.
    #[view]
    public fun autopurchase_cap_available(): bool acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return false
        };
        let control = borrow_global<CoreControl>(@lottery);
        option::is_some(&control.autopurchase_cap)
    }

    /// Выдаёт capability истории для административной транзакции.
    public fun borrow_history_writer_cap(
        caller: &signer,
    ): HistoryWriterCap acquires CoreControl {
        ensure_core_control_initialized();
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (!option::is_some(&control.history_cap)) {
            abort E_HISTORY_CAP_BORROWED
        };
        option::extract(&mut control.history_cap)
    }

    /// Пытается получить capability истории, возвращая `none`, если она занята.
    public fun try_borrow_history_writer_cap(
        caller: &signer,
    ): option::Option<HistoryWriterCap> acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return option::none<HistoryWriterCap>()
        };
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (!option::is_some(&control.history_cap)) {
            return option::none<HistoryWriterCap>()
        };
        let cap = option::extract(&mut control.history_cap);
        option::some(cap)
    }

    /// Возвращает capability истории обратно в `CoreControl`.
    public fun return_history_writer_cap(
        caller: &signer,
        cap: HistoryWriterCap,
    ) acquires CoreControl {
        ensure_core_control_initialized();
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (option::is_some(&control.history_cap)) {
            abort E_HISTORY_CAP_NOT_BORROWED
        };
        option::fill(&mut control.history_cap, cap);
    }

    /// Выдаёт capability автопокупок. Возвращает ошибку, если она уже занята.
    public fun borrow_autopurchase_round_cap(
        caller: &signer,
    ): AutopurchaseRoundCap acquires CoreControl {
        ensure_core_control_initialized();
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (!option::is_some(&control.autopurchase_cap)) {
            abort E_AUTOPURCHASE_CAP_BORROWED
        };
        option::extract(&mut control.autopurchase_cap)
    }

    /// Пытается получить capability автопокупок без ошибки, если ресурс занят.
    public fun try_borrow_autopurchase_round_cap(
        caller: &signer,
    ): option::Option<AutopurchaseRoundCap> acquires CoreControl {
        if (!exists<CoreControl>(@lottery)) {
            return option::none<AutopurchaseRoundCap>()
        };
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (!option::is_some(&control.autopurchase_cap)) {
            return option::none<AutopurchaseRoundCap>()
        };
        let cap = option::extract(&mut control.autopurchase_cap);
        option::some(cap)
    }

    /// Возвращает capability автопокупок обратно в `CoreControl`.
    public fun return_autopurchase_round_cap(
        caller: &signer,
        cap: AutopurchaseRoundCap,
    ) acquires CoreControl {
        ensure_core_control_initialized();
        ensure_core_admin(caller);
        let control = borrow_global_mut<CoreControl>(@lottery);
        if (option::is_some(&control.autopurchase_cap)) {
            abort E_AUTOPURCHASE_CAP_NOT_BORROWED
        };
        option::fill(&mut control.autopurchase_cap, cap);
    }

    fun ensure_initialized() {
        if (!exists<RoundCollection>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun ensure_admin(caller: &signer) acquires RoundCollection {
        let addr = signer::address_of(caller);
        ensure_initialized();
        let state = borrow_global<RoundCollection>(@lottery);
        if (addr != state.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun ensure_core_control_initialized() {
        if (!exists<CoreControl>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
    }

    fun ensure_core_admin(caller: &signer) acquires CoreControl {
        let addr = signer::address_of(caller);
        let control = borrow_global<CoreControl>(@lottery);
        if (addr != control.admin) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun prepare_purchase(
        state: &mut RoundCollection,
        lottery_id: u64,
    ): registry::LotteryBlueprint {
        let info_opt = instances::get_lottery_info(lottery_id);
        if (!option::is_some(&info_opt)) {
            abort E_INSTANCE_MISSING
        };
        let info_ref = option::borrow(&info_opt);
        let blueprint = registry::lottery_info_blueprint(info_ref);
        if (!instances::is_instance_active(lottery_id)) {
            abort E_INSTANCE_INACTIVE
        };
        {
            let round = ensure_round(state, lottery_id);
            ensure_round_available(round);
        };
        blueprint
    }

    fun ensure_round_available(round: &RoundState) {
        if (round.draw_scheduled) {
            abort E_DRAW_ALREADY_SCHEDULED
        };
        if (option::is_some(&round.pending_request)) {
            abort E_REQUEST_PENDING
        };
    }

    fun complete_purchase(
        state: &mut RoundCollection,
        lottery_id: u64,
        buyer: address,
        ticket_price: u64,
        jackpot_share_bps: u16,
        ticket_count: u64,
    ): u64 {
        let jackpot_bps = u16_to_u64(jackpot_share_bps);
        let jackpot_contribution = ticket_price * jackpot_bps / BASIS_POINT_DENOMINATOR;
        let issued = 0;
        let total_amount = 0;
        while (issued < ticket_count) {
            issue_ticket_with_amount(
                state,
                lottery_id,
                buyer,
                ticket_price,
                jackpot_contribution,
            );
            total_amount = total_amount + ticket_price;
            issued = issued + 1;
        };
        enqueue_purchase_record(lottery_id, buyer, ticket_count, total_amount);
        treasury_multi::record_allocation_internal(lottery_id, total_amount);
        let snapshot = {
            let round = ensure_round(state, lottery_id);
            snapshot_from_round_mut(round)
        };
        emit_snapshot_event(state, lottery_id, snapshot);
        total_amount
    }

    fun ensure_round(state: &mut RoundCollection, lottery_id: u64): &mut RoundState {
        if (!instances::contains_instance(lottery_id)) {
            abort E_INSTANCE_MISSING
        };
        if (!table::contains(&state.rounds, lottery_id)) {
            record_lottery_id(&mut state.lottery_ids, lottery_id);
            table::add(
                &mut state.rounds,
                lottery_id,
                RoundState {
                    tickets: vector::empty<address>(),
                    draw_scheduled: false,
                    next_ticket_id: 0,
                    pending_request: option::none<u64>(),
                },
            );
        };
        table::borrow_mut(&mut state.rounds, lottery_id)
    }

    fun emit_all_snapshots(state: &mut RoundCollection) {
        let len = vector::length(&state.lottery_ids);
        let idx = 0;
        while (idx < len) {
            let lottery_id = *vector::borrow(&state.lottery_ids, idx);
            if (table::contains(&state.rounds, lottery_id)) {
                let snapshot = {
                    let round = table::borrow(&state.rounds, lottery_id);
                    snapshot_from_round(round)
                };
                emit_snapshot_event(state, lottery_id, snapshot);
            };
            idx = idx + 1;
        };
    }

    fun emit_snapshot_event(
        state: &mut RoundCollection,
        lottery_id: u64,
        snapshot: RoundSnapshot,
    ) {
        event::emit_event(
            &mut state.snapshot_events,
            RoundSnapshotUpdatedEvent { lottery_id, snapshot },
        );
    }

    fun snapshot_from_round_mut(round: &mut RoundState): RoundSnapshot {
        snapshot_from_round_parts(
            &round.tickets,
            round.draw_scheduled,
            &round.pending_request,
            round.next_ticket_id,
        )
    }

    fun snapshot_from_round(round: &RoundState): RoundSnapshot {
        snapshot_from_round_parts(
            &round.tickets,
            round.draw_scheduled,
            &round.pending_request,
            round.next_ticket_id,
        )
    }

    fun snapshot_from_round_parts(
        tickets: &vector<address>,
        draw_scheduled: bool,
        pending_request: &option::Option<u64>,
        next_ticket_id: u64,
    ): RoundSnapshot {
        RoundSnapshot {
            ticket_count: vector::length(tickets),
            draw_scheduled,
            has_pending_request: option::is_some(pending_request),
            next_ticket_id,
            pending_request_id: copy_option_u64(pending_request),
        }
    }

    fun record_lottery_id(ids: &mut vector<u64>, lottery_id: u64) {
        let len = vector::length(ids);
        let idx = 0;
        while (idx < len) {
            if (*vector::borrow(ids, idx) == lottery_id) {
                return
            };
            idx = idx + 1;
        };
        vector::push_back(ids, lottery_id);
    }

    public fun purchase_record_fields(
        record: &PendingPurchaseRecord,
    ): (u64, address, u64, u64) {
        (
            record.lottery_id,
            record.buyer,
            record.ticket_count,
            record.paid_amount,
        )
    }

    public fun history_record_fields(
        record: &PendingHistoryRecord,
    ): (u64, u64, address, u64, u64) {
        (
            record.lottery_id,
            record.request_id,
            record.winner,
            record.ticket_index,
            record.prize_amount,
        )
    }

    fun issue_ticket_with_amount(
        state: &mut RoundCollection,
        lottery_id: u64,
        buyer: address,
        amount: u64,
        jackpot_contribution: u64,
    ) {
        let ticket_id = {
            let round = ensure_round(state, lottery_id);
            let ticket_id_inner = round.next_ticket_id;
            round.next_ticket_id = ticket_id_inner + 1;
            vector::push_back(&mut round.tickets, buyer);
            ticket_id_inner
        };
        instances::record_ticket_sale(lottery_id, jackpot_contribution);
        event::emit_event(
            &mut state.ticket_events,
            TicketPurchasedEvent { lottery_id, ticket_id, buyer, amount },
        );
    }

    fun enqueue_purchase_record(
        lottery_id: u64,
        buyer: address,
        ticket_count: u64,
        paid_amount: u64,
    ) acquires PurchaseQueue {
        if (!exists<PurchaseQueue>(@lottery)) {
            abort E_PURCHASE_QUEUE_MISSING
        };
        let queue = borrow_global_mut<PurchaseQueue>(@lottery);
        vector::push_back(
            &mut queue.pending,
            PendingPurchaseRecord { lottery_id, buyer, ticket_count, paid_amount },
        );
    }

    fun clear_tickets(tickets: &mut vector<address>) {
        while (vector::length(tickets) > 0) {
            vector::pop_back(tickets);
        };
    }

    fun clone_u64_vector(values: &vector<u64>): vector<u64> {
        let len = vector::length(values);
        let result = vector::empty<u64>();
        let idx = 0;
        while (idx < len) {
            let value = *vector::borrow(values, idx);
            vector::push_back(&mut result, value);
            idx = idx + 1;
        };
        result
    }

    fun clone_bytes(data: &vector<u8>): vector<u8> {
        let buffer = vector::empty<u8>();
        let len = vector::length(data);
        let i = 0;
        while (i < len) {
            let byte = *vector::borrow(data, i);
            vector::push_back(&mut buffer, byte);
            i = i + 1;
        };
        buffer
    }

    fun drain_history_records(
        records: &mut vector<PendingHistoryRecord>,
        limit: u64,
    ): vector<PendingHistoryRecord> {
        let available = vector::length(records);
        let to_take = if (limit == 0 || limit > available) {
            available
        } else {
            limit
        };
        let mut temp = vector::empty<PendingHistoryRecord>();
        let mut taken = 0;
        while (taken < to_take) {
            let record = vector::pop_back(records);
            vector::push_back(&mut temp, record);
            taken = taken + 1;
        };
        let mut result = vector::empty<PendingHistoryRecord>();
        while (!vector::is_empty(&temp)) {
            let record = vector::pop_back(&mut temp);
            vector::push_back(&mut result, record);
        };
        result
    }

    fun drain_purchase_records(
        records: &mut vector<PendingPurchaseRecord>,
        limit: u64,
    ): vector<PendingPurchaseRecord> {
        let available = vector::length(records);
        let to_take = if (limit == 0 || limit > available) {
            available
        } else {
            limit
        };
        let mut temp = vector::empty<PendingPurchaseRecord>();
        let mut taken = 0;
        while (taken < to_take) {
            let record = vector::pop_back(records);
            vector::push_back(&mut temp, record);
            taken = taken + 1;
        };
        let mut result = vector::empty<PendingPurchaseRecord>();
        while (!vector::is_empty(&temp)) {
            let record = vector::pop_back(&mut temp);
            vector::push_back(&mut result, record);
        };
        result
    }

    fun enqueue_history_record(
        lottery_id: u64,
        request_id: u64,
        winner: address,
        ticket_index: u64,
        prize_amount: u64,
        random_bytes: vector<u8>,
        payload: vector<u8>,
    ) acquires HistoryQueue {
        if (!exists<HistoryQueue>(@lottery)) {
            abort E_HISTORY_QUEUE_MISSING
        };
        let queue = borrow_global_mut<HistoryQueue>(@lottery);
        vector::push_back(
            &mut queue.pending,
            PendingHistoryRecord {
                lottery_id,
                request_id,
                winner,
                ticket_index,
                prize_amount,
                random_bytes,
                payload,
            },
        );
    }

    fun randomness_to_u64(randomness: &vector<u8>): u64 {
        if (vector::length(randomness) < 8) {
            abort E_RANDOM_BYTES_TOO_SHORT
        };
        let result = 0u64;
        let i = 0;
        while (i < 8) {
            let byte = *vector::borrow(randomness, i);
            let result_mul = result * 256;
            let byte_u64 = u8_to_u64(byte);
            result = result_mul + byte_u64;
            i = i + 1;
        };
        result
    }

    fun u16_to_u64(value: u16): u64 {
        let result = 0u64;
        let remaining = value;
        while (remaining > 0u16) {
            result = result + 1u64;
            remaining = remaining - 1u16;
        };
        result
    }

    fun u8_to_u64(value: u8): u64 {
        let result = 0u64;
        let remaining = value;
        while (remaining > 0) {
            result = result + 1;
            remaining = remaining - 1;
        };
        result
    }

    fun ensure_lottery_signer(caller: &signer) {
        if (signer::address_of(caller) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }

    fun copy_option_u64(value: &option::Option<u64>): option::Option<u64> {
        if (option::is_some(value)) {
            option::some(*option::borrow(value))
        } else {
            option::none<u64>()
        }
    }
}
