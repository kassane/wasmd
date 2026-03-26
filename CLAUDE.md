# CLAUDE.md - wasmd Project Knowledge

## What This Project Is

wasmd is an experimental **mini D runtime (druntime)** that replaces the standard D runtime to enable compilation to WebAssembly targets (wasm32, wasi, emsdk). It provides just enough runtime support for D programs to run in the browser with JavaScript interop.

## Build System

- **Primary:** `dub.json` with configurations (one per build target)
- **Convenience:** `build.sh` wraps dub commands
- **Compiler:** LDC (ldmd2/ldc2) only - requires LLVM backend for wasm
- **Target triple:** `wasm32-unknown-unknown-wasm`

### Critical Compiler Flags

| Flag | Purpose |
|------|---------|
| `-i` | Auto-resolve imports (essential - replaces manual module listing) |
| `-i=std` | Resolve `std.*` from project paths, not system |
| `-defaultlib=` | No default library (we ARE the runtime) |
| `-conf=` | No compiler config file |
| `--d-version=CarelessAlocation` | Enables inline concat allocation strategy |
| `--link-internally` | Use LDC's internal linker |
| `-L--no-entry` | No default wasm entry point (we export `_start`) |
| `-L-allow-undefined` | Allow undefined symbols (resolved by JS at load time) |

### Build Commands

```bash
# Build tests
dub build --config=test_all --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm

# Build an example
dub build --config=hello --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm

# Build everything
./build.sh
```

## Directory Layout

```
druntime/          → Mini druntime (import root: -Idruntime)
  object.d         → THE core module. Defines string, size_t, _start, memset, memcpy, asserts
  arsd/            → JS bridge + display libs (module: arsd.webassembly, arsd.simpledisplay)
  core/arsd/       → Custom allocator (memory_allocation.d), AA impl, UTF decoding
  core/internal/   → Array ops, hashing, traits, assertions
  core/stdc/       → Minimal C stdlib stubs
  rt/hooks.d       → abort(), assumeSafeAppend, assumeUniqueReference
  std/             → Partial stdlib: stdio (writeln→DOM), math, random (→Math.random)
tests/             → TDD test suite (test_harness + focused test modules)
examples/          → Example programs (each compiles to standalone .wasm)
server/            → Web server + JS bridge + HTML template
```

## Architecture Key Points

### Memory Allocator (`core.arsd.memory_allocation`)
- **Bump-pointer allocator** - no GC, no free list (except last-block optimization)
- Each allocation has an `AllocatedBlock` header: size, flags, magic (0x731a_9bec), checksum
- 16-byte alignment enforced
- Grows wasm linear memory via `llvm.wasm.memory.grow` intrinsic (64KB pages)
- `free()` only reclaims the last allocated block; others are leaked

### JS Bridge (`arsd.webassembly`)
- `eval!T(jsCode, args...)` - execute JS with D arguments, typed return
- Argument types: int(0), string(1), NativeHandle(2), float(3), ubyte[](4)
- Return types: void(0), int(1), float(2), object/handle(3), string(7)
- JS objects tracked via `bridgeObjects[]` array with refcounting
- `NativeHandle` struct wraps JS object references with ARC

### Entry Point
- `object.d` exports `_start()` which calls `_Dmain(null)`
- Non-wasm path: standard `main(int argc, char** argv)` for native testing
- `version(CustomRuntimePrinter)` enables printf-based output for native builds

### Version Flags
- `WebAssembly` - wasm target (set by compiler for wasm triple)
- `CarelessAlocation` - enables inline concat (always used currently)
- `CustomRuntimeTest` / `CustomRuntimePrinter` - native test mode with printf

## Test Structure (TDD)

Tests are split by concern:
- `test_memory.d` - allocator: new, append growth, struct heap alloc
- `test_arrays.d` - append, concat, slice, cast, foreach, multi-dim
- `test_classes.d` - class alloc, inheritance, interface cast, delegates
- `test_strings.d` - concat, slice, char append, UTF-8, switch-on-string
- `test_aa.d` - insert, lookup, reassign, missing key
- `test_harness.d` - `runTests(TestCase[])` runner with pass/fail reporting
- `test_all.d` - master runner importing all suites

Tests compile to `server/test_all.wasm` and run in the browser.
Assert failure → wasm trap → visible in browser console.

## LDC 1.42.0 Compatibility Fixes

This version required several fixes to work with LDC 1.42.0 (DMD v2.112.1, LLVM 21):

1. **`_d_cast` template** - DMD 2.112 lowering of `cast(To)obj` now uses a template `_d_cast!(To,From)(from)` instead of the old `_d_dynamic_cast` C hook. Added in `object.d`.

2. **`_d_arraysetlengthT` template** - `arr.length = N` lowering now uses a 2-arg template instead of the old 3-arg extern(C). Renamed the old extern(C) version to `_d_arraysetlengthT_legacy` and added a top-level template wrapper.

3. **`nothrow` chain** - `TypeInfo.toString()` is `nothrow` but calls `~` (concat) which chains through `_d_arraycatnTX` → `_d_arraysetlengthT` → `pureRealloc`. Added `nothrow` to the full chain.

4. **`--export-dynamic` linker flag** - LDC 1.42's `--gc-sections` (default) strips D `export` symbols when `--no-entry` is used. Added `--export-dynamic` to retain all exported functions.

5. **Explicit `object.d`** - LDC 1.42 doesn't codegen `object.d` via `-i` alone. Must be passed as an explicit source file.

## Emscripten / WasmGC Support

### Emscripten (`arsd.emscripten`)
- D bindings for core emscripten C APIs (main loop, JS eval, memory, timing, canvas)
- Only compiled when `version(Emscripten)` is set (triple: `wasm32-unknown-emscripten`)
- Requires Emscripten SDK installed separately

### WasmGC (`core.gc.wasmgc`)
- Integration layer with `gcAlloc()`, `gcFree()`, `gcCollect()` API
- Currently falls back to the bump-pointer allocator
- `hasNativeWasmGC` enum for compile-time feature detection
- When LLVM gains WasmGC codegen, stubs will map to `struct.new`/`array.new` intrinsics
- WasmGC is Phase 4 (standardised), baseline across all browsers since late 2024

### BoehmGC/bdwgc
- Not viable for wasm: requires stack scanning which is problematic in wasm's linear memory model
- Would need Emscripten's ASYNCIFY (~50% code size + perf overhead)
- WasmGC is the recommended modern approach instead

## Known Limitations

- No real GC (bump allocator leaks most freed memory)
- No threading (wasm is single-threaded)
- No file I/O (only JS bridge to DOM)
- No exception unwinding (assert → abort)
- Many std library features missing
- `simpledisplay` is canvas-only, no audio

## Reference Projects

- **pacman.d** (kassane/pacman.d) - D game targeting wasm via LDC
- **sokol-d** (floooh/sokol-d) - D bindings with emsdk support, nogc approach
- **libwasm** (etcimon/libwasm) - Full D wasm framework with custom druntime
- **spasm** (skoppe/spasm) - D SPA framework compiling to wasm

## CI

GitHub Actions: `.github/workflows/ci.yml`
- Matrix: ubuntu-latest, macos-latest
- Uses `dlang-community/setup-dlang@v2` with LDC latest
- Builds test_all + all examples
- Verifies .wasm outputs exist
