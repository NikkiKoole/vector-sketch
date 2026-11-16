-- humpty: Humpty Dumpty — an egg-shaped Mipo on a wall falls off, breaks apart, and you put him back together.
-- Story idea from docs/STORY-IDEAS.md (verb: fall, put back together).
--
-- A pear-bodied Mipo (the rubberleg-pearbod breed: the body is the head, an egg) stands on a brick wall.
-- Drag him off (or drop him from high up): a hard landing (the torso's speed drops by more than a fall from
-- `breakHeight` gives) breaks his shoulder, hip and neck joints, and the arms and legs tumble off whole.
-- Putting him back: drag a piece (or the body) so the piece's joint end comes near where it belongs: it clicks
-- back on, the joint made again with the engine's own createJoint (same id, anchors, limits, motor), so
-- the Mipo systems (joint guard, walking, drawing) go on as before. All back on: a happy squeak.
--
-- play mode (tab): drag him around. keys: b break him now   r back on the wall, whole   n a new Humpty

local s = {}

local engine = love.filesystem.load('scripts/spikes/humpty-joints.lua')()
local joints = engine.joints

local WALL_W, WALL_H = 520, 760          -- the wall, standing on the ground at y = 0
local GROUND_W = 6000
local BREAKS = { 'torso1->luarm', 'torso1->ruarm', 'torso1->luleg', 'torso1->ruleg', 'torso1->head' }

local tune = { breakHeight = 450, snapDist = 170, scatter = 350 }

local function humpty()
    local h = state.humpty
    if not h then
        h = { mipos = {}, pops = {} }
        state.humpty = h
    end
    return h
end

local function isAlive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

