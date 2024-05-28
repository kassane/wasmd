/**
 * The atomic module provides basic support for lock-free
 * concurrent programming.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2016.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Source:    $(DRUNTIMESRC core/_atomic.d)
 */
module core.internal.atomic;

import core.atomic;

private {
    /* Construct a type with a shared tail, and if possible with an unshared
    head. */
    template TailShared(U) if (!is(U == shared)) {
        alias TailShared = .TailShared!(shared U);
    }

    template TailShared(S) if (is(S == shared)) {
        // Get the unshared variant of S.
        static if (is(S U == shared U)) {
        } else
            static assert(false, "Should never be triggered. The `static " ~
                    "if` declares `U` as the unshared version of the shared type " ~
                    "`S`. `S` is explicitly declared as shared, so getting `U` " ~
                    "should always work.");

        static if (is(S : U))
            alias TailShared = U;
        else static if (is(S == struct)) {
            enum implName = () {
                /* Start with "_impl". If S has a field with that name, append
                underscores until the clash is resolved. */
                string name = "_impl";
                string[] fieldNames;
                static foreach (alias field; S.tupleof) {
                    fieldNames ~= __traits(identifier, field);
                }
                static bool canFind(string[] haystack, string needle) {
                    foreach (candidate; haystack) {
                        if (candidate == needle)
                            return true;
                    }
                    return false;
                }

                while (canFind(fieldNames, name))
                    name ~= "_";
                return name;
            }();
            struct TailShared {
                static foreach (i, alias field; S.tupleof) {
                    /* On @trusted: This is casting the field from shared(Foo)
                    to TailShared!Foo. The cast is safe because the field has
                    been loaded and is not shared anymore. */
                    mixin("
                        @trusted @property
                        ref "
                            ~ __traits(identifier, field) ~ "()
                        {
                            alias R = TailShared!(typeof(field));
                            return * cast(R*) &"
                            ~ implName ~ ".tupleof[i];
                        }
                    ");
                }
                mixin("
                    S "
                        ~ implName ~ ";
                    alias "
                        ~ implName ~ " this;
                ");
            }
        } else
            alias TailShared = S;
    }
}

 alias atomicCompareExchangeWeak = atomicCompareExchangeStrong;

    bool atomicCompareExchangeStrong(MemoryOrder succ = MemoryOrder.seq, MemoryOrder fail = MemoryOrder.seq, T)(T* dest, T* compare, T value) pure nothrow @nogc @trusted
        if (CanCAS!T)
    {
        static assert(fail != MemoryOrder.rel && fail != MemoryOrder.acq_rel,
                      "Invalid fail MemoryOrder for atomicCompareExchangeStrong()");
        static assert (succ >= fail, "The first MemoryOrder argument for atomicCompareExchangeStrong() cannot be weaker than the second argument");
        bool success;

        static if (T.sizeof == size_t.sizeof * 2)
        {
            // some values simply cannot be loa'd here, so we'll use an intermediary pointer that we can move instead
            T* valuePointer = &value;

            version (D_InlineAsm_X86)
            {
                asm pure nothrow @nogc @trusted
                {
                    push EBX; // call preserved
                    push EDI;

                    mov EDI, valuePointer; // value
                    mov EBX, [EDI];
                    mov ECX, [EDI + size_t.sizeof];
                    mov EDI, compare; // [compare]
                    mov EAX, [EDI];
                    mov EDX, [EDI + size_t.sizeof];

                    mov EDI, dest;
                    lock; cmpxchg8b [EDI];

                    setz success;
                    mov EDI, compare;
                    mov [EDI], EAX;
                    mov [EDI + size_t.sizeof], EDX;

                    pop EDI;
                    pop EBX;
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm pure nothrow @nogc @trusted
                {
                    push RBX; // call preserved

                    mov R8, valuePointer; // value
                    mov RBX, [R8];
                    mov RCX, [R8 + size_t.sizeof];
                    mov R8, compare; // [compare]
                    mov RAX, [R8];
                    mov RDX, [R8 + size_t.sizeof];

                    mov R8, dest;
                    lock; cmpxchg16b [R8];

                    setz success;
                    mov R8, compare;
                    mov [R8], RAX;
                    mov [R8 + size_t.sizeof], RDX;

                    pop RBX;
                }
            }
            else
                static assert(0, "Operation not supported");
        }
        else
        {
            version (D_InlineAsm_X86)
            {
            }
            else version (D_InlineAsm_X86_64)
            {
            }
            else
                static assert(0, "Operation not supported");

            enum SrcReg = SizedReg!CX;
            enum ValueReg = SizedReg!(DX, T);
            enum CompareReg = SizedReg!(AX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    mov %1, value;
                    mov %0, compare;
                    mov %2, [%0];

                    mov %0, dest;
                    lock; cmpxchg [%0], %1;

                    setz success;
                    mov %0, compare;
                    mov [%0], %2;
                }
            }, [SrcReg, ValueReg, CompareReg]));
        }

        return success;
    }

    alias atomicCompareExchangeWeakNoResult = atomicCompareExchangeStrongNoResult;

    bool atomicCompareExchangeStrongNoResult(MemoryOrder succ = MemoryOrder.seq, MemoryOrder fail = MemoryOrder.seq, T)(T* dest, const T compare, T value) pure nothrow @nogc @trusted
        if (CanCAS!T)
    {
        static assert(fail != MemoryOrder.rel && fail != MemoryOrder.acq_rel,
                      "Invalid fail MemoryOrder for atomicCompareExchangeStrongNoResult()");
        static assert (succ >= fail, "The first MemoryOrder argument for atomicCompareExchangeStrongNoResult() cannot be weaker than the second argument");
        bool success;

        static if (T.sizeof == size_t.sizeof * 2)
        {
            // some values simply cannot be loa'd here, so we'll use an intermediary pointer that we can move instead
            T* valuePointer = &value;
            const(T)* comparePointer = &compare;

            version (D_InlineAsm_X86)
            {
                asm pure nothrow @nogc @trusted
                {
                    push EBX; // call preserved
                    push EDI;

                    mov EDI, valuePointer; // value
                    mov EBX, [EDI];
                    mov ECX, [EDI + size_t.sizeof];
                    mov EDI, comparePointer; // compare
                    mov EAX, [EDI];
                    mov EDX, [EDI + size_t.sizeof];

                    mov EDI, dest;
                    lock; cmpxchg8b [EDI];

                    setz success;

                    pop EDI;
                    pop EBX;
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm pure nothrow @nogc @trusted
                {
                    push RBX; // call preserved

                    mov R8, valuePointer; // value
                    mov RBX, [R8];
                    mov RCX, [R8 + size_t.sizeof];
                    mov R8, comparePointer; // compare
                    mov RAX, [R8];
                    mov RDX, [R8 + size_t.sizeof];

                    mov R8, dest;
                    lock; cmpxchg16b [R8];

                    setz success;

                    pop RBX;
                }
            }
            else
                static assert(0, "Operation not supported");
        }
        else
        {
            version (D_InlineAsm_X86)
            {
            }
            else version (D_InlineAsm_X86_64)
            {
            }
            else
                static assert(0, "Operation not supported");

            enum SrcReg = SizedReg!CX;
            enum ValueReg = SizedReg!(DX, T);
            enum CompareReg = SizedReg!(AX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    mov %1, value;
                    mov %2, compare;

                    mov %0, dest;
                    lock; cmpxchg [%0], %1;

                    setz success;
                }
            }, [SrcReg, ValueReg, CompareReg]));
        }

        return success;
    }
    
