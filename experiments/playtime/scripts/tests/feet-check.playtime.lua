-- feet-check: every foot picture on a Mipo of its own (the same Mipo otherwise), to see how
-- each one stands. A foot hangs from its picture's ankle (src/shape8-dict.lua, the anchors
-- on the meta sheet). Red: the feet's collision outline. Under each: how far each foot is
-- off level, and STOP when it's pressed against the ankle's stop. spec/feet-stand checks
-- the same (three drops, each foot at rest on its sole). Load the scene again for fresh Mipos
-- after changing how feet are built.
-- Springy ankle experiment, parked (2026-11-01, docs/MIPO-EDITOR-LEFTOVERS.md E8), off at the
-- start; turn it on in the panel (play mode): a weld joint next to each ankle hinge, soft in
-- its turn only (as the ears are), pulls the foot back to flat; the hinge's stop can be widened
-- to give it room. Only in this scene.
-- keys: d: drop them all again   p: pause the world   h: hide/show the panel

local s = {}

local PER_ROW = 4
local SPACING = 650
local ROW_GAP = 1300
local GROUND_Y = 900 -- of the first row
local ZOOM = 0.45
local ANKLES = { { foot = 'lfoot', shin = 'llleg' }, { foot = 'rfoot', shin = 'rlleg' } }

local function check() -- on state: a script hot reload keeps the Mipos
    state.feetCheck = state.feetCheck or { mipos = {}, grounds = {}, ankles = {} }
    local c = state.feetCheck
    c.ankles = c.ankles or {}
    -- the experiment's settings, off: the ankle as built (a free hinge, stop pi / 8 either way)
    c.spring = c.spring or { on = false, frequency = 4, damping = 0.4, stop = 22.5 }
    if c.showPanel == nil then c.showPanel = true end
    return c
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function slot(i)
    local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    return col * SPACING, GROUND_Y + row * ROW_GAP
end

local function rows() return math.ceil(#shapeCatalogs.handShapes / PER_ROW) end

local function makeGrounds()
    local c = check()
    for r = 1, rows() do
        local g = c.grounds[r]
        if not (g and not g:isDestroyed()) then
            local w = SPACING * (PER_ROW + 1)
            g = love.physics.newBody(world, (PER_ROW - 1) * SPACING / 2, GROUND_Y + (r - 1) * ROW_GAP + 50, 'static')
            love.physics.newFixture(g, love.physics.newRectangleShape(w, 100)):setFriction(0.9)
            c.grounds[r] = g
        end
    end
end

local function build()
    local c = check()
    for i, name in ipairs(shapeCatalogs.handShapes) do
        if not alive(c.mipos[i]) then
            local x, groundY = slot(i)
            local inst = characterManager.createCharacter('humanoid', x, groundY - 400, 0.3)
            if inst then
                characterManager.updatePart('lfoot', { shape8URL = name .. '.png' }, inst)
                characterManager.updatePart('rfoot', { shape8URL = name .. '.png' }, inst)
                characterManager.rebuildTextures(inst)
            end
            c.mipos[i] = inst
        end
    end
end

-- the ankle: the revolute joint between a foot and its shin
local function ankle(inst, foot, shin)
    local fb, sb = inst.parts[foot] and inst.parts[foot].body, inst.parts[shin] and inst.parts[shin].body
    if not (fb and sb) or fb:isDestroyed() or sb:isDestroyed() then return end
    for _, joint in ipairs(fb:getJoints()) do
        local a, b = joint:getBodies()
        if joint:getType() == 'revolute' and (a == sb or b == sb) then return joint end
    end
end

-- Each ankle hinge, remembered with the middle of its range as built (flat) and its spring.
local function ankleEntry(hinge)
    local c = check()
    local entry = c.ankles[hinge]
    if not entry then
        local low, up = hinge:getLimits()
        entry = { mid = (low + up) / 2 }
        c.ankles[hinge] = entry
    end
    return entry
end

-- Springs on (a weld at the ankle, soft in its turn, its rest the middle of the range) or off,
-- the settings applied, and the hinge's stop at spring.stop either way of flat.
local function applySprings()
    local c = check()
    local spring = c.spring
    for hinge in pairs(c.ankles) do
        if hinge:isDestroyed() then
            c.ankles[hinge] = nil
        end
    end
    for _, inst in pairs(c.mipos) do
        if alive(inst) then
            for _, a in ipairs(ANKLES) do
                local hinge = ankle(inst, a.foot, a.shin)
                if hinge then
                    local entry = ankleEntry(hinge)
                    local stop = math.rad(spring.stop)
                    hinge:setLimits(entry.mid - stop, entry.mid + stop)
                    local weld = entry.weld
                    if weld and weld:isDestroyed() then weld, entry.weld = nil, nil end
                    if spring.on and not weld then
                        local bodyA, bodyB = hinge:getBodies()
                        local x, y = hinge:getAnchors()
                        weld = love.physics.newWeldJoint(bodyA, bodyB, x, y, x, y, false,
                            hinge:getReferenceAngle() + entry.mid)
                        entry.weld = weld
                    elseif not spring.on and weld then
                        weld:destroy()
                        weld, entry.weld = nil, nil
                    end
                    if weld then
                        weld:setFrequency(spring.frequency)
                        weld:setDampingRatio(spring.damping)
                    end
                end
            end
        end
    end
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation((PER_ROW - 1) * SPACING / 2, GROUND_Y + (rows() - 1) * ROW_GAP / 2 - 250)
    check().hold = true
end

function s.onStart()
    makeGrounds()
    build()
    applySprings()
    lookAtAll()
end

function s.update()
    applySprings()
    -- the follow camera moves the view: hold it on all the Mipos until you touch, drag or zoom
    local c = check()
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

-- lift each Mipo and let go, as spec/feet-stand does
local function dropAll()
    for _, inst in pairs(check().mipos) do
        if alive(inst) then
            for _, part in pairs(inst.parts) do
                local body = part.body
                body:setPosition(body:getX(), body:getY() - 400)
                body:setLinearVelocity(0, 0)
                body:setAngularVelocity(0)
            end
        end
    end
end

function s.onUnload()
    local c = state.feetCheck
    if not c then return end
    for r, g in pairs(c.grounds) do
        if not g:isDestroyed() then g:destroy() end
        c.grounds[r] = nil
    end
end

function s.onKeyPress(key)
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'd' then dropAll() end
    if key == 'h' then check().showPanel = not check().showPanel end
end

-- built a quarter turn from its shin: flat is ±90 degrees
local REST = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }

