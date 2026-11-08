-- scene-catalog.lua — every scene in scripts/ for the editor's scenes tab (src/ui/scenes-tab.lua):
-- its name, a line saying what it is, and a group to list it under.
--
-- A scene is scripts/<folder>/<name>.playtime.json (+ .lua): rooms/ (what the game is made of),
-- spikes/ (tries, parked or not), tests/ (scenes for checking a thing), tech/ (one engine piece each;
-- docs/ASSETS-AND-BUILDS.md AB7). A scene is called by its name alone ('dollhouse': doors' `to`,
-- --scene, the specs), so names are unique across the folders; pathOf finds the file. A script
-- without a json (tufts) runs on the scene that's open. The line is the script's first comment
-- (`-- burrow: a spike for ...`, its name prefix dropped), else NOTES below. The group is the folder
-- (one straight in scripts/: 'spikes' or 'tests' when the line says so, else 'rooms').
local lib = {}

local DIR = 'scripts'
local JSON, LUA = '.playtime.json', '.playtime.lua'
lib.FOLDERS = { 'rooms', 'spikes', 'tests', 'tech' }

-- A scene's file: 'dollhouse' (or 'rooms/dollhouse', 'tech/hoop') -> 'scripts/rooms/dollhouse.playtime.json',
-- ext LUA for its script; nil when there's none.
function lib.pathOf(id, ext)
    ext = ext or JSON
    local direct = DIR .. '/' .. id .. ext
    if love.filesystem.getInfo(direct, 'file') then return direct end
    local name = id:match('([^/]+)$')
    for _, folder in ipairs(lib.FOLDERS) do
        local path = DIR .. '/' .. folder .. '/' .. name .. ext
        if love.filesystem.getInfo(path, 'file') then return path end
    end
    return nil
end

-- Where saving a scene of this name writes: beside its script or over its file, a new one in spikes/.
function lib.savePathOf(id)
    local path = lib.pathOf(id) or lib.pathOf(id, LUA)
    if path then return (path:gsub('%.playtime%.lua$', JSON)) end
    return DIR .. '/spikes/' .. id:match('([^/]+)$') .. JSON
end

-- For scenes whose script doesn't say (or that have none).
local NOTES = {
    empty = 'nothing on it, to start something new', -- saving it goes to 'untitled' (src/scene-loader.lua)
    bakery = 'a room behind a door (worlds and doors)',
    treehouse = 'a room behind a door (worlds and doors)',
    overworld = 'the overworld: doors into the rooms (docs/WORLDS-AND-DOORS.md)',
    crowd = 'twenty Mipos: the phone test (docs/MEASURING.md)',
    ['spine-test'] = 'one Mipo on a floor',
    spine = 'Mipos with spine torsos (docs/MIPO-SPINE.md) test',
    miposhader = 'the start scene: Mipos in the claymation light',
    elasto = 'an elastic band between two points',
    mudready = 'the Bathhouse mud: foam on a Mipo, a shower (parked)',
    planets = 'planets that pull what comes near',
    platforms = 'platforms you jump up through test',
    water = 'floating in water: drag and density sliders',
    meta = 'the save/load round-trip test scene',
}
local FOLDER_NOTES = { -- a scene there without a line of its own still says what it is (a new save in spikes/)
    rooms = 'what the game is made of',
    spikes = 'tries, parked or not',
    tests = 'scenes for checking a thing',
    tech = 'one engine piece each',
}
lib.GROUP_ORDER = { 'rooms', 'spikes', 'tests', 'tech' }
lib.EMPTY = 'empty' -- scripts/spikes/empty: a scene with nothing on it, to start from

-- A script's first comment line, its 'name:' / 'name.playtime.lua —' prefix dropped.
local function firstComment(path)
    local ok, contents = pcall(love.filesystem.read, path)
    if not ok or not contents then return nil end
    for line in contents:gmatch('[^\n]+') do
        local text = line:match('^%-%-%s*(.-)%s*$')
        if text and text ~= '' and not text:match('^[-%s]*$') then
            if text:match('^function') or text:match('^%-%-%-') then return nil end -- commented-out code
            text = text:gsub('^[%w%-_.]+%.playtime%.lua%s*[—-]+%s*', ''):gsub('^[%w%-_]+:%s*', '')
            return text
        elseif not line:match('^%s*$') then
            return nil -- code before any comment
        end
    end
end

local function groupOf(folder, note)
    if folder then return folder end
    note = (note or ''):lower()
    if note:find('spike') then return 'spikes' end
    if (note:find('test') and not note:find('test room')) or note:find('example') then return 'tests' end
    return 'rooms'
end

local function add(out, folder, file)
    local base = file:match('^(.-)%.playtime%.json$') or file:match('^(.-)%.playtime%.lua$')
    if not base then return end
    local id = base
    local entry = out[id]
    if not entry then
        entry = { id = id, name = base, folder = folder }
        out[id] = entry
    elseif entry.folder ~= folder then
        entry.clash = (folder or '.') .. ' and ' .. (entry.folder or '.') -- one name in two folders
    end
    local path = DIR .. '/' .. (folder and (folder .. '/') or '') .. file
    if file:sub(-#JSON) == JSON then entry.json, entry.path = true, path else entry.lua, entry.luaPath = true, path end
end

-- Every scene: { id, name, folder, json, lua, path, luaPath, note, group, scriptOnly, clash }, sorted by
-- group then name (clash: the same name in two folders, which pathOf can't tell apart).
function lib.list()
    local found = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        local path = DIR .. '/' .. item
        local info = love.filesystem.getInfo(path)
        if info and info.type == 'directory' then
            for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do add(found, item, file) end
        else
            add(found, nil, item)
        end
    end
    local out = {}
    for _, entry in pairs(found) do
        entry.note = (entry.lua and firstComment(entry.luaPath)) or NOTES[entry.id] or ''
        entry.group = groupOf(entry.folder, entry.note)
        entry.scriptOnly = entry.lua and not entry.json
        entry.blank = entry.id == lib.EMPTY
        out[#out + 1] = entry
    end
    local rank = {}
    for i, g in ipairs(lib.GROUP_ORDER) do rank[g] = i end
    table.sort(out, function(a, b)
        local ra, rb = rank[a.group] or 99, rank[b.group] or 99
        if ra ~= rb then return ra < rb end
        if a.group ~= b.group then return a.group < b.group end
        if a.blank ~= b.blank then return a.blank end -- the empty scene first in its group
        return a.id < b.id
    end)
    return out
end

function lib.folderNote(group) return FOLDER_NOTES[group] end

-- Load a scene (or run a script-only one on what's open) at the start of the next update, not
-- in the middle of drawing the UI that asked for it. play: go into play mode after.
local pending = nil
function lib.request(entry, play)
    pending = { entry = entry, play = play }
end

function lib.update()
    if not pending then return end
    local p = pending
    pending = nil
    local sceneLoader = require('src.scene-loader')
    local playMode = require('src.play-mode')
    if p.entry.scriptOnly then
        -- the full path when it's there (as loadScriptAndScene does: hot reload needs it), else
        -- the game's own (web, .love)
        local relative = '/' .. (p.entry.luaPath or lib.pathOf(p.entry.id, LUA) or (DIR .. '/' .. p.entry.id .. LUA))
        local absolute = love.filesystem.getWorkingDirectory() .. relative
        local file = io and io.open(absolute, 'r')
        if file then file:close() end
        sceneLoader.loadAndRunScript(file and absolute or relative)
    else
        sceneLoader.loadScriptAndScene(p.entry.id)
    end
    if p.play and not playMode.isOn() then playMode.enter() end
end

return lib
