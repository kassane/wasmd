 ## arsd-webassembly - Minimal D runtime for Wasm targets
 
This custom D runtime for Wasm targets was started by [Adam D. Ruppe](https://github.com/adamdruppe) and improved by [Marcelo S. N. Mancini](https://github.com/MrcSnm).

- **arsd-webassembly** is the library code, including partial source ports
of some libraries I use and a minimal druntime for use on the web.
You should compile with these modules instead of the real libraries.

- **server** is a little web server and the other bridge code in javascript
and html. Of course you don't need to use my webserver.

This is **EXTREMELY MINIMAL**. I only wrote what I needed for my demo. Your
use cases will probably not work.
