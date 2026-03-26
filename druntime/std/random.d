module std.random;

int uniform(int low, int high) 
{
	import arsd.webassembly;
	int max = high - low;
	return low + eval!int(q{ return Math.floor(Math.random() * $0); }, max);
}
