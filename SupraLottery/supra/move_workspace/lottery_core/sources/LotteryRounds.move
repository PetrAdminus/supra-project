/// Временная заглушка `lottery_core::rounds`.
/// TODO: перенести реализацию из `lottery::rounds` и адаптировать capability API.
module lottery_core::rounds {
    use std::signer;

    /// Capability для записи истории в поддерживающем пакете.
    /// TODO: заменить заглушку реальной структурой при переносе логики.
    pub struct HistoryWriterCap has store {}

    /// Временная функция выдачи capability истории.
    /// TODO: реализовать выдачу `HistoryWriterCap` после переноса ядра.
    public fun borrow_history_writer_cap(_admin: &signer): HistoryWriterCap {
        abort 1
    }

    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;
}
