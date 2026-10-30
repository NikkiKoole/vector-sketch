-- influences.lua
-- MESHUSERT influences in a scene file (src/scene-save.lua, src/scene-load.lua). At runtime each
-- vertex has a list of influences { body, nodeType, nodeId, side, nodeIndex, offx, offy, dx, dy,
-- dist, w, bindAngle }; the file keeps no bodies and less repetition:
--   bones: the per-bone part (nodeType, nodeId, offx, offy, bindAngle) is the same for every entry
--     on one (nodeIndex, side), so it goes into one table keyed by that pair (normalizeBones) and
--     comes back on load (restoreBones). Keys "N:" (anchor, no side) and "N:A" / "N:B" (joint sides).
--   dist is sqrt(dx^2 + dy^2): stripped on save, computed again on load.
--   entries with weight 0 add nothing to the DQS sum and aren't saved.
-- Split out of io.lua (CODE-SPLITS-2026-10.md SPLIT6).
local registry = require('src.registry')
local NT = require('src.node-types')
local SIDES = require('src.sides')

local lib = {}

-- Every influence table in the per-vertex lists, skipping anything that isn't one.
local function eachInfluence(influences, fn)
    if type(influences) ~= 'table' then return end
    for i = 1, #influences do
        local inflList = influences[i]
        if type(inflList) == 'table' then
            for j = 1, #inflList do
                local infl = inflList[j]
                if type(infl) == 'table' then fn(infl) end
            end
        end
    end
end

local function boneKey(nodeIndex, side)
    return tostring(nodeIndex or '') .. ':' .. tostring(side or '')
end

-- Takes the per-bone fields off every entry; returns them as one table per bone.
function lib.normalizeBones(influences)
    local bones = {}
    eachInfluence(influences, function(infl)
        local key = boneKey(infl.nodeIndex, infl.side)
        if not bones[key] then
            bones[key] = {
                nodeType  = infl.nodeType,
                nodeId    = infl.nodeId,
                offx      = infl.offx,
                offy      = infl.offy,
                bindAngle = infl.bindAngle,
            }
        end
        infl.nodeType  = nil
        infl.nodeId    = nil
        infl.offx      = nil
        infl.offy      = nil
        infl.bindAngle = nil
    end)
    return bones
end

-- Puts the per-bone fields back on every entry (what an entry has itself wins).
function lib.restoreBones(influences, bones)
    if type(bones) ~= 'table' then return end
    eachInfluence(influences, function(infl)
        local bone = bones[boneKey(infl.nodeIndex, infl.side)]
        if bone then
            if infl.nodeType  == nil then infl.nodeType  = bone.nodeType  end
            if infl.nodeId    == nil then infl.nodeId    = bone.nodeId    end
            if infl.offx      == nil then infl.offx      = bone.offx      end
            if infl.offy      == nil then infl.offy      = bone.offy      end
            if infl.bindAngle == nil then infl.bindAngle = bone.bindAngle end
        end
    end)
end

-- In place; the caller has already copied the structure.
function lib.stripDist(influences)
    eachInfluence(influences, function(infl) infl.dist = nil end)
end

function lib.restoreDist(influences)
    eachInfluence(influences, function(infl)
        if infl.dist == nil and infl.dx ~= nil and infl.dy ~= nil then
            infl.dist = math.sqrt(infl.dx * infl.dx + infl.dy * infl.dy)
        end
    end)
end

-- Drops entries with weight 0 (or none). A vertex whose entries all go keeps an empty list, not
-- nil, so the per-vertex array has no holes.
function lib.pruneZeroWeight(influences)
    if type(influences) ~= 'table' then return end
    for i = 1, #influences do
        local inflList = influences[i]
        if type(inflList) == 'table' then
            local kept = {}
            for j = 1, #inflList do
                local infl = inflList[j]
                if type(infl) == 'table' and (infl.w or 0) ~= 0 then
                    kept[#kept + 1] = infl
                end
            end
            influences[i] = kept
        end
    end
end

-- A loaded scene's influences get their bodies back (from the joint or anchor they name), and
-- dist; files from before DQS get a bindAngle from the loaded pose (saved at rest, so that is the
-- bind pose).
function lib.restoreBodies(influences)
    for i = 1, #influences do
        local inflList = influences[i]
        for j = 1, #inflList do
            local infl = inflList[j]
            if infl.nodeType == NT.JOINT then
                local joint = registry.getJointByID(infl.nodeId)
                local bodyA, bodyB = joint:getBodies()
                infl.body = (infl.side == SIDES.A) and bodyA or bodyB
            elseif infl.nodeType == NT.ANCHOR then
                local anchor = registry.getSFixtureByID(infl.nodeId)
                infl.body = anchor:getBody()
            end
            if infl.bindAngle == nil and infl.body then
                infl.bindAngle = infl.body:getAngle()
            end
            if infl.dist == nil and infl.dx ~= nil and infl.dy ~= nil then
                infl.dist = math.sqrt(infl.dx * infl.dx + infl.dy * infl.dy)
            end
        end
    end
end

-- A saved fixture's extra, ready for the file: no zero weights, no dist, bones pulled out (after
-- pruning, so a bone only zero-weight entries used isn't kept).
function lib.forFile(extra)
    if not (extra and extra.influences) then return end
    lib.pruneZeroWeight(extra.influences)
    lib.stripDist(extra.influences)
    extra.bones = lib.normalizeBones(extra.influences)
end

-- The other way, on decoded file data: the bones back onto the entries.
function lib.fromFile(extra)
    if not (extra and extra.influences and extra.bones) then return end
    lib.restoreBones(extra.influences, extra.bones)
    extra.bones = nil
end

return lib