// This is an ABI adapter that works on all architectures.  It type puns
// floats and doubles to ints and longs, atomically loads them, then puns
// them back.  This is necessary so that they get returned in floating
// point instead of integer registers.
TailShared!T atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)(ref const shared T val) pure nothrow @nogc @trusted
        if (__traits(isFloating, T)) {
    static if (T.sizeof == int.sizeof) {
        static assert(is(T : float));
        auto ptr = cast(const shared int*)&val;
        auto asInt = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*)&asInt);
    } else static if (T.sizeof == long.sizeof) {
        static assert(is(T : double));
        auto ptr = cast(const shared long*)&val;
        auto asLong = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*)&asLong);
    } else {
        static assert(0, "Cannot atomically load 80-bit reals.");
    }
}

// This is an ABI adapter that works on all architectures.  It type puns
// floats and doubles to ints and longs, atomically loads them, then puns
// them back.  This is necessary so that they get returned in floating
// point instead of integer registers.
T atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)(ref const T val) pure nothrow @nogc @trusted
        if (__traits(isFloating, T)) {
    static if (T.sizeof == int.sizeof) {
        static assert(is(T : float));
        auto ptr = cast(const shared int*)&val;
        auto asInt = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*)&asInt);
    } else static if (T.sizeof == long.sizeof) {
        static assert(is(T : double));
        auto ptr = cast(const shared long*)&val;
        auto asLong = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*)&asLong);
    } else {
        static assert(0, "Cannot atomically load 80-bit reals.");
    }
}
