/// Tests for the WasmGC integration layer.
module test_wasmgc;

import test_harness;
import std.stdio;

void testFeatureDetection()
{
    import core.gc.wasmgc;
    // Currently, native WasmGC is not available via LLVM
    assert(hasNativeWasmGC == false, "native WasmGC should be false for now");
}

void testGcAllocFallback()
{
    import core.gc.wasmgc;
    auto block = gcAlloc(128);
    assert(block.length == 128, "gcAlloc should return requested size");
    assert(block.ptr !is null, "gcAlloc should not return null");
    // Write to verify memory is usable
    block[0] = 0xAA;
    block[127] = 0xBB;
    assert(block[0] == 0xAA);
    assert(block[127] == 0xBB);
}

void testGcFreeFallback()
{
    import core.gc.wasmgc;
    auto block = gcAlloc(64);
    // Should not crash
    gcFree(block.ptr);
}

void testGcCollectNoop()
{
    import core.gc.wasmgc;
    // Should be a no-op and not crash
    gcCollect();
}

TestCase[] getTests()
{
    return [
        TestCase("wasmgc: feature detection", &testFeatureDetection),
        TestCase("wasmgc: alloc fallback", &testGcAllocFallback),
        TestCase("wasmgc: free fallback", &testGcFreeFallback),
        TestCase("wasmgc: collect noop", &testGcCollectNoop),
    ];
}
