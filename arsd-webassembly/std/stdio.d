module std.stdio;


void writeln(T...)(T t) {
	import arsd.webassembly;
	eval(q{
		var str = "";
		for(var i = 0; i < arguments.length; i++)
			str += arguments[i];

		str += "\n";

		var txt = document.createTextNode(str);
		var fd = document.getElementById("stdout");
		fd.appendChild(txt);
	}, t);
}