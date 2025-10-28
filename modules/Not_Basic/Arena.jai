/*
This is poor man version of arena allocator. I should probably use Pool / Flat_Pool.
But wanted to learn how hard is it to add custom allocator to Jai so here it is.

TODOs
- Maybe we need to scan previous buckets to not waste memory?
*/
Arena :: struct {
    first_block:         *Block;
    current_block:       *Block;
    default_block_size:  int;
    allocator:           Allocator;
}

arena_init :: ($block_size: int = DEFAULT_BLOCK_SIZE) -> *Arena {
    #run {
        if block_size & (block_size - 1) != 0 compiler_report("block size must be a power of two");
    }
    block := block_new(block_size);
    
    arena := New(Arena);
    arena.* = .{
        first_block = block,
        current_block = block,
        default_block_size = block_size,
        allocator = context.allocator,
    };
    return arena;
}


arena_alloc :: (arena: *Arena, size: int) -> *void {
    assert(arena && arena.first_block && arena.current_block, "arena is not initialized");
    push_allocator(arena.allocator);
    
    aligned_size := align_up(size);
    
    block := arena.current_block;
    if block.used + aligned_size > block.size {
        new_block_size := ifx aligned_size > arena.default_block_size aligned_size else arena.default_block_size;
        new_block := block_new(new_block_size);
        block.next = new_block;
        arena.current_block = new_block;
        block = new_block;
    }
    result := block.memory + block.used;
    block.used += aligned_size;
    
    return result;
}

arena_deinit :: (arena: *Arena) {
    push_allocator(arena.allocator);
    current := arena.first_block;
    while current {
        next := current.next;
        free(current.memory);
        free(current);
        current = next;
    }
    free(arena);
}

arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .RESIZE; #through;
        case .ALLOCATE;
            // log("-------------\n----------------\ncalled custom alloc\n");
            arena := cast(*Arena) allocator_data;
            assert(arena && arena.first_block && arena.current_block, "arena is not initialized");
            
            alloc_ptr := arena_alloc(arena, requested_size);
            
            if mode == .RESIZE {
                size_to_copy := min(old_size, requested_size);
                if alloc_ptr && size_to_copy memcpy(alloc_ptr, old_memory, size_to_copy);
            }
            return alloc_ptr;
            
        case .IS_THIS_YOURS;
            arena := cast(*Arena) allocator_data;
            
            result := 0;
            current := arena.first_block;
            while current.next {
                if old_memory >= current.memory && old_memory <= current.memory + current.size {
                    return cast(*void)1;
                }
                current = current.next;
            }
            return null;
            
        case .FREE;    #through;
        case .STARTUP; #through;
        case .SHUTDOWN;
            return null;
            
        case .THREAD_START; #through;
        case .THREAD_STOP;  #through;
        case .CREATE_HEAP;  #through;
        case .DESTROY_HEAP;
            assert(false, "not supported");
            return null;
        case .CAPS;
            if old_memory { (cast(*string)old_memory).* = CAPS_VERSION_STRING; }
            return cast(*void)(Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR | .IS_THIS_YOURS);
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

#if MEMORY_DEBUGGER {
    ARENA_AWARE_MEMORY_DEBUGGER :: struct {
        check_alloc   :: custom_check_alloc;
        check_free    :: custom_check_free;
        check_realloc :: custom_check_realloc;
    
        check_create_heap  :: _check_create_heap;
        check_destroy_heap :: _check_destroy_heap;
        
        custom_check_alloc :: inline (allocator: Allocator, memory: *void, size: s64) #expand {
            if allocator.proc == arena_allocator_proc return; 
            _check_alloc(allocator, memory, size);
        };
        
        custom_check_free :: inline (allocator: Allocator, memory: *void) #expand {
            if allocator.proc == arena_allocator_proc return; 
            _check_free(allocator, memory);
        };
        
        
        custom_check_realloc :: inline (allocator: Allocator, old_memory: *void, old_size: s64, new_memory: *void, new_size: s64) #expand {
            if allocator.proc == arena_allocator_proc return; 
            _check_realloc(allocator, old_memory, old_size, new_memory, new_size);
        };
    }
}

#scope_file

// TODO(seg4lt): Make this a module parameter
DEFAULT_BLOCK_SIZE :: 4 *  1024;

Block :: struct {
    next:   *Block;
    size:   int;
    used:   int;
    memory: *void; // Question? Is there a flexible array in Jai like C?
}

block_new :: (block_size: int) -> *Block #expand {
    block := New(Block);
    block.* = .{ size = block_size, memory = alloc(block_size), used = 0, next = null };
    return block;
}

align_up :: (value: int, $alignment: int = 8) -> int {
    #run {
        #import "Compiler";
        if (alignment & (alignment - 1)) != 0 {
            compiler_report("Alignment must be a power of two");
        }
    }
    return (value + (alignment - 1)) & ~(alignment - 1);
}

CAPS_VERSION_STRING :: "modules/Not_Basic/Arena";
