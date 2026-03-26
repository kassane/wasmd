/// Tests for the custom bump-pointer allocator (core.arsd.memory_allocation).
module test_memory;

import test_harness;
import std.stdio;

void testBasicAllocation()
{
    // New arrays trigger the allocator
    int[] a = new int[4];
    assert(a.length == 4, "new int[4] should have length 4");
    assert(a[0] == 0, "new int[] should be zero-initialised");
}

void testAppendGrowsMemory()
{
    int[] a;
    foreach (i; 0 .. 64)
        a ~= i;
    assert(a.length == 64, "append 64 times should give length 64");
    assert(a[63] == 63, "last element should be 63");
}

void testFloatArrayInit()
{
    float[] f = new float[4];
    assert(f[0] is float.init, "new float[] should be float.init");
}

void testStructArrayInit()
{
    struct S
    {
        int b = 50;
        string a = "hello";
    }

    S[] t = new S[10];
    assert(t.length == 10, "struct array length");
    assert(t[0] == S.init, "struct array should be default-initialised");
}

void testStructHeapAllocation()
{
    struct S
    {
        int x;
        string label;
    }

    S* p = new S(42, "heap");
    assert(p !is null, "heap struct must not be null");
    assert(p.x == 42, "heap struct field x");
    assert(p.label == "heap", "heap struct field label");
}

TestCase[] getTests()
{
    return [
        TestCase("memory: basic allocation", &testBasicAllocation),
        TestCase("memory: append grows", &testAppendGrowsMemory),
        TestCase("memory: float array init", &testFloatArrayInit),
        TestCase("memory: struct array init", &testStructArrayInit),
        TestCase("memory: struct heap alloc", &testStructHeapAllocation),
    ];
}
