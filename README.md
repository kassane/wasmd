# wasmd - Minimal D Runtime for WebAssembly

A custom, minimal D runtime (druntime) for WebAssembly targets, enabling D programs to compile to wasm32 and run in the browser with JavaScript interop.

Started by [Adam D. Ruppe](https://github.com/adamdruppe), improved by [Marcelo S. N. Mancini](https://github.com/MrcSnm).

> **Note:** This is an experimental mini-druntime. Only the features needed for the included examples are implemented. Many standard library features will not work.

## Project Structure

```
wasmd/
├── druntime/              # Mini D runtime (replaces standard druntime)
│   ├── object.d           # Core object module & entry point
│   ├── arsd/              # JS/wasm bridge & display libraries
│   │   ├── webassembly.d  # JavaScript eval/interop bridge
│   │   ├── simpledisplay.d# Canvas-based graphics API
│   │   └── color.d        # Color utilities
│   ├── core/              # Runtime internals
│   │   ├── arsd/          # Custom allocator, AA, UTF decoding
│   │   ├── internal/      # Array ops, hashing, traits, assertions
│   │   └── stdc/          # Minimal C stdlib bindings
│   ├── rt/                # Runtime hooks (abort, memory helpers)
│   └── std/               # Partial standard library (stdio, math, random)
├── tests/                 # TDD test suite
│   ├── test_harness.d     # Lightweight test runner
│   ├── test_memory.d      # Allocator tests
│   ├── test_arrays.d      # Array operation tests
│   ├── test_classes.d     # Class/interface/delegate tests
│   ├── test_strings.d     # String & UTF-8 tests
│   ├── test_aa.d          # Associative array tests
│   ├── test_wasmgc.d      # WasmGC integration tests
│   └── test_all.d         # Master runner (imports all suites)
├── examples/              # Example programs
│   ├── hello.d            # Hello world + JS interop
│   ├── features.d         # Array feature showcase
│   ├── tetris.d           # Tetris game
│   ├── asteroids.d        # Asteroids game
│   ├── nuke.d             # Colorful circles animation
│   ├── numbers.d          # 15-puzzle game
│   └── minesweeper.d      # Minesweeper game
├── server/                # Web server & JS bridge
│   ├── serve.d            # D web server for demos
│   ├── webassembly-core.js# JS/wasm interop bridge
│   └── webassembly-skeleton.html
├── dub.json               # Build configuration
└── build.sh               # Convenience build script
```

## Prerequisites

- [LDC](https://github.com/ldc-developers/ldc) (latest) - the LLVM-based D compiler
- [DUB](https://dub.pm/) - D's package manager (bundled with LDC)

## Building

### Build everything (tests + examples)

```bash
./build.sh
```

### Build a single configuration

```bash
# Using dub directly
dub build --config=test_all --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm

# Using the convenience script
./build.sh test_all
./build.sh hello
./build.sh tetris
```

### Available configurations

| Config       | Description                    |
|-------------|-------------------------------|
| `test_all`  | Full test suite               |
| `hello`     | Hello world + JS interop      |
| `features`  | Array feature showcase         |
| `tetris`    | Tetris game                   |
| `nuke`      | Colorful circles animation    |
| `asteroids` | Asteroids game                |
| `numbers`   | 15-puzzle game                |
| `minesweeper`| Minesweeper game             |

## Running Tests

Build and load in the browser:

```bash
./build.sh tests
cd server && dmd -version=embedded_httpd serve.d && ./serve
# Open http://localhost:8080/test_all
```

Tests output `[PASS]`/`[FAIL]` for each case. On failure, the wasm module traps (aborts), which is visible in the browser console.

## Runtime Features

- **Memory:** Custom bump-pointer allocator (no GC), grows wasm linear memory on demand
- **Arrays:** Dynamic append (`~=`), slicing, concatenation, multi-dimensional
- **Classes:** Single inheritance, interfaces, virtual dispatch, dynamic cast
- **Strings:** Full UTF-8 support with `dchar` iteration
- **Associative Arrays:** String-keyed hash maps
- **JS Interop:** `eval!T()` template for type-safe JavaScript execution
- **Graphics:** Canvas-based drawing via `simpledisplay`

## Platform Support

| Target | Triple | Status |
|--------|--------|--------|
| Pure WASM | `wasm32-unknown-unknown-wasm` | Working |
| Emscripten | `wasm32-unknown-emscripten` | Bindings available (`arsd.emscripten`) |
| WASI | `wasm32-wasi` | Planned |

### WasmGC

The `core.gc.wasmgc` module provides a forward-compatible GC integration layer:
- Currently falls back to the bump-pointer allocator
- When LLVM gains WasmGC codegen, it will use native `struct.new`/`array.new` instructions
- WasmGC is standardised (Phase 4) and supported across all major browsers

## Architecture

The runtime replaces D's standard druntime with wasm-compatible implementations:

- `object.d` provides the core module (`_start` entry, `memset`, `memcpy`, array bounds, asserts)
- `core.arsd.memory_allocation` implements a bump-pointer heap allocator using `llvm.wasm.memory.grow`
- `arsd.webassembly` bridges D and JavaScript via a shared `acquire()` function
- `std.stdio.writeln` outputs to a `#stdout` DOM element via JS eval

## License

BSL-1.0 (Boost Software License)
