// sources/Events.move
module lottery::events {
    use supra_framework::event;

    /// Unified wrapper around Supra-Labs event emission.
    public fun emit<Event: store + drop>(event: Event) {
        event::emit(event);
    }
}
