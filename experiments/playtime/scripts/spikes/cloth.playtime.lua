-- cloth: a spike for curtains, flags and sheets (src/cloth.lua, docs/CLOTH.md)
-- A curtain on a rail in a doorway (in front: walk a Mipo through it), a flag on a pole that you
-- can push over, and a sheet on a clothesline at the back. Each is a grid of points on a verlet
-- step of its own, drawn as one textured mesh with a drawn outline; folds shade darker.
--
-- play mode (tab): drag Mipos through the cloth; drag the cloth itself where no body is.
-- keys: r hang them again   m a Mipo   w wind on/off   t tearing on/off   c collisions on/off
--       f next fabric for the curtain   d wireframe   h the panel
--       1 silk   2 cotton   3 heavy (velvet)   4 storm

local s = {}

local GROUND_TOP = 0
local GROUND = { 0.5, 0.64, 0.36 }
local WOOD = { 0.6, 0.45, 0.34 }
local OUTLINE = { 0.2, 0.13, 0.1 }

-- Ways for the cloth to feel, on 1-4 and the panel. The cloth moves in 3D (src/cloth.lua): it
-- folds toward and away from you, the air calms it. Wind is the air's speed, px/s at 100 px/m.
local PRESETS = {
    { name = 'silk', bend = 0.01, shear = 0.3, drag = 0.6, lift = 2.5, gravity = 1, wind = 250, gust = 0.5,
      flutter = 0.6, substeps = 15, iterations = 1, damping = 0.999, stretch = 1, slack = 1 },
    { name = 'cotton', bend = 0.05, shear = 0.5, drag = 0.8, lift = 3, gravity = 1, wind = 300, gust = 0.4,
      flutter = 0.5, substeps = 15, iterations = 1, damping = 0.999, stretch = 1, slack = 1 },
    { name = 'heavy', bend = 0.25, shear = 0.8, drag = 0.5, lift = 1.5, gravity = 1.2, wind = 200, gust = 0.3,
      flutter = 0.35, substeps = 15, iterations = 1, damping = 0.999, stretch = 1, slack = 1 },
    { name = 'storm', bend = 0.05, shear = 0.5, drag = 0.8, lift = 3, gravity = 1, wind = 900, gust = 0.8,
      flutter = 1, substeps = 15, iterations = 1, damping = 0.999, stretch = 1, slack = 1 },
}

local function scene()
    state.clothScene = state.clothScene or {
        settings = { -- cotton
            wind = 300, windOn = true, gust = 0.4, flutter = 0.5, substeps = 15, iterations = 1,
            damping = 0.999, gravity = 1, drag = 0.8, lift = 3, tear = 2.6, tearOn = false, push = 0.02,
            shade = 0.6, fabricScale = 1, spacing = 20, shear = 0.5, bend = 0.05, stretch = 1, slack = 1,
        },
        preset = 'cotton', fabric = 1, debug = false, collide = true, mipos = {},
        showPanel = false, -- h shows it (it covers the curtain)
    }
    return state.clothScene
end

-- the live settings reach every cloth
local function apply(sc)
    local st = sc.settings
    for _, c in ipairs(sc.cloths or {}) do
        c.wind = st.windOn and (st.wind * (c.windShare or 1)) or 0
        c.gust, c.flutter, c.substeps, c.iterations = st.gust, st.flutter, st.substeps, st.iterations
        c.damping, c.gravity, c.drag, c.lift = st.damping, st.gravity, st.drag, st.lift
        c.tear = st.tearOn and st.tear or 0
        c.push, c.shade, c.fabricScale = st.push, st.shade, st.fabricScale
        c.collide = sc.collide and c.collides
    end
end

local function staticBox(x1, y1, x2, y2)
    local body = love.physics.newBody(world, (x1 + x2) / 2, (y1 + y2) / 2, 'static')
    love.physics.newFixture(body, love.physics.newRectangleShape(x2 - x1, y2 - y1))
    return body
end

