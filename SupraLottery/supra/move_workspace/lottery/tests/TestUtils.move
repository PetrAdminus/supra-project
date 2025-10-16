
#[test_only]
module lottery::test_utils {
    use std::option;

    public fun unwrap<T>(o: option::Option<T>): T {
        assert!(option::is_some(&o), 9);
        option::destroy_some(o)
    }

    public fun unwrap_copy<T: copy>(o: &option::Option<T>): T {
        assert!(option::is_some(o), 9);
        *option::borrow(o)
    }
}