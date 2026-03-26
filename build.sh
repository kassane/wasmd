#!/usr/bin/env bash
set -euo pipefail

# wasmd build script - builds all configurations using ldc2/ldmd2
# Usage:
#   ./build.sh              # build all (tests + examples)
#   ./build.sh tests        # build tests only
#   ./build.sh examples     # build examples only
#   ./build.sh <name>       # build a single target (e.g. hello, tetris)
#   ./build.sh clean        # remove build artifacts

LDC="${LDC:-ldmd2}"

DFLAGS="-O -i -defaultlib= -conf= --d-version=CarelessAlocation \
--link-internally -i=std -Idruntime \
-L--no-entry -L--export-dynamic -L-allow-undefined \
-mtriple=wasm32-unknown-unknown-wasm"

OUT="server"
RUNTIME="druntime/object.d"

TESTS="test_all"
EXAMPLES="hello features tetris nuke asteroids numbers minesweeper"

build_target() {
    local name="$1"
    local src="$2"
    local extra="${3:-}"
    echo "--- Building: $name ---"
    $LDC $DFLAGS $extra $RUNTIME "$src" -of="$OUT/$name.wasm"
}

case "${1:-all}" in
    tests)
        build_target "$TESTS" "tests/test_all.d" "-Itests"
        ;;
    examples)
        for name in $EXAMPLES; do
            build_target "$name" "examples/$name.d"
        done
        ;;
    all)
        build_target "$TESTS" "tests/test_all.d" "-Itests"
        for name in $EXAMPLES; do
            build_target "$name" "examples/$name.d"
        done
        ;;
    clean)
        rm -f "$OUT"/*.wasm "$OUT"/*.o
        echo "Cleaned."
        exit 0
        ;;
    *)
        # Build a single target by name
        if [ -f "tests/${1}.d" ]; then
            build_target "$1" "tests/${1}.d" "-Itests"
        elif [ -f "examples/${1}.d" ]; then
            build_target "$1" "examples/${1}.d"
        else
            echo "Unknown target: $1"
            echo "Available: $TESTS $EXAMPLES"
            exit 1
        fi
        ;;
esac

rm -f "$OUT"/*.o
echo "=== Done ==="
