# Playtime Test Suite

## Quick Start

```bash
# Run all tests (unit + integration) via LÖVE
love . --test

# Run unit tests only (no LÖVE required)
lua tests/run.lua
```

---

## Testing Strategy: Hybrid Approach

This project uses a **hybrid testing approach** because it's a graphical, interactive, physics-based application - one of the hardest things to test automatically.

### The Challenge

| Aspect | Difficulty | Why |
|--------|------------|-----|
| Visual output | Hard | "Does this look right?" requires human eyes |
| Physics simulation | Medium | Floating-point drift, timing sensitivity |
| User interaction | Hard | Mouse dragging, clicking objects |
| State mutations | Medium | `state.lua` touched by almost everything |

### Our Solution: Two Test Types

```
tests/
├── mini-test.lua          # The test framework (single file, no dependencies)
├── run.lua                # Test runner (discovers and runs tests)
├── unit/                  # Pure Lua tests - NO LÖVE required
│   └── test_math_utils.lua
└── integration/           # Tests requiring LÖVE
    └── test_physics_world.lua
```

#### 1. Unit Tests (`tests/unit/`)

**What**: Pure function testing - no LÖVE, no graphics, no physics engine.

**Good for**:
- `math-utils.lua` - geometry, splines, vector operations
- `shapes.lua` - shape vertex generation
- `utils.lua` - generic utilities (map, filter, etc.)
- `uuid.lua` - ID generation
- Serialization logic (input/output transformations)

**Run with**: `lua tests/run.lua`

**Example**:
```lua
T.describe("math-utils", function()
    T.it("calculates distance correctly", function()
        T.expect(mathUtils.calculateDistance(0, 0, 3, 4)).toBe(5)
    end)
end)
```

#### 2. Integration Tests (`tests/integration/`)

**What**: Tests that need the LÖVE runtime (physics, graphics context, etc.)

**Good for**:
- Physics world creation and simulation
- Body/fixture/joint creation
- Scene serialization round-trips
- Character creation
- Anything touching `love.physics`, `love.graphics`, etc.

**Run with**: `love . --test`

**Example**:
```lua
T.describe("physics world", function()
    T.it("can create a revolute joint", function()
        local world = love.physics.newWorld(0, 100, true)
        local bodyA = love.physics.newBody(world, 0, 0, "dynamic")
        local bodyB = love.physics.newBody(world, 50, 0, "dynamic")
        local joint = love.physics.newRevoluteJoint(bodyA, bodyB, 25, 0)
        
        T.expect(joint:getType()).toBe("revolute")
        world:destroy()
    end)
end)
```

---

## The Test Framework: mini-test.lua

A single-file test framework (~200 lines) with no external dependencies.

### API

```lua
local T = require 'tests.mini-test'

-- Group tests
T.describe("module name", function()
    
    -- Individual test
    T.it("does something", function()
        -- Assertions
        T.expect(value).toBe(expected)
    end)
end)

-- Run all tests
T.run()
```

### Available Assertions

| Assertion | Description |
|-----------|-------------|
| `.toBe(expected)` | Strict equality (`==`) |
| `.toEqual(expected)` | Deep equality for tables |
| `.toBeNil()` | Value is `nil` |
| `.toNotBeNil()` | Value is not `nil` |
| `.toBeTruthy()` | Value is truthy |
| `.toBeFalsy()` | Value is falsy |
| `.toBeGreaterThan(n)` | Value > n |
| `.toBeLessThan(n)` | Value < n |
| `.toBeCloseTo(n, precision)` | Floating point comparison |
| `.toContain(item)` | Table/string contains item |
| `.toThrow()` | Function throws an error |

---

## Writing New Tests

### Unit Test Template

Create `tests/unit/test_<module>.lua`:

```lua
local T = require 'tests.mini-test'
local myModule = require 'src.my-module'

T.describe("my-module", function()
    
    T.describe("someFunction", function()
        T.it("handles normal input", function()
            local result = myModule.someFunction(input)
            T.expect(result).toBe(expected)
        end)
        
        T.it("handles edge case", function()
            T.expect(function()
                myModule.someFunction(nil)
            end).toThrow()
        end)
    end)
end)
```

### Integration Test Template

Create `tests/integration/test_<feature>.lua`:

```lua
local T = require 'tests.mini-test'

T.describe("feature (integration)", function()
    
    T.it("works with LÖVE physics", function()
        local world = love.physics.newWorld(0, 100, true)
        -- ... test logic ...
        world:destroy()  -- Always clean up!
    end)
end)
```

---

## What We CAN'T Easily Test

Some things are inherently hard to automate:

| Thing | Why | Alternative |
|-------|-----|-------------|
| Visual correctness | Need human eyes | Manual testing, screenshot comparison |
| UI interactions | Click/drag simulation complex | Test underlying state changes |
| "Feel" of physics | Subjective | Test physics values, not feel |
| Performance | Varies by machine | Benchmark separately |

### Workarounds

1. **Serialization round-trips**: Save scene → load scene → compare. Catches data loss bugs.

2. **State assertions**: Instead of testing UI clicks, test that state changes correctly:
   ```lua
   -- Instead of: simulate clicking "Add Rectangle" button
   -- Do: call the function directly and check state
   objectManager.addThing('rectangle', {...})
   T.expect(#world:getBodies()).toBe(1)
   ```

3. **Golden file tests**: For complex outputs, save a known-good result and compare:
   ```lua
   local output = generateSomething()
   local expected = loadGoldenFile("expected_output.json")
   T.expect(output).toEqual(expected)
   ```

---

## Test Organization Guidelines

1. **One test file per source module** (roughly)
   - `src/math-utils.lua` → `tests/unit/test_math_utils.lua`
   - `src/joints.lua` → `tests/integration/test_joints.lua`

2. **Use `describe` to group related tests**
   ```lua
   T.describe("math-utils", function()
       T.describe("lerp", function()
           T.it("...", function() end)
       end)
       T.describe("distance", function()
           T.it("...", function() end)
       end)
   end)
   ```

3. **Clean up in integration tests** - Always destroy physics worlds, bodies, etc.

4. **Test file naming**: `test_<name>.lua` (the runner auto-discovers this pattern)

---

## Running Tests in CI

For automated testing (GitHub Actions, etc.):

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      # Unit tests (no LÖVE)
      - name: Run unit tests
        run: lua tests/run.lua
      
      # Integration tests (needs LÖVE)
      - name: Install LÖVE
        run: sudo apt-get install love
      - name: Run all tests
        run: love . --test
```

---

## Future Improvements

As the test suite grows, consider:

1. **Code coverage** - Track which functions are tested
2. **Mocking** - Fake LÖVE APIs for faster unit tests
3. **Snapshot testing** - Auto-save expected outputs
4. **Performance benchmarks** - Track regressions
5. **Visual regression** - Screenshot comparison (complex but valuable)

---

## Troubleshooting

**Tests won't run with `lua tests/run.lua`**:
- Make sure you're in the project root directory
- Check that `package.path` includes `src/` and `tests/`

**Integration tests fail but unit tests pass**:
- LÖVE might not be installed or not in PATH
- Run `love --version` to verify

**Tests pass locally but fail in CI**:
- Check LÖVE version compatibility
- Floating point precision may differ across platforms
