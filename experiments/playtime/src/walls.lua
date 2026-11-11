-- walls.lua — walls as things (Nikki 2026-11-11: walls not as backdrops, "a sort of hack single image to
-- draw over"). A 'wall' sfixture on a body makes that body a wall: its shape is the wall, filled with a
-- repeating picture (extra.main.bgURL under textures/, e.g. world/walls/plaster-01.jpg, CC0 from
-- ambientCG), drawn behind everything (an engine system's drawBelow: after the scene script's ground,
-- before the shadows and the bodies), and the wall shadows fall on it (src/scene-light.lua 'falls on':
-- walls). Each wall says how far it is behind the things (extra.behind): further back, a longer and softer
-- shadow. A wall touches nothing: its body's own fixtures become sensors and it stays where it's put
-- (static).
local state = require('src.state')
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local shapes = require('src.shapes')
local utils = require('src.utils')
local color = require('src.color')
local mathutils = require('src.math-utils')

local lib = {}

lib.DEFAULT_BEHIND = 90
lib.DEFAULT_TILE = 600 -- world units one picture covers across
lib.DEFAULT_TEXTURE = 'world/walls/plaster-01.jpg'

function lib.newExtra()
    return { main = { bgURL = lib.DEFAULT_TEXTURE }, tile = lib.DEFAULT_TILE, behind = lib.DEFAULT_BEHIND }
end

-- the walls now: { fixture, body, extra, thing }, live ones only
function lib.list()
    local out = {}
    for _, fixture in ipairs(registry.sfixturesOf(subtypes.WALL)) do
        if not fixture:isDestroyed() then
            local body = fixture:getBody()
            local thing = utils.thingOf(body)
            if thing and thing.vertices then
                out[#out + 1] = { fixture = fixture, body = body, extra = fixture:getUserData().extra, thing = thing }
            end
        end
    end
    return out
end

function lib.any() return #registry.sfixturesOf(subtypes.WALL) > 0 end

-- is this body a wall (the debug draw leaves it out: its picture is its body, and drawn behind
-- everything the editor's body fill would cover it); kept until an sfixture comes or goes
local wallBodies = { version = nil, set = nil }
function lib.isWallBody(body)
    if wallBodies.version ~= registry.sfixtureVersion then
        local set = setmetatable({}, { __mode = 'k' })
        for _, fixture in ipairs(registry.sfixturesOf(subtypes.WALL)) do
            if not fixture:isDestroyed() then set[fixture:getBody()] = true end
        end
        wallBodies.version, wallBodies.set = registry.sfixtureVersion, set
    end
    return wallBodies.set[body] == true
end

-- a wall touches nothing and stays put: its body's own fixtures sensors, the body static
function lib.update()
    for _, wall in ipairs(lib.list()) do
        local body = wall.body
        if body:getType() ~= 'static' then body:setType('static') end
        for _, fixture in ipairs(body:getFixtures()) do
            if fixture:getUserData() == nil and not fixture:isSensor() then fixture:setSensor(true) end
        end
    end
end

---------------------------------------------------------------- drawing

-- a wall's triangles around its body's origin, made once per vertices table (a reshaped body gets a new
-- one). thing.vertices keep the coordinates the shape was made with; the body sits at their centroid
-- (as the tile-repeat draw takes them)
local trisCache = setmetatable({}, { __mode = 'k' })
local function trisOf(vertices)
    local tris = trisCache[vertices]
    if not tris then
        local cx, cy = mathutils.computeCentroid(vertices)
        local centred = {}
        for i = 1, #vertices, 2 do
            centred[i], centred[i + 1] = vertices[i] - cx, vertices[i + 1] - cy
        end
        tris = shapes.makeTrianglesFromPolygon(centred) or {}
        trisCache[vertices] = tris
    end
    return tris
end

local images = {}
local function imageOf(url)
    if not url or url == '' then return nil end
    local img = images[url]
    if img == nil then
        local path = 'textures/' .. url
        img = love.filesystem.getInfo(path) and love.graphics.newImage(path) or false
        if img then img:setWrap('repeat', 'repeat') end
        images[url] = img
    end
    return img or nil
end

-- the wall's mesh in its body's coordinates, the picture repeating every `tile` world units across;
-- made again when the shape, the picture or the tile size change (meshes: module-local, a hot swap
-- just makes them again)
local meshes = setmetatable({}, { __mode = 'k' })
local function meshOf(wall)
    local extra, vertices = wall.extra, wall.thing.vertices
    local img = imageOf(extra.main and extra.main.bgURL)
    if not img then return nil end
    local tile = math.max(1, extra.tile or lib.DEFAULT_TILE)
    local key = tostring(vertices) .. '|' .. #vertices .. '|' .. extra.main.bgURL .. '|' .. tile
    local cached = meshes[extra]
    if cached and cached.key == key then return cached.mesh end
    local tileW, tileH = tile, tile * img:getHeight() / img:getWidth()
    local tris = trisOf(vertices)
    local verts = {}
    for _, tri in ipairs(tris) do
        for k = 0, 2 do
            local x, y = tri[k * 2 + 1], tri[k * 2 + 2]
            verts[#verts + 1] = { x, y, x / tileW, y / tileH, 1, 1, 1, 1 }
        end
    end
    if #verts == 0 then return nil end
    local mesh = love.graphics.newMesh(verts, 'triangles', 'static')
    mesh:setTexture(img)
    meshes[extra] = { key = key, mesh = mesh }
    return mesh
end

-- the light on the walls: with a sky and the light on, the hour's (state.hourLight, src/scene-light.lua
-- from src/sky-light.lua: dark and blue at night, warm at dusk; Nikki 2026-11-11: walls bright at night
-- stood out), else as drawn
local function hourLight()
    local h = state.hourLight
    if not h then return 1, 1, 1 end
    return h[1], h[2], h[3]
end

-- behind everything (src/systems.lua drawBelow)
function lib.drawBelow()
    if not state.world.showTextures then return end
    local lr, lg, lb = hourLight()
    for _, wall in ipairs(lib.list()) do
        local mesh = meshOf(wall)
        if mesh then
            local r, g, b, a = color.hexToColor(wall.extra.main.tint or 'ffffffff')
            love.graphics.setColor(r * lr, g * lg, b * lb, a)
            love.graphics.draw(mesh, wall.body:getX(), wall.body:getY(), wall.body:getAngle())
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- the wall's shape filled, in world space (a stencil for the shadows)
local function fillShape(wall)
    local tris = trisOf(wall.thing.vertices)
    love.graphics.push()
    love.graphics.translate(wall.body:getX(), wall.body:getY())
    love.graphics.rotate(wall.body:getAngle())
    for _, tri in ipairs(tris) do love.graphics.polygon('fill', tri) end
    love.graphics.pop()
end

-- the walls grouped by how far behind they are: { { behind = n, draw = function() (their shapes) } },
-- and a key that changes when any of that does (what the light compares to make its settings again)
function lib.layers()
    local groups, order, parts = {}, {}, {}
    for _, wall in ipairs(lib.list()) do
        local behind = wall.extra.behind or lib.DEFAULT_BEHIND
        if not groups[behind] then
            groups[behind] = {}
            order[#order + 1] = behind
        end
        table.insert(groups[behind], wall)
        local bx, by = wall.body:getPosition()
        parts[#parts + 1] = string.format('%s:%g:%d:%d:%g', tostring(wall.thing.vertices), behind, bx, by,
            wall.body:getAngle())
    end
    table.sort(order)
    local out = {}
    for _, behind in ipairs(order) do
        local list = groups[behind]
        out[#out + 1] = { behind = behind, draw = function()
            for _, wall in ipairs(list) do
                if not wall.body:isDestroyed() then fillShape(wall) end
            end
        end }
    end
    return out, table.concat(parts, ',')
end

return lib
