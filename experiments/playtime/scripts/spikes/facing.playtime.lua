-- facing: one Mipo three times, facing left, front and right (dna.facing, src/mipo-facing.lua;
-- docs/MIPO-FACING.md), after puppet-maker2's facingVars.legs. Facing a side, both legs bend like
-- that side's leg and both feet point that way; the far arm and leg draw behind the torso.
-- Sit puts a stool under each and folds the legs: thighs forward, shins down (front can't: its
-- hips only swing outward).
-- Turning: arrows turn every Mipo a step (left <- front -> right): the body quickly, the head
-- slowly after it; , and . turn only the heads; t turns them back and forth.
-- keys: r: a new Mipo   s: sit / stand   a: arms follow the facing (on/off)   left/right: turn
--       , .: turn the heads   j: a little hop as the body switches (on/off)
--       b: switch the body in place, or rebuild the whole Mipo (to compare)
--       f: the turning foot leans round, or flips   w: autowalk when dragged along the floor
--       t: turning by itself   p: pause   h: panel
--       c: face patches on/off (src/face-patches.lua: eye hollows and a snout, turning with the face)

local s = {}

local facing = mipoFacing
local actions = mipoActions
local walk = mipoWalk -- turning and walking (src/mipo-walk.lua)

local SPACING = 1100
local GROUND_Y = 900
local ZOOM = 0.3
local SCALE = 0.3
-- all front: a Mipo faces front and turns when pulled (was left / front / right)
local SIDES = { 'front', 'front', 'front' }

local function check() -- on state: a script hot reload keeps the Mipos
    state.facingSpike = state.facingSpike or { mipos = {}, stools = {}, showPanel = true }
    return state.facingSpike
end

local alive = mipoKit.isAlive -- src/mipo-kit.lua

local function removeStools()
    local c = check()
    for _, body in ipairs(c.stools) do
        if not body:isDestroyed() then body:destroy() end
    end
    c.stools = {}
end

local function removeMipos()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
end

local function xOf(i) return (i - 2) * SPACING end

-- face patches on every Mipo, or none (c)
local function placePatches()
    local c = check()
    if c.patches == nil then c.patches = true end
    for _, inst in pairs(c.mipos) do
        if alive(inst) then
            inst.facePatches = c.patches and facePatches.defaults() or nil
            facePatches.place(inst, true)
        end
    end
end

local function newMipos()
    local c = check()
    removeStools()
    removeMipos()
    c.sitting = false
    local first = characterManager.createCharacter('humanoid', xOf(1), GROUND_Y - 500, SCALE)
    if not first then return end
    characterManager.randomizeMipo(first)
    characterManager.removeCharacter(first)
    for i, side in ipairs(SIDES) do
        first.dna.facing = side -- createCharacterFromJustDNA builds on a copy
        c.mipos[i] = characterManager.createCharacterFromJustDNA(first.dna, xOf(i), GROUND_Y - 500, SCALE)
    end
    placePatches()
end

-- arms on/off: the same Mipos rebuilt
local function rebuildAll()
    local c = check()
    for _, inst in pairs(c.mipos) do
        if alive(inst) then
            characterManager.rebuildFromCreation(inst, {})
        end
    end
end

-- where a joint between parent and part sits (hip, knee)
local function jointPoint(inst, parentName, partName)
    local part, parent = inst.parts[partName], inst.parts[parentName]
    if not (part and parent) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

local LEGS = { l = { 'luleg', 'llleg' }, r = { 'ruleg', 'rlleg' } }

local function setLegTargets(inst, thigh, shin)
    for _, leg in pairs(LEGS) do
        local upper = actions.ensureKeepAngle(inst.parts[leg[1]], 0, 40)
        local lower = actions.ensureKeepAngle(inst.parts[leg[2]], 0, 40)
        if upper then upper.angle, upper.enabled = thigh, nil end
        if lower then lower.angle, lower.enabled = shin, nil end
    end
end

local function dist(ax, ay, bx, by) return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) end

