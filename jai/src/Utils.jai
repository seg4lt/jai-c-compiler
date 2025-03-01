
Owing_Entry :: struct(T: Type) {
    owing_block: bool;
    processed: T;
}

table_clone_owing_entry :: (table: *Table(string, Owing_Entry(string))) -> Table(string, Owing_Entry(string)) {
    new_table : Table(string, Owing_Entry(string));
    init(*new_table);

    for table {
        value := it;
        value.owing_block = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

#scope_file
#import "Hash_Table";