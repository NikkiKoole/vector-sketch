-- nofeet: Mipos without feet, or with very small ones, on a bumpy course, to feel how they move
-- when the big foot boxes they get stuck on are gone. The panel switches every Mipo's feet:
-- as built (their random feet), small (scaled down, still standing on them) or none (the foot
-- shrunk to a dot and turned into a sensor: the shin's round capsule end touches the ground).
-- The hands too, on their own row (none: the arm's round end). Only in this scene; no DNA option yet.
-- keys: d: drop them all again   r: new Mipos   p: pause the world   h: hide/show the panel

local s = {}

local COUNT = 5
local SPACING = 420
local GROUND_Y = 900
local ZOOM = 0.4
local NONE_SCALE = 0.08 -- a foot at 'none': a dot under the leg's end, and a sensor
local KINDS = {
    { key = 'feet', label = 'feet', parts = { 'lfoot', 'rfoot' } },
    { key = 'hands', label = 'hands', parts = { 'lhand', 'rhand' } },
}

local function check() -- on state: a script hot reload keeps the Mipos
    state.noFeet = state.noFeet or { mipos = {}, statics = {}, orig = {} }
    local c = state.noFeet
    -- Nikki's picks (2026-11-08): feet 1, hands 0.74 (the randomizer gives both 1-2)
    c.kinds = c.kinds or { feet = { mode = 'small', small = 1 }, hands = { mode = 'small', small = 0.74 } }
    if c.showPanel == nil then c.showPanel = true end
    return c
end

local alive = mipoKit.isAlive -- src/mipo-kit.lua

-- ground, and right of the Mipos things to get stuck on: a low step, a slot, a row of
-- little bumps, a kerb
local function makeCourse()
    local c = check()
    if c.statics[1] and not c.statics[1]:isDestroyed() then return end
    local function block(x, y, w, h, angle)
        local b = love.physics.newBody(world, x, y, 'static')
        b:setAngle(angle or 0)
        love.physics.newFixture(b, love.physics.newRectangleShape(w, h)):setFriction(0.9)
        c.statics[#c.statics + 1] = b
    end
    local left = -(COUNT + 1) / 2 * SPACING
    local right = 4200
    block((left + right) / 2, GROUND_Y + 50, right - left, 100)
    local x0 = (COUNT + 1) / 2 * SPACING
    block(x0 + 150, GROUND_Y - 30, 300, 60)              -- a low step
    block(x0 + 650, GROUND_Y - 40, 200, 80)              -- a slot between two blocks
    block(x0 + 960, GROUND_Y - 40, 200, 80)
    for i = 0, 5 do                                       -- little bumps
        block(x0 + 1400 + i * 110, GROUND_Y - 12, 50, 50, math.pi / 4)
    end
    block(x0 + 2300, GROUND_Y - 70, 500, 140)            -- a kerb
    block(x0 + 2800, GROUND_Y - 160, 120, 40, -0.4)      -- a ledge sticking out
end

local function setSensors(inst, kind, on)
    for _, name in ipairs(kind.parts) do
        local body = inst.parts[name] and inst.parts[name].body
        if body and not body:isDestroyed() then
            for _, fixture in ipairs(body:getFixtures()) do
                if not fixture:getUserData() and fixture:isSensor() ~= on then fixture:setSensor(on) end
            end
        end
    end
end

-- a Mipo's feet or hands to the panel's mode; as built is the scale the randomizer gave them
local function applyKind(inst, kind)
    local c = check()
    local orig = c.orig[inst] and c.orig[inst][kind.key]
    if not orig then return end
    local k = c.kinds[kind.key]
    local scale = (k.mode == 'small' and k.small) or (k.mode == 'none' and NONE_SCALE) or orig
    characterManager.updatePart(kind.parts[1], { sx = scale, sy = scale }, inst)
    characterManager.updatePart(kind.parts[2], { sx = -scale, sy = scale }, inst)
    setSensors(inst, kind, k.mode == 'none')
end

local function applyMipo(inst)
    for _, kind in ipairs(KINDS) do applyKind(inst, kind) end
    characterManager.rebuildTextures(inst)
    for _, kind in ipairs(KINDS) do setSensors(inst, kind, check().kinds[kind.key].mode == 'none') end
end

local function applyAll(kind)
    for _, inst in ipairs(check().mipos) do
        if alive(inst) then
            applyKind(inst, kind)
            characterManager.rebuildTextures(inst)
        end
    end
end

local function makeMipos()
    local c = check()
    for _, inst in ipairs(c.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos, c.orig = {}, {}
    for i = 1, COUNT do
        local x = (i - (COUNT + 1) / 2) * SPACING
        local inst = characterManager.createCharacter('humanoid', x, GROUND_Y - 500, 0.3)
        if inst then
            characterManager.randomizeMipo(inst)
            c.orig[inst] = { feet = math.abs(inst.dna.parts.lfoot.dims.sy or 1),
                hands = math.abs(inst.dna.parts.lhand.dims.sy or 1) }
            c.mipos[i] = inst
            applyMipo(inst)
        end
    end
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(600, GROUND_Y - 380)
    check().hold = true
end

function s.onStart()
    worldState.paused = false
    makeCourse()
    local c = check()
    local any = false
    for _, inst in ipairs(c.mipos) do any = any or alive(inst) end
    if not any then makeMipos() end
    lookAtAll()
end

function s.onUnload()
    local c = state.noFeet
    if not c then return end
    for i, b in ipairs(c.statics) do
        if not b:isDestroyed() then b:destroy() end
        c.statics[i] = nil
    end
end

function s.update()
    local c = check()
    -- a rebuild elsewhere (the Mipo editor, a facing switch) makes the parts solid again
    for _, kind in ipairs(KINDS) do
        if c.kinds[kind.key].mode == 'none' then
            for _, inst in ipairs(c.mipos) do
                if alive(inst) then setSensors(inst, kind, true) end
            end
        end
    end
    -- the follow camera moves the view: hold it on the Mipos until you touch, drag or zoom
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

local function dropAll()
    for _, inst in ipairs(check().mipos) do
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

function s.onKeyPress(key)
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'd' then dropAll() end
    if key == 'r' then makeMipos() end
    if key == 'h' then check().showPanel = not check().showPanel end
end

local MODES = {
    { key = 'built', label = 'as built' },
    { key = 'small', label = 'small' },
    { key = 'none', label = 'none' },
}

function s.drawUI()
    local c = check()
    if not (state.playMode and c.showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 8, 380
    local rows = #KINDS * 2 + 1
    local h = BH * rows + pad * (rows + 1) + 24 + #KINDS * 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• feet & hands ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y
        for _, kind in ipairs(KINDS) do
            local k = c.kinds[kind.key]
            x, y = ui.nextLayoutPosition(layout, w - 20, 20)
            ui.label(x, y, kind.label)
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local bw = (w - 20 - 2 * pad) / 3
            for i, m in ipairs(MODES) do
                local label = (k.mode == m.key and '> ' or '') .. m.label
                if ui.button(x + (i - 1) * (bw + pad), y, bw, label) and k.mode ~= m.key then
                    k.mode = m.key
                    applyAll(kind)
                end
            end
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('noFeetSmall' .. kind.key, x, y, 160, 0.15, 1, k.small)
            if v and math.abs(v - k.small) > 0.01 then
                k.small = v
                if k.mode == 'small' then applyAll(kind) end
            end
            ui.label(x + 260, y, 'small size')
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, (w - 20 - pad) / 2, 'drop (d)') then dropAll() end
        if ui.button(x + (w - 20 + pad) / 2, y, (w - 20 - pad) / 2, 'new Mipos (r)') then makeMipos() end
    end)
end

return s
