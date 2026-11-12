-- reach: a Mipo whose hands reach in 3D — toward you, behind its back — with arms honest in Box2D (docs/REACH.md).
-- The arm is scripts/spikes/reach-arm.lua: an elbow and a hand on distance joints whose lengths are the arm
-- as seen from the front, pulled by muscles toward a two-bone solve in 3D; the Mipo's own arm is posed on it.
-- (not space or c: the editor's pause and screenshot)
-- keys: m the hand follows the mouse (1 / 2 which hand, up / down its depth)   o circle toward you
--       w wave at you   f reach for the camera   g hold the belly   b behind the back   x hang
--       t 3D / flat (the Mipo's own arm, to compare)   r new Mipo   h panel
local s = {}

local reachArm = love.filesystem.load('scripts/spikes/reach-arm.lua')()

local GROUND_Y = 600
local MIPO_SCALE = 0.6

local MODES = {
    { key = 'mouse', label = 'mouse (m)' }, { key = 'circle', label = 'circle (o)' },
    { key = 'wave', label = 'wave (w)' }, { key = 'reach', label = 'to you (f)' },
    { key = 'hug', label = 'belly (g)' }, { key = 'behind', label = 'behind (b)' },
    { key = 'hang', label = 'hang (x)' },
}

local function st()
    state.reachSpike = state.reachSpike or { arms = {}, showPanel = true, mode = 'circle', hand = 'r',
        depth = 0.5, flat = false, guides = true, t0 = love.timer.getTime() }
    local c = state.reachSpike
    c.cfg = c.cfg or {}
    for k, v in pairs(reachArm.defaults) do
        if c.cfg[k] == nil then c.cfg[k] = v end
    end
    return c
end

local function armsAlive()
    local c = st()
    if not (c.inst and mipoKit.isAlive(c.inst)) then return false end
    local any = false
    for _, arm in pairs(c.arms) do
        if not reachArm.alive(arm) or arm.up:isDestroyed() then return false end
        any = true
    end
    return any
end

-- the physics arms gone, the Mipo's own arms back (when it's still there)
local function clearArms()
    local c = st()
    for _, arm in pairs(c.arms) do
        if reachArm.alive(arm) and not arm.up:isDestroyed() then reachArm.setMode(arm, 'flat') end
        if arm.palm and not arm.palm:isDestroyed() then reachArm.destroy(arm) end
    end
    c.arms = {}
end

local function buildArms()
    local c = st()
    clearArms()
    for _, side in ipairs({ 'l', 'r' }) do
        c.arms[side] = reachArm.build(world, c.inst, side)
        if c.arms[side] and c.flat then reachArm.setMode(c.arms[side], 'flat') end
    end
end

local function newMipo()
    local c = st()
    clearArms()
    if c.inst and mipoKit.isAlive(c.inst) then characterManager.removeCharacter(c.inst) end
    c.inst = characterManager.createCharacter('humanoid', 0, GROUND_Y - 700, MIPO_SCALE)
    if c.inst then
        characterManager.randomizeMipoConstrained(c.inst)
        buildArms()
    end
end

local function ensureGround()
    local c = st()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(6000, 100)):setFriction(0.9)
end

-- Where each hand goes now, in the world (x, y) with z toward the camera; nil: it hangs.
local function targetFor(arm, mode, t)
    local c = st()
    local sx, sy = reachArm.shoulder(arm)
    local R, sg = arm.reach, arm.sign
    -- the shoulder's distance from the body's middle (the other hand's side is -sg)
    local tx = arm.torso:getWorldCenter()
    local mid = tx - sx
    if mode == 'mouse' then
        if arm.side ~= c.hand then return nil end
        local mx, my = mouseWorldPos()
        return { x = mx, y = my, z = c.depth * R }
    elseif mode == 'circle' then
        -- a circle standing square to the screen: down, toward you, up, behind
        local ph = t * 1.6 + (sg > 0 and 0 or math.pi)
        return { x = sx + sg * 0.15 * R, y = sy + 0.15 * R + 0.6 * R * math.cos(ph), z = 0.6 * R * math.sin(ph) }
    elseif mode == 'wave' then
        if sg < 0 then return nil end
        return { x = sx + sg * (0.3 * R + 0.18 * R * math.sin(t * 7)), y = sy - 0.45 * R, z = 0.55 * R }
    elseif mode == 'reach' then
        return { x = sx + sg * 0.1 * R, y = sy + 0.05 * R, z = 0.97 * R }
    elseif mode == 'hug' then
        return { x = sx + mid * 1.15, y = sy + 0.55 * R, z = 0.5 * R }
    elseif mode == 'behind' then
        return { x = sx + mid * 0.6, y = sy + 0.6 * R, z = -0.6 * R }
    end
    return nil
end

local ZOOM = 0.45
local function frameIt()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 600)
end

