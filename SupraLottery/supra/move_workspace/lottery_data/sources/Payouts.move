module lottery_data::payouts {
    use std::hash;
    use std::signer;
    use std::vector;

    use supra_framework::account;
    use supra_framework::event;
    use vrf_hub::table;

    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_PUBLISHED: u64 = 2;
    const E_PAYOUT_UNKNOWN: u64 = 3;
    const E_STATUS_MISMATCH: u64 = 4;
    const E_NO_PENDING: u64 = 5;

    const STATUS_PENDING: u8 = 1;
    const STATUS_PAID: u8 = 2;
    const STATUS_REFUNDED: u8 = 3;

    struct PayoutRecord has copy, drop, store {
        payout_id: u64,
        lottery_id: u64,
        round_number: u64,
        winner: address,
        ticket_index: u64,
        amount: u64,
        status: u8,
        randomness_hash: vector<u8>,
        payload_hash: vector<u8>,
    }

    struct LotteryPayoutState has store {
        round_number: u64,
        pending_count: u64,
        paid_count: u64,
        refunded_count: u64,
        payouts: table::Table<u64, PayoutRecord>,
        payout_ids: vector<u64>,
    }

    #[event]
    struct WinnerRecordedEvent has drop, store, copy {
        payout_id: u64,
        lottery_id: u64,
        round_number: u64,
        winner: address,
        ticket_index: u64,
        amount: u64,
        randomness_hash: vector<u8>,
        payload_hash: vector<u8>,
    }

    #[event]
    struct PayoutStatusUpdatedEvent has drop, store, copy {
        payout_id: u64,
        lottery_id: u64,
        round_number: u64,
        previous_status: u8,
        next_status: u8,
    }

    #[event]
    struct RefundIssuedEvent has drop, store, copy {
        payout_id: u64,
        lottery_id: u64,
        round_number: u64,
        recipient: address,
        amount: u64,
    }

    struct PayoutLedger has key {
        admin: address,
        next_payout_id: u64,
        states: table::Table<u64, LotteryPayoutState>,
        payout_index: table::Table<u64, u64>,
        winner_events: event::EventHandle<WinnerRecordedEvent>,
        payout_events: event::EventHandle<PayoutStatusUpdatedEvent>,
        refund_events: event::EventHandle<RefundIssuedEvent>,
    }

    public entry fun init_ledger(caller: &signer) {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @lottery, E_NOT_PUBLISHED);
        assert!(!exists<PayoutLedger>(caller_address), E_ALREADY_INITIALIZED);

        move_to(
            caller,
            PayoutLedger {
                admin: caller_address,
                next_payout_id: 1,
                states: table::new<u64, LotteryPayoutState>(),
                payout_index: table::new<u64, u64>(),
                winner_events: account::new_event_handle<WinnerRecordedEvent>(caller),
                payout_events: account::new_event_handle<PayoutStatusUpdatedEvent>(caller),
                refund_events: account::new_event_handle<RefundIssuedEvent>(caller),
            },
        );
    }

    public fun exists_at(addr: address): bool {
        exists<PayoutLedger>(addr)
    }

    public fun borrow(addr: address): &PayoutLedger acquires PayoutLedger {
        assert!(exists_at(addr), E_NOT_PUBLISHED);
        borrow_global<PayoutLedger>(addr)
    }

    public fun borrow_mut(addr: address): &mut PayoutLedger acquires PayoutLedger {
        assert!(exists_at(addr), E_NOT_PUBLISHED);
        borrow_global_mut<PayoutLedger>(addr)
    }

    public fun status_pending(): u8 {
        STATUS_PENDING
    }

    public fun status_paid(): u8 {
        STATUS_PAID
    }

    public fun status_refunded(): u8 {
        STATUS_REFUNDED
    }

    public fun record_draw_winner(
        lottery_id: u64,
        winner: address,
        ticket_index: u64,
        amount: u64,
        randomness: vector<u8>,
        payload: vector<u8>,
    ) acquires PayoutLedger {
        let ledger = borrow_mut(@lottery);

        let payout_id = ledger.next_payout_id;
        ledger.next_payout_id = payout_id + 1;

        let randomness_hash = hash::sha3_256(randomness);
        let payload_hash = hash::sha3_256(payload);
        let randomness_event = clone_bytes(&randomness_hash);
        let payload_event = clone_bytes(&payload_hash);

        let round_number = add_record(
            ledger,
            lottery_id,
            payout_id,
            winner,
            ticket_index,
            amount,
            randomness_hash,
            payload_hash,
        );

        table::add(&mut ledger.payout_index, payout_id, lottery_id);

        event::emit_event(
            &mut ledger.winner_events,
            WinnerRecordedEvent {
                payout_id,
                lottery_id,
                round_number,
                winner,
                ticket_index,
                amount,
                randomness_hash: randomness_event,
                payload_hash: payload_event,
            },
        );
    }

    public fun mark_paid(payout_id: u64) acquires PayoutLedger {
        update_status(payout_id, STATUS_PAID, STATUS_PENDING);
    }

    public fun mark_refunded(
        payout_id: u64,
        recipient: address,
        amount: u64,
    ) acquires PayoutLedger {
        let (lottery_id, round_number) = update_status(payout_id, STATUS_REFUNDED, STATUS_PENDING);

        let ledger = borrow_mut(@lottery);
        event::emit_event(
            &mut ledger.refund_events,
            RefundIssuedEvent { payout_id, lottery_id, round_number, recipient, amount },
        );
    }

    public fun payout_record(payout_id: u64): PayoutRecord acquires PayoutLedger {
        let ledger = borrow(@lottery);
        assert!(table::contains(&ledger.payout_index, payout_id), E_PAYOUT_UNKNOWN);
        let lottery_id = *table::borrow(&ledger.payout_index, payout_id);
        let state_ref = table::borrow(&ledger.states, lottery_id);
        let record_ref = table::borrow(&state_ref.payouts, payout_id);
        *record_ref
    }

    fun ensure_state(ledger: &mut PayoutLedger, lottery_id: u64): &mut LotteryPayoutState {
        if (!table::contains(&ledger.states, lottery_id)) {
            table::add(
                &mut ledger.states,
                lottery_id,
                LotteryPayoutState {
                    round_number: 0,
                    pending_count: 0,
                    paid_count: 0,
                    refunded_count: 0,
                    payouts: table::new<u64, PayoutRecord>(),
                    payout_ids: vector::empty<u64>(),
                },
            );
        };
        table::borrow_mut(&mut ledger.states, lottery_id)
    }

    fun update_status(
        payout_id: u64,
        next_status: u8,
        expected_current: u8,
    ): (u64, u64) acquires PayoutLedger {
        let ledger = borrow_mut(@lottery);
        assert!(table::contains(&ledger.payout_index, payout_id), E_PAYOUT_UNKNOWN);
        let lottery_id = *table::borrow(&ledger.payout_index, payout_id);

        let (round_number, previous_status) = {
            let state = table::borrow_mut(&mut ledger.states, lottery_id);
            let record = table::borrow_mut(&mut state.payouts, payout_id);
            assert!(record.status == expected_current, E_STATUS_MISMATCH);
            assert!(state.pending_count > 0, E_NO_PENDING);

            let previous = record.status;
            record.status = next_status;
            state.pending_count = state.pending_count - 1;
            if (next_status == STATUS_PAID) {
                state.paid_count = state.paid_count + 1;
            } else if (next_status == STATUS_REFUNDED) {
                state.refunded_count = state.refunded_count + 1;
            };

            (record.round_number, previous)
        };

        event::emit_event(
            &mut ledger.payout_events,
            PayoutStatusUpdatedEvent {
                payout_id,
                lottery_id,
                round_number,
                previous_status,
                next_status,
            },
        );

        (lottery_id, round_number)
    }

    fun add_record(
        ledger: &mut PayoutLedger,
        lottery_id: u64,
        payout_id: u64,
        winner: address,
        ticket_index: u64,
        amount: u64,
        randomness_hash: vector<u8>,
        payload_hash: vector<u8>,
    ): u64 {
        let state = ensure_state(ledger, lottery_id);
        state.round_number = state.round_number + 1;
        let round_number = state.round_number;

        let record = PayoutRecord {
            payout_id,
            lottery_id,
            round_number,
            winner,
            ticket_index,
            amount,
            status: STATUS_PENDING,
            randomness_hash,
            payload_hash,
        };

        table::add(&mut state.payouts, payout_id, record);
        vector::push_back(&mut state.payout_ids, payout_id);
        state.pending_count = state.pending_count + 1;

        round_number
    }

    fun clone_bytes(source: &vector<u8>): vector<u8> {
        let copy = vector::empty<u8>();
        let len = vector::length(source);
        clone_bytes_into(&mut copy, source, 0, len);
        copy
    }

    fun clone_bytes_into(
        copy: &mut vector<u8>,
        source: &vector<u8>,
        index: u64,
        len: u64,
    ) {
        if (index >= len) {
            return;
        };
        vector::push_back(copy, *vector::borrow(source, index));
        let next_index = index + 1;
        clone_bytes_into(copy, source, next_index, len);
    }
}
