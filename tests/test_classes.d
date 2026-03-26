/// Tests for class allocation, inheritance, interfaces, dynamic cast.
module test_classes;

import test_harness;
import std.stdio;

// --- test fixtures at module level (D requires this for classes) ---

class Base
{
    int _b = 200;
    int val() { return 123; }
}

interface ITest
{
    void test();
}

interface ICheck
{
    void check();
}

class Derived : Base, ITest
{
    int extra;
    override int val() { return 455 + extra; }
    void test() {}
}

// --- tests ---

void testClassAllocation()
{
    auto b = new Base;
    assert(b._b == 200, "default field init");
    assert(b.val() == 123, "base virtual call");
}

void testInheritance()
{
    auto d = new Derived;
    d.extra = 5;
    Base b = d;
    assert(b.val() == 460, "virtual dispatch through base ref");
}

void testInterfaceCast()
{
    auto d = new Derived;
    ITest t = d;
    t.test(); // should not crash

    // Derived does NOT implement ICheck
    assert(cast(ICheck) d is null, "cast to unimplemented interface must be null");
}

void testDynamicCastNull()
{
    Base b = new Base;
    // Base is not Derived
    auto d = cast(Derived) b;
    assert(d is null, "downcast to unrelated derived must be null");
}

void testDelegateLambda()
{
    int captured = 42;
    auto dg = delegate() {
        return captured;
    };
    assert(dg() == 42, "delegate captures local");
}

TestCase[] getTests()
{
    return [
        TestCase("classes: allocation", &testClassAllocation),
        TestCase("classes: inheritance", &testInheritance),
        TestCase("classes: interface cast", &testInterfaceCast),
        TestCase("classes: dynamic cast null", &testDynamicCastNull),
        TestCase("classes: delegate/lambda", &testDelegateLambda),
    ];
}
