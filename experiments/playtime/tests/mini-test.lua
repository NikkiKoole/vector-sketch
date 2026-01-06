--[[
    mini-test.lua - A minimal test framework for Playtime

    Usage:
        local T = require 'tests.mini-test'

        T.describe("my module", function()
            T.it("does something", function()
                T.expect(1 + 1).toBe(2)
            end)
        end)

        T.run()  -- Returns true if all passed, false otherwise
]]

local T = {}

-- State
local suites = {}
local currentSuite = nil
local results = { passed = 0, failed = 0, errors = {} }

-- Colors (ANSI escape codes, works in most terminals)
local colors = {
    reset = "\27[0m",
    green = "\27[32m",
    red = "\27[31m",
    yellow = "\27[33m",
    dim = "\27[2m",
}

-- Disable colors if not a TTY or on Windows without ANSI support
local useColors = true
if os.getenv("NO_COLOR") or os.getenv("TERM") == "dumb" then
    useColors = false
    for k in pairs(colors) do colors[k] = "" end
end

local function colored(color, text)
    return colors[color] .. text .. colors.reset
end

-- Expectation builder
local function makeExpect(actual)
    local expect = {}

    function expect.toBe(expected)
        if actual ~= expected then
            error(string.format("Expected %s to be %s", tostring(actual), tostring(expected)), 2)
        end
    end

    function expect.toEqual(expected)
        -- Deep equality for tables
        if type(actual) == "table" and type(expected) == "table" then
            local function deepEqual(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do
                    if not deepEqual(v, b[k]) then return false end
                end
                for k, v in pairs(b) do
                    if not deepEqual(v, a[k]) then return false end
                end
                return true
            end
            if not deepEqual(actual, expected) then
                error(string.format("Expected tables to be equal"), 2)
            end
        else
            if actual ~= expected then
                error(string.format("Expected %s to equal %s", tostring(actual), tostring(expected)), 2)
            end
        end
    end

    function expect.toBeNil()
        if actual ~= nil then
            error(string.format("Expected %s to be nil", tostring(actual)), 2)
        end
    end

    function expect.toNotBeNil()
        if actual == nil then
            error("Expected value to not be nil", 2)
        end
    end

    function expect.toBeTruthy()
        if not actual then
            error(string.format("Expected %s to be truthy", tostring(actual)), 2)
        end
    end

    function expect.toBeFalsy()
        if actual then
            error(string.format("Expected %s to be falsy", tostring(actual)), 2)
        end
    end

    function expect.toBeGreaterThan(expected)
        if not (actual > expected) then
            error(string.format("Expected %s to be greater than %s", tostring(actual), tostring(expected)), 2)
        end
    end

    function expect.toBeLessThan(expected)
        if not (actual < expected) then
            error(string.format("Expected %s to be less than %s", tostring(actual), tostring(expected)), 2)
        end
    end

    function expect.toBeCloseTo(expected, precision)
        precision = precision or 0.0001
        if math.abs(actual - expected) > precision then
            error(string.format("Expected %s to be close to %s (precision: %s)",
                tostring(actual), tostring(expected), tostring(precision)), 2)
        end
    end

    function expect.toContain(item)
        if type(actual) == "table" then
            for _, v in ipairs(actual) do
                if v == item then return end
            end
            error(string.format("Expected table to contain %s", tostring(item)), 2)
        elseif type(actual) == "string" then
            if not actual:find(item, 1, true) then
                error(string.format("Expected string to contain '%s'", item), 2)
            end
        else
            error("toContain only works on tables and strings", 2)
        end
    end

    function expect.toThrow()
        if type(actual) ~= "function" then
            error("toThrow expects a function", 2)
        end
        local ok = pcall(actual)
        if ok then
            error("Expected function to throw an error", 2)
        end
    end

    return expect
end

-- Public API

function T.describe(name, fn)
    currentSuite = { name = name, tests = {} }
    table.insert(suites, currentSuite)
    fn()
    currentSuite = nil
end

function T.it(name, fn)
    if not currentSuite then
        error("it() must be called inside describe()", 2)
    end
    table.insert(currentSuite.tests, { name = name, fn = fn })
end

function T.expect(actual)
    return makeExpect(actual)
end

-- Aliases
T.test = T.it

function T.run(options)
    options = options or {}
    local verbose = options.verbose ~= false  -- default true

    results = { passed = 0, failed = 0, errors = {} }

    if verbose then
        print("")
        print(colored("dim", "Running tests..."))
        print("")
    end

    for _, suite in ipairs(suites) do
        if verbose then
            print(colored("yellow", "  " .. suite.name))
        end

        for _, test in ipairs(suite.tests) do
            local ok, err = pcall(test.fn)

            if ok then
                results.passed = results.passed + 1
                if verbose then
                    print(colored("green", "    [PASS] ") .. test.name)
                end
            else
                results.failed = results.failed + 1
                table.insert(results.errors, {
                    suite = suite.name,
                    test = test.name,
                    error = err
                })
                if verbose then
                    print(colored("red", "    [FAIL] ") .. test.name)
                    print(colored("dim", "           " .. tostring(err)))
                end
            end
        end

        if verbose then print("") end
    end

    -- Summary
    local total = results.passed + results.failed
    local summary = string.format("  %d passed, %d failed, %d total",
        results.passed, results.failed, total)

    if results.failed > 0 then
        print(colored("red", summary))
    else
        print(colored("green", summary))
    end
    print("")

    -- Clear suites for next run
    suites = {}

    return results.failed == 0, results
end

-- For running individual test files
function T.runFile(filepath)
    local chunk, err = loadfile(filepath)
    if not chunk then
        print(colored("red", "Error loading " .. filepath .. ": " .. err))
        return false
    end

    local ok, err = pcall(chunk)
    if not ok then
        print(colored("red", "Error running " .. filepath .. ": " .. err))
        return false
    end

    return true
end

-- Auto-discover and run tests from a directory
function T.runDir(dir, pattern)
    pattern = pattern or "test_.*%.lua$"

    -- This works with LÖVE's filesystem or standard Lua
    local files = {}

    if love and love.filesystem then
        local items = love.filesystem.getDirectoryItems(dir)
        for _, item in ipairs(items) do
            if item:match(pattern) then
                table.insert(files, dir .. "/" .. item)
            end
        end
    else
        -- Standard Lua with io.popen (Unix-like)
        local handle = io.popen('ls "' .. dir .. '" 2>/dev/null')
        if handle then
            for file in handle:lines() do
                if file:match(pattern) then
                    table.insert(files, dir .. "/" .. file)
                end
            end
            handle:close()
        end
    end

    for _, filepath in ipairs(files) do
        T.runFile(filepath)
    end
end

return T
