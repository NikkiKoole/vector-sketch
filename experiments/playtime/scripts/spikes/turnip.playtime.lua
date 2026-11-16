-- turnip: the Enormous Turnip (STORY-IDEAS.md) — Mipos hold on to each other in a chain and pull until it pops.
-- A big turnip half in the ground, held there by a motor joint with a hold force: pulled harder than that, it
-- slides up out of the earth, and once it's come far enough the hold lets go (pop), the turnip jumps out and the
-- pullers tumble over backwards. One Mipo holds the leaves at the start; the others wait at the side.
-- Drop a Mipo with its hands near the last one in the chain (or the leaves) and it holds on. While you drag a
-- Mipo of the chain (or with 'pull' on), every one in the chain leans back and pulls; your own drag on it is kept
-- to about one Mipo's pull, so one Mipo can't do it alone and three can.
--
-- play mode (tab): drag Mipos. keys: p pull on/off   r reset   m a Mipo at the mouse

local s = {}

local GROUND_Y = 0
local TURNIP_X = 250
local R = 230                -- the bulb's radius
local SINK = 40              -- the bulb's centre this far below the ground line
local GRAB_D = 170           -- a hand this close to a hold takes it
local GROUND_CAT = 2         -- the ground's collision category (the buried turnip doesn't touch it)

local tune = {
    lean = 0.55,             -- a Mipo's pull, as a share of its weight
    need = 2.8,              -- Mipos pulling (your drag counts as 'kid') before the earth gives: 3, not 2 + you
    kid = 0.7,               -- your drag on a chain Mipo, in Mipo pulls at most
    popAt = 110,             -- how far up it slides before the hold lets go
    leanAngle = 0.35,        -- how far the pullers lean back (radians)
}

local function st()
    state.turnip = state.turnip or { mipos = {}, chain = {}, grips = {}, pulling = false }
    return state.turnip
end

local function alive(body) return body and not body:isDestroyed() end

-- one Mipo's weight and its pull
local function weightOf(inst)
    local m = 0
    for _, part in pairs(inst.parts) do
        if alive(part.body) then m = m + part.body:getMass() end
    end
    local _, gy = world:getGravity()
    return m * gy
end

local function leanUnit(t)
    local w, n = 0, 0
    for _, inst in ipairs(mipoKit.alive(t.mipos)) do
        w, n = w + weightOf(inst), n + 1
    end
    return n > 0 and (w / n) * tune.lean or 1
end

local function destroyTurnip(t)
    for _, key in ipairs({ 'hold', 'stem' }) do
        if t[key] and not t[key]:isDestroyed() then t[key]:destroy() end
        t[key] = nil
    end
    for _, key in ipairs({ 'leaves', 'bulb', 'ground' }) do
        if t[key] and state.hiddenBodies then state.hiddenBodies[t[key]] = nil end
        if alive(t[key]) then t[key]:destroy() end
        t[key] = nil
    end
end

local function makeTurnip(t)
    t.ground = love.physics.newBody(world, 0, 0, 'static')
    local floor = love.physics.newFixture(t.ground,
        love.physics.newChainShape(false, -4000, GROUND_Y - 3000, -4000, GROUND_Y, 4000, GROUND_Y, 4000, GROUND_Y - 3000))
    floor:setFriction(0.9)
    floor:setCategory(GROUND_CAT)

    local cy = GROUND_Y + SINK
    t.bulb = love.physics.newBody(world, TURNIP_X, cy, 'dynamic')
    local f1 = love.physics.newFixture(t.bulb, love.physics.newCircleShape(R), 1)
    local f2 = love.physics.newFixture(t.bulb, love.physics.newPolygonShape(-70, R * 0.7, 70, R * 0.7, 0, R + 180), 1)
    for _, f in ipairs({ f1, f2 }) do
        f:setMask(GROUND_CAT)
        f:setFriction(0.8)
    end
    -- the leaves: something to hold, a stalk on a hinge that bends a little; not in the way of the Mipos
    t.leaves = love.physics.newBody(world, TURNIP_X, cy - R - 170, 'dynamic')
    local lf = love.physics.newFixture(t.leaves, love.physics.newRectangleShape(60, 340), 0.3)
    lf:setSensor(true)
    t.stem = love.physics.newRevoluteJoint(t.bulb, t.leaves, TURNIP_X, cy - R + 10, false)
    t.stem:setLimits(-0.5, 0.5)
    t.stem:setLimitsEnabled(true)
    -- the earth's hold: a motor joint that keeps the bulb where it is with at most the hold force
    t.hold = love.physics.newMotorJoint(t.ground, t.bulb, 0.3, false)
    t.hold:setMaxTorque(1e9)
    t.popped, t.flying, t.rootIn = false, nil, nil
    t.home = { TURNIP_X, cy }
    -- drawn by this script, not as plain grey shapes (src/physics/box2d-draw.lua showsBody)
    state.hiddenBodies = state.hiddenBodies or {} -- (taken out again in destroyTurnip)
    state.hiddenBodies[t.bulb], state.hiddenBodies[t.leaves], state.hiddenBodies[t.ground] = true, true, true
