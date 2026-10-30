-- web-bridge.lua
-- The browser build's stand-in for vendor/claude-bridge.lua (which needs luasocket): Lua eval into
-- the running game, for Claude and for debugging (docs/WEB-EXPORT-LOVEJS.md WEB4).
--
-- The page (webtest/index.template.html, `playtime.eval(code)`) writes each request as a file
-- `<id>.lua` into the save directory's `web-bridge/` folder. Every frame this runs those files,
-- deletes them, and prints each answer as one line: '@bridge' TAB id TAB json, which the page
-- catches. The code gets the same locals as the desktop bridge's /eval (state, registry,
-- objectManager, joints, sceneIO, inspect, utils) and the same answer shape: {ok, data} or
-- {ok = false, error}.

local json = require('vendor.dkjson')
local serialize = require('vendor.bridge-serialize').serialize

local lib = {}

lib.dir = 'web-bridge'
lib.maxDepth = 4
lib.errors = {}

-- One line, ending in a space: the code starts on line 1, so error line numbers match what was sent.
local PREAMBLE = "local state = require('src.state') local registry = require('src.registry') " ..
    "local objectManager = require('src.object-manager') local joints = require('src.joints') " ..
    "local sceneIO = require('src.io') local inspect = require('vendor.inspect') " ..
    "local utils = require('src.utils') "

local started = false

-- Makes the inbox and tells the page where it is (the page can't ask love.filesystem).
local function start()
    started = true
    love.filesystem.createDirectory(lib.dir)
    for _, name in ipairs(love.filesystem.getDirectoryItems(lib.dir)) do
        love.filesystem.remove(lib.dir .. '/' .. name) -- requests from an earlier visit
    end
    print('@bridge\tready\t' .. json.encode({ dir = love.filesystem.getSaveDirectory() .. '/' .. lib.dir }))
end

local function answer(id, response)
    print('@bridge\t' .. id .. '\t' .. json.encode(response))
end

local function run(id, code)
    local fn, compileError = loadstring(PREAMBLE .. code, 'eval')
    if not fn then
        answer(id, { ok = false, error = 'compile error: ' .. tostring(compileError) })
        return
    end
    local ok, result = pcall(fn)
    if ok then
        answer(id, { ok = true, data = serialize(result, 0, lib.maxDepth) })
    else
        answer(id, { ok = false, error = tostring(result) })
    end
end

-- main.lua calls this every frame (as bridge.update).
function lib.update()
    if not started then start() end
    local names = love.filesystem.getDirectoryItems(lib.dir)
    table.sort(names) -- the page numbers them, so they run in the order sent
    for _, name in ipairs(names) do
        local id = name:match('^(%w+)%.lua$')
        local path = lib.dir .. '/' .. name
        if id then
            local code = love.filesystem.read(path)
            love.filesystem.remove(path)
            run(id, code or '')
        end
    end
end

-- main.lua passes lurker's errors here on desktop; on the web it's kept for `errors` evals.
function lib.recordError(source, message)
    lib.errors[#lib.errors + 1] = { source = source, message = tostring(message), time = love.timer.getTime() }
    while #lib.errors > 50 do table.remove(lib.errors, 1) end
end

return lib
