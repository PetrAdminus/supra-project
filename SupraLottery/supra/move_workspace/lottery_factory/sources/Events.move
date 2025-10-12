module lottery_factory::events {
    use supra_framework::account;
    use supra_framework::event;

    /// Создаёт обработчик событий для администратора фабрики лотерей.
    ///
    /// Вынос функции в отдельный модуль избавляет остальные компоненты от
    /// прямых вызовов `account::new_event_handle` и позволяет централизованно
    /// адаптировать код при обновлениях Supra Framework.
    public(package) fun new_handle<T: drop + store>(signer: &signer): event::EventHandle<T> {
        account::new_event_handle<T>(signer)
    }

    /// Публикует событие, перемещая значение в лог.
    public(package) fun emit<T: drop + store>(handle: &mut event::EventHandle<T>, message: T) {
        event::emit_event(handle, message)
    }

    /// Публикует событие, копируя значение — удобно для переиспользования
    /// структуры после записи в лог.
    public(package) fun emit_copy<T: drop + store + copy>(
        handle: &mut event::EventHandle<T>,
        message: &T,
    ) {
        event::emit_event(handle, copy message)
    }
}
