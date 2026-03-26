/// Tests for array operations: append, slice, concat, cast.
module test_arrays;

import test_harness;
import std.stdio;

void testDynamicAppend()
{
    int[] a;
    a ~= 50;
    a ~= 500;
    a ~= 5000;
    assert(a.length == 3, "append length");
    assert(a[0] == 50);
    assert(a[1] == 500);
    assert(a[2] == 5000);
}

void testInlineConcat()
{
    int[] c = [1, 2] ~ [3, 4];
    assert(c.length == 4, "inline concat length");
    assert(c[0] == 1);
    assert(c[3] == 4);
}

void testSlicing()
{
    string s = "test"[0 .. $];
    assert(s == "test", "string slice");
}

void testArrayCast()
{
    int[] arr = [int.max];
    auto bytes = cast(ubyte[]) arr;
    assert(bytes.length == 4, "int[] cast to ubyte[] length");
    // int.max == 0x7FFF_FFFF  (little-endian: FF FF FF 7F)
    assert(bytes[3] == 0x7F, "high byte of int.max");
}

void testAppendToSlice()
{
    enum Type { int_, string_ }

    struct S
    {
        int* a;
        Type t = Type.string_;
    }

    S[] arr;
    arr ~= S(new int(50), Type.int_);
    arr = arr[0 .. $ - 1]; // shrink
    arr ~= S(new int(100), Type.string_);
    arr ~= S(new int(150), Type.string_);
    arr ~= S(new int(200), Type.int_);
    assert(arr.length == 3, "append after shrink length");
    assert(*arr[0].a == 100);
    assert(*arr[2].a == 200);
}

void testFloatAppend()
{
    float[] f = new float[4];
    f ~= 5.5;
    f ~= [3, 4];
    assert(f.length == 7, "float append length");
}

void testMultiDimArray()
{
    float[][] m = new float[][](4, 4);
    assert(m.length == 4, "outer length");
    assert(m[0].length == 4, "inner length");
}

void testForeach()
{
    int[] a;
    a ~= 1;
    a ~= 2;
    a ~= 3;
    int sum = 0;
    foreach (v; a)
        sum += v;
    assert(sum == 6, "foreach sum");
}

TestCase[] getTests()
{
    return [
        TestCase("arrays: dynamic append", &testDynamicAppend),
        TestCase("arrays: inline concat", &testInlineConcat),
        TestCase("arrays: slicing", &testSlicing),
        TestCase("arrays: cast to ubyte[]", &testArrayCast),
        TestCase("arrays: append after slice", &testAppendToSlice),
        TestCase("arrays: float append", &testFloatAppend),
        TestCase("arrays: multi-dimensional", &testMultiDimArray),
        TestCase("arrays: foreach", &testForeach),
    ];
}
