# Tooling Setup — External Tools for Code Quality

Existing Lua and LÖVE tools that directly address the issues we've identified. These are mature, well-maintained projects — no need to reinvent the wheel.

---

## 1. Luacheck — Static Analysis & Global Detection

**What it does**: Scans Lua files and reports global variable leaks, unused variables, unreachable code, shadowed definitions, and more. This is the single most impactful tool for our codebase — it would have found all ~40 global leaks in seconds.

**Install**:
```bash
luarocks install luacheck
```

**Run**:
```bash
# Scan everything:
luacheck src/ main.lua

# Just globals:
luacheck src/ main.lua --only 111 112 113
# 111 = setting non-standard global
# 112 = mutating non-standard global
# 113 = accessing undefined global
```

**Configuration**: Create `.luacheckrc` in the playtime project root:

```lua
-- .luacheckrc for playtime

-- Lua 5.1 (LuaJIT) + LÖVE framework globals
std = "lua51+love"

-- Maximum line length (0 = no limit)
max_line_length = false

-- Globals that we intentionally set (should shrink to zero over time)
globals = {
    -- These are set in main.lua and used across modules.
    -- As we add explicit requires (Phase 3), remove them from here.
    "logger",
    "snap",
    "keep_angle",
    "registry",
    "benchmarks",
    "inspect",
    "prof",
    "PROF_CAPTURE",
    "ProFi",
}

-- Globals we read but don't set (LÖVE callbacks)
read_globals = {
    "love",
}

-- Exclude vendor and temp code from analysis
exclude_files = {
    "vendor/*",
    "temp/*",
    "spec/*",          -- busted tests use their own globals (describe, it, assert)
    "concat2.lua",
    "output.md",
}

-- Per-file overrides
files["main.lua"] = {
    -- main.lua is allowed to set the globals it creates
    globals = {
        "logger", "snap", "keep_angle", "registry", "benchmarks",
        "inspect", "prof", "PROF_CAPTURE", "ProFi",
        -- Physics callbacks (globals by design in LÖVE)
        "beginContact", "endContact", "preSolve", "postSolve",
    },
}

files["src/script.lua"] = {
    -- Script sandbox intentionally creates globals for scene scripts
    -- (these should eventually move into the sandbox env table only)
    globals = {
        "getObjectsByLabel",
        "mouseWorldPos",
    },
}
```

**What it catches for us**:

| Luacheck warning | Our issue | Example |
|-----------------|-----------|---------|
| W111: setting non-standard global variable | Global function leaks | `add` in character-manager.lua |
| W112: mutating non-standard global variable | Global mutation | `offset` in camera.lua |
| W113: accessing undefined global variable | Using globals without require | `logger:info()` without `local logger = require ...` |
| W211: unused local variable | Dead variables | After cleanup |
| W212: unused argument | Unused function parameters | `swapBodies` in joints.lua |
| W311: value assigned to local variable is unused | Dead assignments | |
| W411: variable was previously defined | Shadowing | `rotateBodyTowards` defined twice |
| W421: accessing undefined variable | Typos in variable names | |
| W521: accessing undefined global variable | Missing requires | |

**Integration with our plan**:

1. **Phase 0.5**: Install luacheck, create `.luacheckrc`, run once to get baseline count
2. **Phase 1**: Fix globals — re-run after each round, watch the count drop to zero
3. **Ongoing**: Add `luacheck src/ main.lua` to the test runner so new leaks are caught immediately

**Progressive tightening**: Start with the permissive config above (allowing known globals). As Phase 3 adds explicit requires, remove globals from the allowed list. The goal is an empty `globals = {}` table — meaning every dependency is explicit.

**Links**:
- Repository: https://github.com/lunarmodules/luacheck
- Documentation: https://luacheck.readthedocs.io/en/stable/
- LuaRocks: https://luarocks.org/modules/mpeterv/luacheck

---

