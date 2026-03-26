/// Lightweight test harness for the wasmd mini-druntime.
///
/// Each test module defines test functions and registers them via
/// a top-level `getTests` function that returns an array of `TestCase`.
/// The harness runs every case, reports pass/fail to the console,
/// and aborts on first failure so the wasm trap is visible in the browser.
module test_harness;

import std.stdio;

struct TestCase
{
    string name;
    void function() fn;
}

private int passCount;
private int failCount;

void runTests(const(TestCase)[] cases)
{
    writeln("=== running ", cases.length, " tests ===");

    foreach (tc; cases)
    {
        // We rely on assert() inside the test function to signal failure.
        // If the function returns normally, the test passed.
        tc.fn();
        passCount++;
        writeln("[PASS] ", tc.name);
    }

    writeln("=== ", passCount, " passed, ", failCount, " failed ===");
}
