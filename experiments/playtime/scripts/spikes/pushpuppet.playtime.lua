-- pushpuppet: a vintage thumb-press puppet — press the base and the Mipo goes limp, let go and it snaps up.
-- Vintage toys idea (2026-11-16, Nikki: "help me with some other toys, see what we can mimic"; "y push puppet").
--
-- The real toy: a wooden figure on a drum, strings through its limbs to a button underneath; press the button,
-- the strings slacken and it collapses; let go and it stands again, and pressing on one edge of the button
-- slackens one side only. Here: a real Mipo, feet welded to the top of a painted drum on a table. Its own
-- muscles are off (mipoActions ragdoll, mipoWalk hold); instead every revolute joint gets a motor pulling it
-- to the pose it was built in, as strong as the strings' tension. Tension = 1 - press, per joint: with a
-- tilt, the Mipo's left limbs slacken more than its right (or the other way).
--
-- play mode (tab): hold the drum (or space) to press; while holding, drag left/right (or the arrow keys) to
-- tilt. keys: n a new Mipo   space press   left/right tilt
-- From the bridge: s.status(); s.press(v, tilt) sets the panel's press (0..1) and tilt (-1..1).

local s = {}

local engine = love.filesystem.load('scripts/spikes/humpty-joints.lua')() -- weakKeys (no setmetatable here)

local GROUND_W = 5000
local TABLE_Y = 0                     -- the table top
local LEG_H = 46                      -- the drum stands on three little feet
local BASE_W, BASE_H = 400, 230       -- the drum
local BASE_BOTTOM = TABLE_Y - LEG_H
local BASE_TOP = BASE_BOTTOM - BASE_H

local PP_VERSION = 7 -- what mount() records; a reload with an older one mounts a fresh Mipo

