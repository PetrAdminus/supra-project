// sources/Events.move
module lottery::events {
    use supra_framework::event;

    /// Унифицированная обёртка для эмиссии событий Supra-Labs.
    public fun emit<Event: store + drop>(event: Event) {
        event::emit(event);
    }
}
