module std::borrow {
    public fun freeze<T>(reference: &mut T): &T {
        reference
    }
}
