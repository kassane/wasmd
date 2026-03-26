/// Tests for string operations, concatenation, and UTF-8 handling.
module test_strings;

import test_harness;
import std.stdio;

void testStringConcat()
{
    string s;
    s ~= "Hello";
    s ~= "World";
    assert(s == "HelloWorld", "string concat");
}

void testStringSlice()
{
    string s = "test"[0 .. $];
    assert(s == "test", "string slice full");
    assert(s[1 .. 3] == "es", "string sub-slice");
}

void testCharAppend()
{
    char[] buf;
    for (int i = 'a'; i <= 'z'; i++)
        buf ~= cast(char) i;
    assert(buf.length == 26, "char append length");
    assert(buf[0] == 'a');
    assert(buf[25] == 'z');
}

void testUTF8ForeachDchar()
{
    // "こんいちは" is 5 code points, each 3 bytes in UTF-8 = 15 bytes
    string jp = "こんいちは";
    int count = 0;
    foreach (dchar ch; jp)
        count++;
    assert(count == 5, "UTF-8 dchar iteration count");
}

void testUTF8Append()
{
    string s = "a";
    s ~= "こんいちは";
    // 1 + 15 = 16 bytes
    assert(s.length == 16, "UTF-8 byte length after append");
}

void testSwitchString()
{
    string result;
    switch ("hello")
    {
    case "test":
        result = "broken";
        break;
    case "hello":
        result = "ok";
        break;
    default:
        result = "broken";
    }
    assert(result == "ok", "switch on string");
}

TestCase[] getTests()
{
    return [
        TestCase("strings: concat", &testStringConcat),
        TestCase("strings: slice", &testStringSlice),
        TestCase("strings: char append", &testCharAppend),
        TestCase("strings: UTF-8 foreach dchar", &testUTF8ForeachDchar),
        TestCase("strings: UTF-8 append", &testUTF8Append),
        TestCase("strings: switch on string", &testSwitchString),
    ];
}