end

local function setLean(inst, angle)
    local torso = inst.parts.torso1
    local keep = mipoActions.getKeepAngle(torso)
    if keep then keep.angle = angle end
end

local function clearGrips(t)
    for _, g in ipairs(t.grips) do
        if g.joint and not g.joint:isDestroyed() then g.joint:destroy() end
    end
    t.grips = {}
    for _, inst in ipairs(t.chain) do
        if mipoKit.isAlive(inst) then setLean(inst, 0) end
    end
    t.chain = {}
end

-- both hands onto a point on `body`
local function holdOn(t, inst, body, px, py)
    for _, name in ipairs({ 'lhand', 'rhand' }) do
        local h = inst.parts[name]
        if h and alive(h.body) then
            h.body:setPosition(px, py)
            h.body:setLinearVelocity(body:getLinearVelocity())
            t.grips[#t.grips + 1] = { joint = love.physics.newRevoluteJoint(body, h.body, px, py, false), inst = inst }
        end
    end
    t.chain[#t.chain + 1] = inst
    mipoVoice.squeak(inst, 'pickup')
end

-- where the next one holds: the leaves, or the last one in the chain's torso (its back, away from the turnip)
local function nextHold(t)
    local last = t.chain[#t.chain]
    if not last then
        local x, y = t.leaves:getWorldPoint(0, -60)
        return t.leaves, x, y
    end
    local torso = last.parts.torso1.body
    local x, y = torso:getPosition()
    return torso, x + 60, y
end

local function inChain(t, inst)
    for _, c in ipairs(t.chain) do if c == inst then return true end end
    return false
end

local function heldBodies()
    local held = {}
    for _, b in ipairs(getInteractedWithPointer()) do held[b] = true end
    return held
end

local function isHeld(inst, held)
    for _, part in pairs(inst.parts) do
        if part.body and held[part.body] then return true end
    end
    return false
end

-- a Mipo not in the chain and not held, with a hand near the next hold, holds on
local function joinChain(t, held)
    if t.popped then return end
    local body, px, py = nextHold(t)
    if not alive(body) then return end
    for _, inst in ipairs(mipoKit.alive(t.mipos)) do
        if not inChain(t, inst) and not isHeld(inst, held) then
            for _, name in ipairs({ 'lhand', 'rhand' }) do
                local h = inst.parts[name]
                if h and alive(h.body) then
                    local hx, hy = h.body:getPosition()
                    if (hx - px) ^ 2 + (hy - py) ^ 2 < GRAB_D * GRAB_D then
                        holdOn(t, inst, body, px, py)
                        return
                    end
                end
            end
        end
    end
end

local function pop(t)
    if t.hold and not t.hold:isDestroyed() then t.hold:destroy() end
    t.hold = nil
    t.popped = true
    t.flying = true -- it touches the ground again once its centre is above it (update): below, it fell through
    local m = t.bulb:getMass()
    t.bulb:applyLinearImpulse(m * 500, -m * 1700)
    t.bulb:applyAngularImpulse(t.bulb:getInertia() * 4)
    camera.shake(25, 0.5)
    for _, inst in ipairs(t.chain) do
        if mipoKit.isAlive(inst) then
            setLean(inst, 0)
            mipoVoice.squeak(inst, 'oof')
        end
    end
end

local function spawnAll(t)
    t.mipos = {}
    mipoKit.spawn(t.mipos, TURNIP_X + 450, GROUND_Y - 500)
    for k = 1, 4 do mipoKit.spawn(t.mipos, TURNIP_X + 1000 + k * 330, GROUND_Y - 500) end
end

local function reset(t)
    clearGrips(t)
    destroyTurnip(t)
    for _, inst in ipairs(mipoKit.alive(t.mipos)) do
        for _, part in pairs(inst.parts) do
            if alive(part.body) then objectManager.destroyBody(part.body) end
        end
    end
    makeTurnip(t)
    spawnAll(t)
    t.firstHoldAt = love.timer.getTime() + 1.2 -- the first one takes the leaves once it has landed
end

function s.onStart()
    worldState.paused = false
    local t = st()
    if not alive(t.bulb) then
        clearGrips(t)
        destroyTurnip(t)
        makeTurnip(t)
    end
    t.mipos = mipoKit.alive(t.mipos)
    if #t.mipos == 0 then
        spawnAll(t)
        t.firstHoldAt = love.timer.getTime() + 1.2
    end
    camera.setBounds(-3200, -2600, 4400, 900)
end

function s.onUnload()
    local t = state.turnip
    if not t then return end
    clearGrips(t)
    destroyTurnip(t)
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local t = st()
    if key == 'p' then t.pulling = not t.pulling
    elseif key == 'r' then reset(t)
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(t.mipos, mx, my)
    end
end

function s.update()
    local t = st()
    if not alive(t.bulb) then return end
    local held = heldBodies()
    -- the first Mipo walks... well, is put on the leaves
    if t.firstHoldAt and love.timer.getTime() > t.firstHoldAt then
        t.firstHoldAt = nil
        local first = t.mipos[1]
        if first and mipoKit.isAlive(first) and #t.chain == 0 then
            local body, px, py = nextHold(t)
            holdOn(t, first, body, px, py)
        end
    end
    joinChain(t, held)

    -- pulling: while you drag one of the chain (or 'pull' is on)
    local unit = leanUnit(t)
    local dragging = false
    for _, inst in ipairs(t.chain) do
        if mipoKit.isAlive(inst) and isHeld(inst, held) then
            dragging = true
            for _, part in pairs(inst.parts) do
                local pj = part.body and held[part.body] and getPJAttachedTo(part.body)
                if pj and pj.joint and not pj.joint:isDestroyed() then pj.joint:setMaxForce(unit * tune.kid) end
            end
        end
    end
    local pulling = (dragging or t.pulling) and not t.popped
    for _, inst in ipairs(t.chain) do
        if mipoKit.isAlive(inst) then
            local torso = inst.parts.torso1.body
            setLean(inst, pulling and tune.leanAngle or 0)
            if pulling then torso:applyForce(unit, 0) end
        end
    end

    if t.flying then
        local _, y = t.bulb:getPosition()
        if y < GROUND_Y - 20 then -- the round part touches the ground again: pushed up out of it (the root never does)
            t.flying = nil
            t.rootIn = true
            for _, f in ipairs(t.bulb:getFixtures()) do
                if f:getShape():getType() == 'circle' then f:setMask() end
            end
        end
    elseif t.rootIn then -- and the root once its tip is out too: from then on it's a body like any other
        local _, tipY = t.bulb:getWorldPoint(0, R + 180)
        if tipY < GROUND_Y - 5 then
            t.rootIn = nil
            for _, f in ipairs(t.bulb:getFixtures()) do f:setMask() end
        end
    end
    -- the earth's hold, and the pop once it's come far enough
    if t.hold and not t.hold:isDestroyed() then
        -- How many pull (your drag counts as part of one) decides it: the pull through the chain also depends
        -- on how well each Mipo's feet grip, so measured it gave 2 Mipos one time and 4 another. Not enough:
        -- the earth holds firm and the turnip shivers, more the closer it is; enough: it gives, and the
        -- chain drags it out.
        local _, gy = world:getGravity()
        local count = 0
        for _, inst in ipairs(t.chain) do
            if mipoKit.isAlive(inst) then count = count + 1 end
        end
        t.count = pulling and (count + (dragging and tune.kid or 0)) or 0
        local gives = t.count >= tune.need
        t.hold:setMaxForce(unit * (gives and 0.6 or tune.need + 3) + t.bulb:getMass() * gy)
        if pulling and not gives then
            local shiver = math.min(1, t.count / tune.need) ^ 2
            t.bulb:applyAngularImpulse(t.bulb:getInertia() * shiver * 0.5 * math.sin(love.timer.getTime() * 40))
        end
        local x, y = t.bulb:getPosition()
        t.moved = math.sqrt((x - t.home[1]) ^ 2 + (y - t.home[2]) ^ 2)
        if t.moved > tune.popAt then pop(t) end
    end
end

-- the turnip: cream below, purple on top, leaves; the earth drawn over its buried half
local function drawTurnip(t)
    local b = t.bulb
    love.graphics.push()
    love.graphics.translate(b:getPosition())
    love.graphics.rotate(b:getAngle())
    love.graphics.setColor(0.93, 0.9, 0.82)
    love.graphics.polygon('fill', -70, R * 0.7, 70, R * 0.7, 0, R + 180)
    love.graphics.circle('fill', 0, 0, R)
    love.graphics.setColor(0.55, 0.25, 0.55)
    love.graphics.arc('fill', 0, 0, R, math.pi * 1.05, math.pi * 1.95)
    love.graphics.ellipse('fill', 0, -R * 0.2, R * 0.98, R * 0.55)
    love.graphics.setColor(0.25, 0.15, 0.25)
    love.graphics.setLineWidth(6)
    love.graphics.circle('line', 0, 0, R)
    love.graphics.pop()
    local l = t.leaves
    if alive(l) then
        love.graphics.push()
        love.graphics.translate(l:getPosition())
        love.graphics.rotate(l:getAngle())
        love.graphics.setColor(0.3, 0.6, 0.25)
        for k = -1, 1 do
            love.graphics.ellipse('fill', k * 50, -40 - math.abs(k) * 20, 45, 150)
        end
        love.graphics.setColor(0.2, 0.45, 0.18)
        love.graphics.rectangle('fill', -12, -60, 24, 240)
        love.graphics.pop()
    end
    love.graphics.setLineWidth(1)
end

function s.drawBelow()
    local t = state.turnip
    if not (t and alive(t.bulb)) then return end
    love.graphics.setColor(0.86, 0.92, 0.95)
    love.graphics.rectangle('fill', -4000, GROUND_Y - 3000, 8000, 3000)
    drawTurnip(t)
    love.graphics.setColor(1, 1, 1)
end

function s.draw()
    local t = state.turnip
    if not (t and alive(t.bulb)) then return end
    -- the earth, over the buried half
    love.graphics.setColor(0.45, 0.32, 0.22)
    love.graphics.rectangle('fill', -4000, GROUND_Y, 8000, 1200)
    love.graphics.setColor(0.36, 0.55, 0.25)
    love.graphics.rectangle('fill', -4000, GROUND_Y, 8000, 26)
    if not t.popped then -- a crack in the earth around the turnip, wider as it comes up
        local open = math.min(1, (t.moved or 0) / tune.popAt)
        love.graphics.setColor(0.25, 0.17, 0.12)
        love.graphics.ellipse('fill', TURNIP_X, GROUND_Y + 14, R * (0.9 + 0.25 * open), 16 + 30 * open)
    end
    love.graphics.setColor(1, 1, 1)
end

function s.drawUI()
    local t = state.turnip
    if not (t and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = 6
    local h = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• turnip ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local used, on = ui.toggleButton(x, y, w - 20, BH, 'pulling', 'pull', t.pulling)
        if used then t.pulling = on end
        for _, row in ipairs({ { 'need', 0.5, 6 }, { 'lean', 0.1, 1.5 }, { 'kid', 0, 3 } }) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('turnip' .. row[1], x, y, 140, row[2], row[3], tune[row[1]])
            if v then tune[row[1]] = v + 0 end
            ui.label(x + 240, y, row[1])
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (r)') then reset(t) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('chain %d  pulling %.1f / %.1f  up %d', #t.chain, t.count or 0, tune.need,
            math.floor(t.moved or 0)))
    end)
end

return s
