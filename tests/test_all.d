/// Master test runner. Compiles to a single wasm module that
/// exercises every test suite in the wasmd mini-druntime.
///
/// Build:  make tests
/// Run:    load server/test_all.wasm via the HTML skeleton
module test_all;

import test_harness;
import test_memory;
import test_arrays;
import test_classes;
import test_strings;
import test_aa;
import test_wasmgc;

void main()
{
    runTests(test_memory.getTests());
    runTests(test_arrays.getTests());
    runTests(test_classes.getTests());
    runTests(test_strings.getTests());
    runTests(test_aa.getTests());
    runTests(test_wasmgc.getTests());

    import std.stdio;
    writeln("=== ALL TESTS PASSED ===");
}