function s.onStart()
    local c = st()
    worldState.paused = false
    frameIt()
    st().hold = true
    ensureGround()
    if not armsAlive() then
        -- a reload of this script keeps the Mipo (onUnload gave it its own arms back)
        if c.inst and mipoKit.isAlive(c.inst) then buildArms() else newMipo() end
    end
    state.drawableWrap = s.wrap
end

function s.onUnload()
    local c = state.reachSpike
    if state.drawableWrap == s.wrap then state.drawableWrap = nil end
    if c then
        clearArms()
    end
end

function s.update(dt)
    local c = st()
    state.drawableWrap = s.wrap -- (again: a reload of this script makes a new function)
    if not armsAlive() then
        if c.inst and mipoKit.isAlive(c.inst) then buildArms() else return end -- (a rebuild of the Mipo)
        if not armsAlive() then return end
    end
    dt = dt or 1 / 60
    -- the follow camera moves the view: hold it on the Mipo until you touch, drag or zoom
    if c.hold then
        if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
            c.hold = false
        else
            frameIt()
        end
    end
    if c.mode == 'mouse' then
        local dz = (love.keyboard.isDown('up') and 1 or 0) - (love.keyboard.isDown('down') and 1 or 0)
        c.depth = math.max(-1, math.min(1, c.depth + dz * dt * 0.8))
    end
    local t = love.timer.getTime() - c.t0
    local g = { world:getGravity() }
    for _, arm in pairs(c.arms) do
        reachArm.update(arm, dt, targetFor(arm, c.mode, t), c.cfg, g)
        reachArm.pose(arm) -- every step too: the ghost arm never lags its joints
    end
end

-- drawing: the Mipo's arm drawables come through here (state.drawableWrap)
local frame = { back = false }
-- a drawable whose fixture went (the Mipo rebuilt: a new look, the editor) is never drawn again
local function gone(d)
    return (d.texfixture and d.texfixture:isDestroyed()) or (d.fixture and d.fixture:isDestroyed())
        or (d.body and d.body:isDestroyed())
end
-- the arm's drawables seen this frame (`seen`) and the frame before (`prev`): the back layer is drawn
-- before the torso, which can come before the arm in the list, so it takes the frame before's
local function drawLayer(layer, which)
    local c = st()
    for _, arm in pairs(c.arms) do
        if reachArm.alive(arm) then
            local list = {}
            for d, draw in pairs(arm[which] or {}) do
                if not gone(d) and reachArm.layerOf(arm, d, c.cfg) == layer then
                    list[#list + 1] = { d = d, draw = draw }
                end
            end
            table.sort(list, function(p, q) return (p.d.z or 0) < (q.d.z or 0) end)
            for _, it in ipairs(list) do reachArm.drawPart(arm, it.d, it.draw, c.cfg) end
        end
    end
end

function s.wrap(d, draw)
    local c = state.reachSpike
    if c then
        for _, arm in pairs(c.arms) do
            if reachArm.alive(arm) and reachArm.owns(arm, d) then
                arm.seen = arm.seen or {}
                arm.seen[d] = draw
                if not reachArm.layerOf(arm, d, c.cfg) then reachArm.drawPart(arm, d, draw, c.cfg) end
                return
            end
        end
        -- the arms behind the body: before its torso
        local torso = c.arms.l and c.arms.l.torso or c.arms.r and c.arms.r.torso
        if not frame.back and torso and d.body == torso then
            frame.back = true
            drawLayer('back', 'prev')
        end
    end
    draw(d)
end

function s.drawBelow()
    frame.back = false
    if not armsAlive() then return end
    for _, arm in pairs(st().arms) do
        arm.prev, arm.seen = arm.seen, {}
        reachArm.pose(arm)
    end
end

local function drawGuides()
    local c = st()
    for _, arm in pairs(c.arms) do
        if reachArm.alive(arm) and arm.mode == '3d' then
            local sx, sy = reachArm.shoulder(arm)
            local ex, ey = arm.elbow:getPosition()
            local hx, hy = arm.palm:getPosition()
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1, 0.3, 0.6, 0.7)
            love.graphics.line(sx, sy, ex, ey, hx, hy)
            love.graphics.circle('line', hx, hy, arm.radius)
            if arm.goal then
                local gx, gy = sx + arm.goal.hx, sy + arm.goal.hy
                local r = 8 * reachArm.handScale({ zH = arm.goal.hz, reach = arm.reach }, c.cfg)
                love.graphics.setColor(0.2, 0.7, 1, 0.8)
                love.graphics.line(gx - r, gy, gx + r, gy)
                love.graphics.line(gx, gy - r, gx, gy + r)
            end
        end
    end
end

function s.draw()
    if not armsAlive() then return end
    drawLayer('front', 'seen') -- the arms in front of the body: over everything
    if st().guides then drawGuides() end
end