local tune = {
    strength = 2.5, -- the strings' pull: max motor torque in (the weight a joint holds x its lever)
    gain = 10,      -- how quick a joint goes back to its pose (1/s at full tension)
    pressTime = 0.07, -- seconds the press takes to go in / out (the button's travel)
    tiltSide = 1.0, -- how much a tilt adds on one side and takes off the other
    sidePx = 220,   -- a drag this far sideways = full tilt
    freeAt = 0.5,   -- slack past this widens a joint's limits (they come back inside the range)
    widen = 1.3,    -- by this much each way (radians); not the ankles: the feet stay square on the drum
    limp = 0,       -- the share of the strings' pull left when fully pressed
    gather = 1.6,   -- slack strings still pull the torso and head down to the middle of the drum (in weights)
}

local function pp()
    local p = state.pushpuppet
    if not p then
        p = { mipos = {}, pops = {}, press = 0, tilt = 0, manualPress = 0, manualTilt = 0 }
        state.pushpuppet = p
    end
    return p
end

local function isAlive(inst) return mipoKit.isAlive(inst) end

local function partBodies(inst)
    local list = {}
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() then list[#list + 1] = part.body end
    end
    return list
end

-- the lowest point of a body's collision fixtures (sfixtures carry userData and are sensors)
local function lowestY(body)
    local low = -math.huge
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() and f:getUserData() == nil then
            local _, _, _, by = f:getBoundingBox(1)
            low = math.max(low, by)
        end
    end
    return low
end

local function highestY(body)
    local high = math.huge
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() and f:getUserData() == nil then
            local _, ty = f:getBoundingBox(1)
            high = math.min(high, ty)
        end
    end
    return high
end

local function footBody(inst, side)
    for _, name in ipairs({ side .. 'foot', side .. 'lleg', side .. 'uleg' }) do
        local part = inst.parts[name]
        if part and part.body and not part.body:isDestroyed() then return part.body end
    end
end

local function pop(x, y, r, g, b)
    local p = pp()
    p.pops[#p.pops + 1] = { x = x, y = y, t = 0, color = { r, g, b } }
end

-- Which side of the Mipo a joint belongs to: its child part's name ('luarm', 'rlleg', 'lear') — l = -1,
-- r = +1, the middle (neck, head, torso) 0.
local function sideOf(childName)
    local c = childName:sub(1, 1)
    if c == 'l' then return -1 end
    if c == 'r' then return 1 end
    return 0
end

-- the part names under a part, by the Mipo's own joint list ('parent->child')
local function subtree(inst, name, out)
    out = out or {}
    out[name] = true
    for key in pairs(inst.joints or {}) do
        local parent, child = key:match('^(.-)%->(.+)$')
        if parent == name then subtree(inst, child, out) end
    end
    return out
end

-- What a joint's string holds up: the weight on the far side of it times its lever. Out on a limb that's the
-- limb below it (an elbow holds a forearm and hand); with the feet welded, a leg joint holds everything
-- above it instead. One strength for all (sized for the whole Mipo) yanked the hands and shook it.
local function carried(inst, child, joint, lf, rf)
    local below = subtree(inst, child)
    local belowFeet = false
    for name in pairs(below) do
        local b = inst.parts[name] and inst.parts[name].body
        if b == lf or b == rf then belowFeet = true end
    end
    local ax, ay = joint:getAnchors()
    local mass, lever = 0, 0
    for name, part in pairs(inst.parts) do
        local b = part.body
        if b and not b:isDestroyed() and (below[name] and not belowFeet or not below[name] and belowFeet) then
            mass = mass + b:getMass()
            local x, y = b:getPosition()
            lever = math.max(lever, math.sqrt((x - ax) ^ 2 + (y - ay) ^ 2))
        end
    end
    return mass * math.max(lever, 1)
end

-- Put a new Mipo on the drum: feet on its top, welded there, its pose remembered, its own muscles off.
local function mount(p, inst)
    local lf, rf = footBody(inst, 'l'), footBody(inst, 'r')
    if not (lf and rf) then return false end
    -- feet onto the drum top
    local dy = BASE_TOP - math.max(lowestY(lf), lowestY(rf))
    local tx = inst.parts.torso1.body:getPosition()
    for _, body in ipairs(partBodies(inst)) do
        local x, y = body:getPosition()
        body:setPosition(x - tx, y + dy)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
    for _, foot in ipairs({ lf, rf }) do
        local fx = foot:getPosition()
        love.physics.newWeldJoint(p.ground, foot, fx, BASE_TOP, false)
    end
    mipoActions.setRagdoll(inst, true)
    mipoWalk.hold(inst, true)
    -- the strings: each revolute joint and its rest angle
    local strings = {}
    local mass = 0
    for _, body in ipairs(partBodies(inst)) do mass = mass + body:getMass() end
    local top = math.huge
    for _, body in ipairs(partBodies(inst)) do top = math.min(top, highestY(body)) end
    local tx0 = inst.parts.torso1.body:getX()
    for key, id in pairs(inst.joints or {}) do
        local joint = registry.getJointByID(id)
        local child = key:match('%->(.+)$') or key
        -- the hands dangle: light, on a strong string they twitched without end
        if joint and not joint:isDestroyed() and joint:getType() == 'revolute' and not child:find('hand') then
            local side = sideOf(child)
            local part = inst.parts[child]
            if part and part.body and side ~= 0 then
                side = (part.body:getX() < tx0) and -1 or 1
            end
            strings[#strings + 1] = { joint = joint, rest = joint:getJointAngle(), side = side, name = key,
                ankle = key:find('foot') ~= nil, carry = carried(inst, child, joint, lf, rf),
                limits = joint:areLimitsEnabled(), lower = joint:getLowerLimit(), upper = joint:getUpperLimit() }
        end
    end
    inst._pp = { strings = strings, mass = mass, height = BASE_TOP - top, version = PP_VERSION }
    return true
end

local function destroyMipos(p)
    for _, inst in ipairs(p.mipos) do
        if isAlive(inst) then
            for _, body in ipairs(partBodies(inst)) do objectManager.destroyBody(body) end
        end
    end
    p.mipos = {}
end

local function newPuppet(p)
    destroyMipos(p)
    local inst = mipoKit.spawn(p.mipos, 0, BASE_TOP - 500)
    if inst and not mount(p, inst) then destroyMipos(p) end
end

local function makeGround(p)
    if p.ground and not p.ground:isDestroyed() then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, GROUND_W / 2, TABLE_Y))
    top:setFriction(0.9)
    local drum = love.physics.newFixture(p.ground,
        love.physics.newRectangleShape(0, (BASE_TOP + BASE_BOTTOM) / 2, BASE_W, BASE_H))
    drum:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, TABLE_Y, GROUND_W / 2, -3000))
    state.hiddenBodies = state.hiddenBodies or engine.weakKeys()
    state.hiddenBodies[p.ground] = true
