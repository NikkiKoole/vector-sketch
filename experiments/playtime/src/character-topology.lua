-- character-topology.lua
-- Declarative topology for character body-part assembly.
-- Replaces the if/elseif chains in character-manager.lua:
--   getParentAndChildrenFromPartName, getOffsetFromParent, getOwnOffset, getAngleOffset
--
-- Usage:
--   local topo = topology.resolve(creation)        -- flat ordered list of entries
--   local entryMap = topology.buildEntryMap(topo)   -- name → entry lookup
--   local childMap = topology.buildChildrenMap(topo) -- parent → {children}
--
-- Each entry: { name, parent, parentAttach, ownAttach, angleOffset }

local lib = {}

local mathutils = require('src.math-utils')
local ST = require('src.shape-types')

local sign = mathutils.sign
local lerp = mathutils.clampedLerp
local makeTransformedVertices = mathutils.scalePolygonPoints

-- Shape8 dictionary — set by character-manager at init time via lib.setShape8Dict()
local shape8Dict

function lib.setShape8Dict(dict)
    shape8Dict = dict
end

-- ─── Vertex helpers ───

local function getTransformedIndex(index, flipX, flipY)
    if flipY == -1 and flipX == 1 then
        local values = { 5, 4, 3, 2, 1, 8, 7, 6 }
        return values[index]
    end
    if flipX == -1 and flipY == 1 then
        local values = { 1, 8, 7, 6, 5, 4, 3, 2 }
        return values[index]
    end
    if flipX == -1 and flipY == -1 then
        local values = { 5, 6, 7, 8, 1, 2, 3, 4 }
        return values[index]
    end
    if flipX == 1 and flipY == 1 then
        local values = { 1, 2, 3, 4, 5, 6, 7, 8 }
        return values[index]
    end
end

-- Read a shape8 vertex, scaled. Returns (x * scale, y * scale).
local function getVertex(part, vertexIndex, scale)
    local raw = shape8Dict[part.shape8URL].vertices
    local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
    local idx = getTransformedIndex(vertexIndex, sign(part.dims.sx), sign(part.dims.sy))
    return vertices[(idx * 2) - 1] * scale, vertices[(idx * 2)] * scale
end

-- Read a shape8 vertex, negated and scaled. Anchor point for part attachment.
local function getAnchor(part, vertexIndex, scale)
    local x, y = getVertex(part, vertexIndex, scale)
    return -x, -y
end

local function isShape8(part)
    return part.shape == ST.SHAPE8
end

-- Export helpers for tests and potential reuse
lib.getTransformedIndex = getTransformedIndex
lib.getVertex = getVertex
lib.getAnchor = getAnchor
lib.isShape8 = isShape8

-- ─── Parent-attach strategies ───
-- Each returns (x, y) offset on PARENT where child attaches.

local parentStrategies = {}

-- Root part, no parent
parentStrategies.none = function()
    return 0, 0
end

-- Attach at parent's bottom edge: 0, +h/2 * scale
parentStrategies.parentBottom = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local scale = guy.scale
    return 0, (parentPart.dims.h / 2) * scale
end

-- Attach at parent's top edge: 0, -h/2 * scale
parentStrategies.parentTop = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local scale = guy.scale
    return 0, (-parentPart.dims.h / 2) * scale
end

-- Attach at parent's top vertex (SHAPE8) or top edge (fallback).
-- Used for torso chains, neck→torso, head→torso.
parentStrategies.chainTop = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local scale = guy.scale
    if isShape8(parentPart) then
        return getVertex(parentPart, 1, scale)
    else
        return 0, (-parentPart.dims.h / 2) * scale
    end
end

-- Attach at a specific vertex on parent's SHAPE8, with dimension fallback.
parentStrategies.vertex = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local pa = entry.parentAttach
    local scale = guy.scale
    if isShape8(parentPart) then
        return getVertex(parentPart, pa.vertex, scale)
    else
        local w, h = parentPart.dims.w, parentPart.dims.h
        return (pa.fallbackXSign or 0) * (w / 2) * scale, (pa.fallbackYSign or 0) * (h / 2) * scale
    end
end

-- Lerp between two parent vertices, driven by a positioner value.
-- Used for legs (on lowest torso) and ears (on head/torso).
parentStrategies.lerpVertices = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local pa = entry.parentAttach
    local scale = guy.scale
    local t = guy.dna.positioners[pa.positioner][pa.posField]

    if isShape8(parentPart) then
        local ax, ay = getVertex(parentPart, pa.vertex1, scale)
        local bx, by = getVertex(parentPart, pa.vertex2, scale)
        local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
        if pa.negateX then rx = -rx end
        return rx, ry
    else
        local w, h = parentPart.dims.w, parentPart.dims.h
        if pa.legStyle then
            return (pa.xSign or 1) * (w / 2) * (1 - t) * scale, (h / 2) * scale
        else
            -- ear fallback
            return (pa.xSign or 1) * (w / 2) * scale, (-h / 2) * scale
        end
    end
