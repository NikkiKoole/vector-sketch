-- beaks: Mipos with real beaks — an upper and a lower half that open and shut, a hole between them, in 3D
-- (turning with the head), from a little finch to a stork (docs/BEAKS.md; scripts/spikes/beak.lua).
-- Nikki 2026-11-11: "an upper lower part, no teeth, some hole, it works in '3d', open and close, very
-- different sizes, stork and duck". Pictures: textures/beak/<name>-upper/-lower/-top.png, placeholders from
-- claudetools/beak-pictures.py, to be drawn by hand.
-- (not space or c: the editor's pause and screenshot)
-- keys: t every Mipo squeaks (the beak talks)   o open / shut   k clack   b next beak (picked Mipo)
--       left/right turn the Mipos   r new Mipos   h panel
local s = {}

local beak = love.filesystem.load('scripts/spikes/beak.lua')()

local GROUND_Y = 600
local MIPO_SCALE = 0.6

local function st()
    state.beaks = state.beaks or { kinds = {}, showPanel = true, view = 0.45, size = 1, wMul = 1, hMul = 1,
        open = 0, outline = 6, turn = 0, up = 0, opens = {}, all = true }
    return state.beaks
end

local function mipos()
    local list = {}
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return list
end

local function ensureGround()
    if getObjectsByLabel('ground')[1] then return end
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 6000, height = 600,
        bodyType = 'static', label = 'ground' })
    if not thing then return end
    local tile = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    tile.main = tile.main or {}
    tile.main.bgURL, tile.opacity, tile.tileWidthM, tile.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
end

local function faceOf(inst)
    local owner = inst.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = inst.dna.parts[owner]
    return part and part.appearance and part.appearance.face, owner
end

-- a bird has no nose and no teeth
local function birdFace(inst)
    local face = faceOf(inst)
    if not face then return end
    if face.nose then face.nose.shape = 0 end
    if face.teeth then face.teeth.shape = 0 end
    characterManager.rebuildFromCreation(inst, {})
end

local function ensureMipos()
    local c = st()
    if #mipos() > 0 then return end
    for i, name in ipairs(beak.NAMES) do
        local inst = characterManager.createCharacter('humanoid', -1400 + (i - 1) * 700, GROUND_Y - 700, MIPO_SCALE)
        if inst then
            characterManager.randomizeMipoConstrained(inst)
            birdFace(inst)
            c.kinds[inst.id] = name
        end
    end
end

local function clearMipos()
    for _, inst in ipairs(mipos()) do characterManager.removeCharacter(inst) end
    st().kinds = {}
end

-- The lips stay (where the mouth is, and the turned face moves them) but draw nothing: without their
-- curve points the renderer skips them. Every frame, as a rebuild (a turn) makes them again.
local function hideLips(body)
    local upper
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        local e = ud and ud.extra
        if e and (e.mouthCurve == 'upper' or e.mouthCurve == 'lower') then
            if e.curvePoints then e.beakCurve, e.curvePoints = e.curvePoints, nil end
            if e.mouthCurve == 'upper' then upper = e end
        end
    end
    return upper
end

local picked
local wasDown = false
local function pick()
    local down = love.mouse.isDown(1)
    if down and not wasDown and not ui.overPanel then
        local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
        local best, bestD = nil, 700 * 700
        for _, inst in ipairs(mipos()) do
            local x, y = inst.parts.head.body:getPosition()
            local d = (x - wx) ^ 2 + (y - wy) ^ 2
            if d < bestD then best, bestD = inst, d end
        end
        if best then picked = best.id end
    end
    wasDown = down
end

local function targets()
    local c = st()
    if c.all then return mipos() end
    local inst = picked and mipoRegistry.getAll()[picked]
    return inst and mipoKit.isAlive(inst) and { inst } or {}
end

function s.onStart()
    worldState.paused = false
    st()
    ensureGround()
    ensureMipos()
end