-- a little view from above and one from the side: where the arm is in 3D
local function drawSideViews(x0, y0, size)
    local c = st()
    local arm = c.arms.l or c.arms.r
    if not (arm and reachArm.alive(arm)) then return end
    local cx = arm.torso:getWorldCenter()
    local _, sy = reachArm.shoulder(arm)
    local scale = size * 0.45 / arm.reach
    local views = {
        { title = 'above', x = x0, u = function(x, _, _) return x - cx end,
          v = function(_, _, z) return z end },
        { title = 'side', x = x0 + size + 10, u = function(_, _, z) return z end,
          v = function(_, y, _) return y - sy end },
    }
    for _, view in ipairs(views) do
        local ox, oy = view.x + size / 2, y0 + size / 2
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', view.x, y0, size, size, 6)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.line(view.x + 6, oy, view.x + size - 6, oy)
        love.graphics.line(ox, y0 + 6, ox, y0 + size - 6)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(view.title, view.x + 6, y0 + 4)
        for _, a in pairs(c.arms) do
            if reachArm.alive(a) and a.mode == '3d' then
                local sx2, sy2 = reachArm.shoulder(a)
                local ex, ey = a.elbow:getPosition()
                local hx, hy = a.palm:getPosition()
                local pts = {}
                for _, p in ipairs({ { sx2, sy2, 0 }, { ex, ey, a.zE }, { hx, hy, a.zH } }) do
                    pts[#pts + 1] = ox + view.u(p[1], p[2], p[3]) * scale
                    pts[#pts + 1] = oy + view.v(p[1], p[2], p[3]) * scale
                end
                love.graphics.setColor(a.side == 'l' and { 1, 0.7, 0.3 } or { 0.4, 0.9, 1 })
                love.graphics.setLineWidth(3)
                love.graphics.line(pts)
                love.graphics.circle('fill', pts[5], pts[6], 5)
            end
        end
    end
    love.graphics.setLineWidth(1)
end

local PANEL = { w = 380, row = 30, pad = 6 }
function s.drawUI()
    local c = st()
    if c.guides then drawSideViews(12, 12, 170) end
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local sliders = {
        { 'depth', 'depth (mouse)', -1, 1, 0.05, c }, { 'strength', 'muscles', 0, 1, 0.05 },
        { 'kp', 'pull', 50, 1200, 10 }, { 'elbowOut', 'elbow out', -1, 1.5, 0.05 },
        { 'elbowBack', 'elbow back', -1, 1.5, 0.05 }, { 'focal', 'camera far', 1.2, 8, 0.1 },
    }
    local checks = {
        { 'flat', 'flat: the Mipo\'s own arm (t)', c }, { 'depthSize', 'hand size by depth' },
        { 'layers', 'behind / in front of the body' }, { 'guides', 'guides and side views', c },
    }
    local rows = 3 + #sliders + #checks + 2
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    ui.panel(x0, y0, w, h, '•• reach ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local per = 4
        local bw = (w - PANEL.pad * 2 - 4 * (per - 1)) / per
        local x, y
        for i, m in ipairs(MODES) do
            if (i - 1) % per == 0 then x, y = row() end
            local col = (i - 1) % per
            local label = (c.mode == m.key and '> ' or '') .. m.label
            if ui.button(x + col * (bw + 4), y, bw, label, PANEL.row - 6) then c.mode = m.key end
        end
        x, y = row()
        ui.label(x, y + 4, 'mouse hand:')
        for i, side in ipairs({ 'l', 'r' }) do
            local label = (c.hand == side and '> ' or '') .. (side == 'l' and 'left (1)' or 'right (2)')
            if ui.button(x + 100 + (i - 1) * 110, y, 104, label, PANEL.row - 6) then c.hand = side end
        end
        for _, sl in ipairs(sliders) do
            local tbl = sl[6] or c.cfg
            x, y = row()
            ui.label(x, y + 4, sl[2])
            local v = ui.sliderWithInput('reach-' .. sl[1], x + 120, y - 2, 150, sl[3], sl[4], tbl[sl[1]], nil, sl[5])
            if v then tbl[sl[1]] = v + 0 end
        end
        for _, ch in ipairs(checks) do
            local tbl = ch[3] or c.cfg
            x, y = row()
            local clicked, v = ui.checkbox(x, y, tbl[ch[1]], ch[2])
            if clicked then
                tbl[ch[1]] = v
                if ch[1] == 'flat' then
                    for _, arm in pairs(c.arms) do reachArm.setMode(arm, v and 'flat' or '3d') end
                end
            end
        end
        x, y = row()
        if ui.button(x, y, 160, 'new Mipo (r)', PANEL.row - 6) then newMipo() end
    end)
end

function s.onKeyPress(key)
    local c = st()
    local byKey = { m = 'mouse', o = 'circle', w = 'wave', f = 'reach', g = 'hug', b = 'behind', x = 'hang' }
    if byKey[key] then c.mode = byKey[key]; c.t0 = love.timer.getTime() end
    if key == '1' then c.hand = 'l' end
    if key == '2' then c.hand = 'r' end
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'r' then newMipo() end
    if key == 't' then
        c.flat = not c.flat
        for _, arm in pairs(c.arms) do reachArm.setMode(arm, c.flat and 'flat' or '3d') end
    end
end

return s
