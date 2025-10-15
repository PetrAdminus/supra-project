module lottery::events {
    use std::event;

    public fun emit<T: drop>(handle: &mut event::EventHandle<T>, message: T) {
        event::emit(handle, message);
    }
}