end

function s.onStart()
    worldState.paused = false
    local p = pp()
    makeGround(p)
    p.mipos = mipoKit.alive(p.mipos)
    -- a script reload keeps the Mipo, but its welds went with the old ground: start a fresh one
    local stale = p.mipos[1] and not (p.mipos[1]._pp and p.mipos[1]._pp.version == PP_VERSION)
    if #p.mipos == 0 or p.remount or stale then newPuppet(p) end
    p.remount = nil
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 600)
end

function s.onUnload()
    local p = state.pushpuppet
    if p and p.ground and not p.ground:isDestroyed() then p.ground:destroy() end
    if p then
        p.ground = nil
        p.remount = true
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    if key == 'n' then newPuppet(pp()) end
end

local function overDrum(x, y)
    return x > -BASE_W / 2 - 40 and x < BASE_W / 2 + 40 and y > BASE_TOP - 20 and y < TABLE_Y + 40
end

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

-- The press and tilt wanted this frame: the pointer on the drum, space and the arrows, or the panel's.
local function wanted(p)
    local mx, my = mouseWorldPos()
    local down = state.playMode and love.mouse.isDown(1)
    if down and not p.pointerWas then
        p.holding = overDrum(mx, my) and not overPanel()
        p.holdX = mx
    elseif not down then
        p.holding = false
    end
    p.pointerWas = down
    local press, tilt = p.manualPress, p.manualTilt
    if p.holding then
        press = 1
        tilt = math.max(-1, math.min(1, (mx - p.holdX) / tune.sidePx))
    end
    if state.playMode and love.keyboard.isDown('space') then press = 1 end
    if state.playMode and love.keyboard.isDown('left') then tilt = -1 end
    if state.playMode and love.keyboard.isDown('right') then tilt = 1 end
    return press, tilt
end

local function pullStrings(inst, press, tilt)
    local pd = inst._pp
    if not pd then return end
    local _, gy = world:getGravity()
    for _, st in ipairs(pd.strings) do
        local joint = st.joint
        if not joint:isDestroyed() then
            -- side: -1 a part left of the torso on screen, +1 right; tilt -1 slackens the left side
            local slack = press
            if st.side ~= 0 then slack = press * (1 + tilt * st.side * tune.tiltSide) end
            local tension = 1 - math.max(0, math.min(1, slack))
            -- the Mipo's joint limits brace its legs (feet welded, it couldn't fold): widened by tune.widen
            -- while slack (a heap, not a full spin), narrowed back once the strings have pulled the joint
            -- inside its own range again
            if st.limits and not st.ankle then
                local angle = joint:getJointAngle()
                if slack > tune.freeAt and not st.widened then
                    joint:setLimits(st.lower - tune.widen, st.upper + tune.widen)
                    st.widened = true
                elseif slack < tune.freeAt and st.widened and angle >= st.lower and angle <= st.upper then
                    joint:setLimits(st.lower, st.upper)
                    st.widened = nil
                end
            end
            local err = st.rest - joint:getJointAngle()
            local speed = math.max(-30, math.min(30, tune.gain * err))
            joint:setMotorEnabled(true)
            joint:setMotorSpeed(speed)
            joint:setMaxMotorTorque(tune.strength * st.carry * math.abs(gy) * math.max(tune.limp, tension * tension))
        end
    end
end

