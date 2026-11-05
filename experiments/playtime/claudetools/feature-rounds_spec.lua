-- Sweep: the little-used features (docs/LITTLE-USED.md), each built from nothing the way the editor
-- or a toy makes it, then put through every inspector row and tool-rail attach (claudetools/actions.lua,
-- like the editor-actions sweep), a clone of the whole and of a part, a save loaded twice over, and a
-- minute of play with a finger dragging it about; at 200 and 400 px per metre.
-- After each: the sweep's checks (sfixtures first, the registry, draw / step / save / reload) and the
-- feature's own (a blob has its rim and its handle inside it, nothing flew off or went NaN), on the
-- world and on its reload. Problems the untouched build has already are left out.
-- Run: FEATURES_OUT=/some/file.txt love . --specs claudetools/feature-rounds_spec.lua  [FEATURES_ONLY=softbody]
--      [FEATURES_SEED=3] [FEATURES_CASE='a minute of play']  (a recipe's random picks; one case alone)
if not love then return end
local out = os.getenv('FEATURES_OUT')
if not out or out == '' then return end
local only = os.getenv('FEATURES_ONLY')
-- a recipe may pick at random (a blob's look, and so its outline): the same seed builds the same
local SEED = tonumber(os.getenv('FEATURES_SEED') or '') or 1
-- only the cases whose label holds this text (to replay one)
local CASE = os.getenv('FEATURES_CASE')

local json = require('vendor.dkjson')
local state = require('src.state')
local sceneIO = require('src.io')
local camera = require('src.camera')
local utils = require('src.utils')
local objectManager = require('src.object-manager')
local library = require('src.library')
local props = require('src.props')
local subtypes = require('src.subtypes')
local registry = require('src.registry')
local units = require('src.physics-units')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local fixtures = require('src.fixtures')
local shaders = require('src.render.shaders')
local sweep = require('claudetools.sweep')
local actions = require('claudetools.actions')

love.mouse.getPosition = function() return 0, 0 end

local METERS = { 200, 400 }

-- a closed room (floor, walls, ceiling) 3000 wide: what leaves it went through a wall. Scenery:
-- no cases are made for its bodies (labels starting with 'room ')
local function room()
    local function wall(label, x, y, w, h)
        objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h, bodyType = 'static', label = label })
    end
    wall('room floor', 0, 400, 3200, 100)
    wall('room ceiling', 0, -2400, 3200, 100)
    wall('room left wall', -1550, -1000, 100, 2900)
    wall('room right wall', 1550, -1000, 100, 2900)
end

local blob = require('src.blob')

-- which body: its label, or a blob's rim
local function nameOf(body)
    if blob.ownerOf(body) then return 'a blob rim body' end
    local thing = utils.thingOf(body)
    if not thing then return 'a body without a thing' end
    return 'a ' .. tostring(thing.shapeType) .. ' "' .. tostring(thing.label) .. '"'
end

-- every body where it can be: no NaN, nothing out of the room
local function sane(p, world)
    for _, body in ipairs(world:getBodies()) do
        local x, y = body:getPosition()
        if x ~= x or y ~= y then p.add(nameOf(body) .. ' at NaN') return end
        if math.abs(x) > 1600 or y > 500 or y < -2500 then
            p.add(nameOf(body) .. ' got out of the room, at ' .. math.floor(x) .. ', ' .. math.floor(y))
            return
        end
    end
end

