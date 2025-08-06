#run run();

run :: () {
    defer report_memory_leaks();
    set_build_options_dc(.{ do_output=false, output_path="out", output_executable_name="arena_example" });
    
    print("================ Arena =================== \n\n");
    
    arena := arena_init(256);
    defer arena_deinit(arena);
    
    print_arena(arena);
    {
    
        arena_allocator: Allocator = .{ arena_allocator_proc, arena };
        push_allocator(arena_allocator);
        
        s1 := alloc(160);
        s2 := alloc(160);
        
        Struct_Type :: struct {
            a: int;
            b: float;
            c: *void;
        };
        print("-- size_of - % -- \n", size_of(Struct_Type));
        print_arena(arena);
        x := New(Struct_Type);
        print_arena(arena);
        x1 := New(Struct_Type);
        print_arena(arena);
        x2 := New(Struct_Type);
        print_arena(arena);
    }
}

print_arena :: (using arena: *Arena) {
    print("\n================ Arena Info =================== \n");
    total_size := 0;
    total_uzed := 0;
    
    block_counter := 1;
    current := arena.first_block;
    while current {
        total_size += current.size;
        total_uzed += current.used;
        print("\t %. Address: %\n",block_counter, current.memory);
        print("\t %. Used: %\n", block_counter, current.used);
        print("\t %. Size: %\n", block_counter, current.size);
        current = current.next;
        block_counter += 1;
    }
    
    print("Total Used: %\n", total_uzed);
    print("Total Size: %\n", total_size);
    print("Num Buckets: %\n", block_counter);
    print("================ End: Arena Info =================== \n\n");
}


#import "Compiler";
#import,file "../module.jai"()(MEMORY_DEBUGGER = true);
#import "Basic"()(MEMORY_DEBUGGER = true, REPLACEMENT_INTERFACE = ARENA_AWARE_MEMORY_DEBUGGER);