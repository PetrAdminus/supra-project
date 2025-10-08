module example::table {
    use std::vector;

    const E_KEY_EXISTS: u64 = 1;
    const E_KEY_MISSING: u64 = 2;

    struct Table<phantom K: copy + drop, V: store> has store {
        keys: vector<K>,
        values: vector<V>,
    }

    public fun new<K: copy + drop, V: store>(): Table<K, V> {
        Table { keys: vector::empty<K>(), values: vector::empty<V>() }
    }

    public fun add<K: copy + drop, V: store>(table: &mut Table<K, V>, key: K, value: V) {
        let (found, _) = find_index(&table.keys, copy key);
        if (found) {
            abort E_KEY_EXISTS;
        };
        vector::push_back(&mut table.keys, key);
        vector::push_back(&mut table.values, value);
    }

    public fun borrow<K: copy + drop, V: store>(table: &Table<K, V>, key: K): &V {
        let (found, index) = find_index(&table.keys, key);
        if (!found) {
            abort E_KEY_MISSING;
        };
        vector::borrow(&table.values, index)
    }

    public fun borrow_mut<K: copy + drop, V: store>(table: &mut Table<K, V>, key: K): &mut V {
        let (found, index) = find_index(&table.keys, copy key);
        if (!found) {
            abort E_KEY_MISSING;
        };
        vector::borrow_mut(&mut table.values, index)
    }

    fun find_index<K: copy + drop>(keys: &vector<K>, key: K): (bool, u64) {
        let len = vector::length(keys);
        let mut i = 0;
        while (i < len) {
            if (*vector::borrow(keys, i) == key) {
                return (true, i);
            };
            i = i + 1;
        };
        (false, 0)
    }
}