-- turn these parts rigidly about a point (as characterManager.poseTpose does with arms)
local function turnParts(inst, names, px, py, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, name in ipairs(names) do
        local part = inst.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            local b = part.body
            local x, y = b:getPosition()
            local rx, ry = x - px, y - py
            b:setPosition(px + rx * cs - ry * sn, py + rx * sn + ry * cs)
            b:setAngle(b:getAngle() + delta)
        end
    end
end

local function moveAll(inst, dx, dy)
    for _, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() then
            local px, py = b:getPosition()
            b:setPosition(px + dx, py + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
end

-- A stool as high as a shin plus a foot, and the Mipo put on it already sitting: each leg folded
-- (thigh turned forward about the hip, shin and foot turned back down about the knee), hips just
-- above the seat's front half.
local function seat(inst, dir, x)
    local hx, hy = jointPoint(inst, 'torso1', 'luleg')
    local kx, ky = jointPoint(inst, 'luleg', 'llleg')
    local ax, ay = jointPoint(inst, 'llleg', 'lfoot')
    if not (hx and kx and ax) then return end
    local thigh, shin = dist(hx, hy, kx, ky), dist(kx, ky, ax, ay)
    local foot = math.max(0, GROUND_Y - ay)
    local height = shin + foot
    local width = thigh * 1.2
    local body = love.physics.newBody(world, x - dir * width * 0.25, GROUND_Y - height / 2, 'static')
    love.physics.newFixture(body, love.physics.newRectangleShape(width, height)):setFriction(0.9)
    table.insert(check().stools, body)

    local forward = -dir * math.pi / 2 -- radians: a thigh pointing the way the Mipo faces
    for _, side in ipairs({ 'l', 'r' }) do
        local u, l, f = side .. 'uleg', side .. 'lleg', side .. 'foot'
        local hipX, hipY = jointPoint(inst, 'torso1', u)
        if hipX then
            local delta = forward - inst.parts[u].body:getAngle()
            turnParts(inst, { u, l, f }, hipX, hipY, delta)
            local kneeX, kneeY = jointPoint(inst, u, l)
            turnParts(inst, { l, f }, kneeX, kneeY, -inst.parts[l].body:getAngle())
        end
    end
    local nx, ny = jointPoint(inst, 'torso1', 'luleg')
    moveAll(inst, x - nx, (GROUND_Y - height - thigh * 0.15) - ny)
end

local function sit(on)
    local c = check()
    c.sitting = on
    removeStools()
    for i, inst in pairs(c.mipos) do
        if alive(inst) then
            local side = facing.get(inst)
            walk.hold(inst, on and side ~= 'front')
            if on and side ~= 'front' then
                local dir = side == 'right' and 1 or -1
                seat(inst, dir, xOf(i))
                setLegTargets(inst, -dir * 90, 0) -- degrees (keep-angle): thighs forward, shins down
            else
                setLegTargets(inst, 0, 0)
            end
        end
    end
end

local function makeGround()
    local c = check()
    if getObjectsByLabel('ground')[1] then return end -- the scene's own (soil and grass, saved with it)
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(SPACING * 5, 100)):setFriction(0.9)
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 380)
    check().hold = true
end

function s.onStart()
    worldState.paused = false
    makeGround()
    local c = check()
    local any = false
    for _, inst in pairs(c.mipos) do any = any or alive(inst) end
    if not any then newMipos() else placePatches() end
    lookAtAll()
end

function s.onUnload()
    local c = state.facingSpike
    if not c then return end
    removeStools()
    if c.ground and not c.ground:isDestroyed() then c.ground:destroy() end
    c.ground = nil
end

-- Turning and walking are the engine's now (src/mipo-walk.lua, every Mipo in every scene, MIPO-FACING
-- MF6): this scene turns its Mipos with mipoWalk.turn / turnHead, and its panel sets mipoWalk's
-- switches (lean, hop, rebuild, turning by itself, arms at) and the scene's walking.
local function forAll(fn, dir)
    local c = check()
    if c.sitting then sit(false) end
    for _, inst in pairs(c.mipos) do
        if alive(inst) then fn(inst, dir) end
    end
end

local function turnAll(dir) forAll(walk.turn, dir) end
local function turnHeads(dir) forAll(walk.turnHead, dir) end

-- the follow camera moves the view: hold it on the Mipos until you touch, drag or zoom
function s.update()
    local c = check()
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

local function toggleArms()
    facing.arms = not facing.arms
    local sitting = check().sitting
    rebuildAll()
    sit(sitting)
