/++
    WasmGC integration layer for the wasmd mini-druntime.

    The WebAssembly Garbage Collection proposal (WasmGC) adds heap-allocated
    struct and array types managed by the host VM's garbage collector.  This
    eliminates the need for a custom bump-pointer allocator or ported bdwgc
    when targeting runtimes that support WasmGC (Chrome 119+, Firefox 120+,
    Safari 18.2+).

    Status: WasmGC is Phase 4 (standardised) and baseline-available across
    all major browsers as of late 2024.

    LLVM/LDC support: As of LDC 1.42 / LLVM 21, the LLVM backend does NOT
    yet expose WasmGC struct/array instructions through its IR.  This module
    provides:

    1. A high-level D interface that mirrors what a WasmGC backend would
       provide, currently backed by the existing bump allocator.
    2. Compile-time feature detection so code can be written once and
       seamlessly switch to native WasmGC when LLVM support lands.
    3. Documentation of the WasmGC instruction set for future implementors.

    Future: When LDC gains WasmGC codegen, the stubs below will be replaced
    by LLVM intrinsics (e.g. `pragma(LDC_intrinsic, "wasm.struct.new")`).

    See_Also:
        https://github.com/WebAssembly/gc/blob/main/proposals/gc/MVP.md
        https://v8.dev/blog/wasm-gc-porting
+/
module core.gc.wasmgc;

// ── Feature detection ──────────────────────────────────────────────

/// True when the target supports native WasmGC instructions.
/// Currently always false; will become true when LLVM gains WasmGC codegen.
enum bool hasNativeWasmGC = false;

// ── GC-managed allocation (fallback to bump allocator) ─────────────

version (WebAssembly)
{
    import core.arsd.memory_allocation : malloc, free;

    /++
        Allocate a GC-managed block of `size` bytes.

        When native WasmGC is available, this will map to `struct.new` /
        `array.new` instructions and the host VM's GC will manage lifetime.
        Until then, it delegates to the bump-pointer allocator.
    +/
    ubyte[] gcAlloc(size_t size) nothrow @trusted
    {
        static if (hasNativeWasmGC)
        {
            // Future: use wasm GC struct.new / array.new intrinsics
            assert(false, "native WasmGC not yet implemented");
        }
        else
        {
            return malloc(size);
        }
    }

    /++
        Release a GC-managed block.

        With native WasmGC, this is a no-op (the host GC collects).
        With the fallback allocator, it calls free().
    +/
    void gcFree(ubyte* ptr) nothrow @trusted
    {
        static if (hasNativeWasmGC)
        {
            // No-op: host GC handles collection
        }
        else
        {
            free(ptr);
        }
    }

    /++
        Trigger a GC collection cycle.

        With native WasmGC, this is a hint to the host VM.
        With the fallback, this is a no-op (bump allocator has no collection).
    +/
    void gcCollect() nothrow @safe
    {
        static if (hasNativeWasmGC)
        {
            // Future: hint to host GC
        }
        else
        {
            // No-op: bump allocator does not collect
        }
    }
}

// ── WasmGC instruction reference (for documentation) ───────────────
//
// These correspond to the WasmGC MVP instructions. When LLVM adds
// codegen support, each will become a `pragma(LDC_intrinsic, ...)`.
//
// Struct operations:
//   struct.new       $type  - allocate struct with field values
//   struct.new_default $type - allocate struct with default values
//   struct.get       $type $field - read field
//   struct.set       $type $field - write field
//
// Array operations:
//   array.new        $type  - allocate array, fill with value
//   array.new_default $type - allocate array, default values
//   array.new_fixed  $type N - allocate array, N elements from stack
//   array.get        $type  - read element
//   array.set        $type  - write element
//   array.len               - get array length
//   array.copy       $dst $src - bulk copy elements
//   array.fill       $type  - fill range with value
//
// Reference types:
//   ref.cast         $type  - checked downcast
//   ref.test         $type  - downcast test (returns i32)
//   ref.eq                  - reference equality
//   ref.null         $heap  - null reference
//   ref.is_null             - null check
//   ref.func         $func  - function reference
//
// Reference type hierarchy:
//   anyref  >  eqref  >  structref / arrayref / i31ref
//   funcref >  ref $func_type
//   externref (host-provided references)
//
// Casts:
//   ref.cast (non-null) and ref.cast null (nullable)
//   br_on_cast / br_on_cast_fail - branching casts