local clackUntil = 0
function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'o' then c.open = c.open > 0.5 and 0 or 1 end
    if key == 'k' then clackUntil = love.timer.getTime() + 1.2 end
    if key == 't' then
        for _, inst in ipairs(mipos()) do mipoVoice.squeak(inst, nil, 0.9 + love.math.random() * 0.3) end
    end
    if key == 'b' then
        for _, inst in ipairs(targets()) do
            local now = c.kinds[inst.id] or 'duck'
            for i, name in ipairs(beak.NAMES) do
                if name == now then c.kinds[inst.id] = beak.NAMES[i % #beak.NAMES + 1]; break end
            end
        end
    end
    if key == 'left' or key == 'right' then
        for _, inst in ipairs(targets()) do mipoWalk.turn(inst, key == 'left' and -1 or 1) end
    end
    if key == 'r' then
        clearMipos()
        ensureMipos()
    end
end

-- how open each beak wants to be: the panel's, a clack, and chattering while it squeaks
local function goal(inst, t)
    local c = st()
    local g = c.open
    if t < clackUntil then g = math.max(g, (math.sin(t * 22) > 0) and 1 or 0) end
    if mipoVoice.isTalking(inst) then g = math.max(g, 0.45 + 0.55 * math.abs(math.sin(t * 13 + #tostring(inst.id)))) end
    return g
end

function s.update(dt)
    pick()
    local c = st()
    local t = love.timer.getTime()
    for _, inst in ipairs(mipos()) do
        local g = goal(inst, t)
        local o = c.opens[inst.id] or 0
        local speed = g > o and 18 or 10 -- snaps open, shuts a little slower
        c.opens[inst.id] = o + (g - o) * math.min(1, speed * dt)
    end
end

-- before the Mipos are drawn: a rebuild (a turn) makes the lips again, and hidden only in draw (after
-- them) they showed for a frame
function s.drawBelow()
    for _, inst in ipairs(mipos()) do
        local _, owner = faceOf(inst)
        local part = inst.parts[owner]
        if part and part.body and not part.body:isDestroyed() then hideLips(part.body) end
    end
end

function s.draw()
    local c = st()
    for _, inst in ipairs(mipos()) do
        local name = c.kinds[inst.id]
        local _, owner = faceOf(inst)
        local part = inst.parts[owner]
        local body = part and part.body
        if name and body and not body:isDestroyed() then
            local lip = hideLips(body)
            local cx, r = mipoFacing.headBox(inst, owner)
            if lip and cx then
                local headW = r * 2
                local rx, ry = body:getWorldPoint(lip.ox, lip.oy + c.up * headW)
                beak.draw(inst.id, {
                    name = name, rx = rx, ry = ry, headAngle = body:getAngle(),
                    yaw = mipoFacing.angle(inst) + math.rad(c.turn), view = c.view,
                    L = headW * beak.KINDS[name].length * c.size, wMul = c.wMul, hMul = c.hMul,
                    open = c.opens[inst.id] or 0, textured = c.textured ~= false, outline = c.outline * (cam.scale and 1 / cam.scale or 1),
                })
            end
        end
    end
end

-- the panel, bottom right
local PANEL = { w = 340, row = 32, pad = 6 }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local sliders = {
        { 'view', 'from above', 0, 1.2, 0.05 }, { 'turn', 'turn (deg)', -90, 90, 5 },
        { 'size', 'size', 0.3, 2.5, 0.05 }, { 'wMul', 'width', 0.3, 3, 0.05 }, { 'hMul', 'height', 0.3, 3, 0.05 },
        { 'open', 'open', 0, 1, 0.05 }, { 'up', 'up / down', -0.4, 0.4, 0.02 }, { 'outline', 'outline px', 0, 8, 0.5 },
    }
    local rows = #sliders + 6
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    ui.panel(x0, y0, w, h, '•• beaks ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local bw = (w - PANEL.pad * 2 - 4 * 4) / 5
        local x, y = row()
        for i, name in ipairs(beak.NAMES) do
            if ui.button(x + (i - 1) * (bw + 4), y, bw, name, PANEL.row - 6) then
                for _, inst in ipairs(targets()) do c.kinds[inst.id] = name end
            end
        end
        for _, sl in ipairs(sliders) do
            x, y = row()
            ui.label(x, y + 4, sl[2])
            local v = ui.sliderWithInput('beak-' .. sl[1], x + 100, y - 2, 140, sl[3], sl[4], c[sl[1]], nil, sl[5])
            if v then c[sl[1]] = v + 0 end
        end
        x, y = row()
        local ac, av = ui.checkbox(x, y, c.all, 'every Mipo (else the one touched)')
        if ac then c.all = av end
        x, y = row()
        local tc, tv = ui.checkbox(x, y, c.textured ~= false, 'the drawn picture on the beak (off: its colours only)')
        if tc then c.textured = tv end
        x, y = row()
        local inst = picked and mipoRegistry.getAll()[picked]
        ui.label(x, y + 4, inst and ('picked: ' .. tostring(c.kinds[inst.id])) or 'touch a Mipo to pick it')
        x, y = row()
        ui.label(x, y + 4, 't talk  o open  k clack  b next beak')
        x, y = row()
        ui.label(x, y + 4, 'left/right turn  r new Mipos  h panel')
    end)
end

return s
