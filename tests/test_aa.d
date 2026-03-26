/// Tests for associative array support.
module test_aa;

import test_harness;
import std.stdio;

void testBasicInsertLookup()
{
    int[string] aa = ["hello": 500];
    assert(("hello" in aa) !is null, "key must exist");
    assert(aa["hello"] == 500, "value must be 500");
}

void testReassign()
{
    int[string] aa = ["hello": 500];
    aa["hello"] = 1200;
    assert(aa["hello"] == 1200, "reassign value");
}

void testNewKey()
{
    int[string] aa = ["hello": 500];
    aa["h2o"] = 250;
    assert(aa["h2o"] == 250, "new key");
    assert(("hello" in aa) !is null, "old key still present");
}

void testMissingKey()
{
    int[string] aa;
    assert(("missing" in aa) is null, "missing key returns null");
}

TestCase[] getTests()
{
    return [
        TestCase("aa: basic insert/lookup", &testBasicInsertLookup),
        TestCase("aa: reassign", &testReassign),
        TestCase("aa: new key", &testNewKey),
        TestCase("aa: missing key", &testMissingKey),
    ];
}