## 2. Lua Language Server (LuaLS) — IDE Integration

**What it does**: Language server that provides real-time analysis in your editor. Highlights globals, unused variables, type mismatches, and missing fields as you type — before you even save the file.

**Install**: Via your editor's extension manager:
- **VS Code**: Install "Lua" extension by sumneko
- **Neovim**: Via Mason or manual LSP config
- **Other editors**: Any editor with LSP support

**Configuration**: Create `.luarc.json` in the playtime project root:

```json
{
    "runtime": {
        "version": "Lua 5.1"
    },
    "workspace": {
        "library": [],
        "checkThirdParty": false
    },
    "diagnostics": {
        "globals": [
            "love"
        ],
        "disable": [
            "lowercase-global"
        ]
    },
    "hint": {
        "enable": true
    }
}
```

**LÖVE support**: LuaLS has a LÖVE addon that provides autocomplete for all `love.*` APIs. Enable it through the addon manager in your editor or by adding the love-api definitions to `workspace.library`.

**What it gives us beyond luacheck**:
- **Autocomplete** for LÖVE APIs and our own modules
- **Go to definition** across files
- **Find all references** — more reliable than grep when globals are eliminated
- **Hover documentation** — shows function signatures and types
- **Real-time feedback** — see issues as you type, not at lint time

**Optional: Type annotations**: LuaLS supports LuaCATS annotations. We could gradually annotate key structures:

```lua
---@class Thing
---@field id string
---@field label string
---@field shapeType string
---@field body love.Body
---@field vertices number[]
---@field width number?
---@field height number?

---@param shapeType string
---@param settings table
---@return Thing
function createThing(shapeType, settings)
```

This is optional and low priority — but once our core data structures (thing, fixture userData, DNA) are annotated, the language server can catch type mismatches automatically. Good for Phase 7+ when we're refactoring the big systems.

**Links**:
- Repository: https://github.com/LuaLS/lua-language-server
- Wiki: https://luals.github.io/wiki/
- Type Checking docs: https://github.com/LuaLS/lua-language-server/wiki/Type-Checking

---

## 3. Busted — Test Framework (Already Partially Present)

**What it does**: Full-featured Lua test framework with `describe`/`it`/`assert` syntax. We already have `spec/math-utils_spec.lua` (23KB) and `spec/utils_spec.lua` (15KB) written for it.

**Install**:
```bash
luarocks install busted
```

**Run**:
```bash
cd experiments/playtime
busted spec/
```

**What it provides over mini-test.lua**:
- **Code coverage** via luacov (`luarocks install luacov`, then `busted --coverage`)
- **Mocking/stubbing** — can mock `love.*` calls for testing modules that use LÖVE
- **Async testing** — useful for testing physics callbacks
- **Multiple output formats** — TAP, JUnit XML (for CI), etc.
- **File watching** — `busted --watch` re-runs on file changes

**Decision**: We have two test frameworks (`tests/mini-test.lua` and `spec/busted`). Options:

| Option | Pros | Cons |
|--------|------|------|
| Keep both | No migration work | Confusing, two places to look |
| Migrate to busted | Better features, larger existing spec/ suite | Need to rewrite tests/unit/*.lua |
| Migrate to mini-test | Zero dependencies, already documented | Lose spec/'s comprehensive tests |
| **Keep both, converge later** | Pragmatic, no work now | Two conventions temporarily |

**Recommendation**: Keep both for now. New tests can use either. Converge later when it matters.

**Links**:
- Repository: https://github.com/lunarmodules/busted
- Documentation: https://lunarmodules.github.io/busted/

---

## 4. StyLua — Code Formatter

**What it does**: Opinionated Lua code formatter. Like prettier for JavaScript — enforces consistent style automatically.

**Install**:
```bash
# Via cargo (Rust):
cargo install stylua

# Or download binary from GitHub releases:
# https://github.com/JohnnyMorganz/StyLua/releases
```

**Configuration**: Create `stylua.toml` in the project root:

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferSingle"
call_parentheses = "Always"
```

**Run**:
```bash
# Check what would change (dry run):
stylua --check src/ main.lua

# Format in place:
stylua src/ main.lua
```

**When to use**: After a big refactor (like splitting playtime-ui.lua or extracting from main.lua), run StyLua to normalize formatting. Don't run it on every save — it can create noisy diffs.

**Risk**: Formatting changes create large diffs that obscure real changes in git history. Best used as a dedicated "format" commit separate from logic changes.

**Links**:
- Repository: https://github.com/JohnnyMorganz/StyLua
- Releases: https://github.com/JohnnyMorganz/StyLua/releases

---

## 5. Luacov — Code Coverage

**What it does**: Measures which lines of code are executed during tests. Shows you exactly what's tested and what's not.

**Install**:
```bash
luarocks install luacov
```

**Run with busted**:
```bash
busted --coverage spec/
# Generates luacov.stats.out, then:
luacov
# Generates luacov.report.out — shows line-by-line coverage
```

**What it tells us**: Right now we have ~22 tests for ~17,000 lines. Coverage will be very low. But as we add tests (Phase 2), we can track progress: "utils.lua went from 0% to 85% coverage."

**Links**:
- Repository: https://github.com/keplerproject/luacov

---

## 6. Selene — Alternative Linter (For Reference)

**What it does**: Modern Lua linter written in Rust. Faster than luacheck with richer output.

**Why we're NOT using it**: Selene is more focused on Roblox/Luau. Luacheck has built-in `std = "love"` support for LÖVE2D, which is what we need. If we ever outgrow luacheck, selene is the upgrade path.

**Links**:
- Repository: https://github.com/Kampfkarren/selene
- Comparison with luacheck: https://kampfkarren.github.io/selene/luacheck.html

---

## Recommended Setup Order

### Immediate (before any code changes)

1. **Install luacheck** → `luarocks install luacheck`
2. **Create `.luacheckrc`** → use the config above
3. **Run once** → `luacheck src/ main.lua` → save output as our baseline

This gives us an exact, machine-verified count of every issue. No more manual grepping.

### Before Phase 1 (fixing globals)

4. **Set up LuaLS** in your editor with LÖVE addon
5. **Try busted** → `luarocks install busted && busted spec/` → see if existing spec/ tests pass

### After Phase 2 (tests written)

6. **Install luacov** → run coverage to see our starting point
7. **Consider StyLua** → only if we want consistent formatting

---

## Integration: Adding Luacheck to the Test Runner

Once luacheck is installed, we can add it to the existing test pipeline. Modify `tests/run.lua` or create a wrapper script:

```bash
#!/bin/bash
# run-checks.sh

echo "=== Luacheck ==="
luacheck src/ main.lua
LINT_EXIT=$?

echo ""
echo "=== Unit Tests ==="
lua tests/run.lua
TEST_EXIT=$?

echo ""
echo "=== Busted Tests ==="
busted spec/ 2>/dev/null
BUSTED_EXIT=$?

if [ $LINT_EXIT -ne 0 ] || [ $TEST_EXIT -ne 0 ]; then
    echo ""
    echo "FAILED: lint=$LINT_EXIT tests=$TEST_EXIT busted=$BUSTED_EXIT"
    exit 1
else
    echo ""
    echo "ALL PASSED"
    exit 0
fi
```

This means every time we check our work, we get: lint results + unit tests + spec tests in one command.

---

## 7. Profiling — What We Have and What Else Exists

### Already in the project

**jprof** (vendor/jprof.lua) — Manual zone profiler designed for LÖVE. You push/pop named zones around code sections, and it records timing + memory. Already instrumented in main.lua with zones for `frame`, `physics-update`, `physicsWorld:update`, `pointers`, `drawworld`, `drawtexturedworld`.

```lua
-- Already in main.lua:
prof = require 'vendor.jprof'
PROF_CAPTURE = false  -- set true to record

prof.push('frame')
-- ... game logic ...
prof.pop('frame')

-- When PROF_CAPTURE is true, writes prof.mpack on quit
prof.write("prof.mpack")
```

**Viewer**: jprof includes its own LÖVE-based flame graph viewer. It shows frame duration (purple) and memory consumption (green) over time. You can select frame ranges and switch between time-based and memory-based analysis. Three averaging modes (max, arithmetic, harmonic mean).

**When PROF_CAPTURE is false**, all profiling functions become no-ops — zero overhead in normal use.

**ProFi** (vendor/ProFi.lua) — Debug-hook-based profiler. Hooks into Lua's debug system to measure every function call automatically (no manual instrumentation). Currently commented out in main.lua. Produces a text report with per-function call counts, durations, and memory.

```lua
-- Currently commented out in main.lua:
ProFi = require 'vendor.ProFi'
ProFi:start()
-- ... run game ...
ProFi:stop()
ProFi:writeReport('ProFi.txt')
```

**Trade-off**: ProFi doesn't need manual zones (measures everything), but debug hooks add overhead and don't play well with LuaJIT's JIT compiler. Use it for finding "which function is slow?" but don't trust absolute timings.

### Comparison of all LÖVE/Lua profiling options

| Tool | Type | Instrumentation | Viewer | Best for |
|------|------|----------------|--------|----------|
| **jprof** (have it) | Manual zones | Push/pop in code | Own LÖVE flame graph | Frame-level timing, memory per zone |
| **ProFi** (have it) | Debug hook | Automatic | Text file report | Finding which functions are slow |
| **AppleCake** | Manual zones | Push/pop in code | **Chrome `about://tracing`** | Best visualization, thread support |
| **profile.lua** | Debug hook | Automatic | Text/CSV | Lightweight (~200 lines), zero deps |
| **LuaJIT built-in** | Statistical sampling | None needed | Text/flamegraph | Zero-instrumentation sampling |
| **Piefiller** | Debug hook | Automatic | In-app pie chart overlay | Quick visual during development |

### AppleCake — The upgrade worth knowing about

If jprof's viewer ever feels limiting, AppleCake is the clear upgrade path. It outputs to **Chrome's built-in tracing tool** (`about://tracing` or Perfetto), which is far more powerful for zooming, searching, and comparing frames.

Key advantages over jprof:
- **Chrome DevTools timeline** — industry-standard profiling UI with zoom, search, thread lanes
- **jprof compatibility** — designed as a migration path, similar push/pop API
- **Memory timeline** — tracks Lua memory as a graph over time
- **Multi-thread support** — if LÖVE threads are ever used
- **Crash recovery** — flushes on every profile write, so data survives crashes

```lua
-- AppleCake usage (similar to jprof):
local ac = require("lib.AppleCake")(true) -- true = enabled
ac:beginSession("gameplay")
ac:profileFunc("physics", function()
    world:update(dt)
end)
ac:endSession()
-- Opens in Chrome: about://tracing → load the JSON
```

**Install**: `git clone https://github.com/EngineerSmith/AppleCake` into vendor/

**Links**:
- Repository: https://github.com/EngineerSmith/AppleCake
- Documentation: https://engineersmith.github.io/AppleCake-Docs/

### Tools we're NOT using and why

| Tool | Why not |
|------|---------|
| **LuaJIT built-in profiler** | Wipes the JIT cache to sample — changes what it's measuring. Bad for physics-heavy apps where JIT performance matters. |
| **Piefiller** | Fun visual but less useful than flame graphs for a complex app. |
| **profile.lua** | ProFi already fills the "automatic debug hook profiler" role. |
| **SystemTap/perf** | Linux-only, C-level profiling. Overkill for Lua-level analysis. |

### Assessment

The project is **already well-equipped for profiling**. jprof gives precise per-zone timing with flame graphs, ProFi gives automatic function-level overview. The only meaningful upgrade would be AppleCake for Chrome-based visualization — worth installing when we get to Phase 8 (performance) but not needed before then.

---

## 8. Hot Reload & Live Console — Runtime Code Injection

Lua is a scripting language. The game doesn't need to restart to pick up code changes. This is arguably the most powerful capability for AI-assisted development — it turns the running game into a live laboratory.

### What's already available

**Lurker + lume.hotswap** (already in `vendor/` in the main vector-sketch project, but NOT hooked up in playtime).

The main vector-sketch `main.lua` already calls:
```lua
require("vendor.lurker").update()
```

Lurker watches all `.lua` files every 0.5s. When a file changes on disk, it:
1. Unloads the module from `package.loaded`
2. Re-requires the updated file
3. Recursively walks the old module table and replaces all values with the new ones
4. Any code holding a reference to the old module table now sees the new functions

If the new code has a syntax error, lurker shows a nice error screen and keeps watching — fix the file and the game recovers automatically.

**To enable in playtime**, add to `main.lua`:
```lua
local lurker = require('vendor.lurker')
-- In love.update:
lurker.update()
```

Note: lurker and lume already exist in the parent project's vendor/. They'd need to be copied or path-adjusted for the playtime experiment.

### The full landscape

| Tool | Type | Interface | What it does |
|------|------|-----------|-------------|
| **lurker** (have it) | File-watching hot reload | Automatic on save | Detects changed `.lua` files, hot-swaps module tables in place |
| **lovebird** | Browser REPL | `http://localhost:8000` | Runs an HTTP server; execute any Lua in a browser console |
| **LoveDebug** | In-game console | Overlay inside game | Press a key to open console, type Lua, see results |
| **vudu** | In-game debug GUI | Overlay inside game | Variable browser, console, speed controls, settings editor |

### Lurker — Hot Reload on File Save

**How it works**: `lume.hotswap(modname)` is the core mechanism. It:
1. Snapshots `_G` (to detect new globals the module creates)
2. Clears `package.loaded[modname]`
3. Re-requires the module
4. Walks the old module table recursively, replacing functions and values with the new ones
5. Restores `_G` to prevent global leaks during reload

**What updates**: Any function stored in a module's return table. Since most playtime modules follow the `local lib = {} ... return lib` pattern, their functions swap cleanly.

**What does NOT update**:
- **Closures** — if a function captures an upvalue, the old closure persists in whoever holds it
- **Global functions** — those ~88 global function leaks live in `_G`, not in module tables, so lurker can't swap them
- **State/data** — existing table instances keep their old shape; only the module's function table is refreshed
- **`main.lua` itself** — the entry point can't hot-swap itself

**Critical implication**: Fixing the global leaks (Phase 1) directly unlocks reliable hot reload. Once every function lives in a proper module table, lurker can swap everything.

**Links**:
- Repository: https://github.com/rxi/lurker (by rxi, same author as lume)
- Depends on: `vendor/lume.lua` (already in project)

### Lovebird — Browser-Based REPL

**What it does**: Drops a tiny HTTP server into your LÖVE game. Open `http://localhost:8000` in any browser and you get a console where you can type any Lua expression and it executes in the running game.

**Install**: Single file, drop into vendor/
```lua
-- In main.lua:
local lovebird = require('vendor.lovebird')
-- In love.update:
lovebird.update()
```

**What this enables for AI collaboration**:

```lua
-- Inspect live state:
return inspect(state.selection)
return registry:get("body-abc-123")
return state.world.physicsWorld:getBodyCount()

-- Dump a thing's full structure:
local bodies = state.world.physicsWorld:getBodies()
return inspect(bodies[1]:getUserData())

-- Check fixture ordering on a body:
local body = registry:get("some-id").body
for _, f in ipairs(body:getFixtures()) do
    print(f:getUserData() and "sfixture" or "plain")
end

-- Test a function before committing it:
local mu = require('src.math-utils')
return mu.calculateDistance(0, 0, 3, 4)

-- Poke at the scene:
state.world.paused = true
state.currentMode = nil
```

**Why this is the killer tool for AI**: Every custom tool idea from TOOLING-IDEAS.md (scene validator, fixture dumper, character report, influence visualizer) could be implemented as a lovebird command instead of building separate CLI tools. The game is already running with all state loaded — we just need a way to query it. Lovebird IS that way.

**Configuration**:
- `lovebird.port` — default 8000
- `lovebird.whitelist` — IP addresses allowed to connect (default: localhost only)
- `lovebird.wrapprint` — captures `print()` output to the browser console (default: true)
- `lovebird.maxlines` — output buffer size (default: 200)

**Using lovebird without a browser — direct HTTP from Claude/terminal**:

Lovebird is just an HTTP server. The protocol is simple:
- **Execute Lua**: `POST /` with body `input=<url-encoded lua code>`
- **Read output**: `GET /buffer` returns HTML of all print output
- **Browse state**: `GET /env.json?p=<dotted.path>` returns JSON of any global table

This means Claude (or any script) can interact with the running game directly via `curl`:

```bash
# Execute Lua code in the running game:
curl -s -X POST http://localhost:8000/ \
  -d "input=print(state.world.physicsWorld:getBodyCount())"

# Read the output buffer:
curl -s http://localhost:8000/buffer

# Browse a global table as JSON:
curl -s "http://localhost:8000/env.json?p=state"

# One-liner: execute and immediately read output:
curl -s -X POST http://localhost:8000/ \
  -d "input=print(inspect(state.selection))" && \
  sleep 0.1 && \
  curl -s http://localhost:8000/buffer
```

**This is the most direct way for AI to interact with the running game.** No browser needed. Claude can:
1. Send a `curl` POST to execute any Lua expression
2. Read back the output via `curl` GET on `/buffer`
3. Parse the `/env.json` endpoint to browse state programmatically

The `/env.json` endpoint is especially useful — it returns structured JSON that Claude can parse:
```bash
# Returns: {"valid": true, "path": "state", "vars": [{"key": "currentMode", "value": "nil", "type": "nil"}, ...]}
curl -s "http://localhost:8000/env.json?p=state"
```

**Potential improvement**: The output comes back as HTML (with `<span>` tags for timestamps). A small helper could be added to lovebird to return plain text, or we strip tags with `sed`. Alternatively, we could add a custom `/api` endpoint that returns raw text — a ~10 line addition to lovebird.lua.

**Links**:
- Repository: https://github.com/rxi/lovebird
- LÖVE wiki: https://love2d.org/wiki/Lovebird

### LoveDebug — In-Game Overlay Console

**What it does**: Renders a Lua console directly inside the game window. No browser needed — press a key and type Lua. Supports code hot-swapping from within the console.

**When to use**: When you want to inspect something quick without switching to a browser. Less powerful than lovebird but more immediate.

**Links**:
- Forum thread: https://love2d.org/forums/viewtopic.php?t=76742
- Repository: https://github.com/Ranguna/LOVEDEBUG

### Vudu — In-Game Debug GUI

**What it does**: Full debug GUI with a variable browser (drill into any table), console, and settings panel. Toggle with backtick key.

**When to use**: When you want to visually browse the state tree — click through `state.world`, `registry`, individual thing tables. More visual than lovebird but heavier.

**Links**:
- Repository: https://github.com/deltadaedalus/vudu

### Recommended setup for AI collaboration

**Minimum** (Phase 0-1):
1. Copy lurker + lume to playtime's vendor/ (or adjust paths)
2. Add `lurker.update()` to love.update
3. Now AI can edit files and see changes live

**Ideal** (Phase 2+):
1. Lurker for hot reload
2. Lovebird for runtime inspection
3. Combined: AI edits a file → lurker hot-swaps it → AI queries lovebird to verify the change worked

**The dream workflow** (all via terminal — no browser needed):
```bash
# 1. AI queries the running game via curl:
curl -s -X POST http://localhost:8000/ \
  -d "input=local count=0; for _,b in ipairs(state.world.physicsWorld:getBodies()) do if not b:getUserData() then count=count+1 end end; print(count..' bodies have nil userData')"
# Output: "3 bodies have nil userData"

# 2. AI edits object-manager.lua to add validation
# (lurker detects the file change and hot-swaps automatically)

# 3. AI queries again to verify:
curl -s -X POST http://localhost:8000/ \
  -d "input=print('bodies: '..state.world.physicsWorld:getBodyCount())"
# Output: "bodies: 47, all validated"
```

This turns the running game into a live REPL where AI can investigate, fix, and verify — all without restarting. No browser required — just `curl`.

### What hot reload can NOT do

| Limitation | Why | Workaround |
|-----------|-----|-----------|
| Can't swap closures | Old closure captures old upvalue references | Restart game for closure-heavy changes |
| Can't swap global functions | They live in `_G`, not module tables | Fix globals first (Phase 1) |
| Can't reset state | Changed data structures keep old shape | Manual state reset or scene reload |
| Can't swap main.lua | Entry point bootstraps everything | Restart game for main.lua changes |
| Can't swap C modules | LÖVE's C code isn't Lua | Restart game for engine-level changes |

---

## What Each Tool Solves

| Our Issue | Tool | How |
|-----------|------|-----|
| ~40 global function leaks | **Luacheck** | W111 warnings list every single one |
| Unused parameters (`swapBodies`) | **Luacheck** | W212 warnings |
| Shadowed definitions (`rotateBodyTowards`) | **Luacheck** | W411 warnings |
| Dead variables after cleanup | **Luacheck** | W211 warnings |
| Missing `require` statements | **Luacheck** | W113 (accessing undefined global) |
| Real-time feedback while editing | **LuaLS** | Editor warnings as you type |
| Autocomplete for LÖVE APIs | **LuaLS** | With LÖVE addon |
| Navigate to definitions across files | **LuaLS** | Go-to-definition |
| Verify test coverage | **Luacov** | Line-by-line coverage reports |
| Run comprehensive existing tests | **Busted** | spec/ already has 38KB of tests |
| Consistent code formatting | **StyLua** | After refactoring sessions |
| Per-zone frame timing | **jprof** (already in project) | Flame graph of update/draw/physics zones |
| Function-level hotspots | **ProFi** (already in project) | Automatic call counting + duration report |
| Advanced profiling visualization | **AppleCake** (upgrade path) | Chrome tracing timeline with zoom/search |
| Hot reload code while game runs | **Lurker** (already in parent project) | File watcher auto-swaps changed modules |
| Inspect live runtime state | **Lovebird** | Browser REPL executes Lua in running game |
| Browse state visually in-game | **Vudu** | Variable browser + console overlay |

---

## What These Tools Can NOT Solve

These are things we still need our custom tools (TOOLING-IDEAS.md) for:

| Issue | Why external tools don't help |
|-------|-------------------------------|
| Runtime state inspection | **Lovebird** solves this (see Section 8) — browser REPL can query live physics world |
| Save/load correctness | Need actual scene loading, not just code analysis |
| Fixture ordering invariant | Runtime constraint, not visible in code |
| Visual rendering correctness | No tool can judge "does this character look right" |
| Performance hotspots | jprof + ProFi already in project (see Section 7) |
| Character assembly validation | Domain-specific, needs our character report tool |

The external tools handle code quality (globals, types, style). Our custom tools handle domain correctness (physics state, serialization, character assembly).
