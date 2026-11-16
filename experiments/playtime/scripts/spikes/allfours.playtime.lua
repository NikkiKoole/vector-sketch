-- allfours: any Mipo down on all fours, walking or trotting like an animal (docs/ALL-FOURS.md; Nikki 2026-11-16)
-- The pose and the gait are scripts/spikes/all-fours.lua. Facing a side only (as sitting).
-- keys: f all down / up   left/right (hold): go that way   g walk / trot   r new Mipos   n one more
--       p pause   h panel

local s = {}

-- (a change to all-fours.lua alone doesn't reload this scene: save this file too, or the bridge's /reload)
local fours = love.filesystem.load('scripts/spikes/all-fours.lua')()

local alive = mipoKit.isAlive

local GROUND_Y = 900
local HALF = 6000
local ZOOM = 0.25
local SCALE = 0.3
local COUNT = 3

local function check() -- on state: a script hot reload keeps the Mipos
    state.foursSpike = state.foursSpike or { mipos = {}, bodies = {}, showPanel = true, gait = 'walk', hold = true,
        twoTorsos = true, evenLimbs = true } -- (Nikki: "lets give the mipos here 2 segmented torso, might help, and
                                               -- lets arrange the arm and legs to be roughly same length")
    return state.foursSpike
end

local function each(fn)
    for _, inst in pairs(check().mipos) do
        if alive(inst) then fn(inst) end
    end
end

local function removeMipos()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then fours.up(inst) characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
end

local LIMB_PARTS = { 'luleg', 'ruleg', 'llleg', 'rlleg', 'luarm', 'ruarm', 'llarm', 'rlarm' }

local function addMipo(x)
    local c = check()
    local inst = characterManager.createCharacter('humanoid', x, GROUND_Y - 600, SCALE)
    if not inst then return end
    -- two torso segments before the roll, so it gives both a shape (a bendy back)
    if c.twoTorsos then characterManager.rebuildFromCreation(inst, { torsoSegments = 2 }) end
    characterManager.randomizeMipo(inst)
    -- arms and legs the same length: each the average of the two
    if c.evenLimbs then
        local parts = inst.dna.parts
        local leg, arm = parts.luleg and parts.luleg.dims.h, parts.luarm and parts.luarm.dims.h
        if leg and arm then
            local h = (leg + arm) / 2
            for _, name in ipairs(LIMB_PARTS) do
                if parts[name] and parts[name].dims then parts[name].dims.h = h end
            end
            characterManager.rebuildFromCreation(inst, {})
            characterManager.rebuildTextures(inst)
        end
    end
    table.insert(c.mipos, inst)
end

local function newMipos()
    removeMipos()
    for i = 1, COUNT do addMipo((i - (COUNT + 1) / 2) * 900) end
end

local function makeGround()
    local c = check()
    for _, b in ipairs(c.bodies) do if not b:isDestroyed() then return end end
    c.bodies = {}
    local floor = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(HALF * 2, 100)):setFriction(0.9)
    table.insert(c.bodies, floor)
    for _, side in ipairs({ -1, 1 }) do
        local wall = love.physics.newBody(world, side * (HALF + 50), GROUND_Y - 1000, 'static')
        love.physics.newFixture(wall, love.physics.newRectangleShape(100, 2000)):setFriction(0.5)
        table.insert(c.bodies, wall)
    end
end

local function lookAt()
    local sx, n = 0, 0
    each(function(inst) sx, n = sx + inst.parts.torso1.body:getX(), n + 1 end)
    cam:setScale(ZOOM)
    cam:setTranslation(n > 0 and sx / n or 0, GROUND_Y - 450)
end

local function allDown()
    local c = check()
    local anyUp = false
    each(function(inst) anyUp = anyUp or not fours.isDown(inst) end)
    each(function(inst)
        if anyUp then fours.down(inst) else fours.up(inst) end
    end)
    c.hold = true
