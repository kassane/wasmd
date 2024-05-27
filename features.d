void main() {
	int[] a;
	a ~= 1;
	a ~= 2;
	import std.stdio;
	writeln("length ", a.length);
	foreach(i; a)
		writeln(i);
}

version(none):
class A {
	string b;
	int[] c;
	A[] a;
	ubyte[4] e;
	void foo() const {}

	union {
		short p;
		void* t;
	}

	S[] omg;

	void delegate(S)[] test;

	//string[string] aa;
}

struct S {}

void main() {
	int[] test;
	test[6] = 5;

	A a;
	a.test ~= null;
	//a.aa["foo"] = "bar";
}
