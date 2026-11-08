-- glasses: the first Mipo wearable, glasses that go on a face and a bump knocks off (glass lenses)
-- A pair is a loose toy (a light body). Let go of it near a Mipo's eyes and it welds on, fitted
-- to that face (the eye spacing scales it across, the eye height up). A hard bump (a landing, a
-- throw) knocks it off: the face's speed changing by more than `grip` px/s within ~0.1 s. Grab a
-- worn pair with the pointer and it comes off. The lenses are glass after the glass bead spike
-- (GLASS-BEADS.md): the
-- world is drawn into a canvas first, and each lens bends it, magnifies the middle (big eyes behind
-- thick lenses), tints it, darkens it (sunglasses), with a rim and highlights. The roundness comes
-- from src/render/form-bake.lua. Frames are greybox lines, to be swapped for Nikki's drawings.
--
-- play mode (tab): drag glasses onto faces, throw Mipos about.
-- keys: g a pair at the mouse (the next kind)   m a Mipo   w glasses on every Mipo   o all off
--       r start over   p the panel

local s = {}

-- the frames, in design units: lenses E0 apart (a typical Mipo's eye spacing at scale 0.3)
local E0 = 70
local KINDS = {
    { name = 'granny', shape = 'round', w = 58, h = 58, rim = 4, frame = { 0.78, 0.6, 0.25 },
      tint = { 0.95, 0.97, 1 }, dark = 0, lens = 0.9 },
    { name = 'nerd', shape = 'square', w = 66, h = 54, rim = 10, frame = { 0.12, 0.1, 0.12 },
      tint = { 0.88, 0.95, 1 }, dark = 0, lens = 1.4 },
    { name = 'sun', shape = 'oval', w = 68, h = 50, rim = 6, frame = { 0.1, 0.1, 0.1 },
      tint = { 0.35, 0.28, 0.22 }, dark = 0.8, lens = 0.15 },
    { name = 'heart', shape = 'heart', w = 64, h = 58, rim = 6, frame = { 0.95, 0.35, 0.55 },
      tint = { 1, 0.45, 0.6 }, dark = 0.3, lens = 0.4 },
    { name = 'red', shape = 'round', w = 68, h = 68, rim = 9, frame = { 0.85, 0.15, 0.15 },
      tint = { 0.92, 0.95, 1 }, dark = 0, lens = 0.6 },
}
local GROUND = { x = 0, w = 4200, h = 140 } -- its top at y = 0
local LIGHT = { -0.55, -0.83 }              -- towards the light, on the screen: the top left
local MASK = 128                            -- a lens mask's longer side, in pixels
local JOLT_STEPS = 6                        -- steps the jolt looks back over (~0.1 s)

local function glasses()
    state.glasses = state.glasses or {
        pairs = {}, statics = {}, mipos = {}, nextKind = 1, showPanel = true, peak = 0,
        settings = { lens = 1, bend = 1, shine = 1, glint = 1, grip = 1300, snap = 0.9 },
    }
    return state.glasses
end

---------------------------------------------------------------- lens shapes, baked once

-- a lens outline, in units (-0.5..0.5 both ways)
local function shapePoints(shape, n)
    n = n or 48
    local pts = {}
    if shape == 'heart' then
        local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
        for i = 0, n - 1 do
            local t = i / n * math.pi * 2
            local x = 16 * math.sin(t) ^ 3
            local y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            pts[#pts + 1] = { x, y }
            minx, maxx, miny, maxy = math.min(minx, x), math.max(maxx, x), math.min(miny, y), math.max(maxy, y)
        end
        for _, p in ipairs(pts) do
            p[1] = (p[1] - minx) / (maxx - minx) - 0.5
            p[2] = (p[2] - miny) / (maxy - miny) - 0.5
        end
        return pts
    end
    local power = shape == 'square' and 4 or 2 -- a superellipse: 4 a rounded square
    for i = 0, n - 1 do
        local t = i / n * math.pi * 2
        local c, si = math.cos(t), math.sin(t)
        local x = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / power)
        local y = (si < 0 and -1 or 1) * math.abs(si) ^ (2 / power)
        pts[#pts + 1] = { x * 0.5, y * 0.5 }
    end
    return pts
end

local function inside(pts, x, y)
    local hit = false
    local j = #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then hit = not hit end
        j = i
    end
    return hit
end

-- per kind: the mask (white, alpha the coverage, 2x2 samples a pixel), its roundness and dome
local looks = {}
local function look(kind)
    if looks[kind.name] then return looks[kind.name] end
    local pts = shapePoints(kind.shape, 64)
    local aspect = kind.h / kind.w
    local mw, mh = MASK, math.max(8, math.floor(MASK * aspect))
    if aspect > 1 then mw, mh = math.max(8, math.floor(MASK / aspect)), MASK end
    local data = love.image.newImageData(mw, mh)
    for py = 0, mh - 1 do
        for px = 0, mw - 1 do
            local cov = 0
            for sy = 0, 1 do
                for sx = 0, 1 do
                    if inside(pts, (px + 0.25 + sx * 0.5) / mw - 0.5, (py + 0.25 + sy * 0.5) / mh - 0.5) then
                        cov = cov + 0.25
                    end
                end
            end
            data:setPixel(px, py, 1, 1, 1, cov)
        end
    end
    local function image(d)
        local img = love.graphics.newImage(d)
        img:setFilter('linear', 'linear')
        return img
    end
    local l = {
        mask = image(data), mw = mw, mh = mh, pts = pts,
        hmap = image(formBake.bakeData(data, 0.35)), -- a pebble: round rim, flatter middle
        lensMap = image(formBake.bakeData(data, 1)), -- one dome: how much the middle magnifies
    }
    looks[kind.name] = l
    return l
end

---------------------------------------------------------------- the lens shader

local lensShader = love.graphics.newShader([[
uniform Image hmap;
uniform Image lensMap;
uniform Image back;      // the world behind, as on the screen
uniform vec2 screen;     // pixels
uniform vec2 centre;     // the lens's middle, in pixels
uniform float angle;     // the glasses' turn, to bring the normal onto the screen
uniform float lens;      // how much the middle magnifies (below 0 it shrinks)
uniform float bend;      // how far the rim bends what's behind, in pixels
uniform vec3 tint;
uniform float dark;      // sunglasses
uniform float shine;
uniform float glint;     // the storybook stripe across a lens
uniform vec2 lightDir;   // towards the light, on the screen

vec4 effect(vec4 color, Image mask, vec2 uv, vec2 pc) {
    float cov = Texel(mask, uv).a;
    if (cov < 0.01) discard;
    vec4 hm = Texel(hmap, uv);
    float h = hm.r;
    vec2 nb = (hm.gb - 0.5) * 2.0;
    float c = cos(angle), s = sin(angle);
    vec2 ns = vec2(nb.x * c - nb.y * s, nb.x * s + nb.y * c);
    float nz = sqrt(max(0.0, 1.0 - dot(ns, ns)));
    vec3 n = vec3(ns, nz);
    float edge = 1.0 - nz;
    // magnified in the middle, bent at the rim
    float dome = Texel(lensMap, uv).r;
    float z = max(0.3, 1.0 + lens * dome);
    vec2 look = centre + (pc - centre) / z - ns * bend * (0.4 + 0.6 * h);
    vec3 behind = Texel(back, look / screen).rgb;
    vec3 col = behind * mix(vec3(1.0), tint, 0.3 + 0.4 * h) * (1.0 - dark) + tint * 0.05;
    // the rim: darker, a pale line right at the edge
    float fres = pow(edge, 2.2);
    col *= mix(1.0, 0.6, fres * 0.8);
    col += vec3(1.0) * pow(edge, 6.0) * 0.3 * shine;
    // highlights from the top left, a sharp and a soft one
    vec3 L = normalize(vec3(normalize(lightDir), 0.9));
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    float nh = max(0.0, dot(n, H));
    col += vec3(1.0) * (pow(nh, 90.0) * 1.0 + pow(nh, 12.0) * 0.1) * shine;
    // the glint: two slanted stripes, as drawn on glasses in picture books
    float d = uv.x + uv.y;
    float stripe = smoothstep(0.02, 0.0, abs(d - 0.62) - 0.07) + 0.6 * smoothstep(0.02, 0.0, abs(d - 0.86) - 0.025);
    col = mix(col, vec3(1.0), stripe * 0.45 * glint);
    return vec4(col, cov) * color;
}
]])

---------------------------------------------------------------- bodies

local function alivePairs(b)
    local out = {}
    for _, g in ipairs(b.pairs) do
        if g.body and not g.body:isDestroyed() then out[#out + 1] = g end
    end
    return out
end

local function aliveMipos(b)
    local out = {}
    for _, inst in ipairs(b.mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then out[#out + 1] = inst end
    end
    return out
end

-- every Mipo in the scene, not only ours
local function allMipos()
    local out = {}
    for _, inst in pairs(mipoRegistry.getAll()) do out[#out + 1] = inst end
    return out
end

local function headOf(inst)
    local name = inst.dna and inst.dna.creation and inst.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = inst.parts and inst.parts[name]
    if part and part.body and not part.body:isDestroyed() then return part.body end
end

-- where the glasses sit on this face: the eyes' middle in the world, the head's angle, and the
-- fit (x from the eye spacing, y from how tall the eyes are for that spacing)
local function fitOn(head)
    local l, r
    for _, f in ipairs(head:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.extra then
            if ud.label == 'lpupil' then l = ud.extra elseif ud.label == 'rpupil' then r = ud.extra end
        end
    end
    if not (l and r) then return nil end
    local lx, ly, rx, ry = l.ox or 0, l.oy or 0, r.ox or 0, r.oy or 0
    local spacing = math.max(1, math.abs(rx - lx))
    local sx = math.max(0.35, spacing / E0)
    local tall = (l.eyeH or l.h or spacing) / spacing
    local sy = sx * mathutils.clamp(tall, 0.85, 1.5)
    local wx, wy = head:getWorldPoint((lx + rx) / 2, (ly + ry) / 2)
    return wx, wy, head:getAngle(), sx, sy
end

local function addPair(b, x, y, kindIndex)
    kindIndex = kindIndex or b.nextKind
    b.nextKind = kindIndex % #KINDS + 1
    local kind = KINDS[kindIndex]
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = E0 + kind.w, height = kind.h * 0.8,
        bodyType = 'dynamic', label = 'glasses', density = 0.3 })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.6); fixture:setRestitution(0.2)
    end
    local g = { body = thing.body, kind = kindIndex, cooldown = 0, seed = love.math.random(1000) }
    b.pairs[#b.pairs + 1] = g
    return g
end

-- worn: they touch nothing (a neighbour's head, a wall: a bump there tore them off while the Mipos
-- only stood about), but the pointer can still grab them (it skips sensors, so not a sensor)
local function setWorn(g, worn)
    for _, fixture in ipairs(g.body:getFixtures()) do
        if worn then fixture:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16) else fixture:setMask() end
    end
end

local function wear(g, _inst, head)
    local wx, wy, a = fitOn(head)
    if not wx then return end
    g.body:setPosition(wx, wy)
    g.body:setAngle(a)
    g.body:setLinearVelocity(head:getLinearVelocityFromWorldPoint(wx, wy))
    g.body:setAngularVelocity(head:getAngularVelocity())
    setWorn(g, true)
    g.joint = love.physics.newWeldJoint(head, g.body, wx, wy, false)
    g.head, g.peak, g.vel = head, 0, nil
    g.settle = 0.4 -- the weld's first pulls (the glasses catching up with the head) don't count
end

local function takeOff(g, pop)
    if g.joint and not g.joint:isDestroyed() then g.joint:destroy() end
    g.joint, g.head = nil, nil
    if not g.body:isDestroyed() then
        setWorn(g, false)
        if pop then
            local vx, vy = g.body:getLinearVelocity()
            g.body:setLinearVelocity(vx + (love.math.random() - 0.5) * 300, vy - 250)
            g.body:setAngularVelocity((love.math.random() - 0.5) * 12)
        end
    end
    g.cooldown = 0.8
end

local function staticBox(b, x, y, w, h)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = 'glasses-floor' })
    if thing then
        for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setFriction(0.8) end
        b.statics[#b.statics + 1] = { body = thing.body }
    end
end

local function buildRoom(b)
    for _, t in ipairs(b.statics) do
        if t.body and not t.body:isDestroyed() then return end
    end
    b.statics = {}
    staticBox(b, GROUND.x, GROUND.h / 2, GROUND.w, GROUND.h)
    staticBox(b, GROUND.x - GROUND.w / 2 - 20, -1200, 40, 2400)
    staticBox(b, GROUND.x + GROUND.w / 2 + 20, -1200, 40, 2400)
end

local function spawnMipo(b, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then b.mipos[#b.mipos + 1] = inst end
end

local function stock(b)
    for _, g in ipairs(alivePairs(b)) do
        takeOff(g)
        objectManager.destroyBody(g.body)
    end
    b.pairs = {}
    for i = 1, #KINDS do addPair(b, -900 + (i - 1) * 450, -200, i) end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = glasses()
    buildRoom(b)
    b.pairs = alivePairs(b)
    if #b.pairs == 0 then stock(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        for i = 1, 4 do spawnMipo(b, -1050 + i * 420, -700) end
    end
end

function s.onUnload()
    local b = state.glasses
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.update(dt)
    local b = state.glasses
    if not b then return end
    b.pairs = alivePairs(b)
    local set = b.settings
    for _, g in ipairs(b.pairs) do
        if g.joint then
            if g.joint:isDestroyed() or not g.head or g.head:isDestroyed() then
                takeOff(g)
            elseif getPJAttachedTo(g.body) then
                takeOff(g) -- picked off the face by hand
            else
                -- the jolt: how much the face's speed changed over the last ~0.1 s (JOLT_STEPS
                -- steps). A landing or a throw changes it a lot; a standing Mipo's head jitters
                -- (its pull on the weld spiked as high as a throw's, 2026-11-08) but its speed
                -- hardly moves.
                local vx, vy = g.head:getLinearVelocityFromWorldPoint(g.body:getPosition())
                g.vel = g.vel or {}
                table.insert(g.vel, 1, { vx, vy })
                g.vel[JOLT_STEPS + 1] = nil
                local old = g.vel[#g.vel]
                local jolt = math.sqrt((vx - old[1]) ^ 2 + (vy - old[2]) ^ 2)
                g.settle = math.max(0, (g.settle or 0) - dt)
                if g.settle <= 0 then
                    g.peak = math.max(g.peak or 0, jolt)
                    b.peak = math.max(b.peak * 0.995, jolt)
                    if jolt > set.grip then
                        print(string.format('[glasses] off: jolt %d over grip %d', jolt, set.grip))
                        takeOff(g, true)
                    end
                end
            end
        else
            g.cooldown = math.max(0, (g.cooldown or 0) - dt)
            g.near = nil
            local held = getPJAttachedTo(g.body) ~= nil
            if g.cooldown <= 0 then
                local gx, gy = g.body:getPosition()
                local best, bestD
                for _, inst in ipairs(allMipos()) do
                    local head = headOf(inst)
                    local wx, wy, _, sx
                    if head then wx, wy, _, sx = fitOn(head) end
                    if wx then
                        local d = math.sqrt((gx - wx) ^ 2 + (gy - wy) ^ 2)
                        if d < set.snap * E0 * sx and (not bestD or d < bestD) then best, bestD = inst, d end
                    end
                end
                if best then
                    -- held over a face: shown; let go: on
                    if held then g.near = best else wear(g, best, headOf(best)) end
                end
            end
        end
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = glasses()
    local mx, my = mouseWorldPos()
    if key == 'g' then addPair(b, mx, my)
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'r' then stock(b)
    elseif key == 'p' then b.showPanel = not b.showPanel
    elseif key == 'o' then
        for _, g in ipairs(alivePairs(b)) do if g.joint then takeOff(g, true) end end
    elseif key == 'w' then
        -- a pair on every bare face: a free one if there is, else a new one
        local worn = {}
        for _, g in ipairs(alivePairs(b)) do if g.head then worn[g.head] = true end end
        for _, inst in ipairs(allMipos()) do
            local head = headOf(inst)
            if head and not worn[head] then
                local free
                for _, g in ipairs(alivePairs(b)) do
                    if not g.joint and not getPJAttachedTo(g.body) then free = g; break end
                end
                free = free or addPair(b, head:getPosition())
                if free then wear(free, inst, head) end
            end
        end
    end
end

---------------------------------------------------------------- drawing

local backCanvas
local function backdrop()
    local pw, ph = love.graphics.getPixelDimensions()
    local w, h = love.graphics.getDimensions()
    local _, _, flags = love.window.getMode()
    if not backCanvas or backCanvas:getPixelWidth() ~= pw or backCanvas:getPixelHeight() ~= ph then
        if backCanvas then backCanvas:release() end
        backCanvas = love.graphics.newCanvas(w, h, { msaa = flags.msaa or 0 })
    end
    return backCanvas
end

-- a plain room: a wallpaper with soft stripes, a wooden floor
local function drawRoom()
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getDimensions())
    love.graphics.setColor(0.93, 0.88, 0.76)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    love.graphics.setColor(0.86, 0.72, 0.6, 0.5)
    for x = math.floor(x0 / 160) * 160, x1, 160 do
        love.graphics.rectangle('fill', x, y0, 40, y1 - y0)
    end
    love.graphics.setColor(0.62, 0.45, 0.32)
    love.graphics.rectangle('fill', GROUND.x - GROUND.w / 2, 0, GROUND.w, math.max(GROUND.h, y1))
    love.graphics.setColor(0.75, 0.58, 0.42)
    love.graphics.rectangle('fill', GROUND.x - GROUND.w / 2, 0, GROUND.w, 18)
end

-- the frame round a lens: the lens outline a rim wider, a little wobbly (drawn, not machined)
local function frameLine(l, kind, cx, seed)
    local pts = {}
    local rng = love.math.newRandomGenerator(seed)
    for _, p in ipairs(l.pts) do
        local wob = 1 + (rng:random() - 0.5) * 0.04
        pts[#pts + 1] = cx + p[1] * (kind.w + kind.rim) * wob
        pts[#pts + 1] = p[2] * (kind.h + kind.rim) * wob
    end
    return pts
end

local function drawPair(b, g, x, y, angle, sx, sy)
    local kind = KINDS[g.kind]
    local l = look(kind)
    local set = b.settings
    local dpi = love.graphics.getDPIScale()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    love.graphics.scale(sx, sy)
    -- the lenses: glass over what's behind
    love.graphics.setShader(lensShader)
    lensShader:send('hmap', l.hmap)
    lensShader:send('lensMap', l.lensMap)
    lensShader:send('angle', angle)
    lensShader:send('lens', kind.lens * set.lens)
    lensShader:send('tint', kind.tint)
    lensShader:send('dark', kind.dark)
    love.graphics.setColor(1, 1, 1, 1)
    for _, cx in ipairs({ -E0 / 2, E0 / 2 }) do
        local px, py = love.graphics.transformPoint(cx, 0)
        lensShader:send('centre', { px * dpi, py * dpi })
        love.graphics.draw(l.mask, cx, 0, 0, kind.w / l.mw, kind.h / l.mh, l.mw / 2, l.mh / 2)
    end
    love.graphics.setShader()
    -- the frame: two rims, a bridge, the temples' hinges
    local c = kind.frame
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.setLineWidth(kind.rim)
    love.graphics.setLineJoin('bevel')
    for i, cx in ipairs({ -E0 / 2, E0 / 2 }) do
        love.graphics.polygon('line', frameLine(l, kind, cx, g.seed + i))
    end
    local inner = E0 / 2 - (kind.w + kind.rim) / 2
    local bridge = love.math.newBezierCurve(-inner, -kind.h * 0.12, 0, -kind.h * 0.32, inner, -kind.h * 0.12)
    love.graphics.line(bridge:render(3))
    local outer = E0 / 2 + (kind.w + kind.rim) / 2
    love.graphics.line(-outer, -kind.h * 0.18, -outer - kind.w * 0.18, -kind.h * 0.1)
    love.graphics.line(outer, -kind.h * 0.18, outer + kind.w * 0.18, -kind.h * 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

function s.drawBelow()
    local b = state.glasses
    if not b then return end
    -- the room into a canvas, and the canvas stays on: the game draws the Mipos into it too, so
    -- the lenses can bend them; s.draw puts it on the screen (as in the glass spike)
    local canvas = backdrop()
    b.before = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true }) -- the mouths clip with a stencil
    love.graphics.clear(0, 0, 0, 1)
    drawRoom()
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false -- the glasses' box would show
    end
    b.drawing = true
end

function s.draw()
    local b = state.glasses
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    love.graphics.setCanvas(b.before)
    b.before = nil
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(backCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
    local set = b.settings
    local pw, ph = love.graphics.getPixelDimensions()
    local dpi = love.graphics.getDPIScale()
    lensShader:send('back', backCanvas)
    lensShader:send('screen', { pw, ph })
    lensShader:send('lightDir', LIGHT)
    lensShader:send('bend', 10 * set.bend * cam:getScale() / 0.35 * dpi)
    lensShader:send('shine', set.shine)
    lensShader:send('glint', set.glint)
    for _, g in ipairs(alivePairs(b)) do
        local wx, wy, a, sx, sy
        if g.head and not g.head:isDestroyed() then
            wx, wy, a, sx, sy = fitOn(g.head) -- right on the face, whatever the weld does
        end
        if not wx then
            wx, wy = g.body:getPosition()
            a, sx, sy = g.body:getAngle(), 1, 1
        end
        drawPair(b, g, wx, wy, a, sx, sy)
        -- held over a face: a ring round the eyes to say "let go"
        local near = g.near and headOf(g.near)
        if near then
            local nx, ny, _, nsx = fitOn(near)
            if nx then
                love.graphics.setColor(1, 1, 1, 0.5 + 0.3 * math.sin(love.timer.getTime() * 8))
                love.graphics.setLineWidth(4)
                love.graphics.circle('line', nx, ny, E0 * nsx)
                love.graphics.setLineWidth(1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.glasses and glasses()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'lens', -0.5, 3 }, { 'bend', 0, 3 }, { 'shine', 0, 2 }, { 'glint', 0, 2 },
        { 'grip', 100, 3000 }, { 'snap', 0.2, 2 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• glasses ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('glasses' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('jolt now %d px/s (off over grip)', math.floor(b.peak)))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'g glasses  m Mipo  w all on  o all off  r reset  p panel')
    end)
end

return s