end

function s.onStart()
    worldState.paused = false
    makeGround()
    local any = false
    for _, inst in pairs(check().mipos) do any = any or alive(inst) end
    if not any then newMipos() end
    check().hold = true
    lookAt()
end

function s.onUnload()
    local c = state.foursSpike
    if not c then return end
    fours.upAll()
    for _, b in ipairs(c.bodies) do if not b:isDestroyed() then b:destroy() end end
    c.bodies = {}
end

function s.update(dt)
    local c = check()
    local dir = (love.keyboard.isDown('right') and 1 or 0) - (love.keyboard.isDown('left') and 1 or 0)
    if dir ~= 0 or (c.keyDir or 0) ~= 0 or c.go then
        local d = dir ~= 0 and dir or (c.go or 0)
        each(function(inst) fours.drive(inst, d * fours.tuning.speed, c.gait) end)
    end
    c.keyDir = dir
    fours.update(dt or love.timer.getDelta())
    -- the camera goes with the Mipos until you touch, drag or zoom
    if c.hold then
        if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
            c.hold = false
        else
            lookAt()
        end
    end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'f' then allDown() end
    if key == 'g' then c.gait = c.gait == 'walk' and 'trot' or 'walk' end
    if key == 'r' then newMipos() c.hold = true end
    if key == 'n' then addMipo((love.math.random() - 0.5) * 2000) end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'h' then c.showPanel = not c.showPanel end
end

-- the panel's sliders: the module's tuning
local SLIDERS = {
    { 'bend', 'body tips', 45, 110, 1 }, { 'level', 'level (0: high back)', 0, 1, 0.05 },
    { 'maxTilt', 'nose down at most', 0, 45, 1 },
    { 'look', 'head looks up', 0, 120, 1 }, { 'stride', 'stride', 5, 50, 1 }, { 'lift', 'knee lift', 0, 90, 1 },
    { 'cycle', 'step length', 0.15, 1.2, 0.05 }, { 'speed', 'speed', 0.1, 2, 0.05 },
    { 'push', 'push', 0.05, 1.5, 0.05 }, { 'kp', 'muscles', 2, 80, 1 },
    { 'bodyKp', 'body muscle', 5, 200, 5 }, { 'maxOmega', 'muscle speed', 1, 12, 0.5 },
}

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 6, 400
    local rows = #SLIDERS + 5
    local h = BH * rows + pad * (rows + 1) + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• all fours ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 24 })
        local bw = w - 12
        local third = (bw - 2 * pad) / 3
        local x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, bw, 'down / up (f)') then allDown() end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, third, '< go') then c.go = -1 end
        if ui.button(x + third + pad, y, third, 'stop') then
            c.go = nil
            each(function(inst) fours.drive(inst, 0) end)
        end
        if ui.button(x + 2 * (third + pad), y, third, 'go >') then c.go = 1 end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, bw, 'gait: ' .. c.gait .. ' (g)') then c.gait = c.gait == 'walk' and 'trot' or 'walk' end
        -- how the next Mipos are made (r)
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local half = (bw - pad) / 2
        if ui.button(x, y, half, (c.twoTorsos and '2 torsos' or '1 torso')) then c.twoTorsos = not c.twoTorsos end
        if ui.button(x + half + pad, y, half, (c.evenLimbs and 'even limbs' or 'own limbs')) then
            c.evenLimbs = not c.evenLimbs
        end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, bw, 'new Mipos (r)') then newMipos() c.hold = true end
        for _, sl in ipairs(SLIDERS) do
            x, y = ui.nextLayoutPosition(layout, bw, BH)
            local v = ui.sliderWithInput('fours-' .. sl[1], x, y, 160, sl[3], sl[4], fours.tuning[sl[1]], nil, sl[5])
            if v then fours.tuning[sl[1]] = v + 0 end
            ui.label(x + 235, y, sl[2])
        end
    end)
end

return s
