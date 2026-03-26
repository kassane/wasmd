/++
    Emscripten SDK API bindings for D.

    When compiling with `-mtriple=wasm32-unknown-emscripten`, the Emscripten
    version flag is set.  These declarations let D code call the standard
    emscripten C APIs (`emscripten_*`) without an intermediate C wrapper.

    Usage:
    ---
    import arsd.emscripten;
    emscripten_run_script("alert('hello from D!')");
    emscripten_set_main_loop(&gameLoop, 60, true);
    ---

    See_Also: https://emscripten.org/docs/api_reference/emscripten.h.html
+/
module arsd.emscripten;

version (Emscripten):

// ── Main loop ──────────────────────────────────────────────────────
alias em_callback_func = void function();
alias em_arg_callback_func = void function(void*);

extern (C) @nogc nothrow
{
    /// Set the main event loop.  `fps <= 0` uses requestAnimationFrame.
    void emscripten_set_main_loop(em_callback_func func, int fps, bool simulateInfiniteLoop);

    /// Variant that passes user data to the callback.
    void emscripten_set_main_loop_arg(em_arg_callback_func func, void* arg, int fps, bool simulateInfiniteLoop);

    /// Cancel the current main loop.
    void emscripten_cancel_main_loop();

    /// Pause / resume the main loop.
    void emscripten_pause_main_loop();
    void emscripten_resume_main_loop();
}

// ── JavaScript execution ───────────────────────────────────────────
extern (C) @nogc nothrow
{
    /// Execute JavaScript via eval().  Blocks until complete.
    void emscripten_run_script(const char* script);

    /// Execute JS returning an int.
    int emscripten_run_script_int(const char* script);

    /// Execute JS returning a string (caller must NOT free).
    const(char)* emscripten_run_script_string(const char* script);

    /// Asynchronous eval (non-blocking).
    void emscripten_async_run_script(const char* script, int millis);
}

// ── Memory ─────────────────────────────────────────────────────────
extern (C) @nogc nothrow
{
    /// Get current total wasm memory in bytes.
    size_t emscripten_get_heap_size();

    /// Request memory growth (returns true on success).
    bool emscripten_resize_heap(size_t requestedSize);
}

// ── Timing ─────────────────────────────────────────────────────────
extern (C) @nogc nothrow
{
    /// High-resolution monotonic time in milliseconds (performance.now).
    double emscripten_get_now();

    /// Schedule a callback after `millis` milliseconds.
    void emscripten_async_call(em_arg_callback_func func, void* arg, int millis);
}

// ── Canvas / DOM ───────────────────────────────────────────────────
extern (C) @nogc nothrow
{
    /// Get the CSS pixel size of the target canvas element.
    int emscripten_get_canvas_element_size(const char* target, int* width, int* height);

    /// Set the CSS pixel size of the target canvas element.
    int emscripten_set_canvas_element_size(const char* target, int width, int height);
}

// ── Fetch / networking (async) ─────────────────────────────────────
struct emscripten_fetch_attr_t
{
    char[32] requestMethod;
    void* userData;
    // Simplified; full struct has more fields
}

extern (C) @nogc nothrow
{
    void emscripten_fetch_attr_init(emscripten_fetch_attr_t* fetchAttr);
}

// ── Misc ───────────────────────────────────────────────────────────
extern (C) @nogc nothrow
{
    /// Force a browser exit (not normally used).
    void emscripten_force_exit(int status);

    /// Print a stack trace to stderr.
    void emscripten_log(int flags, const char* fmt, ...);

    /// Sleep for `ms` milliseconds (requires ASYNCIFY).
    void emscripten_sleep(uint ms);
}

/// Emscripten log flags
enum EM_LOG
{
    CONSOLE = 1,
    WARN = 2,
    ERROR = 4,
    C_STACK = 8,
    JS_STACK = 16,
    DEMANGLE = 32,
    NO_PATHS = 64,
    FUNC_PARAMS = 128,
}
