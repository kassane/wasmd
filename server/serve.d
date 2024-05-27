import arsd.cgi;
import std.path;
import std.file;
import std.string;
import std.process;
import std.stdio;

// -Wl,--export=__heap_base

// https://github.com/skoppe/wasm-sourcemaps

void handler(Cgi cgi)
{

    if (cgi.pathInfo == "/webassembly-core.js")
    {
        cgi.setResponseContentType("text/javascript");
        cgi.write(readText("webassembly-core.js"), true);
        return;
    }

    // lol trivial validation
    size_t dot;
    {
        if (cgi.pathInfo.length > 32)
            return;
        foreach (idx, ch; cgi.pathInfo[1 .. $])
        {
            if (!(
                    (ch >= '0' && ch <= '9') ||
                    (ch >= 'A' && ch <= 'Z') ||
                    (ch >= 'a' && ch <= 'z') ||
                    ch == '_' ||
                    ch == '.'
                ))
                return;
            if (ch == '.')
            {
                if (idx == 0)
                    return;
                if (dot)
                    return;
                dot = idx;
            }
        }
    }

    auto path = cgi.pathInfo.length == 0 ? "" : cgi.pathInfo[1 .. $];

    if (dot && path[dot .. $] == ".wasm")
    {
        cgi.setResponseContentType("application/wasm");
        cgi.write(read("../" ~ path), true);
        return;

    }

    if (path.length == 0)
    {
        // index
        string html = "<html><head><title>Webassembly in D</title></head><body><ul>";
        foreach (string name; dirEntries("..", "*.d", SpanMode.shallow))
        {
            if (name == "../usertemp.d")
                continue;
            html ~= "<li><a href=\"" ~ name[3 .. $ - 2] ~ "\">" ~ name[3 .. $] ~ "</a></li>";
        }

        html ~= `</ul><b>Try it yourself</b><p>Rules: <ol><li>Small files only</li><li>Copy/paste your code locally because I don't save it</li><li>Most things won't work</li><li>If two users try this simultaneously the race condition might bite you.</li><li>Tip: use the export keyword on functions you want visible by javascript!</li></ol>
		<form method="POST" action="/usertemp">
			Paste your D source code here:<br />
			<textarea name="source"></textarea>
			<br /><button type="submit">Try it</button>
		</form>
		</body></html>`;
        cgi.write(html, true);
        return;
    }

    if (dot && path[dot .. $] == ".d")
    {
        cgi.setResponseContentType("text/plain");
        cgi.write(readText("../" ~ path), true);
        return;

    }

    if (dot)
        return;

    if (path == "usertemp")
    {
        if ("source" in cgi.post)
            std.file.write("../usertemp.d", cgi.post["source"]);
    }

    // otherwise, compile and serve!
    if (!exists("../" ~ path ~ ".d"))
    {
        cgi.write("404");
        return;
    }
    //--revert=dtorfields
    string cmd;
    cmd = "ldc2 --revert=dtorfields --fvisibility=hidden -i=. -i=core -i=std -Iarsd-webassembly/ -L-allow-undefined -of" ~ path ~ ".wasm -mtriple=wasm32-unknown-unknown-wasm " ~ path ~ ".d arsd-webassembly/object.d";

    writefln("getcmd=%s", getcwd);
    const wasm_file = buildPath("..", path).setExtension("wasm");
    cmd = "ldc2 -i=. --d-version=CarelessAlocation -i=std -Iarsd-webassembly/ -L-allow-undefined -of" ~ wasm_file ~ " -mtriple=wasm32-unknown-unknown-wasm arsd-webassembly/core/arsd/aa arsd-webassembly/core/arsd/objectutils arsd-webassembly/core/internal/utf arsd-webassembly/core/arsd/utf_decoding " ~ path ~ ".d arsd-webassembly/object.d";

    cmd = "ldc2 --revert=dtorfields -i=. --d-version=CarelessAlocation -i=std -Iarsd-webassembly/ -L-allow-undefined -of"~path~".wasm -mtriple=wasm32-unknown-unknown-wasm arsd-webassembly/core/arsd/aa arsd-webassembly/core/arsd/objectutils arsd-webassembly/core/internal/utf arsd-webassembly/core/arsd/utf_decoding arsd-webassembly/core/arsd/memory_allocation arsd-webassembly/core/array/v2102 arsd-webassembly/core/array/v2099 arsd-webassembly/core/array/common "~path~" arsd-webassembly/object.d ";
    //    const wasm_file=buildPath(getcwd,"..",path).setExtension("wasm");
    writefln("wasm-file=%s %s", wasm_file, wasm_file.exists);
    writefln("cmd\n%s", cmd);
    if (!wasm_file.exists || cgi.requestMethod == Cgi.RequestMethod.POST)
    {
        auto res = executeShell(
            cmd,
            null,
            Config.none,
            64_000,
            ".."
        );
        if (res.status == 0)
        {
            // yay
        }
        else
        {
            cgi.setResponseContentType("text/plain");
            cgi.write(res.output);
            return;
        }
    }

    const response = readText("webassembly-skeleton.html").replace("omg", path);
    cgi.write(response, true);
    writefln("path=%s exists", path, wasm_file.exists);
    writeln(response);
}

mixin GenericMain!handler;