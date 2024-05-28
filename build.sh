#!/usr/bin/env bash

# LDCPATH=$HOME/Downloads/ldc2-1.36.0-linux-x86_64/bin

ldmd2 -O \
hello.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/omg.wasm \
-mtriple=wasm32-unknown-unknown-wasm

## Test

ldmd2 -O \
test_runtime.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/test.wasm \
-mtriple=wasm32-unknown-unknown-wasm

## Examples

ldmd2 -O \
examples/tetris.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/tetris.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
examples/nuke.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/nuke.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
examples/asteroids.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/asteroids.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
examples/numbers.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/numbers.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
features.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/features.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
hello.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/hello.wasm \
-mtriple=wasm32-unknown-unknown-wasm

ldmd2 -O \
examples/minesweeper.d \
-i \
-defaultlib= \
-conf= \
--d-version=CarelessAlocation \
-vtls \
-vgc \
-verrors=context \
--link-internally \
-i=std \
-L--no-entry \
-Iarsd-webassembly \
-L-allow-undefined \
-of=server/minesweeper.wasm \
-mtriple=wasm32-unknown-unknown-wasm

# ldmd2 -O \
# examples/ronaroids.d \
# -i \
# -defaultlib= \
# -conf= \
# --d-version=CarelessAlocation \
# -vtls \
# -vgc \
# -verrors=context \
# --link-internally \
# -i=std \
# -L--no-entry \
# -Iarsd-webassembly \
# -L-allow-undefined \
# -of=server/ronaroids.wasm \
# -mtriple=wasm32-unknown-unknown-wasm

rm -fr server/*.o