end

-- Lerp along vertex 1→5 midline on parent (nose placement).
parentStrategies.midlineLerp = function(_partName, guy, entry)
    local parentPart = guy.dna.parts[entry.parent]
    local scale = guy.scale
    local t = guy.dna.positioners.nose.t

    if isShape8(parentPart) then
        local ax, ay = getVertex(parentPart, 1, scale)
        local bx, by = getVertex(parentPart, 5, scale)
        return lerp(ax, bx, t), lerp(ay, by, t)
    else
        return 0, (-parentPart.dims.h) * scale
    end
end

-- Nose chain (nose2+): reads vertex 5 from CURRENT part (not parent).
-- NOTE: Original code checks nose1's shape type but reads from current nose.
-- This quirk is preserved for compatibility.
parentStrategies.noseChain = function(partName, guy, _entry)
    local currentPart = guy.dna.parts[partName]
    local scale = guy.scale
    local nose1 = guy.dna.parts['nose1']
    if nose1 and isShape8(nose1) then
        return getVertex(currentPart, 5, scale)
    else
        return 0, (currentPart.dims.h / 2) * scale
    end
end

-- ─── Own-attach: offset on SELF where parent connects ───

function lib.getOwnOffset(partName, guy, entry)
    local part = guy.dna.parts[partName]
    local scale = guy.scale
    local oa = entry.ownAttach

    if oa.strategy == 'top' then
        if oa.shape8 == 'topEdge' and isShape8(part) then
            -- Torso/head SHAPE8: x from bottom vertex (negated), y from top vertex
            local _, topY = getVertex(part, 1, scale)
            local bottomX, _ = getVertex(part, 5, scale)
            return -bottomX, topY
        elseif type(oa.shape8) == 'number' and isShape8(part) then
            return getAnchor(part, oa.shape8, scale)
        else
            return 0, (-part.dims.h / 2) * scale
        end
    elseif oa.strategy == 'bottom' then
        if type(oa.shape8) == 'number' and isShape8(part) then
            return getAnchor(part, oa.shape8, scale)
        else
            return 0, (part.dims.h / 2) * scale
        end
    end
    return 0, 0
end

-- ─── Parent-attach dispatch ───

function lib.getOffsetFromParent(partName, guy, entry)
    local strategy = parentStrategies[entry.parentAttach.strategy]
    return strategy(partName, guy, entry)
end

-- ─── Angle offset ───

function lib.getAngleOffset(partName, guy, entry)
    local ao = entry.angleOffset
    if ao == 'stanceAngle' then
        return guy.dna.parts[partName].stanceAngle or 0
    end
    return ao or 0
end

-- ─── Topology resolution ───