local function build(sc)
    for _, b in ipairs(sc.bodies or {}) do
        if not b:isDestroyed() then b:destroy() end
    end
    sc.bodies = {}
    local st = sc.settings
    local function body(b) sc.bodies[#sc.bodies + 1] = b; return b end

    body(staticBox(-3000, GROUND_TOP, 3000, GROUND_TOP + 300))
    -- the doorway: two posts and a lintel, the rail under it
    sc.door = { x1 = -260, x2 = 260, top = -620 }
    -- the flag pole: a dynamic pole on a hinge at its foot, so it can be pushed over and swings back
    local poleX, poleH = 700, 760
    local pole = body(love.physics.newBody(world, poleX, GROUND_TOP - poleH / 2, 'dynamic'))
    love.physics.newFixture(pole, love.physics.newRectangleShape(16, poleH), 2)
    local foot = sc.bodies[1]
    local hinge = love.physics.newRevoluteJoint(foot, pole, poleX, GROUND_TOP - 4, false)
    hinge:setLimitsEnabled(true)
    hinge:setLimits(-0.6, 0.6)
    hinge:setMotorEnabled(true) -- a muscle at the foot: it rights the pole (update sets its speed)
    hinge:setMaxMotorTorque(pole:getMass() * 9.8 * love.physics.getMeter() * poleH * 1.5)
    sc.pole, sc.poleH, sc.hinge = pole, poleH, hinge

    local common = { spacing = st.spacing, shear = st.shear, bend = st.bend, stretch = st.stretch, slack = st.slack,
        outline = OUTLINE }
    local function make(o)
        for k, v in pairs(common) do if o[k] == nil then o[k] = v end end
        return cloth.new(o)
    end
    local sp = st.spacing
    local doorW = sc.door.x2 - sc.door.x1
    sc.curtain = make({
        x = sc.door.x1 + 6, y = sc.door.top + 24, cols = math.floor(doorW * 1.1 / sp), rows = math.floor(560 / sp),
        pin = 'rail', ringEvery = 3, railMin = sc.door.x1 + 6, railMax = sc.door.x2 - 6,
        fabric = cloth.fabricNames[sc.fabric], collides = true, windShare = 0.25, layer = 'front',
    })
    -- the curtain starts gathered a little: squeeze its top row to the left half
    local c = sc.curtain
    for col = 0, c.cols - 1 do
        local i = col + 1
        c.x[i] = c.railMin + col * sp * 0.75
        c.px[i] = c.x[i]
    end
    sc.flag = make({
        x = poleX + 8, y = GROUND_TOP - poleH + 10, cols = math.floor(260 / sp), rows = math.floor(170 / sp),
        pin = 'left', pinBody = pole, fabric = 'banner', collides = false, windShare = 1, bend = 0.05,
        layer = 'back',
    })
    sc.sheet = make({
        x = -1300, y = -520, cols = math.floor(420 / sp), rows = math.floor(300 / sp),
        pin = 'ring', ringEvery = 5, fabric = 'gingham', collides = true, windShare = 0.7, layer = 'back',
    })
    sc.cloths = { sc.sheet, sc.flag, sc.curtain }
    apply(sc)
end

local function aliveMipos(sc)
    local out = {}
    for _, inst in ipairs(sc.mipos) do
        if mipoRegistry.getById(inst.id) then out[#out + 1] = inst end
    end
    return out
end

local function spawnMipo(sc, x, y) mipoKit.spawn(sc.mipos, x, y) end -- src/mipo-kit.lua

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local sc = scene()
    local ok = sc.bodies and sc.bodies[1] and not sc.bodies[1]:isDestroyed()
    if not ok then build(sc) end
    sc.mipos = aliveMipos(sc)
    if #sc.mipos == 0 then
        spawnMipo(sc, -60, -500)
        spawnMipo(sc, -900, -500)
    end
end

local function usePreset(sc, k)
    for key, v in pairs(PRESETS[k]) do
        if key ~= 'name' then sc.settings[key] = v end
    end
    sc.preset = PRESETS[k].name
    build(sc)
end

function s.onKeyPress(key)
    local sc = scene()
    local mx, my = mouseWorldPos()
    if key == 'r' then build(sc)
    elseif key == 'm' then spawnMipo(sc, mx, my)
    elseif key == 'w' then sc.settings.windOn = not sc.settings.windOn; apply(sc)
    elseif key == 't' then sc.settings.tearOn = not sc.settings.tearOn; apply(sc)
    elseif key == 'c' then sc.collide = not sc.collide; apply(sc)
    elseif key == 'd' then sc.debug = not sc.debug
    elseif key == 'h' then sc.showPanel = not sc.showPanel
    elseif PRESETS[tonumber(key) or 0] then usePreset(sc, tonumber(key))
    elseif key == 'f' then
        sc.fabric = sc.fabric % #cloth.fabricNames + 1
        sc.curtain.fabric = cloth.fabricNames[sc.fabric]
    end
end

-- is there a body under the hand (then the pointer takes it, not the cloth)?
local function bodyAt(x, y)
    local hit = false
    world:queryBoundingBox(x - 1, y - 1, x + 1, y + 1, function(f)
        if f:getBody():getType() ~= 'static' and f:testPoint(x, y) then hit = true; return false end
        return true
    end)
    return hit
end

local function overPanel(sc)
    local p = sc.panelRect
    if not (p and sc.showPanel and state.playMode) then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= p[1] and mx <= p[1] + p[3] and my >= p[2] and my <= p[2] + p[4]
end

local function hand(sc)
    local down = love.mouse.isDown(1)
    local mx, my = mouseWorldPos()
    if down and not sc.wasDown and not overPanel(sc) and not bodyAt(mx, my) then
        local ax = cam:getWorldCoordinates(0, 0)
        local bx = cam:getWorldCoordinates(30, 0)
        local reach = math.abs(bx - ax)
        for k = #sc.cloths, 1, -1 do -- front first
            local c = sc.cloths[k]
            local i = cloth.nearest(c, mx, my, reach)
            if i then cloth.grab(c, i, mx, my); sc.held = c; break end
        end
    elseif down and sc.held then
        cloth.drag(sc.held, mx, my)
    elseif not down and sc.held then
        cloth.release(sc.held)
        sc.held = nil
    end
    sc.wasDown = down
end

function s.update(dt)
    local sc = state.clothScene
    if not sc or not sc.cloths then return end
    if sc.bodies[1]:isDestroyed() then return end
    hand(sc)
    -- the pole springs back upright
    local pole = sc.pole
    if pole and not pole:isDestroyed() then sc.hinge:setMotorSpeed(-pole:getAngle() * 4) end
    for _, c in ipairs(sc.cloths) do cloth.update(c, dt) end
end

local function drawBox(x1, y1, x2, y2, color)
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', x1, y1, x2 - x1, y2 - y1)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle('line', x1, y1, x2 - x1, y2 - y1)
end

function s.drawBelow()
    local sc = state.clothScene
    if not sc or not sc.cloths then return end
    -- this scene draws its own ground, pole and posts: no debug bodies over them (put back in draw)
    sc.savedDrawBodies = state.world.debugDrawBodies
    state.world.debugDrawBodies = false
    love.graphics.setColor(0.93, 0.89, 0.8)
    love.graphics.rectangle('fill', -3000, -3000, 6000, 3000)
    drawBox(-3000, GROUND_TOP, 3000, GROUND_TOP + 300, GROUND)
    -- the clothesline and its posts
    local sh = sc.sheet
    drawBox(-1340, -560, -1324, GROUND_TOP, WOOD)
    drawBox(-1300 + (sh.cols - 1) * sh.spacing + 24, -560, -1300 + (sh.cols - 1) * sh.spacing + 40, GROUND_TOP, WOOD)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(2)
    love.graphics.line(-1332, -540, -1300 + (sh.cols - 1) * sh.spacing + 32, -540)
    cloth.draw(sc.sheet, { debug = sc.debug })
    -- the pole and its flag
    local pole = sc.pole
    if pole and not pole:isDestroyed() then
        love.graphics.push()
        love.graphics.translate(pole:getPosition())
        love.graphics.rotate(pole:getAngle())
        drawBox(-8, -sc.poleH / 2, 8, sc.poleH / 2, WOOD)
        love.graphics.setColor(0.9, 0.75, 0.3)
        love.graphics.circle('fill', 0, -sc.poleH / 2 - 10, 14)
        love.graphics.pop()
    end
    cloth.draw(sc.flag, { debug = sc.debug })
    -- the doorway's back: a darker room behind
    local d = sc.door
    love.graphics.setColor(0.42, 0.34, 0.3)
    love.graphics.rectangle('fill', d.x1, d.top, d.x2 - d.x1, GROUND_TOP - d.top)
end

function s.draw()
    local sc = state.clothScene
    if not sc or not sc.cloths then return end
    if sc.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = sc.savedDrawBodies
        sc.savedDrawBodies = nil
    end
    local d = sc.door
    cloth.draw(sc.curtain, { debug = sc.debug })
    drawBox(d.x1 - 40, d.top - 40, d.x1, GROUND_TOP, WOOD)
    drawBox(d.x2, d.top - 40, d.x2 + 40, GROUND_TOP, WOOD)
    drawBox(d.x1 - 60, d.top - 70, d.x2 + 60, d.top, WOOD)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(5)
    love.graphics.line(d.x1, d.top + 24, d.x2, d.top + 24)
end

local SLIDERS = {
    { key = 'wind', min = -1500, max = 1500 },
    { key = 'gust', min = 0, max = 1 },
    { key = 'flutter', min = 0.1, max = 2 },
    { key = 'substeps', min = 1, max = 16, step = 1 },
    { key = 'damping', min = 0.95, max = 1 },
    { key = 'drag', min = 0, max = 4 },
    { key = 'lift', min = 0, max = 10 },
    { key = 'gravity', min = 0, max = 2 },
    { key = 'tear', min = 1.3, max = 5 },
    { key = 'push', min = 0, max = 0.2 },
    { key = 'shade', min = 0, max = 1 },
    { key = 'fabricScale', min = 0.3, max = 3 },
    { key = 'spacing', min = 8, max = 30, step = 1, rebuild = true },
    { key = 'shear', min = 0, max = 1, rebuild = true },
    { key = 'bend', min = 0, max = 1, rebuild = true },
    { key = 'stretch', min = 0.1, max = 1, rebuild = true },
    { key = 'slack', min = 1, max = 1.3, rebuild = true },
}

function s.drawUI()
    local sc = state.clothScene
    if not (sc and state.playMode and sc.showPanel) then return end
    ui.startFrame()
    -- two columns of sliders, then the presets, then the switches
    local BH, pad, colW = 34, 8, 360
    local rows = math.ceil(#SLIDERS / 2)
    local w = colW * 2 + pad * 3
    local h = (BH + pad) * (rows + 2) + pad + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    sc.panelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• cloth ' .. (sc.preset and ('(' .. sc.preset .. ') ') or '') .. '••', function()
        local st = sc.settings
        local changed, rebuild = false, false
        local top = y0 + pad + 20
        for k, sl in ipairs(SLIDERS) do
            local x = x0 + pad + ((k - 1) % 2) * (colW + pad)
            local y = top + math.floor((k - 1) / 2) * (BH + pad)
            local v = ui.sliderWithInput('cloth' .. sl.key, x, y, 150, sl.min, sl.max, st[sl.key], nil, sl.step)
            if v and v ~= st[sl.key] then
                if sl.step then v = math.floor(v + 0.5) end
                st[sl.key] = v
                changed = true
                if sl.rebuild then rebuild = true end
                sc.preset = nil
            end
            ui.label(x + 250, y, sl.key)
        end
        local y = top + rows * (BH + pad)
        local bw = (w - pad * 5) / 4
        for k, p in ipairs(PRESETS) do
            if ui.button(x0 + pad + (k - 1) * (bw + pad), y, bw, k .. ' ' .. p.name) then
                usePreset(sc, k)
                return
            end
        end
        y = y + BH + pad
        local half = (w - pad * 3) / 2
        if ui.button(x0 + pad, y, half, st.windOn and 'wind: on' or 'wind: off') then
            st.windOn = not st.windOn; changed = true
        end
        if ui.button(x0 + pad * 2 + half, y, half, st.tearOn and 'tearing: on' or 'tearing: off') then
            st.tearOn = not st.tearOn; changed = true
        end
        if rebuild then build(sc) elseif changed then apply(sc) end
    end)
end

return s
