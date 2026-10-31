-- scene-catalog.lua — every scene in scripts/ for the editor's scenes tab (src/ui/scenes-tab.lua):
-- its name, a line saying what it is, and a group to list it under.
--
-- A scene is scripts/<name>.playtime.json (+ .lua), also one folder down (tech/snap2). A script
-- without a json (tufts) runs on the scene that's open. The line is the script's first comment
-- (`-- burrow: a spike for ...`, its name prefix dropped), else NOTES below. The group: a
-- folder's scenes under the folder's name; the rest under 'spikes' or 'tests' when the line
-- says so, else 'rooms'. So a new scene shows up, described, by having a first comment line.
local lib = {}

local DIR = 'scripts'
local JSON, LUA = '.playtime.json', '.playtime.lua'

-- For scenes whose script doesn't say (or that have none).
local NOTES = {
    bakery = 'a room behind a door (worlds and doors)',
    treehouse = 'a room behind a door (worlds and doors)',
    overworld = 'the overworld: doors into the rooms (docs/WORLDS-AND-DOORS.md)',
    crowd = 'twenty Mipos: the phone test (docs/MEASURING.md)',
    ['spine-test'] = 'one Mipo on a floor',
    spine = 'Mipos with spine torsos (docs/MIPO-SPINE.md) test',
    miposhader = 'the start scene: Mipos in the claymation light',
    catapult = 'a catapult: the cup flings a ball (p)',
    elasto = 'an elastic band between two points',
    mudready = 'the Bathhouse mud: foam on a Mipo, a shower (parked)',
    planets = 'planets that pull what comes near',
    platforms = 'platforms you jump up through test',
    straight = 'bodies that keep themselves upright, tuned with sliders',
    torso = 'torso shape sliders: shoulders, waist, hips',
    water = 'floating in water: drag and density sliders',
    meta = 'the save/load round-trip test scene',
    puppet = 'an early jointed puppet test (2025)',
}
local FOLDER_NOTES = {
    knut = 'the Knut commission (fizzled 2026-04)',
    tech = 'tests of one engine piece',
    scratch = 'scratch scenes',
}
lib.GROUP_ORDER = { 'rooms', 'spikes', 'tests', 'tech', 'scratch', 'knut' }

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
    local id = folder and (folder .. '/' .. base) or base
    local entry = out[id]
    if not entry then
        entry = { id = id, name = base, folder = folder }
        out[id] = entry
    end
    if file:sub(-#JSON) == JSON then entry.json = true else entry.lua = true end
end

-- Every scene: { id, name, folder, json, lua, note, group, scriptOnly }, sorted by group then name.
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
        entry.note = (entry.lua and firstComment(DIR .. '/' .. entry.id .. LUA)) or NOTES[entry.id] or ''
        entry.group = groupOf(entry.folder, entry.note)
        entry.scriptOnly = entry.lua and not entry.json
        out[#out + 1] = entry
    end
    local rank = {}
    for i, g in ipairs(lib.GROUP_ORDER) do rank[g] = i end
    table.sort(out, function(a, b)
        local ra, rb = rank[a.group] or 99, rank[b.group] or 99
        if ra ~= rb then return ra < rb end
        if a.group ~= b.group then return a.group < b.group end
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
        local relative = '/' .. DIR .. '/' .. p.entry.id .. LUA
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
