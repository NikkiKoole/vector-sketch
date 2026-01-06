--[[
    Test runner for Playtime

    Usage:
        Headless (unit tests only):    lua tests/run.lua
        With LÖVE (all tests):         love . --test

    The runner auto-discovers test files matching 'test_*.lua' pattern.
]]

local T = require 'tests.mini-test'

local isLove = love ~= nil

-- Track if we're running from command line vs require
local runningDirectly = (arg and arg[0] and arg[0]:match("run%.lua$")) or
                        (arg and arg[1] == "--test")

local function discoverTests(dir, pattern)
    pattern = pattern or "^test_.*%.lua$"
    local files = {}

    if isLove then
        -- Use LÖVE filesystem
        local items = love.filesystem.getDirectoryItems(dir)
        for _, item in ipairs(items) do
            if item:match(pattern) then
                table.insert(files, dir .. "/" .. item)
            end
        end
    else
        -- Use io.popen for standard Lua
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

    table.sort(files)
    return files
end

local function runTests()
    print("")
    print("========================================")
    print("  Playtime Test Suite")
    print("========================================")

    local allPassed = true
    local totalPassed = 0
    local totalFailed = 0

    -- Always run unit tests (no LÖVE required)
    print("")
    print(">> Unit Tests")
    print("----------------------------------------")

    local unitTests = discoverTests("tests/unit")
    for _, filepath in ipairs(unitTests) do
        print("Loading: " .. filepath)
        local chunk, err = loadfile(filepath)
        if chunk then
            local ok, runErr = pcall(chunk)
            if not ok then
                print("Error running " .. filepath .. ": " .. tostring(runErr))
                allPassed = false
            end
        else
            print("Error loading " .. filepath .. ": " .. tostring(err))
            allPassed = false
        end
    end

    -- Run accumulated unit tests
    local passed, results = T.run()
    if not passed then allPassed = false end
    totalPassed = totalPassed + results.passed
    totalFailed = totalFailed + results.failed

    -- Run integration tests only if LÖVE is available
    if isLove then
        print("")
        print(">> Integration Tests (LÖVE)")
        print("----------------------------------------")

        local integrationTests = discoverTests("tests/integration")
        for _, filepath in ipairs(integrationTests) do
            print("Loading: " .. filepath)
            local chunk, err = loadfile(filepath)
            if chunk then
                local ok, runErr = pcall(chunk)
                if not ok then
                    print("Error running " .. filepath .. ": " .. tostring(runErr))
                    allPassed = false
                end
            else
                print("Error loading " .. filepath .. ": " .. tostring(err))
                allPassed = false
            end
        end

        -- Run accumulated integration tests
        local passed, results = T.run()
        if not passed then allPassed = false end
        totalPassed = totalPassed + results.passed
        totalFailed = totalFailed + results.failed
    else
        print("")
        print(">> Skipping integration tests (LÖVE not available)")
        print("   Run 'love . --test' to include integration tests")
    end

    -- Final summary
    print("")
    print("========================================")
    if allPassed then
        print("  ALL TESTS PASSED")
    else
        print("  SOME TESTS FAILED")
    end
    print(string.format("  Total: %d passed, %d failed", totalPassed, totalFailed))
    print("========================================")
    print("")

    return allPassed
end

-- Export for use as module
local M = {
    run = runTests,
    discoverTests = discoverTests
}

-- Auto-run if executed directly (not required as module)
if runningDirectly then
    local success = runTests()
    if isLove then
        love.event.quit(success and 0 or 1)
    else
        os.exit(success and 0 or 1)
    end
end

return M
