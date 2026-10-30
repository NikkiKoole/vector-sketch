-- music-zones.lua
-- Music zones in one big room (docs/MUSIC-IDEAS.md, iMUSE): a body with a MUSIC_ZONE behavior
-- names a style and/or layers, like a room does (src/room-music.lua). While the camera's centre is
-- inside the zone, that's the music; out again, the room's music comes back. The camera centre is
-- what you look at, and while playing the camera follows the Mipo you play with.
-- Hysteresis, so a Mipo hopping on the border doesn't flip the music every bar: a zone has to hold
-- the centre for DWELL seconds before it counts, and you're only out once the centre is MARGIN past
-- its edge. Zones inside zones: the smallest one wins. Ticked by src/sound.lua.

local state = require('src.state')
local behaviors = require('src.behaviors')
local roomMusic = require('src.room-music')

local lib = {}

lib.dwell = 0.5   -- seconds inside before a zone takes over
lib.margin = 80   -- world px past the edge before you're out
lib.every = 0.2   -- seconds between looks

local function zoneState()
    -- active: the zone body playing now; outside: the music before the first zone, for a room
    -- that keeps whatever plays
    state.musicZones = state.musicZones or { active = nil, candidate = nil, since = 0, wait = 0, outside = nil }
    return state.musicZones
end

-- The zone's box in world space: its collision fixtures (sfixtures left out).
local function box(body)
    local x1, y1, x2, y2
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local ax, ay, bx, by = fixture:getBoundingBox()
            x1, y1 = math.min(x1 or ax, ax), math.min(y1 or ay, ay)
            x2, y2 = math.max(x2 or bx, bx), math.max(y2 or by, by)
        end
    end
    return x1, y1, x2, y2
end

-- Every zone in the world: { body, zone, x1, y1, x2, y2 }.
function lib.zones(world)
    local found = {}
    for _, body in ipairs(world:getBodies()) do
        local zone = behaviors.find(body, 'MUSIC_ZONE')
        if zone then
            local x1, y1, x2, y2 = box(body)
            if x1 then found[#found + 1] = { body = body, zone = zone, x1 = x1, y1 = y1, x2 = x2, y2 = y2 } end
        end
    end
    return found
end

local function contains(z, x, y, margin)
    return x >= z.x1 - margin and x <= z.x2 + margin and y >= z.y1 - margin and y <= z.y2 + margin
end

-- The zone for point x, y: the one playing now while it still holds (with the margin), else the
-- smallest one the point is in. nil: no zone.
function lib.pick(zones, x, y, active)
    for _, z in ipairs(zones) do
        if z.body == active and contains(z, x, y, lib.margin) then return z.body end
    end
    local best, bestArea
    for _, z in ipairs(zones) do
        local area = (z.x2 - z.x1) * (z.y2 - z.y1)
        if contains(z, x, y, 0) and (not best or area < bestArea) then best, bestArea = z.body, area end
    end
    return best
end

local function zoneMusic(body)
    local zone = body and not body:isDestroyed() and behaviors.find(body, 'MUSIC_ZONE')
    if not zone then return nil end
    return { style = zone.style or 'keep', layers = zone.layers or 'keep', at = zone.at or 'bar' }
end

-- Out of every zone: the room's music, or (a room that keeps whatever plays) what played before.
local function backOutside(Z)
    local room = roomMusic.settings()
    local outside = Z.outside or {}
    roomMusic.apply({
        style = room.style ~= 'keep' and room.style or outside.style or 'keep',
        layers = room.layers ~= 'keep' and room.layers or outside.layers or 'keep',
        at = room.at,
    })
    Z.outside = nil
end

local function switchTo(Z, body)
    if not Z.active then -- leaving the room's music: remember it
        local music = require('src.music')
        local now = music.nowPlaying and music.nowPlaying()
        Z.outside = { style = music.style, layers = now and now.layers ~= 'custom' and now.layers or 'full' }
    end
    Z.active = body
    local s = zoneMusic(body)
    if s then roomMusic.apply(s) else backOutside(Z) end
end

local function refill(list, names)
    for i = #list, 2, -1 do list[i] = nil end -- keep 'keep' in front
    for _, name in ipairs(names) do list[#list + 1] = name end
end

-- The zone inspector's choices (behaviors.musicZoneChoices), from the music's styles and layer
-- presets: they grow when the music session adds a style.
function lib.refreshChoices()
    local choices = behaviors.musicZoneChoices
    for _, row in ipairs(require('src.music-params').rows) do
        if row.key == 'style' then refill(choices.style, row.options) end
    end
    refill(choices.layers, require('src.music').layerPresets or {})
end

-- A tick: x, y is the camera centre in world space.
function lib.update(dt, world, x, y)
    local Z = zoneState()
    Z.wait = Z.wait - dt
    if Z.wait > 0 or not world then return end
    Z.wait = lib.every
    lib.refreshChoices()
    if Z.active and Z.active:isDestroyed() then Z.active = nil end
    local want = lib.pick(lib.zones(world), x, y, Z.active)
    if want == Z.active then
        Z.candidate = nil
        return
    end
    if want ~= Z.candidate then Z.candidate, Z.since = want, 0 end
    Z.since = Z.since + lib.every
    if Z.since >= lib.dwell then
        Z.candidate = nil
        switchTo(Z, want)
    end
end

return lib