-- The strings run through the Mipo down into the drum: slack, they still drag it down to the middle of the
-- drum top, so it slumps onto the drum instead of toppling off it whole.
local function gather(inst, press)
    if press < 0.05 then return end
    local _, gy = world:getGravity()
    for _, name in ipairs({ 'torso1', 'head' }) do
        local part = inst.parts[name]
        local body = part and part.body
        if body and not body:isDestroyed() then
            local x, y = body:getPosition()
            local dx, dy = -x, BASE_TOP - y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            local f = tune.gather * press * (inst._pp and inst._pp.mass or body:getMass()) * math.abs(gy) * 0.5
            local vx = body:getLinearVelocity()
            body:applyForce(f * dx / d - vx * body:getMass() * 2, f * dy / d)
        end
    end
end

-- the Mipo's face and voice: collapsing (oof), and standing up again after a real press (happy)
local function react(p, inst)
    local was = p.lastPress or 0
    if p.press > 0.6 and was <= 0.6 then
        mipoVoice.squeak(inst, 'oof')
        mipoEmotion.set(inst, 'surprised', 1, 0.8)
        p.downAt = love.timer.getTime()
    elseif p.press < 0.2 and was >= 0.2 and p.downAt and love.timer.getTime() - p.downAt > 0.2 then
        mipoVoice.squeak(inst, 'happy')
        mipoEmotion.set(inst, 'happy', 1, 1.5)
        pop(0, BASE_TOP - (inst._pp and inst._pp.height or 600) - 60, 1, 0.85, 0.3)
        p.downAt = nil
        p.snaps = (p.snaps or 0) + 1
    end
    p.lastPress = p.press
end

function s.update(dt)
    local p = pp()
    local press, tilt = wanted(p)
    local k = math.min(1, dt / tune.pressTime)
    p.press = p.press + (press - p.press) * k
    p.tilt = p.tilt + (tilt - p.tilt) * k
    for _, inst in ipairs(p.mipos) do
        if isAlive(inst) then
            pullStrings(inst, p.press, p.tilt)
            gather(inst, p.press)
            react(p, inst)
        end
    end
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > 0.45 then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local WALL = { 0.93, 0.87, 0.74 }
local WALL_DOT = { 0.87, 0.78, 0.62 }
local TABLE = { 0.62, 0.42, 0.26 }
local TABLE_EDGE = { 0.47, 0.30, 0.18 }
local RED = { 0.80, 0.22, 0.17 }
local RED_DARK = { 0.58, 0.14, 0.11 }
local YELLOW = { 0.96, 0.76, 0.22 }
local CREAM = { 0.95, 0.89, 0.75 }
local WOOD = { 0.80, 0.62, 0.40 }
local INK = { 0.28, 0.17, 0.12 }
local BLUE = { 0.24, 0.47, 0.72 }