local function footText(inst, foot, shin)
    local joint = ankle(inst, foot, shin)
    if not joint then return '?' end
    local d = inst.parts[foot].body:getAngle() - REST[foot]
    local off = math.deg(math.abs(math.atan2(math.sin(d), math.cos(d))))
    local angle, low, up = joint:getJointAngle(), joint:getLimits()
    local stop = (angle <= low + 0.02 or angle >= up - 0.02) and ' STOP' or ''
    return string.format('%.0f deg%s', off, stop)
end

function s.draw()
    local c = check()
    for i, name in ipairs(shapeCatalogs.handShapes) do
        local inst = c.mipos[i]
        local x, groundY = slot(i)
        love.graphics.setColor(0.95, 0.92, 0.8)
        love.graphics.printf(name, x - 300, groundY + 110, 300, 'center', 0, 2, 2)
        if alive(inst) then
            love.graphics.printf(footText(inst, 'lfoot', 'llleg') .. '   ' .. footText(inst, 'rfoot', 'rlleg'),
                x - 300, groundY + 160, 300, 'center', 0, 2, 2)
            love.graphics.setColor(1, 0, 0)
            love.graphics.setLineWidth(2)
            for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
                local body = inst.parts[foot] and inst.parts[foot].body
                if body and not body:isDestroyed() then
                    for _, fixture in ipairs(body:getFixtures()) do
                        local shape = fixture:getShape()
                        if not fixture:getUserData() and shape:getType() == 'polygon' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        end
                    end
                end
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

local SLIDERS = {
    { key = 'frequency', label = 'stiffness (Hz)', min = 0.5, max = 15 },
    { key = 'damping', label = 'bounce (damping)', min = 0, max = 1.5 },
    { key = 'stop', label = 'stop (degrees)', min = 5, max = 60, step = 1 },
}

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local spring = c.spring
    local BH, pad, w = 34, 8, 380
    local h = BH * (#SLIDERS + 2) + pad * (#SLIDERS + 3) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• springy ankle ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, spring.on and 'spring: on' or 'spring: off (a free hinge, as built)') then
            spring.on = not spring.on
        end
        for _, sl in ipairs(SLIDERS) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('feetSpring' .. sl.key, x, y, 160, sl.min, sl.max, spring[sl.key], nil,
                sl.step)
            if v and v ~= spring[sl.key] then spring[sl.key] = v end
            ui.label(x + 260, y, sl.label)
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'drop them all (d)') then dropAll() end
    end)
end

return s
