#!/usr/bin/env bash

ldc2 -O \
hello.d \
-i \
--d-version=CarelessAlocation \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/omg.wasm \
-mtriple=wasm32-unknown-unknown-wasm

## Tetris

ldc2 -O \
tetris.d \
-i \
--d-version=CarelessAlocation \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/tetris.wasm \
-mtriple=wasm32-unknown-unknown-wasm

## Test

ldc2 -O \
test_runtime.d \
-i \
--d-version=CarelessAlocation \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/test.wasm \
-mtriple=wasm32-unknown-unknown-wasm