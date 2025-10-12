module vrf_hub::events {
    use supra_framework::account;
    use supra_framework::event;

    /// Создаёт обработчик событий VRF-хаба.
    public(package) fun new_handle<T: drop + store>(signer: &signer): event::EventHandle<T> {
        account::new_event_handle<T>(signer)
    }

    /// Унифицированная отправка события с перемещаемой структурой.
    public(package) fun emit<T: drop + store>(handle: &mut event::EventHandle<T>, message: T) {
        event::emit_event(handle, message)
    }

    /// Вариант для повторного использования структуры события после публикации.
    public(package) fun emit_copy<T: drop + store + copy>(
        handle: &mut event::EventHandle<T>,
        message: &T,
    ) {
        event::emit_event(handle, copy message)
    }
}
