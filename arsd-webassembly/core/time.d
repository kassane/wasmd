//Written in the D programming language

/++
    Module containing core time functionality, such as $(LREF Duration) (which
    represents a duration of time) or $(LREF MonoTime) (which represents a
    timestamp of the system's monotonic clock).

    Various functions take a string (or strings) to represent a unit of time
    (e.g. $(D convert!("days", "hours")(numDays))). The valid strings to use
    with such functions are "years", "months", "weeks", "days", "hours",
    "minutes", "seconds", "msecs" (milliseconds), "usecs" (microseconds),
    "hnsecs" (hecto-nanoseconds - i.e. 100 ns) or some subset thereof. There
    are a few functions that also allow "nsecs", but very little actually
    has precision greater than hnsecs.

    $(BOOKTABLE Cheat Sheet,
    $(TR $(TH Symbol) $(TH Description))
    $(LEADINGROW Types)
    $(TR $(TDNW $(LREF Duration)) $(TD Represents a duration of time of weeks
    or less (kept internally as hnsecs). (e.g. 22 days or 700 seconds).))
    $(TR $(TDNW $(LREF TickDuration)) $(TD $(RED DEPRECATED) Represents a duration of time in
    system clock ticks, using the highest precision that the system provides.))
    $(TR $(TDNW $(LREF MonoTime)) $(TD Represents a monotonic timestamp in
    system clock ticks, using the highest precision that the system provides.))
    $(LEADINGROW Functions)
    $(TR $(TDNW $(LREF convert)) $(TD Generic way of converting between two time
    units.))
    $(TR $(TDNW $(LREF dur)) $(TD Allows constructing a $(LREF Duration) from
    the given time units with the given length.))
    $(TR $(TDNW $(LREF weeks)$(NBSP)$(LREF days)$(NBSP)$(LREF hours)$(BR)
    $(LREF minutes)$(NBSP)$(LREF seconds)$(NBSP)$(LREF msecs)$(BR)
    $(LREF usecs)$(NBSP)$(LREF hnsecs)$(NBSP)$(LREF nsecs))
    $(TD Convenience aliases for $(LREF dur).))
    $(TR $(TDNW $(LREF abs)) $(TD Returns the absolute value of a duration.))
    )

    $(BOOKTABLE Conversions,
    $(TR $(TH )
     $(TH From $(LREF Duration))
     $(TH From $(LREF TickDuration))
     $(TH From units)
    )
    $(TR $(TD $(B To $(LREF Duration)))
     $(TD -)
     $(TD $(D tickDuration.)$(REF_SHORT to, std,conv)$(D !Duration()))
     $(TD $(D dur!"msecs"(5)) or $(D 5.msecs()))
    )
    $(TR $(TD $(B To $(LREF TickDuration)))
     $(TD $(D duration.)$(REF_SHORT to, std,conv)$(D !TickDuration()))
     $(TD -)
     $(TD $(D TickDuration.from!"msecs"(msecs)))
    )
    $(TR $(TD $(B To units))
     $(TD $(D duration.total!"days"))
     $(TD $(D tickDuration.msecs))
     $(TD $(D convert!("days", "msecs")(msecs)))
    ))

    Copyright: Copyright 2010 - 2012
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(HTTP jmdavisprog.com, Jonathan M Davis) and Kato Shoichi
    Source:    $(DRUNTIMESRC core/_time.d)
    Macros:
    NBSP=&nbsp;
 +/
module core.time;

import core.exception;
import core.stdc.time;
import core.stdc.stdio;
import core.internal.string;

struct Duration
{
    /++
        Converts this `Duration` to a `string`.

        The string is meant to be human readable, not machine parseable (e.g.
        whether there is an `'s'` on the end of the unit name usually depends on
        whether it's plural or not, and empty units are not included unless the
        Duration is `zero`). Any code needing a specific string format should
        use `total` or `split` to get the units needed to create the desired
        string format and create the string itself.

        The format returned by toString may or may not change in the future.

        Params:
          sink = A sink object, expected to be a delegate or aggregate
                 implementing `opCall` that accepts a `scope const(char)[]`
                 as argument.
      +/
    void toString (SinkT) (scope SinkT sink) const scope
    {
        static immutable units = [
            "weeks", "days", "hours", "minutes", "seconds", "msecs", "usecs"
        ];

        static void appListSep(SinkT sink, uint pos, bool last)
        {
            if (pos == 0)
                return;
            if (!last)
                sink(", ");
            else
                sink(pos == 1 ? " and " : ", and ");
        }

        static void appUnitVal(string units)(SinkT sink, long val)
        {
            immutable plural = val != 1;
            string unit;
            static if (units == "seconds")
                unit = plural ? "secs" : "sec";
            else static if (units == "msecs")
                unit = "ms";
            else static if (units == "usecs")
                unit = "μs";
            else
                unit = plural ? units : units[0 .. $-1];
            sink(signedToTempString(val));
            sink(" ");
            sink(unit);
        }

        if (_hnsecs == 0)
        {
            sink("0 hnsecs");
            return;
        }

        long hnsecs = _hnsecs;
        uint pos;
        static foreach (unit; units)
        {
            if (auto val = splitUnitsFromHNSecs!unit(hnsecs))
            {
                appListSep(sink, pos++, hnsecs == 0);
                appUnitVal!unit(sink, val);
            }
            if (hnsecs == 0)
                return;
        }
        if (hnsecs != 0)
        {
            appListSep(sink, pos++, true);
            appUnitVal!"hnsecs"(sink, hnsecs);
        }
    }

@safe pure:

public:

    /++
        A $(D Duration) of $(D 0). It's shorter than doing something like
        $(D dur!"seconds"(0)) and more explicit than $(D Duration.init).
      +/
    static @property nothrow @nogc Duration zero() { return Duration(0); }

    /++
        Largest $(D Duration) possible.
      +/
    static @property nothrow @nogc Duration max() { return Duration(long.max); }

    /++
        Most negative $(D Duration) possible.
      +/
    static @property nothrow @nogc Duration min() { return Duration(long.min); }

    version (CoreUnittest) unittest
    {
        assert(zero == dur!"seconds"(0));
        assert(Duration.max == Duration(long.max));
        assert(Duration.min == Duration(long.min));
        assert(Duration.min < Duration.zero);
        assert(Duration.zero < Duration.max);
        assert(Duration.min < Duration.max);
        assert(Duration.min - dur!"hnsecs"(1) == Duration.max);
        assert(Duration.max + dur!"hnsecs"(1) == Duration.min);
    }


    /++
        Compares this $(D Duration) with the given $(D Duration).

        Returns:
            $(TABLE
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(Duration rhs) const nothrow @nogc
    {
        return (_hnsecs > rhs._hnsecs) - (_hnsecs < rhs._hnsecs);
    }

    version (CoreUnittest) unittest
    {
        import core.internal.traits : rvalueOf;
        foreach (T; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (U; AliasSeq!(Duration, const Duration, immutable Duration))
            {
                T t = 42;
                // workaround https://issues.dlang.org/show_bug.cgi?id=18296
                version (D_Coverage)
                    U u = T(t._hnsecs);
                else
                    U u = t;
                assert(t == u);
                assert(rvalueOf(t) == u);
                assert(t == rvalueOf(u));
            }
        }

        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (E; AliasSeq!(Duration, const Duration, immutable Duration))
            {
                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(12)) == 0);
                assert((cast(D)Duration(-12)).opCmp(cast(E)Duration(-12)) == 0);

                assert((cast(D)Duration(10)).opCmp(cast(E)Duration(12)) < 0);
                assert((cast(D)Duration(-12)).opCmp(cast(E)Duration(12)) < 0);

                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(10)) > 0);
                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(-12)) > 0);

                assert(rvalueOf(cast(D)Duration(12)).opCmp(cast(E)Duration(12)) == 0);
                assert(rvalueOf(cast(D)Duration(-12)).opCmp(cast(E)Duration(-12)) == 0);

                assert(rvalueOf(cast(D)Duration(10)).opCmp(cast(E)Duration(12)) < 0);
                assert(rvalueOf(cast(D)Duration(-12)).opCmp(cast(E)Duration(12)) < 0);

                assert(rvalueOf(cast(D)Duration(12)).opCmp(cast(E)Duration(10)) > 0);
                assert(rvalueOf(cast(D)Duration(12)).opCmp(cast(E)Duration(-12)) > 0);

                assert((cast(D)Duration(12)).opCmp(rvalueOf(cast(E)Duration(12))) == 0);
                assert((cast(D)Duration(-12)).opCmp(rvalueOf(cast(E)Duration(-12))) == 0);

                assert((cast(D)Duration(10)).opCmp(rvalueOf(cast(E)Duration(12))) < 0);
                assert((cast(D)Duration(-12)).opCmp(rvalueOf(cast(E)Duration(12))) < 0);

                assert((cast(D)Duration(12)).opCmp(rvalueOf(cast(E)Duration(10))) > 0);
                assert((cast(D)Duration(12)).opCmp(rvalueOf(cast(E)Duration(-12))) > 0);
            }
        }
    }


    /++
        Adds, subtracts or calculates the modulo of two durations.

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD %) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            rhs = The duration to add to or subtract from this $(D Duration).
      +/
    Duration opBinary(string op)(const Duration rhs) const nothrow @nogc
        if (op == "+" || op == "-" || op == "%")
    {
        return Duration(mixin("_hnsecs " ~ op ~ " rhs._hnsecs"));
    }

    deprecated Duration opBinary(string op)(const TickDuration rhs) const nothrow @nogc
        if (op == "+" || op == "-")
    {
        return Duration(mixin("_hnsecs " ~ op ~ " rhs.hnsecs"));
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (E; AliasSeq!(Duration, const Duration, immutable Duration))
            {
                assert((cast(D)Duration(5)) + (cast(E)Duration(7)) == Duration(12));
                assert((cast(D)Duration(5)) - (cast(E)Duration(7)) == Duration(-2));
                assert((cast(D)Duration(5)) % (cast(E)Duration(7)) == Duration(5));
                assert((cast(D)Duration(7)) + (cast(E)Duration(5)) == Duration(12));
                assert((cast(D)Duration(7)) - (cast(E)Duration(5)) == Duration(2));
                assert((cast(D)Duration(7)) % (cast(E)Duration(5)) == Duration(2));

                assert((cast(D)Duration(5)) + (cast(E)Duration(-7)) == Duration(-2));
                assert((cast(D)Duration(5)) - (cast(E)Duration(-7)) == Duration(12));
                assert((cast(D)Duration(5)) % (cast(E)Duration(-7)) == Duration(5));
                assert((cast(D)Duration(7)) + (cast(E)Duration(-5)) == Duration(2));
                assert((cast(D)Duration(7)) - (cast(E)Duration(-5)) == Duration(12));
                assert((cast(D)Duration(7)) % (cast(E)Duration(-5)) == Duration(2));

                assert((cast(D)Duration(-5)) + (cast(E)Duration(7)) == Duration(2));
                assert((cast(D)Duration(-5)) - (cast(E)Duration(7)) == Duration(-12));
                assert((cast(D)Duration(-5)) % (cast(E)Duration(7)) == Duration(-5));
                assert((cast(D)Duration(-7)) + (cast(E)Duration(5)) == Duration(-2));
                assert((cast(D)Duration(-7)) - (cast(E)Duration(5)) == Duration(-12));
                assert((cast(D)Duration(-7)) % (cast(E)Duration(5)) == Duration(-2));

                assert((cast(D)Duration(-5)) + (cast(E)Duration(-7)) == Duration(-12));
                assert((cast(D)Duration(-5)) - (cast(E)Duration(-7)) == Duration(2));
                assert((cast(D)Duration(-5)) % (cast(E)Duration(7)) == Duration(-5));
                assert((cast(D)Duration(-7)) + (cast(E)Duration(-5)) == Duration(-12));
                assert((cast(D)Duration(-7)) - (cast(E)Duration(-5)) == Duration(-2));
                assert((cast(D)Duration(-7)) % (cast(E)Duration(5)) == Duration(-2));
            }
        }
    }

    version (CoreUnittest) deprecated unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (T; AliasSeq!(TickDuration, const TickDuration, immutable TickDuration))
            {
                assertApprox((cast(D)Duration(5)) + cast(T)TickDuration.from!"usecs"(7), Duration(70), Duration(80));
                assertApprox((cast(D)Duration(5)) - cast(T)TickDuration.from!"usecs"(7), Duration(-70), Duration(-60));
                assertApprox((cast(D)Duration(7)) + cast(T)TickDuration.from!"usecs"(5), Duration(52), Duration(62));
                assertApprox((cast(D)Duration(7)) - cast(T)TickDuration.from!"usecs"(5), Duration(-48), Duration(-38));

                assertApprox((cast(D)Duration(5)) + cast(T)TickDuration.from!"usecs"(-7), Duration(-70), Duration(-60));
                assertApprox((cast(D)Duration(5)) - cast(T)TickDuration.from!"usecs"(-7), Duration(70), Duration(80));
                assertApprox((cast(D)Duration(7)) + cast(T)TickDuration.from!"usecs"(-5), Duration(-48), Duration(-38));
                assertApprox((cast(D)Duration(7)) - cast(T)TickDuration.from!"usecs"(-5), Duration(52), Duration(62));

                assertApprox((cast(D)Duration(-5)) + cast(T)TickDuration.from!"usecs"(7), Duration(60), Duration(70));
                assertApprox((cast(D)Duration(-5)) - cast(T)TickDuration.from!"usecs"(7), Duration(-80), Duration(-70));
                assertApprox((cast(D)Duration(-7)) + cast(T)TickDuration.from!"usecs"(5), Duration(38), Duration(48));
                assertApprox((cast(D)Duration(-7)) - cast(T)TickDuration.from!"usecs"(5), Duration(-62), Duration(-52));

                assertApprox((cast(D)Duration(-5)) + cast(T)TickDuration.from!"usecs"(-7), Duration(-80), Duration(-70));
                assertApprox((cast(D)Duration(-5)) - cast(T)TickDuration.from!"usecs"(-7), Duration(60), Duration(70));
                assertApprox((cast(D)Duration(-7)) + cast(T)TickDuration.from!"usecs"(-5), Duration(-62), Duration(-52));
                assertApprox((cast(D)Duration(-7)) - cast(T)TickDuration.from!"usecs"(-5), Duration(38), Duration(48));
            }
        }
    }


    /++
        $(RED TickDuration is Deprecated)

        Adds or subtracts two durations.

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD TickDuration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD TickDuration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            lhs = The $(D TickDuration) to add to this $(D Duration) or to
                  subtract this $(D Duration) from.
      +/
    deprecated Duration opBinaryRight(string op, D)(D lhs) const nothrow @nogc
        if ((op == "+" || op == "-") &&
            is(immutable D == immutable TickDuration))
    {
        return Duration(mixin("lhs.hnsecs " ~ op ~ " _hnsecs"));
    }

    version (CoreUnittest) deprecated unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (T; AliasSeq!(TickDuration, const TickDuration, immutable TickDuration))
            {
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) + cast(D)Duration(5), Duration(70), Duration(80));
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) - cast(D)Duration(5), Duration(60), Duration(70));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) + cast(D)Duration(7), Duration(52), Duration(62));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) - cast(D)Duration(7), Duration(38), Duration(48));

                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) + cast(D)Duration(5), Duration(-70), Duration(-60));
                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) - cast(D)Duration(5), Duration(-80), Duration(-70));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) + cast(D)Duration(7), Duration(-48), Duration(-38));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) - cast(D)Duration(7), Duration(-62), Duration(-52));

                assertApprox((cast(T)TickDuration.from!"usecs"(7)) + (cast(D)Duration(-5)), Duration(60), Duration(70));
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) - (cast(D)Duration(-5)), Duration(70), Duration(80));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) + (cast(D)Duration(-7)), Duration(38), Duration(48));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) - (cast(D)Duration(-7)), Duration(52), Duration(62));

                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) + cast(D)Duration(-5), Duration(-80), Duration(-70));
                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) - cast(D)Duration(-5), Duration(-70), Duration(-60));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) + cast(D)Duration(-7), Duration(-62), Duration(-52));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) - cast(D)Duration(-7), Duration(-48), Duration(-38));
            }
        }
    }


    /++
        Adds, subtracts or calculates the modulo of two durations as well as
        assigning the result to this $(D Duration).

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD %) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            rhs = The duration to add to or subtract from this $(D Duration).
      +/
    ref Duration opOpAssign(string op)(const Duration rhs) nothrow @nogc
        if (op == "+" || op == "-" || op == "%")
    {
        mixin("_hnsecs " ~ op ~ "= rhs._hnsecs;");
        return this;
    }

    deprecated ref Duration opOpAssign(string op)(const TickDuration rhs) nothrow @nogc
        if (op == "+" || op == "-")
    {
        mixin("_hnsecs " ~ op ~ "= rhs.hnsecs;");
        return this;
    }

    version (CoreUnittest) unittest
    {
        static void test1(string op, E)(Duration actual, in E rhs, Duration expected, size_t line = __LINE__)
        {
            if (mixin("actual " ~ op ~ " rhs") != expected)
                throw new AssertError("op failed", __FILE__, line);

            if (actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        foreach (E; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            test1!"+="(Duration(5), (cast(E)Duration(7)), Duration(12));
            test1!"-="(Duration(5), (cast(E)Duration(7)), Duration(-2));
            test1!"%="(Duration(5), (cast(E)Duration(7)), Duration(5));
            test1!"+="(Duration(7), (cast(E)Duration(5)), Duration(12));
            test1!"-="(Duration(7), (cast(E)Duration(5)), Duration(2));
            test1!"%="(Duration(7), (cast(E)Duration(5)), Duration(2));

            test1!"+="(Duration(5), (cast(E)Duration(-7)), Duration(-2));
            test1!"-="(Duration(5), (cast(E)Duration(-7)), Duration(12));
            test1!"%="(Duration(5), (cast(E)Duration(-7)), Duration(5));
            test1!"+="(Duration(7), (cast(E)Duration(-5)), Duration(2));
            test1!"-="(Duration(7), (cast(E)Duration(-5)), Duration(12));
            test1!"%="(Duration(7), (cast(E)Duration(-5)), Duration(2));

            test1!"+="(Duration(-5), (cast(E)Duration(7)), Duration(2));
            test1!"-="(Duration(-5), (cast(E)Duration(7)), Duration(-12));
            test1!"%="(Duration(-5), (cast(E)Duration(7)), Duration(-5));
            test1!"+="(Duration(-7), (cast(E)Duration(5)), Duration(-2));
            test1!"-="(Duration(-7), (cast(E)Duration(5)), Duration(-12));
            test1!"%="(Duration(-7), (cast(E)Duration(5)), Duration(-2));

            test1!"+="(Duration(-5), (cast(E)Duration(-7)), Duration(-12));
            test1!"-="(Duration(-5), (cast(E)Duration(-7)), Duration(2));
            test1!"%="(Duration(-5), (cast(E)Duration(-7)), Duration(-5));
            test1!"+="(Duration(-7), (cast(E)Duration(-5)), Duration(-12));
            test1!"-="(Duration(-7), (cast(E)Duration(-5)), Duration(-2));
            test1!"%="(Duration(-7), (cast(E)Duration(-5)), Duration(-2));
        }

        foreach (D; AliasSeq!(const Duration, immutable Duration))
        {
            foreach (E; AliasSeq!(Duration, const Duration, immutable Duration))
            {
                D lhs = D(120);
                E rhs = E(120);
                static assert(!__traits(compiles, lhs += rhs), D.stringof ~ " " ~ E.stringof);
            }
        }
    }

    version (CoreUnittest) deprecated unittest
    {
        static void test2(string op, E)
                         (Duration actual, in E rhs, Duration lower, Duration upper, size_t line = __LINE__)
        {
            assertApprox(mixin("actual " ~ op ~ " rhs"), lower, upper, "op failed", line);
            assertApprox(actual, lower, upper, "op assign failed", line);
        }

        foreach (T; AliasSeq!(TickDuration, const TickDuration, immutable TickDuration))
        {
            test2!"+="(Duration(5), cast(T)TickDuration.from!"usecs"(7), Duration(70), Duration(80));
            test2!"-="(Duration(5), cast(T)TickDuration.from!"usecs"(7), Duration(-70), Duration(-60));
            test2!"+="(Duration(7), cast(T)TickDuration.from!"usecs"(5), Duration(52), Duration(62));
            test2!"-="(Duration(7), cast(T)TickDuration.from!"usecs"(5), Duration(-48), Duration(-38));

            test2!"+="(Duration(5), cast(T)TickDuration.from!"usecs"(-7), Duration(-70), Duration(-60));
            test2!"-="(Duration(5), cast(T)TickDuration.from!"usecs"(-7), Duration(70), Duration(80));
            test2!"+="(Duration(7), cast(T)TickDuration.from!"usecs"(-5), Duration(-48), Duration(-38));
            test2!"-="(Duration(7), cast(T)TickDuration.from!"usecs"(-5), Duration(52), Duration(62));

            test2!"+="(Duration(-5), cast(T)TickDuration.from!"usecs"(7), Duration(60), Duration(70));
            test2!"-="(Duration(-5), cast(T)TickDuration.from!"usecs"(7), Duration(-80), Duration(-70));
            test2!"+="(Duration(-7), cast(T)TickDuration.from!"usecs"(5), Duration(38), Duration(48));
            test2!"-="(Duration(-7), cast(T)TickDuration.from!"usecs"(5), Duration(-62), Duration(-52));

            test2!"+="(Duration(-5), cast(T)TickDuration.from!"usecs"(-7), Duration(-80), Duration(-70));
            test2!"-="(Duration(-5), cast(T)TickDuration.from!"usecs"(-7), Duration(60), Duration(70));
            test2!"+="(Duration(-7), cast(T)TickDuration.from!"usecs"(-5), Duration(-62), Duration(-52));
            test2!"-="(Duration(-7), cast(T)TickDuration.from!"usecs"(-5), Duration(38), Duration(48));
        }

        foreach (D; AliasSeq!(const Duration, immutable Duration))
        {
            foreach (E; AliasSeq!(TickDuration, const TickDuration, immutable TickDuration))
            {
                D lhs = D(120);
                E rhs = E(120);
                static assert(!__traits(compiles, lhs += rhs), D.stringof ~ " " ~ E.stringof);
            }
        }
    }


    /++
        Multiplies or divides the duration by an integer value.

        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply this $(D Duration) by.
      +/
    Duration opBinary(string op)(long value) const nothrow @nogc
        if (op == "*" || op == "/")
    {
        mixin("return Duration(_hnsecs " ~ op ~ " value);");
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(5)) * 7 == Duration(35));
            assert((cast(D)Duration(7)) * 5 == Duration(35));

            assert((cast(D)Duration(5)) * -7 == Duration(-35));
            assert((cast(D)Duration(7)) * -5 == Duration(-35));

            assert((cast(D)Duration(-5)) * 7 == Duration(-35));
            assert((cast(D)Duration(-7)) * 5 == Duration(-35));

            assert((cast(D)Duration(-5)) * -7 == Duration(35));
            assert((cast(D)Duration(-7)) * -5 == Duration(35));

            assert((cast(D)Duration(5)) * 0 == Duration(0));
            assert((cast(D)Duration(-5)) * 0 == Duration(0));
        }
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(5)) / 7 == Duration(0));
            assert((cast(D)Duration(7)) / 5 == Duration(1));

            assert((cast(D)Duration(5)) / -7 == Duration(0));
            assert((cast(D)Duration(7)) / -5 == Duration(-1));

            assert((cast(D)Duration(-5)) / 7 == Duration(0));
            assert((cast(D)Duration(-7)) / 5 == Duration(-1));

            assert((cast(D)Duration(-5)) / -7 == Duration(0));
            assert((cast(D)Duration(-7)) / -5 == Duration(1));
        }
    }


    /++
        Multiplies/Divides the duration by an integer value as well as
        assigning the result to this $(D Duration).

        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply/divide this $(D Duration) by.
      +/
    ref Duration opOpAssign(string op)(long value) nothrow @nogc
        if (op == "*" || op == "/")
    {
        mixin("_hnsecs " ~ op ~ "= value;");
        return this;
    }

    version (CoreUnittest) unittest
    {
        static void test(D)(D actual, long value, Duration expected, size_t line = __LINE__)
        {
            if ((actual *= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if (actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        test(Duration(5), 7, Duration(35));
        test(Duration(7), 5, Duration(35));

        test(Duration(5), -7, Duration(-35));
        test(Duration(7), -5, Duration(-35));

        test(Duration(-5), 7, Duration(-35));
        test(Duration(-7), 5, Duration(-35));

        test(Duration(-5), -7, Duration(35));
        test(Duration(-7), -5, Duration(35));

        test(Duration(5), 0, Duration(0));
        test(Duration(-5), 0, Duration(0));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(!__traits(compiles, cdur *= 12));
        static assert(!__traits(compiles, idur *= 12));
    }

    version (CoreUnittest) unittest
    {
        static void test(Duration actual, long value, Duration expected, size_t line = __LINE__)
        {
            if ((actual /= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if (actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        test(Duration(5), 7, Duration(0));
        test(Duration(7), 5, Duration(1));

        test(Duration(5), -7, Duration(0));
        test(Duration(7), -5, Duration(-1));

        test(Duration(-5), 7, Duration(0));
        test(Duration(-7), 5, Duration(-1));

        test(Duration(-5), -7, Duration(0));
        test(Duration(-7), -5, Duration(1));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(!__traits(compiles, cdur /= 12));
        static assert(!__traits(compiles, idur /= 12));
    }


    /++
        Divides two durations.

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD /) $(TD Duration) $(TD -->) $(TD long))
        )

        Params:
            rhs = The duration to divide this $(D Duration) by.
      +/
    long opBinary(string op)(Duration rhs) const nothrow @nogc
        if (op == "/")
    {
        return _hnsecs / rhs._hnsecs;
    }

    version (CoreUnittest) unittest
    {
        assert(Duration(5) / Duration(7) == 0);
        assert(Duration(7) / Duration(5) == 1);
        assert(Duration(8) / Duration(4) == 2);

        assert(Duration(5) / Duration(-7) == 0);
        assert(Duration(7) / Duration(-5) == -1);
        assert(Duration(8) / Duration(-4) == -2);

        assert(Duration(-5) / Duration(7) == 0);
        assert(Duration(-7) / Duration(5) == -1);
        assert(Duration(-8) / Duration(4) == -2);

        assert(Duration(-5) / Duration(-7) == 0);
        assert(Duration(-7) / Duration(-5) == 1);
        assert(Duration(-8) / Duration(-4) == 2);
    }


    /++
        Multiplies an integral value and a $(D Duration).

        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD long) $(TD *) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            value = The number of units to multiply this $(D Duration) by.
      +/
    Duration opBinaryRight(string op)(long value) const nothrow @nogc
        if (op == "*")
    {
        return opBinary!op(value);
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert(5 * cast(D)Duration(7) == Duration(35));
            assert(7 * cast(D)Duration(5) == Duration(35));

            assert(5 * cast(D)Duration(-7) == Duration(-35));
            assert(7 * cast(D)Duration(-5) == Duration(-35));

            assert(-5 * cast(D)Duration(7) == Duration(-35));
            assert(-7 * cast(D)Duration(5) == Duration(-35));

            assert(-5 * cast(D)Duration(-7) == Duration(35));
            assert(-7 * cast(D)Duration(-5) == Duration(35));

            assert(0 * cast(D)Duration(-5) == Duration(0));
            assert(0 * cast(D)Duration(5) == Duration(0));
        }
    }


    /++
        Returns the negation of this $(D Duration).
      +/
    Duration opUnary(string op)() const nothrow @nogc
        if (op == "-")
    {
        return Duration(-_hnsecs);
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert(-(cast(D)Duration(7)) == Duration(-7));
            assert(-(cast(D)Duration(5)) == Duration(-5));
            assert(-(cast(D)Duration(-7)) == Duration(7));
            assert(-(cast(D)Duration(-5)) == Duration(5));
            assert(-(cast(D)Duration(0)) == Duration(0));
        }
    }


    /++
        $(RED TickDuration is Deprecated)

        Returns a $(LREF TickDuration) with the same number of hnsecs as this
        $(D Duration).
        Note that the conventional way to convert between $(D Duration) and
        $(D TickDuration) is using $(REF to, std,conv), e.g.:
        $(D duration.to!TickDuration())
      +/
    deprecated TickDuration opCast(T)() const nothrow @nogc
        if (is(immutable T == immutable TickDuration))
    {
        return TickDuration.from!"hnsecs"(_hnsecs);
    }

    version (CoreUnittest) deprecated unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            foreach (units; AliasSeq!("seconds", "msecs", "usecs", "hnsecs"))
            {
                enum unitsPerSec = convert!("seconds", units)(1);

                if (TickDuration.ticksPerSec >= unitsPerSec)
                {
                    foreach (T; AliasSeq!(TickDuration, const TickDuration, immutable TickDuration))
                    {
                        auto t = TickDuration.from!units(1);
                        assertApprox(cast(T)cast(D)dur!units(1), t - TickDuration(1), t + TickDuration(1), units);
                        t = TickDuration.from!units(2);
                        assertApprox(cast(T)cast(D)dur!units(2), t - TickDuration(1), t + TickDuration(1), units);
                    }
                }
                else
                {
                    auto t = TickDuration.from!units(1);
                    assert(t.to!(units, long)() == 0, units);
                    t = TickDuration.from!units(1_000_000);
                    assert(t.to!(units, long)() >= 900_000, units);
                    assert(t.to!(units, long)() <= 1_100_000, units);
                }
            }
        }
    }

    /++
        Allow Duration to be used as a boolean.
        Returns: `true` if this duration is non-zero.
      +/
    bool opCast(T : bool)() const nothrow @nogc
    {
        return _hnsecs != 0;
    }

    version (CoreUnittest) unittest
    {
        auto d = 10.minutes;
        assert(d);
        assert(!(d - d));
        assert(d + d);
    }

    //Temporary hack until bug http://d.puremagic.com/issues/show_bug.cgi?id=5747 is fixed.
    Duration opCast(T)() const nothrow @nogc
        if (is(immutable T == immutable Duration))
    {
        return this;
    }


    /++
        Splits out the Duration into the given units.

        split takes the list of time units to split out as template arguments.
        The time unit strings must be given in decreasing order. How it returns
        the values for those units depends on the overload used.

        The overload which accepts function arguments takes integral types in
        the order that the time unit strings were given, and those integers are
        passed by $(D ref). split assigns the values for the units to each
        corresponding integer. Any integral type may be used, but no attempt is
        made to prevent integer overflow, so don't use small integral types in
        circumstances where the values for those units aren't likely to fit in
        an integral type that small.

        The overload with no arguments returns the values for the units in a
        struct with members whose names are the same as the given time unit
        strings. The members are all $(D long)s. This overload will also work
        with no time strings being given, in which case $(I all) of the time
        units from weeks through hnsecs will be provided (but no nsecs, since it
        would always be $(D 0)).

        For both overloads, the entire value of the Duration is split among the
        units (rather than splitting the Duration across all units and then only
        providing the values for the requested units), so if only one unit is
        given, the result is equivalent to $(LREF total).

        $(D "nsecs") is accepted by split, but $(D "years") and $(D "months")
        are not.

        For negative durations, all of the split values will be negative.
      +/
    template split(units...)
        if (allAreAcceptedUnits!("weeks", "days", "hours", "minutes", "seconds",
                                "msecs", "usecs", "hnsecs", "nsecs")([units]) &&
           unitsAreInDescendingOrder([units]))
    {
        /++ Ditto +/
        void split(Args...)(out Args args) const nothrow @nogc
            if (units.length != 0 && args.length == units.length && allAreMutableIntegralTypes!Args)
        {
            long hnsecs = _hnsecs;
            foreach (i, unit; units)
            {
                static if (unit == "nsecs")
                    args[i] = cast(Args[i])convert!("hnsecs", "nsecs")(hnsecs);
                else
                    args[i] = cast(Args[i])splitUnitsFromHNSecs!unit(hnsecs);
            }
        }

        /++ Ditto +/
        auto split() const nothrow @nogc
        {
            static if (units.length == 0)
                return split!("weeks", "days", "hours", "minutes", "seconds", "msecs", "usecs", "hnsecs")();
            else
            {
                static string genMemberDecls()
                {
                    string retval;
                    foreach (unit; units)
                    {
                        retval ~= "long ";
                        retval ~= unit;
                        retval ~= "; ";
                    }
                    return retval;
                }

                static struct SplitUnits
                {
                    mixin(genMemberDecls());
                }

                static string genSplitCall()
                {
                    auto retval = "split(";
                    foreach (i, unit; units)
                    {
                        retval ~= "su.";
                        retval ~= unit;
                        if (i < units.length - 1)
                            retval ~= ", ";
                        else
                            retval ~= ");";
                    }
                    return retval;
                }

                SplitUnits su = void;
                mixin(genSplitCall());
                return su;
            }
        }

        /+
            Whether all of the given arguments are integral types.
          +/
        private template allAreMutableIntegralTypes(Args...)
        {
            static if (Args.length == 0)
                enum allAreMutableIntegralTypes = true;
            else static if (!is(Args[0] == long) &&
                           !is(Args[0] == int) &&
                           !is(Args[0] == short) &&
                           !is(Args[0] == byte) &&
                           !is(Args[0] == ulong) &&
                           !is(Args[0] == uint) &&
                           !is(Args[0] == ushort) &&
                           !is(Args[0] == ubyte))
            {
                enum allAreMutableIntegralTypes = false;
            }
            else
                enum allAreMutableIntegralTypes = allAreMutableIntegralTypes!(Args[1 .. $]);
        }

        version (CoreUnittest) unittest
        {
            foreach (T; AliasSeq!(long, int, short, byte, ulong, uint, ushort, ubyte))
                static assert(allAreMutableIntegralTypes!T);
            foreach (T; AliasSeq!(long, int, short, byte, ulong, uint, ushort, ubyte))
                static assert(!allAreMutableIntegralTypes!(const T));
            foreach (T; AliasSeq!(char, wchar, dchar, float, double, real, string))
                static assert(!allAreMutableIntegralTypes!T);
            static assert(allAreMutableIntegralTypes!(long, int, short, byte));
            static assert(!allAreMutableIntegralTypes!(long, int, short, char, byte));
            static assert(!allAreMutableIntegralTypes!(long, int*, short));
        }
    }

    ///
    unittest
    {
        {
            auto d = dur!"days"(12) + dur!"minutes"(7) + dur!"usecs"(501223);
            long days;
            int seconds;
            short msecs;
            d.split!("days", "seconds", "msecs")(days, seconds, msecs);
            assert(days == 12);
            assert(seconds == 7 * 60);
            assert(msecs == 501);

            auto splitStruct = d.split!("days", "seconds", "msecs")();
            assert(splitStruct.days == 12);
            assert(splitStruct.seconds == 7 * 60);
            assert(splitStruct.msecs == 501);

            auto fullSplitStruct = d.split();
            assert(fullSplitStruct.weeks == 1);
            assert(fullSplitStruct.days == 5);
            assert(fullSplitStruct.hours == 0);
            assert(fullSplitStruct.minutes == 7);
            assert(fullSplitStruct.seconds == 0);
            assert(fullSplitStruct.msecs == 501);
            assert(fullSplitStruct.usecs == 223);
            assert(fullSplitStruct.hnsecs == 0);

            assert(d.split!"minutes"().minutes == d.total!"minutes");
        }

        {
            auto d = dur!"days"(12);
            assert(d.split!"weeks"().weeks == 1);
            assert(d.split!"days"().days == 12);

            assert(d.split().weeks == 1);
            assert(d.split().days == 5);
        }

        {
            auto d = dur!"days"(7) + dur!"hnsecs"(42);
            assert(d.split!("seconds", "nsecs")().nsecs == 4200);
        }

        {
            auto d = dur!"days"(-7) + dur!"hours"(-9);
            auto result = d.split!("days", "hours")();
            assert(result.days == -7);
            assert(result.hours == -9);
        }
    }

    version (CoreUnittest) pure nothrow unittest
    {
        foreach (D; AliasSeq!(const Duration, immutable Duration))
        {
            D d = dur!"weeks"(3) + dur!"days"(5) + dur!"hours"(19) + dur!"minutes"(7) +
                  dur!"seconds"(2) + dur!"hnsecs"(1234567);
            byte weeks;
            ubyte days;
            short hours;
            ushort minutes;
            int seconds;
            uint msecs;
            long usecs;
            ulong hnsecs;
            long nsecs;

            d.split!("weeks", "days", "hours", "minutes", "seconds", "msecs", "usecs", "hnsecs", "nsecs")
                    (weeks, days, hours, minutes, seconds, msecs, usecs, hnsecs, nsecs);
            assert(weeks == 3);
            assert(days == 5);
            assert(hours == 19);
            assert(minutes == 7);
            assert(seconds == 2);
            assert(msecs == 123);
            assert(usecs == 456);
            assert(hnsecs == 7);
            assert(nsecs == 0);

            d.split!("weeks", "days", "hours", "seconds", "usecs")(weeks, days, hours, seconds, usecs);
            assert(weeks == 3);
            assert(days == 5);
            assert(hours == 19);
            assert(seconds == 422);
            assert(usecs == 123456);

            d.split!("days", "minutes", "seconds", "nsecs")(days, minutes, seconds, nsecs);
            assert(days == 26);
            assert(minutes == 1147);
            assert(seconds == 2);
            assert(nsecs == 123456700);

            d.split!("minutes", "msecs", "usecs", "hnsecs")(minutes, msecs, usecs, hnsecs);
            assert(minutes == 38587);
            assert(msecs == 2123);
            assert(usecs == 456);
            assert(hnsecs == 7);

            {
                auto result = d.split!("weeks", "days", "hours", "minutes", "seconds",
                                       "msecs", "usecs", "hnsecs", "nsecs");
                assert(result.weeks == 3);
                assert(result.days == 5);
                assert(result.hours == 19);
                assert(result.minutes == 7);
                assert(result.seconds == 2);
                assert(result.msecs == 123);
                assert(result.usecs == 456);
                assert(result.hnsecs == 7);
                assert(result.nsecs == 0);
            }

            {
                auto result = d.split!("weeks", "days", "hours", "seconds", "usecs");
                assert(result.weeks == 3);
                assert(result.days == 5);
                assert(result.hours == 19);
                assert(result.seconds == 422);
                assert(result.usecs == 123456);
            }

            {
                auto result = d.split!("days", "minutes", "seconds", "nsecs")();
                assert(result.days == 26);
                assert(result.minutes == 1147);
                assert(result.seconds == 2);
                assert(result.nsecs == 123456700);
            }

            {
                auto result = d.split!("minutes", "msecs", "usecs", "hnsecs")();
                assert(result.minutes == 38587);
                assert(result.msecs == 2123);
                assert(result.usecs == 456);
                assert(result.hnsecs == 7);
            }

            {
                auto result = d.split();
                assert(result.weeks == 3);
                assert(result.days == 5);
                assert(result.hours == 19);
                assert(result.minutes == 7);
                assert(result.seconds == 2);
                assert(result.msecs == 123);
                assert(result.usecs == 456);
                assert(result.hnsecs == 7);
                static assert(!is(typeof(result.nsecs)));
            }

            static assert(!is(typeof(d.split("seconds", "hnsecs")(seconds))));
            static assert(!is(typeof(d.split("hnsecs", "seconds", "minutes")(hnsecs, seconds, minutes))));
            static assert(!is(typeof(d.split("hnsecs", "seconds", "msecs")(hnsecs, seconds, msecs))));
            static assert(!is(typeof(d.split("seconds", "hnecs", "msecs")(seconds, hnsecs, msecs))));
            static assert(!is(typeof(d.split("seconds", "msecs", "msecs")(seconds, msecs, msecs))));
            static assert(!is(typeof(d.split("hnsecs", "seconds", "minutes")())));
            static assert(!is(typeof(d.split("hnsecs", "seconds", "msecs")())));
            static assert(!is(typeof(d.split("seconds", "hnecs", "msecs")())));
            static assert(!is(typeof(d.split("seconds", "msecs", "msecs")())));
            alias AliasSeq!("nsecs", "hnsecs", "usecs", "msecs", "seconds",
                              "minutes", "hours", "days", "weeks") timeStrs;
            foreach (i, str; timeStrs[1 .. $])
                static assert(!is(typeof(d.split!(timeStrs[i - 1], str)())));

            D nd = -d;

            {
                auto result = nd.split();
                assert(result.weeks == -3);
                assert(result.days == -5);
                assert(result.hours == -19);
                assert(result.minutes == -7);
                assert(result.seconds == -2);
                assert(result.msecs == -123);
                assert(result.usecs == -456);
                assert(result.hnsecs == -7);
            }

            {
                auto result = nd.split!("weeks", "days", "hours", "minutes", "seconds", "nsecs")();
                assert(result.weeks == -3);
                assert(result.days == -5);
                assert(result.hours == -19);
                assert(result.minutes == -7);
                assert(result.seconds == -2);
                assert(result.nsecs == -123456700);
            }
        }
    }


    /++
        Returns the total number of the given units in this $(D Duration).
        So, unlike $(D split), it does not strip out the larger units.
      +/
    @property long total(string units)() const nothrow @nogc
        if (units == "weeks" ||
           units == "days" ||
           units == "hours" ||
           units == "minutes" ||
           units == "seconds" ||
           units == "msecs" ||
           units == "usecs" ||
           units == "hnsecs" ||
           units == "nsecs")
    {
        return convert!("hnsecs", units)(_hnsecs);
    }

    ///
    unittest
    {
        assert(dur!"weeks"(12).total!"weeks" == 12);
        assert(dur!"weeks"(12).total!"days" == 84);

        assert(dur!"days"(13).total!"weeks" == 1);
        assert(dur!"days"(13).total!"days" == 13);

        assert(dur!"hours"(49).total!"days" == 2);
        assert(dur!"hours"(49).total!"hours" == 49);

        assert(dur!"nsecs"(2007).total!"hnsecs" == 20);
        assert(dur!"nsecs"(2007).total!"nsecs" == 2000);
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"weeks"(12)).total!"weeks" == 12);
            assert((cast(D)dur!"weeks"(12)).total!"days" == 84);

            assert((cast(D)dur!"days"(13)).total!"weeks" == 1);
            assert((cast(D)dur!"days"(13)).total!"days" == 13);

            assert((cast(D)dur!"hours"(49)).total!"days" == 2);
            assert((cast(D)dur!"hours"(49)).total!"hours" == 49);

            assert((cast(D)dur!"nsecs"(2007)).total!"hnsecs" == 20);
            assert((cast(D)dur!"nsecs"(2007)).total!"nsecs" == 2000);
        }
    }

    /// Ditto
    string toString() const scope nothrow
    {
        string result;
        this.toString((in char[] data) { result ~= data; });
        return result;
    }

    ///
    unittest
    {
        assert(Duration.zero.toString() == "0 hnsecs");
        assert(weeks(5).toString() == "5 weeks");
        assert(days(2).toString() == "2 days");
        assert(hours(1).toString() == "1 hour");
        assert(minutes(19).toString() == "19 minutes");
        assert(seconds(42).toString() == "42 secs");
        assert(msecs(42).toString() == "42 ms");
        assert(usecs(27).toString() == "27 μs");
        assert(hnsecs(5).toString() == "5 hnsecs");

        assert(seconds(121).toString() == "2 minutes and 1 sec");
        assert((minutes(5) + seconds(3) + usecs(4)).toString() ==
               "5 minutes, 3 secs, and 4 μs");

        assert(seconds(-42).toString() == "-42 secs");
        assert(usecs(-5239492).toString() == "-5 secs, -239 ms, and -492 μs");
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(0)).toString() == "0 hnsecs");
            assert((cast(D)Duration(1)).toString() == "1 hnsec");
            assert((cast(D)Duration(7)).toString() == "7 hnsecs");
            assert((cast(D)Duration(10)).toString() == "1 μs");
            assert((cast(D)Duration(20)).toString() == "2 μs");
            assert((cast(D)Duration(10_000)).toString() == "1 ms");
            assert((cast(D)Duration(20_000)).toString() == "2 ms");
            assert((cast(D)Duration(10_000_000)).toString() == "1 sec");
            assert((cast(D)Duration(20_000_000)).toString() == "2 secs");
            assert((cast(D)Duration(600_000_000)).toString() == "1 minute");
            assert((cast(D)Duration(1_200_000_000)).toString() == "2 minutes");
            assert((cast(D)Duration(36_000_000_000)).toString() == "1 hour");
            assert((cast(D)Duration(72_000_000_000)).toString() == "2 hours");
            assert((cast(D)Duration(864_000_000_000)).toString() == "1 day");
            assert((cast(D)Duration(1_728_000_000_000)).toString() == "2 days");
            assert((cast(D)Duration(6_048_000_000_000)).toString() == "1 week");
            assert((cast(D)Duration(12_096_000_000_000)).toString() == "2 weeks");

            assert((cast(D)Duration(12)).toString() == "1 μs and 2 hnsecs");
            assert((cast(D)Duration(120_795)).toString() == "12 ms, 79 μs, and 5 hnsecs");
            assert((cast(D)Duration(12_096_020_900_003)).toString() == "2 weeks, 2 secs, 90 ms, and 3 hnsecs");

            assert((cast(D)Duration(-1)).toString() == "-1 hnsecs");
            assert((cast(D)Duration(-7)).toString() == "-7 hnsecs");
            assert((cast(D)Duration(-10)).toString() == "-1 μs");
            assert((cast(D)Duration(-20)).toString() == "-2 μs");
            assert((cast(D)Duration(-10_000)).toString() == "-1 ms");
            assert((cast(D)Duration(-20_000)).toString() == "-2 ms");
            assert((cast(D)Duration(-10_000_000)).toString() == "-1 secs");
            assert((cast(D)Duration(-20_000_000)).toString() == "-2 secs");
            assert((cast(D)Duration(-600_000_000)).toString() == "-1 minutes");
            assert((cast(D)Duration(-1_200_000_000)).toString() == "-2 minutes");
            assert((cast(D)Duration(-36_000_000_000)).toString() == "-1 hours");
            assert((cast(D)Duration(-72_000_000_000)).toString() == "-2 hours");
            assert((cast(D)Duration(-864_000_000_000)).toString() == "-1 days");
            assert((cast(D)Duration(-1_728_000_000_000)).toString() == "-2 days");
            assert((cast(D)Duration(-6_048_000_000_000)).toString() == "-1 weeks");
            assert((cast(D)Duration(-12_096_000_000_000)).toString() == "-2 weeks");

            assert((cast(D)Duration(-12)).toString() == "-1 μs and -2 hnsecs");
            assert((cast(D)Duration(-120_795)).toString() == "-12 ms, -79 μs, and -5 hnsecs");
            assert((cast(D)Duration(-12_096_020_900_003)).toString() == "-2 weeks, -2 secs, -90 ms, and -3 hnsecs");
        }
    }


    /++
        Returns whether this $(D Duration) is negative.
      +/
    @property bool isNegative() const nothrow @nogc
    {
        return _hnsecs < 0;
    }

    version (CoreUnittest) unittest
    {
        foreach (D; AliasSeq!(Duration, const Duration, immutable Duration))
        {
            assert(!(cast(D)Duration(100)).isNegative);
            assert(!(cast(D)Duration(1)).isNegative);
            assert(!(cast(D)Duration(0)).isNegative);
            assert((cast(D)Duration(-1)).isNegative);
            assert((cast(D)Duration(-100)).isNegative);
        }
    }


private:

    /+
        Params:
            hnsecs = The total number of hecto-nanoseconds in this $(D Duration).
      +/
    this(long hnsecs) nothrow @nogc
    {
        _hnsecs = hnsecs;
    }


    long _hnsecs;
}