-- (x, y) inside the polygon through these bodies (a blob's rim)
local function insideRim(nodes, x, y)
    local inside, n = false, #nodes
    local jx, jy = nodes[n]:getPosition()
    for k = 1, n do
        local ix, iy = nodes[k]:getPosition()
        if ((iy > y) ~= (jy > y)) and (x < (jx - ix) * (y - iy) / (jy - iy) + ix) then inside = not inside end
        jx, jy = ix, iy
    end
    return inside
end

-- a box wearing a picture (an OMP texfixture) drawn with a surface shader that reads the lights
local function litBox(x, label, shader)
    local thing = objectManager.addThing('rectangle', { x = x, y = 250, width = 200, height = 200, label = label })
    local fixture = fixtures.createSFixture(thing.body, 0, 0, subtypes.TEXFIXTURE, { width = 200, height = 200 })
    local extra = fixture:getUserData().extra
    extra.OMP, extra.dirty, extra.main = true, true, blob.randomLook()
    extra[shader] = true
    return thing
end

-- the lights a shader gets for this body, against the LIGHT sfixtures in the world
local function lightsReach(p, world)
    local lights = 0
    for _, fixture in ipairs(registry.sfixturesOf(subtypes.LIGHT)) do
        if sweep.alive(fixture) and fixture:getBody():getWorld() == world then lights = lights + 1 end
    end
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.label and thing.label:find('lit by', 1, true) then
            local count = shaders.gatherLightsForBody(body)
            if count ~= math.min(lights, 4) then -- MAX_LIGHTS in src/render/shaders.lua
                p.add('a lit body gets ' .. count .. ' lights of ' .. lights)
            end
        end
    end
end

-- name -> { build = fn() (makes it in the fresh world, returns its host thing), check = fn(p, world) }
local RECIPES = {
    softbody = {
        build = function()
            room()
            return props.makeBlob(0, 0, 300)
        end,
        check = function(p, world)
            sane(p, world)
            blob.beforeStep(true, 0) -- the rims, as the next frame builds them
            for _, fixture in ipairs(registry.sfixturesOf(subtypes.SOFTBODY)) do
                if sweep.alive(fixture) and fixture:getBody():getWorld() == world then
                    local rt = state.blobs[fixture:getUserData().id]
                    if not rt then
                        p.add('a softbody without its rim')
                    else
                        for _, node in ipairs(rt.nodes) do
                            if not sweep.alive(node) then p.add('a softbody rim with a destroyed node') break end
                        end
                        if not insideRim(rt.nodes, rt.body:getPosition()) then
                            p.add('a softbody handle outside its rim')
                        end
                    end
                end
            end
        end,
    },
    light = {
        build = function()
            room()
            litBox(-400, 'lit by plasticine', 'plasticine')
            litBox(400, 'lit by hairs', 'hairs')
            local lamp = objectManager.addThing('rectangle',
                { x = 0, y = -300, width = 60, height = 60, label = 'lamp' })
            fixtures.createSFixture(lamp.body, 0, 0, subtypes.LIGHT, { radius = 10 })
            return lamp
        end,
        check = function(p, world)
            sane(p, world)
            lightsReach(p, world)
        end,
    },
}

-- where two decoded saves differ (numbers within 1e-6), or nil; ids and order of lists as saved
local function differs(a, b, path)
    if type(a) == 'number' and type(b) == 'number' then
        if math.abs(a - b) > 1e-6 * math.max(1, math.abs(a)) then return path .. ': ' .. a .. ' -> ' .. b end
        return nil
    end
    if type(a) ~= type(b) then return path .. ': ' .. type(a) .. ' -> ' .. type(b) end
    if type(a) ~= 'table' then
        if a ~= b then return path .. ': ' .. tostring(a) .. ' -> ' .. tostring(b) end
        return nil
    end
    -- a list of things with ids (bodies, joints, fixtures): matched by id, the world lists them in its own order
    local function byId(t)
        if #t == 0 then return nil end
        local m = {}
        for _, v in ipairs(t) do
            if type(v) ~= 'table' or v.id == nil then return nil end
            m[v.id] = v
        end
        return m
    end
    local ma, mb = byId(a), byId(b)
    if ma and mb and #a == #b then a, b = ma, mb end
    for k, v in pairs(a) do
        local d = differs(v, b[k], path .. '.' .. tostring(k))
        if d then return d end
    end
    for k in pairs(b) do
        if a[k] == nil then return path .. '.' .. tostring(k) .. ': added' end
    end
end

local function things(world)
    local list = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing and thing.id then list[#list + 1] = thing end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- the feature's own cases, besides the inspector rows: done to the loaded world
local function extraCases(hostId, dt)
    local function host() return utils.thingOf(registry.getBodyByID(hostId)) end
    return {
        { 'clone everything', function(world) library.clone(things(world)) end },
        { 'clone the feature alone', function() library.clone({ host() }) end },
        { 'load the save, save that and load it again', function(world, p)
            local first = json.encode(sceneIO.gatherSaveData(world, camera.getInstance()))
            local world2 = sweep.fresh()
            sceneIO.load(first, world2, camera.getInstance())
            local second = json.encode(sceneIO.gatherSaveData(world2, camera.getInstance()))
            local difference = differs(json.decode(first), json.decode(second), 'save')
            if difference then p.add('a save loaded and saved again differs: ' .. difference) end
            local world3 = sweep.fresh()
            sceneIO.load(second, world3, camera.getInstance())
            return world3
        end },
        { 'a minute of play, dragged about', function(world)
            local body = host().body
            local x, y = body:getPosition()
            pointerJoints.grab('mouse', body, x, y)
            local joint = pointerJoints.getPointerJointAttachedTo(body).joint
            for i = 1, 60 / dt do
                local t = i * dt
                -- circles, then hard yanks up and down, then drop it
                if t < 20 then joint:setTarget(x + 300 * math.cos(t * 3), y - 200 + 300 * math.sin(t * 3))
                elseif t < 40 then joint:setTarget(x, (math.floor(t * 2) % 2 == 0) and y - 900 or y + 300)
                elseif t < 40 + dt then pointerJoints.handlePointerReleased(0, 0, 'mouse') end
                sweep.step(world, 1, dt)
                if i % 120 == 0 then sweep.frame(world) end
            end
            pointerJoints.handlePointerReleased(0, 0, 'mouse')
        end },
    }
end

describe('feature rounds', function()
    it('each little-used feature, built from nothing, one change at a time', function()
        local file = assert(io.open(out, 'w'))
        local report = sweep.report('feature-rounds_spec')
        local total, failing = 0, 0
        local realMeter = love.physics.getMeter()
        for name, recipe in pairs(RECIPES) do
            if not only or only == name then
                for _, meter in ipairs(METERS) do
                    love.physics.setMeter(meter)
                    state.world.meter = meter
                    local dt = 1 / units.stepsPerSecond(meter)
                    local where = name .. ' at ' .. meter .. ' (seed ' .. SEED .. ')'
                    local world = sweep.fresh()
                    math.randomseed(SEED); love.math.setRandomSeed(SEED)
                    local hostThing = recipe.build()
                    sweep.step(world, 5, dt)
                    local hostId = hostThing.id
                    local text = json.encode(sceneIO.gatherSaveData(world, camera.getInstance()))
                    local ids = sweep.idsOf(json.decode(text))
                    local own = {}
                    for _, p in ipairs(actions.run(text, nil, recipe.check)) do
                        own[sweep.shape(p, ids)] = true
                        file:write('UNTOUCHED ', where, ': ', p, '\n')
                    end
                    local cases = {}
                    for _, case in ipairs(actions.casesOf(state.physicsWorld, 99)) do
                        local body = case[2] ~= 'joint' and registry.getBodyByID(case[3])
                        local thing = body and utils.thingOf(body)
                        local label = thing and thing.label or ''
                        if label:sub(1, 5) ~= 'room ' then cases[#cases + 1] = case end
                    end
                    for _, extra in ipairs(extraCases(hostId, dt)) do cases[#cases + 1] = extra end
                    for _, case in ipairs(cases) do
                      local label = case[1]
                      if not CASE or label:find(CASE, 1, true) then
                        local action = case
                        if type(case[2]) == 'function' then action = case[2] end
                        local problems = actions.run(text, action, recipe.check)
                        total = total + 1
                        local any = false
                        for _, p in ipairs(problems) do
                            local message = sweep.shape(p, ids)
                            if not own[message] then
                                any = true
                                report.add(message .. '   [' .. (label:match('^(.-) %(') or label) .. ']', p,
                                    where .. ' / ' .. label)
                            end
                        end
                        if any then failing = failing + 1 end
                      end
                    end
                    file:write(where, ' done (', #cases, ' cases)\n'); file:flush()
                end
            end
        end
        love.physics.setMeter(realMeter)
        state.world.meter = realMeter
        report.write(file, total, failing, 'cases')
        file:close()
    end)
end)
