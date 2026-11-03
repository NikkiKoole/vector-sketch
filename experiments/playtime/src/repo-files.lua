-- repo-files: what the editor saves (scenes, library prefabs, music setups) goes into the project
-- folder when the game runs from it on the desktop, so it's in git with everything else
-- (docs/ASSETS-AND-BUILDS.md AB3). Elsewhere (the web build, a .love, the phone) and in a spec run
-- it goes into the save folder as before. Reading needs nothing: conf.lua has appendidentity off, so
-- love.filesystem finds the project's copy first and the save folder's as the fallback.

local lib = {}

local root -- the project folder, false when writes go to the save folder; looked up once

local function specRun()
    if rawget(_G, 'SPEC_RUN') then return true end -- run-specs.lua (it replaces arg with busted's)
    for _, a in ipairs(arg or {}) do
        if a == '--specs' then return true end
    end
    return false
end

-- the project folder when saving goes there, else nil
function lib.root()
    if root == nil then
        root = false
        local system = love.system.getOS()
        local source = love.filesystem.getSource()
        if io and system ~= 'Web' and system ~= 'iOS' and system ~= 'Android' and not specRun() and source
            and not source:match('%.love$') and not love.filesystem.isFused() then
            local probe = io.open(source .. '/main.lua', 'r') -- a real folder we can reach
            if probe then
                probe:close()
                root = source
            end
        end
    end
    return root or nil
end

-- text into <path> (relative to the project): ok, where it went (a full path) or the error
function lib.write(path, text)
    local base = lib.root()
    if base then
        local dir = path:match('^(.*)/[^/]+$')
        if dir then os.execute(('mkdir -p "%s/%s"'):format(base, dir)) end
        local file, err = io.open(base .. '/' .. path, 'wb')
        if not file then return false, err end
        file:write(text)
        file:close()
        return true, base .. '/' .. path
    end
    local dir = path:match('^(.*)/[^/]+$')
    if dir then love.filesystem.createDirectory(dir) end
    local ok, err = love.filesystem.write(path, text)
    return ok, ok and (love.filesystem.getSaveDirectory() .. '/' .. path) or err
end

-- <path> gone from the project and from the save folder (an old copy there would show again)
function lib.remove(path)
    local base = lib.root()
    local gone = false
    if base then gone = os.remove(base .. '/' .. path) ~= nil end
    if love.filesystem.getRealDirectory(path) == love.filesystem.getSaveDirectory() then
        gone = love.filesystem.remove(path) or gone
    end
    return gone
end

return lib
