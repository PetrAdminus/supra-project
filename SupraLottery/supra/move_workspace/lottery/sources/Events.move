module lottery::events {
    use supra_framework::account;
    use supra_framework::event;

    /// Создаёт новый обработчик событий для переданного аккаунта администратора.
    ///
    /// Вынос вспомогательной функции упрощает поддержку пакета: модули
    /// инициализируют event handles через единый вход и не повторяют прямой вызов
    /// `account::new_event_handle`, что позволит централизованно адаптировать код
    /// при будущих изменениях API Supra Framework.
    public(package) fun new_handle<T: drop + store>(signer: &signer): event::EventHandle<T> {
        account::new_event_handle<T>(signer)
    }

    /// Унифицированный помощник для отправки событий с перемещаемым значением.
    public(package) fun emit<T: drop + store>(handle: &mut event::EventHandle<T>, message: T) {
        event::emit_event(handle, message)
    }

    /// Вариант отправки события, когда структура повторно используется после публикации.
    public(package) fun emit_copy<T: drop + store + copy>(
        handle: &mut event::EventHandle<T>,
        message: &T,
    ) {
        event::emit_event(handle, copy message)
    }
}
