module vrf_hub::table {
    use std::vector;

    const E_KEY_EXISTS: u64 = 1;
    const E_KEY_NOT_FOUND: u64 = 2;

    struct Table<K: copy + drop, V: store> has store {
        keys: vector<K>,
        values: vector<V>,
    }

    public fun new<K: copy + drop, V: store>(): Table<K, V> {
        Table { keys: vector::empty<K>(), values: vector::empty<V>() }
    }

    public fun length<K: copy + drop, V: store>(self: &Table<K, V>): u64 {
        vector::length(&self.keys)
    }

    public fun contains<K: copy + drop, V: store>(self: &Table<K, V>, key: K): bool {
        let (found, _) = find_index(&self.keys, key);
        found
    }

    public fun add<K: copy + drop, V: store>(self: &mut Table<K, V>, key: K, value: V) {
        let (found, _) = find_index(&self.keys, copy key);
        if (found) {
            abort E_KEY_EXISTS;
        };
        vector::push_back(&mut self.keys, key);
        vector::push_back(&mut self.values, value);
    }

    public fun borrow<K: copy + drop, V: store>(self: &Table<K, V>, key: K): &V {
        let (found, index) = find_index(&self.keys, key);
        if (!found) {
            abort E_KEY_NOT_FOUND;
        };
        vector::borrow(&self.values, index)
    }

    public fun borrow_mut<K: copy + drop, V: store>(self: &mut Table<K, V>, key: K): &mut V {
        let (found, index) = find_index(&self.keys, copy key);
        if (!found) {
            abort E_KEY_NOT_FOUND;
        };
        vector::borrow_mut(&mut self.values, index)
    }

    public fun remove<K: copy + drop, V: store>(self: &mut Table<K, V>, key: K): V {
        let (found, index) = find_index(&self.keys, copy key);
        if (!found) {
            abort E_KEY_NOT_FOUND;
        };
        vector::swap_remove(&mut self.keys, index);
        vector::swap_remove(&mut self.values, index)
    }

    fun find_index<K: copy + drop>(keys: &vector<K>, key: K): (bool, u64) {
        let len = vector::length(keys);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(keys, i) == key) {
                return (true, i);
            };
            i = i + 1;
        };
        (false, 0)
    }
}