--- Build the full ordered topology list for a given creation configuration.
--- Output ordering: torsos → necks → head → noses → limbs (legs, arms, ears).
--- Parent always appears before child in the list.
function lib.resolve(creation)
    local torsoSegments = creation.torsoSegments or 1
    local neckSegments = creation.neckSegments or 0
    local noseSegments = creation.noseSegments or 0
    local isPotato = creation.isPotatoHead

    local highestTorso = 'torso' .. torsoSegments

    local result = {}

    -- 1. Torso segments
    for i = 1, torsoSegments do
        local parent, parentAttach
        if i == 1 then
            parent = nil
            parentAttach = { strategy = 'none' }
        else
            parent = 'torso' .. (i - 1)
            parentAttach = { strategy = 'chainTop' }
        end
        result[#result + 1] = {
            name = 'torso' .. i,
            parent = parent,
            parentAttach = parentAttach,
            ownAttach = { strategy = 'top', shape8 = 'topEdge' },
            angleOffset = 0,
        }
    end

    -- 2. Neck segments (only if not potato)
    if not isPotato and neckSegments > 0 then
        for i = 1, neckSegments do
            local parent = (i == 1) and highestTorso or ('neck' .. (i - 1))
            local parentAttach
            if i == 1 then
                parentAttach = { strategy = 'chainTop' }
            else
                parentAttach = { strategy = 'parentTop' }
            end
            result[#result + 1] = {
                name = 'neck' .. i,
                parent = parent,
                parentAttach = parentAttach,
                ownAttach = { strategy = 'top' },
                angleOffset = 0,
            }
        end
    end

    -- 3. Head (only if not potato)
    if not isPotato then
        local headParent = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso
        local headParentAttach
        if neckSegments > 0 then
            headParentAttach = { strategy = 'parentTop' }
        else
            headParentAttach = { strategy = 'chainTop' }
        end
        result[#result + 1] = {
            name = 'head',
            parent = headParent,
            parentAttach = headParentAttach,
            ownAttach = { strategy = 'top', shape8 = 'topEdge' },
            angleOffset = 0,
        }
    end

    -- 4. Nose segments
    if noseSegments > 0 then
        for i = 1, noseSegments do
            local parent, parentAttach
            if i == 1 then
                parent = isPotato and highestTorso or 'head'
                parentAttach = { strategy = 'midlineLerp' }
            else
                parent = 'nose' .. (i - 1)
                parentAttach = { strategy = 'noseChain' }
            end
            result[#result + 1] = {
                name = 'nose' .. i,
                parent = parent,
                parentAttach = parentAttach,
                ownAttach = { strategy = 'bottom', shape8 = 1 },
                angleOffset = 0,
            }
        end
    end

    -- 5. Limbs (matching original ordering: legs, arms, ears)
    local earParent = isPotato and highestTorso or 'head'

    local limbs = {
        -- Legs
        { name = 'luleg', parent = 'torso1',
          parentAttach = { strategy = 'lerpVertices', vertex1 = 6, vertex2 = 5,
                           positioner = 'leg', posField = 'x', legStyle = true, xSign = -1 },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'ruleg', parent = 'torso1',
          parentAttach = { strategy = 'lerpVertices', vertex1 = 4, vertex2 = 5,
                           positioner = 'leg', posField = 'x', legStyle = true, xSign = 1 },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'llleg', parent = 'luleg',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'rlleg', parent = 'ruleg',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'lfoot', parent = 'llleg',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom', shape8 = 1 }, angleOffset = math.pi / 2 },
        { name = 'rfoot', parent = 'rlleg',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom', shape8 = 1 }, angleOffset = -math.pi / 2 },
        -- Arms
        { name = 'luarm', parent = highestTorso,
          parentAttach = { strategy = 'vertex', vertex = isPotato and 7 or 8,
                           fallbackXSign = -1, fallbackYSign = -1 },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'ruarm', parent = highestTorso,
          parentAttach = { strategy = 'vertex', vertex = isPotato and 3 or 2,
                           fallbackXSign = 1, fallbackYSign = -1 },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'llarm', parent = 'luarm',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'rlarm', parent = 'ruarm',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom' }, angleOffset = 0 },
        { name = 'lhand', parent = 'llarm',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom', shape8 = 1 }, angleOffset = 0 },
        { name = 'rhand', parent = 'rlarm',
          parentAttach = { strategy = 'parentBottom' },
          ownAttach = { strategy = 'bottom', shape8 = 1 }, angleOffset = 0 },
        -- Ears
        { name = 'lear', parent = earParent,
          parentAttach = { strategy = 'lerpVertices', vertex1 = 2, vertex2 = 4,
                           positioner = 'ear', posField = 'y', negateX = true, xSign = -1 },
          ownAttach = { strategy = 'top', shape8 = 5 }, angleOffset = 'stanceAngle' },
        { name = 'rear', parent = earParent,
          parentAttach = { strategy = 'lerpVertices', vertex1 = 2, vertex2 = 4,
                           positioner = 'ear', posField = 'y', xSign = 1 },
          ownAttach = { strategy = 'top', shape8 = 5 }, angleOffset = 'stanceAngle' },
    }

    for _, entry in ipairs(limbs) do
        result[#result + 1] = entry
    end

    return result
end

-- ─── Lookup builders ───

--- Build name → entry map from topology list.
function lib.buildEntryMap(topology)
    local map = {}
    for _, entry in ipairs(topology) do
        map[entry.name] = entry
    end
    return map
end

--- Build parent → {child names} map from topology list.
function lib.buildChildrenMap(topology)
    local children = {}
    for _, entry in ipairs(topology) do
        if entry.parent then
            if not children[entry.parent] then
                children[entry.parent] = {}
            end
            children[entry.parent][#children[entry.parent] + 1] = entry.name
        end
    end
    return children
end

--- Build ordered name list from topology (for iteration).
function lib.buildOrderedNames(topology)
    local names = {}
    for _, entry in ipairs(topology) do
        names[#names + 1] = entry.name
    end
    return names
end

return lib