-- the parts under a part, by the Mipo's own joint list ('parent->child' = id)
local function subtree(inst, name, out)
    out = out or {}
    out[#out + 1] = name
    for key in pairs(inst.joints or {}) do
        local parent, child = key:match('^(.-)%->(.+)$')
        if parent == name then subtree(inst, child, out) end
    end
    return out
end

local function bodiesOf(inst, names)
    local list = {}
    for _, name in ipairs(names) do
        local part = inst.parts[name]
        if part and part.body and not part.body:isDestroyed() then list[#list + 1] = part.body end
    end
    return list
end

local function heldBodies()
    local held = {}
    for _, body in ipairs(getInteractedWithPointer()) do held[body] = true end
    return held
end

local function pop(x, y, r, g, b)
    local h = humpty()
    h.pops[#h.pops + 1] = { x = x, y = y, t = 0, color = { r, g, b } }
end

-- Break: record what each joint is (bodies, anchors in their own frames, limits, motor, id), then destroy it.
local function breakApart(inst)
    local h = humpty()
    inst.humptyBroken = inst.humptyBroken or {}
    local torso = inst.parts.torso1.body
    local tx, ty = torso:getPosition()
    local any = false
    for _, key in ipairs(BREAKS) do
        local id = inst.joints and inst.joints[key]
        local joint = id and registry.getJointByID(id)
        if joint and not joint:isDestroyed() and not inst.humptyBroken[key] then
            local bodyA, bodyB = joint:getBodies()
            local ax, ay, bx, by = joint:getAnchors()
            local lax, lay = bodyA:getLocalPoint(ax, ay)
            local lbx, lby = bodyB:getLocalPoint(bx, by)
            local ud = joint:getUserData() or {}
            local data = {
                jointType = joint:getType(), id = id, label = ud.label, scriptmeta = ud.scriptmeta,
                collideConnected = joint:getCollideConnected(),
                motorEnabled = joint:isMotorEnabled(), motorSpeed = joint:getMotorSpeed(),
                maxMotorTorque = joint:getMaxMotorTorque(), limitsEnabled = joint:areLimitsEnabled(),
                lowerLimit = joint:getLowerLimit(), upperLimit = joint:getUpperLimit(),
                referenceAngle = joint:getReferenceAngle(),
            }
            local parentName, childName = key:match('^(.-)%->(.+)$')
            inst.humptyBroken[key] = {
                data = data, bodyA = bodyA, bodyB = bodyB, la = { lax, lay }, lb = { lbx, lby },
                parent = parentName, child = childName, at = love.timer.getTime(),
            }
            joint:destroy()
            registry.unregisterJoint(id)
            any = true
            -- the piece tumbles away from the body
            for _, body in ipairs(bodiesOf(inst, subtree(inst, childName))) do
                local px, py = body:getPosition()
                local dx, dy = px - tx, py - ty
                local d = math.max(1, math.sqrt(dx * dx + dy * dy))
                local m = body:getMass()
                body:applyLinearImpulse(dx / d * tune.scatter * m, (dy / d - 0.8) * tune.scatter * m)
                body:applyAngularImpulse((random() - 0.5) * m * 2000)
            end
        end
    end
    if any then
        mipoVoice.squeak(inst, 'oof')
        mipoEmotion.set(inst, 'scared', 1, 2.5)
        pop(tx, ty, 1, 0.9, 0.4)
        h.breaks = (h.breaks or 0) + 1
    end
end

local function brokenCount(inst)
    local n = 0
    for _ in pairs(inst.humptyBroken or {}) do n = n + 1 end
    return n
end

-- Put one piece back: turn and move the piece's whole subtree so its joint end lands on the body's, and its
-- angle is the joint's rest angle; then make the joint again.
local function rejoin(inst, key)
    local rec = inst.humptyBroken[key]
    local parentIsA = inst.parts[rec.parent].body == rec.bodyA
    local parentBody = parentIsA and rec.bodyA or rec.bodyB
    local childBody = parentIsA and rec.bodyB or rec.bodyA
    local lp = parentIsA and rec.la or rec.lb
    local lc = parentIsA and rec.lb or rec.la
    local tx, ty = parentBody:getWorldPoint(lp[1], lp[2])
    local cx, cy = childBody:getWorldPoint(lc[1], lc[2])
    -- the angle the child has at the joint's rest: bodyB = bodyA + referenceAngle
    local ref = rec.data.referenceAngle
    local goal = parentIsA and (parentBody:getAngle() + ref) or (parentBody:getAngle() - ref)
    local d = goal - childBody:getAngle()
    local cosd, sind = math.cos(d), math.sin(d)
    local vx, vy = parentBody:getLinearVelocity()
    for _, body in ipairs(bodiesOf(inst, subtree(inst, rec.child))) do
        local px, py = body:getPosition()
        local rx, ry = px - cx, py - cy
        body:setPosition(tx + rx * cosd - ry * sind, ty + rx * sind + ry * cosd)
        body:setAngle(body:getAngle() + d)
        body:setLinearVelocity(vx, vy)
        body:setAngularVelocity(0)
    end
    local data = rec.data
    data.body1, data.body2 = rec.bodyA, rec.bodyB
    data.offsetA = { x = rec.la[1], y = rec.la[2] }
    data.offsetB = { x = rec.lb[1], y = rec.lb[2] }
    data.anchorB = nil
    local joint = joints.createJoint(data)
    inst.humptyBroken[key] = nil
    pop(tx, ty, 0.5, 0.9, 1)
    if joint and brokenCount(inst) == 0 then
        mipoVoice.squeak(inst, 'happy')
        mipoEmotion.set(inst, 'happy', 1, 3)
        pop(tx, ty - 200, 1, 0.8, 0.2)
    else
        mipoVoice.squeak(inst, 'poke')
    end
end

local function tryRejoin(inst, held, now)
    for key, rec in pairs(inst.humptyBroken or {}) do
        if now - rec.at > 0.8 then
            local pieceHeld, bodyHeld = false, held[inst.parts[rec.parent].body]
            for _, body in ipairs(bodiesOf(inst, subtree(inst, rec.child))) do
                if held[body] then pieceHeld = true end
            end
            if pieceHeld or bodyHeld then
                local ax, ay = rec.bodyA:getWorldPoint(rec.la[1], rec.la[2])
                local bx, by = rec.bodyB:getWorldPoint(rec.lb[1], rec.lb[2])
                local dist = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
                if dist < tune.snapDist then
                    rejoin(inst, key)
                    return -- one a frame
                end
            end
        end
    end
end

local function moveWhole(inst, x, y)
    local torso = inst.parts.torso1.body
    local tx, ty = torso:getPosition()
    for _, part in pairs(inst.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            local px, py = body:getPosition()
            body:setPosition(px - tx + x, py - ty + y)
            body:setLinearVelocity(0, 0)
            body:setAngularVelocity(0)
        end
    end
end

local function allBackOnTheWall(inst)
    for key in pairs(inst.humptyBroken or {}) do rejoin(inst, key) end
    moveWhole(inst, 0, -WALL_H - 420)
    inst.humptyRecent = nil
end

local function newHumpty(h)
    for _, inst in ipairs(h.mipos) do
        if isAlive(inst) then
            for _, part in pairs(inst.parts) do
                if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
            end
        end
    end
    h.mipos = {}
    local inst = characterManager.createCharacter('humanoid', 0, -WALL_H - 420, 0.3)
    if not inst then return end
    mipoBreeds.randomize(inst, 'rubberleg-pearbod')
    h.mipos[1] = inst
end

local function makeGround(h)
    if h.ground and not h.ground:isDestroyed() then return end
    h.ground = love.physics.newBody(world, 0, 0, 'static')
    local floor = love.physics.newFixture(h.ground, love.physics.newEdgeShape(-GROUND_W / 2, 0, GROUND_W / 2, 0))
    floor:setFriction(0.9)
    local wall = love.physics.newFixture(h.ground, love.physics.newRectangleShape(0, -WALL_H / 2, WALL_W, WALL_H))
    wall:setFriction(0.9)
    love.physics.newFixture(h.ground, love.physics.newEdgeShape(-GROUND_W / 2, 0, -GROUND_W / 2, -3000))
    love.physics.newFixture(h.ground, love.physics.newEdgeShape(GROUND_W / 2, 0, GROUND_W / 2, -3000))
    -- the wall is drawn here (drawBelow), not as a grey shape: hidden from the plain body drawing
    state.hiddenBodies = state.hiddenBodies or engine.weakKeys()
    state.hiddenBodies[h.ground] = true
end

function s.onStart()
    worldState.paused = false
    local h = humpty()
    makeGround(h)
    local alive = {}
    for _, inst in ipairs(h.mipos) do if isAlive(inst) then alive[#alive + 1] = inst end end
    h.mipos = alive
    if #h.mipos == 0 then newHumpty(h) end
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 300)
end

function s.onUnload()
    local h = state.humpty
    if h and h.ground and not h.ground:isDestroyed() then h.ground:destroy() end
    if h then h.ground = nil end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local h = humpty()
    local inst = h.mipos[1]
    if key == 'b' and isAlive(inst) then breakApart(inst)
    elseif key == 'r' and isAlive(inst) then allBackOnTheWall(inst)
    elseif key == 'n' then newHumpty(h) end
end

-- A hard landing: the torso's speed dropping, within a few frames (rope legs give a little), by more than a fall
-- from breakHeight gives, while nobody holds him.
local WINDOW = 9
local function landedHard(inst, held)
    local torso = inst.parts.torso1.body
    local vx, vy = torso:getLinearVelocity()
    local speed = math.sqrt(vx * vx + vy * vy)
    local recent = inst.humptyRecent or {}
    inst.humptyRecent = recent
    table.insert(recent, speed)
    if #recent > WINDOW then table.remove(recent, 1) end
    for _, body in ipairs(bodiesOf(inst, subtree(inst, 'torso1'))) do
        if held[body] then
            for i = #recent, 1, -1 do recent[i] = nil end
            return false
        end
    end
    local peak = 0
    for _, v in ipairs(recent) do peak = math.max(peak, v) end
    local drop = peak - speed
    inst.humptyBiggestDrop = math.max(inst.humptyBiggestDrop or 0, drop)
    local _, gy = world:getGravity()
    if drop > math.sqrt(2 * gy * tune.breakHeight) then
        for i = #recent, 1, -1 do recent[i] = nil end
        return true
    end
    return false
end

function s.update(dt)
    local h = humpty()
    local held = heldBodies()
    local now = love.timer.getTime()
    for _, inst in ipairs(h.mipos) do
        if isAlive(inst) then
            if landedHard(inst, held) and brokenCount(inst) < #BREAKS then breakApart(inst) end
            tryRejoin(inst, held, now)
        end
    end
    for i = #h.pops, 1, -1 do
        local p = h.pops[i]
        p.t = p.t + dt
        if p.t > 0.45 then table.remove(h.pops, i) end
    end
end

function s.drawBelow()
    -- the ground and the brick wall
    love.graphics.setColor(0.55, 0.68, 0.38, 1)
    love.graphics.rectangle('fill', -GROUND_W / 2, 0, GROUND_W, 400)
    love.graphics.setColor(0.42, 0.55, 0.30, 1)
    love.graphics.rectangle('fill', -GROUND_W / 2, 0, GROUND_W, 30)
    local x0, y0 = -WALL_W / 2, -WALL_H
    love.graphics.setColor(0.78, 0.40, 0.30, 1)
    love.graphics.rectangle('fill', x0, y0, WALL_W, WALL_H)
    love.graphics.setColor(0.93, 0.86, 0.74, 1)
    love.graphics.setLineWidth(8)
    local bh, bw = 76, 130
    for row = 0, math.floor(WALL_H / bh) do
        local y = y0 + row * bh
        if row > 0 then love.graphics.line(x0, y, x0 + WALL_W, y) end
        local shift = (row % 2) * bw / 2
        for x = x0 + shift, x0 + WALL_W - 1, bw do
            if x > x0 then love.graphics.line(x, y, x, math.min(y + bh, 0)) end
        end
    end
    love.graphics.setColor(0.35, 0.18, 0.14, 1)
    love.graphics.rectangle('line', x0, y0, WALL_W, WALL_H)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local h = state.humpty
    if not h then return end
    -- where a piece goes: a ring at each empty socket while he's in pieces
    for _, inst in ipairs(h.mipos) do
        if isAlive(inst) then
            for _, rec in pairs(inst.humptyBroken or {}) do
                local parentIsA = inst.parts[rec.parent].body == rec.bodyA
                local body = parentIsA and rec.bodyA or rec.bodyB
                local l = parentIsA and rec.la or rec.lb
                local x, y = body:getWorldPoint(l[1], l[2])
                local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
                love.graphics.setColor(1, 1, 1, 0.35 + 0.3 * pulse)
                love.graphics.setLineWidth(6)
                love.graphics.circle('line', x, y, 40 + 10 * pulse)
            end
        end
    end
    for _, p in ipairs(h.pops) do
        local k = p.t / 0.45
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1 - k)
        love.graphics.setLineWidth(10 * (1 - k) + 1)
        love.graphics.circle('line', p.x, p.y, 40 + 220 * k)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local h = state.humpty
    if not (h and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 300
    local rows = 6
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    ui.panel(x0, y0, w, ph, '•• humpty ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local inst = h.mipos[1]
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'back on the wall (r)') and isAlive(inst) then allBackOnTheWall(inst) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'break him (b)') and isAlive(inst) then breakApart(inst) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'a new Humpty (n)') then newHumpty(h) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('humptybreak', x, y, 140, 100, 1500, tune.breakHeight, nil, 1)
        if v then tune.breakHeight = v end
        ui.label(x + 240, y, 'breaks from')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('humptysnap', x, y, 140, 40, 400, tune.snapDist, nil, 1)
        if v then tune.snapDist = v end
        ui.label(x + 240, y, 'clicks from')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('pieces off: %d   falls: %d', isAlive(inst) and brokenCount(inst) or 0,
            h.breaks or 0))
    end)
end

-- From the bridge: s.status() — which pieces are off, where he is
function s.status()
    local inst = humpty().mipos[1]
    if not isAlive(inst) then return 'none' end
    local off = {}
    for key in pairs(inst.humptyBroken or {}) do off[#off + 1] = key end
    local x, y = inst.parts.torso1.body:getPosition()
    return { off = off, x = math.floor(x), y = math.floor(y) }
end

return s
