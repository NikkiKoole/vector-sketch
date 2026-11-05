-- One editor action on a loaded world, through the inspector's own rows (src/body-params.lua,
-- src/joint-params.lua, src/sfixture-params.lua) or an sfixture attached from the tool rail; then
-- checked, drawn, stepped, saved and loaded again. Shared by claudetools/editor-actions_spec.lua
-- (every scene) and claudetools/feature-rounds_spec.lua (one little-used feature built from nothing).
local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local utils = require('src.utils')
local fixtures = require('src.fixtures')
local modes = require('src.modes')
local bodyParams = require('src.body-params')
local jointParams = require('src.joint-params')
local sfixtureParams = require('src.sfixture-params')
local sweep = require('claudetools.sweep')

local lib = {}

-- the tool rail's attach list (src/ui/tool-rail.lua)
lib.ATTACH = { 'snap', 'anchor', 'texfixture', 'connected-texture', 'tile-repeat', 'grass', 'light',
    'softbody', 'liquid', 'resource', 'meshusert', 'uvusert', 'trace-vertices' }

local alive = sweep.alive

local function resolve(v, target)
    if type(v) == 'function' then return v(target) end
    return v
end

local function labelOf(row, target)
    return tostring(row.key or resolve(row.label, target) or '?')
end

-- the rows a target shows, as the panels build them
local function rowsOf(kind, target)
    local list = {}
    local function add(rows) for _, row in ipairs(rows or {}) do list[#list + 1] = row end end
    if kind == 'body' then
        add(bodyParams.rows)
    elseif kind == 'joint' then
        add(jointParams.header); add(jointParams.byType[target:getType()])
    else
        local rows = sfixtureParams.bySubtype[target:getUserData().subtype]
        add(sfixtureParams.header); add(rows); add(sfixtureParams.footer)
    end
    return list
end

local DOABLE = { number = true, numberText = true, bool = true, choice = true, action = true, buttons = true }

-- one change of a row, as a click or a drag would make it
local function change(row, body, target)
    local kind = row.kind
    if kind == 'action' then return row.run(body, target) end
    if kind == 'buttons' then
        local options = resolve(row.options, target)
        return row.run(body, target, options[#options])
    end
    local v
    if row.get then v = row.get(target) else v = target[row.key] end
    if v == nil then v = row.default end
    local new
    if kind == 'bool' then
        new = not v
    elseif kind == 'choice' then
        local options = resolve(row.options, target)
        local i = 1
        for k, o in ipairs(options) do if o == v then i = k end end
        new = options[i % #options + 1]
    else
        v = tonumber(v) or 0
        local min, max = resolve(row.min, target), resolve(row.max, target)
        new = (v ~= 0) and v * 1.5 or 1
        if kind == 'numberText' then new = v + 25 end
        if max and new > max then new = max end
        if min and new < min then new = min end
        if new == v then new = min or (v - 1) end
    end
    if row.set then return row.set(target, new) end
    target[row.key] = new
end

local function findTarget(kind, id)
    if kind == 'body' then
        local body = registry.getBodyByID(id)
        return body and utils.thingOf(body), body
    elseif kind == 'joint' then
        return registry.getJointByID(id), nil
    end
    return registry.getSFixtureByID(id), nil
end

-- the cases of one loaded world: { label, kind, id, row index } and { label, 'attach', body id, subtype };
-- one per row and kind of target (a rectangle's width, a revolute joint's motor), on up to perKind targets
function lib.casesOf(world, perKind)
    local list, perKey = {}, {}
    local function offer(kind, sort, id, target, rows)
        for i, row in ipairs(rows) do
            if DOABLE[row.kind] and (not row.visible or row.visible(target)) then
                local key = kind .. ' ' .. sort .. ' / ' .. labelOf(row, target)
                perKey[key] = (perKey[key] or 0) + 1
                if perKey[key] <= perKind then
                    list[#list + 1] = { key .. ' (' .. tostring(id) .. ')', kind, id, i }
                end
            end
        end
    end
    local bodies = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.id then bodies[#bodies + 1] = thing end
    end
    table.sort(bodies, function(a, b) return a.id < b.id end)
    for _, thing in ipairs(bodies) do
        local sort = tostring(thing.shapeType) .. (thing.mipoId and ' (Mipo part)' or '')
        offer('body', sort, thing.id, thing, rowsOf('body', thing))
    end
    local jointIds = {}
    for id in pairs(registry.joints) do jointIds[#jointIds + 1] = id end
    table.sort(jointIds)
    for _, id in ipairs(jointIds) do
        local joint = registry.joints[id]
        if alive(joint) then offer('joint', joint:getType(), id, joint, rowsOf('joint', joint)) end
    end
    local sfixtureIds = {}
    for id in pairs(registry.sfixtures) do sfixtureIds[#sfixtureIds + 1] = id end
    table.sort(sfixtureIds)
    for _, id in ipairs(sfixtureIds) do
        local fixture = registry.sfixtures[id]
        if alive(fixture) then
            offer('sfixture', tostring(fixture:getUserData().subtype), id, fixture, rowsOf('sfixture', fixture))
        end
    end
    for _, i in ipairs(sweep.spread(#bodies, perKind)) do
        for _, subtype in ipairs(lib.ATTACH) do
            list[#list + 1] = { 'attach ' .. subtype .. ' (' .. bodies[i].id .. ')', 'attach', bodies[i].id, subtype }
        end
    end
    return list
end

local function apply(case)
    local kind, id = case[2], case[3]
    if kind == 'attach' then
        local body = registry.getBodyByID(id)
        local extra = { radius = 30 }
        if case[4] == 'texfixture' then extra = { width = 60, height = 60 } end
        state.selection.selectedSFixture = fixtures.createSFixture(body, 5, 5, case[4], extra)
        return
    end
    local target, body = findTarget(kind, id)
    if not target then error('target gone before the action') end
    change(rowsOf(kind, target)[case[4]], body, target)
    modes.clear()
end

-- one scene's text, one action (nil: as it is; a function(world, p): done to the loaded world, may
-- return another world to go on with); returns the problems.
-- check(p, world), when given, runs after the steps and again on the reloaded world.
function lib.run(text, case, check)
    local p = sweep.problems()
    local world = sweep.fresh()
    state.selection.selectedObj, state.selection.selectedJoint, state.selection.selectedSFixture = nil, nil, nil
    state.selection.selectedBodies = nil
    if not p.phase('load', function() sceneIO.load(text, world, camera.getInstance()) end) then return p.finish() end
    p.phase('first draw', function() sweep.frame(world) end)
    if case and not p.phase('action', function()
            -- a function may hand back the world to go on with (it loaded another)
            if type(case) == 'function' then world = case(world, p) or world else apply(case) end
        end) then
        return p.finish()
    end
    p.phase('check', function() sweep.checkWorld(p, world) end)
    p.phase('draw', function() sweep.frame(world) end)
    p.phase('step', function() sweep.step(world, 3) end)
    p.phase('draw after step', function() sweep.frame(world) end)
    if check then p.phase('feature check', function() check(p, world) end) end
    local world2 = sweep.saveAndReload(p, world)
    if check and world2 then p.phase('feature check reloaded', function() check(p, world2) end) end
    return p.finish()
end

return lib