end

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then newMipos() lookAtAll() end
    if key == 's' then sit(not c.sitting) end
    if key == 'a' then toggleArms() end
    if key == 'left' then turnAll(-1) end
    if key == 'right' then turnAll(1) end
    if key == ',' then turnHeads(-1) end
    if key == '.' then turnHeads(1) end
    if key == 't' then walk.auto = not walk.auto end
    if key == 'j' then walk.hop = not walk.hop end
    if key == 'b' then walk.rebuild = not walk.rebuild end
    if key == 'f' then walk.lean = not walk.lean end
    if key == 'w' then walk.settings().walk = not walk.isOn() end
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'c' then c.patches = not c.patches placePatches() end
end

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 6, 300
    local rows = 19
    local h = BH * rows + pad * (rows + 1) + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• facing ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 24 })
        local x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'a new Mipo (r)') then newMipos() lookAtAll() end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, c.sitting and 'stand (s)' or 'sit (s)') then sit(not c.sitting) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'arms follow: ' .. (facing.arms and 'on' or 'off') .. ' (a)') then toggleArms() end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local half = (w - 12 - pad) / 2
        if ui.button(x, y, half, '< turn') then turnAll(-1) end
        if ui.button(x + half + pad, y, half, 'turn >') then turnAll(1) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, half, '< head (,)') then turnHeads(-1) end
        if ui.button(x + half + pad, y, half, 'head > (.)') then turnHeads(1) end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local autoLabel = 'turning by itself: ' .. (walk.auto and 'on' or 'off') .. ' (t)'
        if ui.button(x, y, w - 12, autoLabel) then walk.auto = not walk.auto end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'hop at the turn: ' .. (walk.hop and 'on' or 'off') .. ' (j)') then
            walk.hop = not walk.hop
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'switch: ' .. (walk.rebuild and 'rebuild all' or 'in place') .. ' (b)') then
            walk.rebuild = not walk.rebuild
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'feet: ' .. (walk.lean and 'lean round' or 'flip') .. ' (f)') then
            walk.lean = not walk.lean
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'autowalk when dragged: ' .. (walk.isOn() and 'on' or 'off') .. ' (w)') then
            walk.settings().walk = not walk.isOn()
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        local v = ui.sliderWithInput('facing-armAt', x, y, 150, 0, 1, walk.armAt, nil, 0.05)
        if v then walk.armAt = v + 0 end
        ui.label(x + 225, y, 'arms at')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'head: ' .. (walk.headKeys and 'keyed' or 'slow drift')) then
            walk.headKeys = not walk.headKeys
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-headTime', x, y, 150, 0.1, 1, walk.headTime, nil, 0.05)
        if v then walk.headTime = v + 0 end
        ui.label(x + 225, y, 'head time')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-headBack', x, y, 150, 0, 4, walk.headBack, nil, 0.1)
        if v then walk.headBack = v + 0 end
        ui.label(x + 225, y, 'overshoot')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-relaxAfter', x, y, 150, 0, 10, walk.relaxAfter, nil, 0.5)
        if v then walk.relaxAfter = v + 0 end
        ui.label(x + 225, y, 'back home after (s)')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-turnBlink', x, y, 150, 0, 1, walk.turnBlink, nil, 0.05)
        if v then walk.turnBlink = v + 0 end
        ui.label(x + 225, y, 'blink on turn')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        if ui.button(x, y, w - 12, 'switch: ' .. (walk.stagger and 'staggered' or 'all at once')) then
            walk.stagger = not walk.stagger
        end
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-earAt', x, y, 150, 0.1, 1, walk.earAt, nil, 0.05)
        if v then walk.earAt = v + 0 end
        ui.label(x + 225, y, 'ears at')
        x, y = ui.nextLayoutPosition(layout, w - 12, BH)
        v = ui.sliderWithInput('facing-armLag', x, y, 150, 0, 0.5, walk.armLag, nil, 0.02)
        if v then walk.armLag = v + 0 end
        ui.label(x + 225, y, 'arms after (s)')
    end)
    love.graphics.setColor(0.95, 0.92, 0.8)
    love.graphics.print('left            front            right', x0 + w + 20, sh - 40, 0, 1.4, 1.4)
    love.graphics.setColor(1, 1, 1)
end

return s