function s.drawBelow()
    -- wallpaper with little dots, a table with a front edge
    setc(WALL)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + TABLE_Y)
    setc(WALL_DOT)
    for y = -2900, TABLE_Y - 60, 160 do
        for x = -GROUND_W / 2 + 40, GROUND_W / 2, 160 do
            local off = (math.floor(y / 160) % 2) * 80
            love.graphics.circle('fill', x + off, y, 10)
        end
    end
    setc(TABLE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y, GROUND_W, 120)
    setc(TABLE_EDGE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y + 120, GROUND_W, 600)

    local p = state.pushpuppet
    local press = p and p.press or 0
    local tilt = p and p.tilt or 0
    local x0, x1 = -BASE_W / 2, BASE_W / 2
    -- the button underneath: a round wooden knob, pushed up into the drum (and tipped) by the press
    local knobY = BASE_BOTTOM + 30 - press * 26
    love.graphics.push()
    love.graphics.translate(0, knobY)
    love.graphics.rotate(tilt * 0.18 * press)
    setc(INK)
    love.graphics.ellipse('fill', 0, 0, 92, 34)
    setc(WOOD)
    love.graphics.ellipse('fill', 0, -4, 84, 27)
    setc(CREAM, 0.6)
    love.graphics.ellipse('fill', -24, -12, 30, 8)
    love.graphics.pop()
    -- three little feet
    setc(INK)
    for _, fx in ipairs({ x0 + 30, 0, x1 - 30 }) do
        if fx ~= 0 then love.graphics.rectangle('fill', fx - 22, BASE_BOTTOM, 44, LEG_H, 8, 8) end
    end
    setc(WOOD)
    for _, fx in ipairs({ x0 + 30, x1 - 30 }) do
        love.graphics.rectangle('fill', fx - 16, BASE_BOTTOM, 32, LEG_H - 6, 6, 6)
    end
    -- the drum: red body, a yellow band with blue dots, a cream rim on top, bottom rim
    setc(INK)
    love.graphics.rectangle('fill', x0 - 8, BASE_TOP - 8, BASE_W + 16, BASE_H + 16, 18, 18)
    setc(RED)
    love.graphics.rectangle('fill', x0, BASE_TOP, BASE_W, BASE_H, 12, 12)
    setc(RED_DARK)
    love.graphics.rectangle('fill', x1 - 70, BASE_TOP + 10, 56, BASE_H - 20, 10, 10)
    setc(CREAM, 0.35)
    love.graphics.rectangle('fill', x0 + 18, BASE_TOP + 22, 26, BASE_H - 44, 10, 10)
    local bandY = BASE_TOP + BASE_H * 0.42
    setc(YELLOW)
    love.graphics.rectangle('fill', x0, bandY, BASE_W, 52)
    setc(BLUE)
    for i = 0, 6 do love.graphics.circle('fill', x0 + 30 + i * (BASE_W - 60) / 6, bandY + 26, 11) end
    setc(CREAM)
    love.graphics.rectangle('fill', x0 - 14, BASE_TOP - 14, BASE_W + 28, 34, 14, 14)
    setc(INK)
    love.graphics.setLineWidth(5)
    love.graphics.rectangle('line', x0 - 14, BASE_TOP - 14, BASE_W + 28, 34, 14, 14)
    setc(WOOD)
    love.graphics.rectangle('fill', x0 - 10, BASE_BOTTOM - 26, BASE_W + 20, 26, 10, 10)
    setc(INK)
    love.graphics.rectangle('line', x0 - 10, BASE_BOTTOM - 26, BASE_W + 20, 26, 10, 10)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local p = state.pushpuppet
    if not p then return end
    for _, q in ipairs(p.pops) do
        local k = q.t / 0.45
        love.graphics.setColor(q.color[1], q.color[2], q.color[3], 1 - k)
        love.graphics.setLineWidth(10 * (1 - k) + 1)
        love.graphics.circle('line', q.x, q.y, 40 + 200 * k)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.pushpuppet
    if not (p and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 6
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• push puppet ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'a new Mipo (n)') then newPuppet(p) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('pppress', x, y, 150, 0, 1, p.manualPress, nil, 0.01)
        if v then p.manualPress = v end
        ui.label(x + 250, y, 'press')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('pptilt', x, y, 150, -1, 1, p.manualTilt, nil, 0.01)
        if v then p.manualTilt = v end
        ui.label(x + 250, y, 'tilt')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('ppstrength', x, y, 150, 0.1, 4, tune.strength, nil, 0.01)
        if v then tune.strength = v end
        ui.label(x + 250, y, 'strings')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('ppgain', x, y, 150, 2, 40, tune.gain, nil, 0.1)
        if v then tune.gain = v end
        ui.label(x + 250, y, 'snap')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'hold the drum; drag sideways to tilt')
    end)
end

-- From the bridge
function s.status()
    local p = pp()
    local inst = p.mipos[1]
    if not isAlive(inst) then return 'none' end
    local hx, hy = (inst.parts.head and inst.parts.head.body or inst.parts.torso1.body):getPosition()
    local err, errs = 0, {}
    for _, st in ipairs(inst._pp and inst._pp.strings or {}) do
        if not st.joint:isDestroyed() then
            local e = math.abs(st.rest - st.joint:getJointAngle())
            err = math.max(err, e)
            if e > 0.35 then errs[st.name] = math.floor(math.deg(e)) end
        end
    end
    return { press = p.press, tilt = p.tilt, headX = math.floor(hx), headY = math.floor(hy),
        worstJointErrDeg = math.floor(math.deg(err)), strings = inst._pp and #inst._pp.strings or 0,
        snaps = p.snaps or 0, off = errs }
end

function s.press(v, tilt)
    local p = pp()
    p.manualPress = v or 0
    p.manualTilt = tilt or 0
end

return s
