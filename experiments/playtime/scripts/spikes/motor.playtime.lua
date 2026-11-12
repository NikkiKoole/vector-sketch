-- motor: Mipos that move by themselves — walk, hop, jump — instead of standing like dolls (docs/MIPO-MOTOR.md).
-- mipoWalk.drive(inst, speed, 'walk' | 'hop'): it turns to face its way, its legs step (or both feet
-- hop) and its feet push it, only while one touches the floor. mipoActions.jump(inst, forward).
-- keys: left/right (hold): walk, jog, run or hop that way   up: jump (the way it faces)   g: the next gait
--       down (hold): squat (up from a squat: jump)   b: bump them (a shove each, to see them catch themselves)
--       w: wander by themselves (on/off)   r: new Mipos   n: one more   p: pause   h: panel

local s = {}

local walk = mipoWalk     -- src/mipo-walk.lua

-- the gaits in turn (g), and each one's speed against the walk's (a jog, a run: MIPO-LOCOMOTION LO10)
local GAITS = { 'walk', 'jog', 'run', 'hop' }
local function nextGait(g)
    for i, name in ipairs(GAITS) do
        if name == g then return GAITS[i % #GAITS + 1] end
    end
    return 'walk'
end
local function gaitSpeed(g)
    local gait = walk.gaits and walk.gaits[g]
    return gait and gait.speed or 1
end
local actions = mipoActions -- src/mipo-actions.lua
local alive = mipoKit.isAlive

local GROUND_Y = 900
local HALF = 6000       -- the floor runs from -HALF to HALF, a wall at each end
local ZOOM = 0.22
local SCALE = 0.3
local COUNT = 3

local function check() -- on state: a script hot reload keeps the Mipos
    state.motorSpike = state.motorSpike or {
        mipos = {}, bodies = {}, showPanel = true,
        gait = 'walk',  -- the keys' gait: 'walk', 'jog', 'run' or 'hop' (g goes round them)
        speed = 1.5,    -- leg lengths a second
        jumpForward = 400,
        wander = false,
    }
    return state.motorSpike
end

local function removeMipos()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
end

local function addMipo(x)
    local c = check()
    local inst = characterManager.createCharacter('humanoid', x, GROUND_Y - 600, SCALE)
    if not inst then return end
    characterManager.randomizeMipo(inst)
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

local function each(fn)
    for _, inst in pairs(check().mipos) do
        if alive(inst) then fn(inst) end
    end
end

local function jumpAll()
    local c = check()
    each(function(inst)
        local face = mipoFacing.dir(inst)
        actions.jump(inst, face * c.jumpForward)
    end)
end

---------------------------------------------------------------- wandering

-- each Mipo by itself: stand a while, walk or hop a way a while, now and then a jump; away from walls
local function wander(inst, now)
    local c = check()
    local w = inst._wander
    if not w or now >= w.untilT then
        local x = inst.parts.torso1.body:getX()
        local r = love.math.random()
        w = { untilT = now + 1 + love.math.random() * 3 }
        if r < 0.35 then
            w.speed = 0
        else
            local dir = love.math.random() < 0.5 and -1 or 1
            if x > HALF * 0.7 then dir = -1 elseif x < -HALF * 0.7 then dir = 1 end
            w.speed = dir * c.speed * (0.6 + love.math.random() * 0.6)
            local g = love.math.random()
            w.gait = g < 0.2 and 'hop' or g < 0.35 and 'run' or g < 0.55 and 'jog' or 'walk'
            w.jumpAt = love.math.random() < 0.25 and now + love.math.random() * 1.5 or nil
        end
        inst._wander = w
    end
    walk.drive(inst, w.speed * gaitSpeed(w.gait), w.gait)
    if w.jumpAt and now >= w.jumpAt then
        w.jumpAt = nil
        actions.jump(inst, mipoFacing.dir(inst) * c.jumpForward * 0.5)
    end
end

---------------------------------------------------------------- the scene

local function lookAt()
    local sx, n = 0, 0
    each(function(inst) sx, n = sx + inst.parts.torso1.body:getX(), n + 1 end)
    cam:setScale(ZOOM)
    cam:setTranslation(n > 0 and sx / n or 0, GROUND_Y - 500)
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
    local c = state.motorSpike
    if not c then return end
    each(function(inst) walk.drive(inst, nil) end)
    if c.jumpSpeedWas then actions.jumpSpeed, c.jumpSpeedWas = c.jumpSpeedWas, nil end
    for _, b in ipairs(c.bodies) do if not b:isDestroyed() then b:destroy() end end
    c.bodies = {}
end

function s.update()
    local c = check()
    local now = love.timer.getTime()
    local dir = (love.keyboard.isDown('right') and 1 or 0) - (love.keyboard.isDown('left') and 1 or 0)
    local released = dir == 0 and (c.keyDir or 0) ~= 0 -- a key let go: stop (the panel's go keeps going)
    c.keyDir = dir
    -- down held: squat (let go: up again)
    local down = love.keyboard.isDown('down')
    if down ~= (c.keyDown or false) then
        each(function(inst) walk.squat(inst, down) end)
    end
    c.keyDown = down
    each(function(inst)
        if dir ~= 0 then
            walk.drive(inst, dir * c.speed * gaitSpeed(c.gait), c.gait)
        elseif c.wander then
            wander(inst, now)
        elseif released then
            walk.drive(inst, nil)
        end
    end)
    -- the camera goes with the Mipos until you touch, drag or zoom
    if c.hold then
        if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
            c.hold = false
        else
            lookAt()
        end
    end
end

local function toggleWander()
    local c = check()
    c.wander = not c.wander
    if not c.wander then each(function(inst) inst._wander = nil walk.drive(inst, nil) end) end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'up' then jumpAll() end
    if key == 'b' then -- a shove each, either way, to see them catch themselves (MIPO-LOCOMOTION LO4b)
        each(function(inst)
            local torso = inst.parts.torso1.body
            local _, ty = torso:getPosition()
            local _, fy = inst.parts.lfoot.body:getPosition()
            local dir = love.math.random() < 0.5 and -1 or 1
            torso:applyLinearImpulse(dir * mipoRegistry.totalMass(inst) * 2.5 * math.abs(fy - ty), 0)
        end)
    end
    if key == 'g' then c.gait = nextGait(c.gait) end
    if key == 'w' then toggleWander() end
    if key == 'r' then newMipos() c.hold = true end
    if key == 'n' then addMipo((love.math.random() - 0.5) * 2000) end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'f' then c.hold = true end
end

local function slider(layout, w, id, label, lo, hi, value, stepSize)
    local x, y = ui.nextLayoutPosition(layout, w, 34)
    local v = ui.sliderWithInput('motor-' .. id, x, y, 150, lo, hi, value, nil, stepSize)
    ui.label(x + 225, y, label)
    return v and (v + 0) or nil
end

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 6, 330
    local rows = 17
    local h = BH * rows + pad * (rows + 1) + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• motor ••', function()
        local layout = ui.createLayout({ type = "columns", spacing = pad,
            startX = x0 + pad, startY = y0 + pad + 24 })
        local bw = w - 12
        local half = (bw - pad) / 2
        local x, y = ui.nextLayoutPosition(layout, bw, BH)
        local sp = c.speed * gaitSpeed(c.gait)
        if ui.button(x, y, half, '< go') then each(function(i) walk.drive(i, -sp, c.gait) end) end
        if ui.button(x + half + pad, y, half, 'go >') then each(function(i) walk.drive(i, sp, c.gait) end) end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, half, 'stop') then each(function(i) walk.drive(i, nil) end) end
        if ui.button(x + half + pad, y, half, 'jump (up)') then jumpAll() end
        -- one go each: a thing, then they stand
        local third, quarter = (bw - 2 * pad) / 3, (bw - 3 * pad) / 4
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, third, '< step') then each(function(i) walk.steps(i, -c.speed, 1) end) end
        if ui.button(x + third + pad, y, third, '2 steps') then
            each(function(i) walk.steps(i, (mipoFacing.dir(i) < 0 and -1 or 1) * c.speed, 2) end)
        end
        if ui.button(x + 2 * (third + pad), y, third, 'step >') then
            each(function(i) walk.steps(i, c.speed, 1) end)
        end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, half, '< hop') then each(function(i) walk.hopOnce(i, -c.speed) end) end
        if ui.button(x + half + pad, y, half, 'hop >') then each(function(i) walk.hopOnce(i, c.speed) end) end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, third, '< turn') then each(function(i) walk.turnTo(i, 'left') end) end
        if ui.button(x + third + pad, y, third, 'front') then each(function(i) walk.turnTo(i, 'front') end) end
        if ui.button(x + 2 * (third + pad), y, third, 'turn >') then each(function(i) walk.turnTo(i, 'right') end) end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, quarter, 'up') then each(function(i) actions.jump(i, 0) end) end
        if ui.button(x + quarter + pad, y, quarter, 'breathe') then each(actions.breathe) end
        if ui.button(x + 2 * (quarter + pad), y, quarter, 'flip') then
            each(function(i) actions.setFlipped(i, not actions.isFlipped(i)) end)
        end
        if ui.button(x + 3 * (quarter + pad), y, quarter, 'limp') then
            each(function(i) actions.setRagdoll(i, not actions.isRagdoll(i)) end)
        end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, bw, 'gait: ' .. c.gait .. ' (g)') then c.gait = nextGait(c.gait) end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local wanderLabel = 'wander by themselves: ' .. (c.wander and 'on' or 'off') .. ' (w)'
        if ui.button(x, y, bw, wanderLabel) then toggleWander() end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, half, 'new Mipos (r)') then newMipos() c.hold = true end
        if ui.button(x + half + pad, y, half, 'one more (n)') then addMipo((love.math.random() - 0.5) * 2000) end
        local v = slider(layout, bw, 'speed', 'speed (legs/s)', 0.3, 4, c.speed, 0.1)
        if v then c.speed = v end
        v = slider(layout, bw, 'accel', 'push (legs/s2)', 0.5, 12, walk.driveAccel, 0.5)
        if v then walk.driveAccel = v end
        v = slider(layout, bw, 'turning', 'pace turning', 0, 1, walk.turningPace, 0.05)
        if v then walk.turningPace = v end
        v = slider(layout, bw, 'hopH', 'hop height (legs)', 0.05, 1.2, walk.hopHeight, 0.05)
        if v then walk.hopHeight = v end
        v = slider(layout, bw, 'hopRest', 'hop rest (s)', 0, 0.6, walk.hopRest, 0.02)
        if v then walk.hopRest = v end
        v = slider(layout, bw, 'jumpF', 'jump forward', 0, 1200, c.jumpForward, 50)
        if v then c.jumpForward = v end
        if walk.animJump then -- the animated jump (LO8): its height in leg lengths
            v = slider(layout, bw, 'jumpHeight', 'jump height (legs)', 0.3, 4, walk.jumpHeight, 0.1)
            if v then walk.jumpHeight = v end
        else
            v = slider(layout, bw, 'jumpUp', 'jump up', 300, 2400, actions.jumpSpeed, 50)
            if v then
                c.jumpSpeedWas = c.jumpSpeedWas or actions.jumpSpeed -- back on unload: it's every scene's
                actions.jumpSpeed = v
            end
        end
        -- the torso muscle (tried at 20: rocked more; walk.upright stays 0): its row went to the squat
        if false then
            v = slider(layout, bw, 'upright', 'torso muscle', 0, 60, walk.upright, 5)
            if v then walk.upright = v end
        end
        v = slider(layout, bw, 'jumpCrouch', 'squat (s)', 0.05, 0.6, walk.jumpCrouch, 0.01)
        if v then walk.jumpCrouch = v end
    end)
    -- the weighty walk (MIPO-MOTOR MM8), on the right
    local sw = love.graphics.getDimensions()
    local rows2 = 17
    local h2 = BH * rows2 + pad * (rows2 + 1) + 24
    local x1, y1 = sw - w - 90, sh - h2 - 20 -- room for the labels past the sliders
    ui.panel(x1, y1, w, h2, '•• weight ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad,
            startX = x1 + pad, startY = y1 + pad + 24 })
        local bw = w - 12
        local x, y = ui.nextLayoutPosition(layout, bw, BH)
        if ui.button(x, y, bw, 'weighty walk: ' .. (walk.weighty and 'on' or 'off')) then
            walk.weighty = not walk.weighty
        end
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local half = (bw - pad) / 2
        if ui.button(x, y, half, 'poses: ' .. (walk.keyed and 'keyed' or 'sine')) then walk.keyed = not walk.keyed end
        if ui.button(x + half + pad, y, half, 'motors: ' .. (walk.legMotors and 'on' or 'off')) then
            walk.legMotors = not walk.legMotors
        end
        local v = slider(layout, bw, 'give', 'knee give (deg)', 0, 60, walk.give, 1)
        if v then walk.give = v end
        v = slider(layout, bw, 'pulse', 'push pulse', 0, 2, walk.pulse, 0.05)
        if v then walk.pulse = v end
        v = slider(layout, bw, 'armSwing', 'arm swing (deg)', 0, 70, walk.armSwing, 1)
        if v then walk.armSwing = v end
        v = slider(layout, bw, 'stanceGrip', 'foot grip', 0, 3, walk.stanceGrip, 0.1)
        if v then walk.stanceGrip = v end
        -- SIMBICON (docs/MIPO-LOCOMOTION.md LO1): the torso held by the standing hip, the foot placed
        -- for balance (the default since 2026-11-12). The button: on (the defaults) or off (as before LO1).
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local lo1 = walk.torsoHold > 0 or walk.placeV > 0
        if ui.button(x, y, bw, 'simbicon: ' .. (lo1 and 'on' or 'off')) then
            if lo1 then
                walk.torsoHold, walk.placeV, walk.driveAccel = 0, 0, 1.5
            else
                walk.torsoHold, walk.placeV, walk.driveAccel = 0.5, 0.5, 1
            end
        end
        v = slider(layout, bw, 'torsoHold', 'torso by hip', 0, 2, walk.torsoHold, 0.05)
        if v then walk.torsoHold = v end
        v = slider(layout, bw, 'placeV', 'foot placement', 0, 2, walk.placeV, 0.05)
        if v then walk.placeV = v end
        v = slider(layout, bw, 'walkLean', 'lean (deg)', 0, 20, walk.walkLean, 1)
        if v then walk.walkLean = v end
        -- the feet roll through the step (LO7): heel strike, plant, heel off, swing, toes up before contact
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local halfW = (bw - pad) / 2
        if ui.button(x, y, halfW, 'foot roll: ' .. (walk.footRoll and 'on' or 'off')) then walk.footRoll = not walk.footRoll end
        -- LO3: the standing leg by IK to where its foot landed (off: tried, slower; to look at)
        if ui.button(x + halfW + pad, y, halfW, 'foot lock: ' .. (walk.footLock > 0 and 'on' or 'off')) then
            walk.footLock = walk.footLock > 0 and 0 or 1
        end
        v = slider(layout, bw, 'heelStrike', 'heel strike (deg)', 0, 40, walk.heelStrike, 1)
        if v then walk.heelStrike = v end
        v = slider(layout, bw, 'toeOff', 'toe off (deg)', 0, 60, walk.toeOff, 1)
        if v then walk.toeOff = v end
        v = slider(layout, bw, 'footFollow', 'foot with shin', 0, 1, walk.footFollow, 0.05)
        if v then walk.footFollow = v end
        -- the jump as animation (LO8), the stopping step and turning on the spot (LO4); off: as before
        x, y = ui.nextLayoutPosition(layout, bw, BH)
        local third = (bw - 2 * pad) / 3
        if ui.button(x, y, third, 'jump: ' .. (walk.animJump and 'anim' or 'old')) then walk.animJump = not walk.animJump end
        if ui.button(x + third + pad, y, third, 'stop: ' .. (walk.stopStep and 'step' or 'old')) then
            walk.stopStep = not walk.stopStep
        end
        if ui.button(x + 2 * (third + pad), y, third, 'turn: ' .. (walk.turnFirst and 'first' or 'old')) then
            walk.turnFirst = not walk.turnFirst
        end
        v = slider(layout, bw, 'jumpDepth', 'squat depth', 0.2, 1.5, walk.jumpDepth, 0.05)
        if v then walk.jumpDepth = v end
    end)
end

return s
