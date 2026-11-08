-- wearables: things Mipos wear as loose toys: glasses (glass lenses), underpants (boxers, knickers, briefs)
-- Each is a light body of its own. Let go of it near its spot (glasses: the eyes, pants: the hips)
-- and it goes on (src/wearables.lua): a jolt (a landing, a throw) or a grab with the pointer and
-- it comes off.
-- Glasses are fitted to the face (the eye spacing scales them across, the eye height up). Their
-- lenses are glass after the glass bead spike (GLASS-BEADS.md): the world is drawn into a canvas
-- first, and each lens bends it, magnifies the middle (big eyes behind thick lenses), tints it,
-- darkens it (sunglasses), with a rim, highlights and a glint; roundness from form-bake. Drawn over
-- everything.
-- Pants are cut from the Mipo itself: a seat from the torso's outline (its shape8, as the skin is
-- drawn) below a waistline, a tube down each upper leg from the hip joint toward the knee, a
-- waistband, a pattern. Drawn inside the Mipo's own layers (state.drawSplits): over the torso and
-- the legs, under the feet, the nose and the arms. Greybox, to be swapped for Nikki's drawings.
--
-- play mode (tab): drag glasses onto faces and pants onto hips, throw Mipos about.
-- keys: g a pair of glasses (the next kind)   u underpants (the next kind)   m a Mipo
--       w glasses on every Mipo   n pants on every Mipo   o all off   r start over   p the panel

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
-- underpants: waist (how far down the torso the waistband is, 0 top .. 1 bottom), leg (how far
-- down the upper leg, hip 0 .. knee 1), legW (the tube's width, a part of the torso's), flare
-- (the hem wider than the top), base / band / ink colours, a pattern
local PANTS = {
    { name = 'boxers', waist = 0.5, leg = 0.5, legW = 0.34, flare = 1.25, base = { 0.3, 0.45, 0.85 },
      band = { 0.93, 0.93, 0.96 }, pattern = 'dots', ink = { 1, 1, 1 } },
    { name = 'striped boxers', waist = 0.48, leg = 0.45, legW = 0.34, flare = 1.2, base = { 0.97, 0.95, 0.88 },
      band = { 0.85, 0.2, 0.2 }, pattern = 'stripes', ink = { 0.85, 0.2, 0.2 } },
    { name = 'knickers', waist = 0.66, leg = 0.06, legW = 0.3, flare = 1, base = { 1, 0.6, 0.75 },
      band = { 1, 0.93, 0.96 }, pattern = 'dots', ink = { 1, 0.86, 0.92 } },
    { name = 'briefs', waist = 0.6, leg = 0.1, legW = 0.3, flare = 1, base = { 0.97, 0.97, 0.97 },
      band = { 0.25, 0.45, 0.85 } },
}
local PANTS_Z = 302 -- in a Mipo's own layers: over the legs (300, 301), under the nose (350), feet (399), arms (402)
local OUTLINE = { 0.12, 0.1, 0.12 }
local GROUND = { x = 0, w = 4200, h = 140 } -- its top at y = 0
local LIGHT = { -0.55, -0.83 }              -- towards the light, on the screen: the top left
local MASK = 128                            -- a lens mask's longer side, in pixels

local function room()
    state.wearables = state.wearables or {
        items = {}, statics = {}, mipos = {}, nextGlasses = 1, nextPants = 1, showPanel = true, peak = 0,
        settings = { lens = 1, bend = 1, shine = 1, glint = 1, grip = 1300, pantsGrip = 1600, snap = 0.9 },
    }
    return state.wearables
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

---------------------------------------------------------------- Mipos

local function aliveItems(b)
    local out = {}
    for _, item in ipairs(b.items) do
        if item.body and not item.body:isDestroyed() then out[#out + 1] = item end
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

local function partBody(inst, name)
    local part = inst.parts and inst.parts[name]
    if part and part.body and not part.body:isDestroyed() then return part.body end
end

local function headOf(inst)
    local potato = inst.dna and inst.dna.creation and inst.dna.creation.isPotatoHead
    return partBody(inst, potato and 'torso1' or 'head')
end

-- a face decal's extra by label ('lpupil', 'lowerlip', ...)
local function decal(body, label)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.extra and ud.label == label then return ud.extra end
    end
end

-- where glasses sit on this face: the eyes' middle in the world, the head's angle, and the fit
-- (x from the eye spacing, y from how tall the eyes are for that spacing)
local function fitOn(head)
    local l, r = decal(head, 'lpupil'), decal(head, 'rpupil')
    if not (l and r) then return nil end
    local lx, ly, rx, ry = l.ox or 0, l.oy or 0, r.ox or 0, r.oy or 0
    local spacing = math.max(1, math.abs(rx - lx))
    local sx = math.max(0.35, spacing / E0)
    local tall = (l.eyeH or l.h or spacing) / spacing
    local sy = sx * mathutils.clamp(tall, 0.85, 1.5)
    local wx, wy = head:getWorldPoint((lx + rx) / 2, (ly + ry) / 2)
    return wx, wy, head:getAngle(), sx, sy
end

---------------------------------------------------------------- pants, cut from the Mipo

-- the joint between two bodies, and its anchor on each (local)
local function jointBetween(a, b)
    for _, j in ipairs(a:getJoints()) do
        local ja, jb = j:getBodies()
        if (ja == a and jb == b) or (ja == b and jb == a) then
            local x, y = j:getAnchors()
            local ax, ay = a:getLocalPoint(x, y)
            local bx, by = b:getLocalPoint(x, y)
            return ax, ay, bx, by
        end
    end
end

-- the torso part the upper legs hang from
local function hipTorso(inst)
    local leg = partBody(inst, 'luleg')
    if not leg then return nil end
    for name, part in pairs(inst.parts) do
        if name:match('^torso') and part.body and not part.body:isDestroyed() and jointBetween(part.body, leg) then
            return name, part.body
        end
    end
end

-- the torso's skin as drawn: its mask picture (white inside), laid over the box of its texfixture
-- (the picture is the shape8 document * 1.1, margins and all: the 8-point outline is only roughly
-- where the torso shows), the flips, and the rows where the mask has something (0..1 down the picture)
local masks = {}
local function maskOf(url)
    if masks[url] == nil then
        local ok, data = pcall(love.image.newImageData, 'textures/' .. url)
        if not ok then masks[url] = false; return nil end
        local iw, ih = data:getDimensions()
        local first, last
        for py = 0, ih - 1, 2 do
            for px = 0, iw - 1, 4 do
                local r, _, _, al = data:getPixel(px, py)
                if r * al > 0.5 then
                    first = first or py
                    last = py
                    break
                end
            end
        end
        local img = love.graphics.newImage(data)
        img:setFilter('linear', 'linear')
        masks[url] = { img = img, w = iw, h = ih, top = (first or 0) / ih, bottom = (last or ih) / ih }
    end
    return masks[url] or nil
end

local function torsoSkin(torso)
    for _, f in ipairs(torso:getFixtures()) do
        local ud = f:getUserData()
        local main = ud and ud.subtype == 'texfixture' and ud.extra and ud.extra.main
        if main and main.fgURL and main.fgURL ~= '' and not main.fgURL:match('hair') then
            local mask = maskOf(main.fgURL)
            if mask then
                local verts = ud.extra.vertices or { f:getShape():getPoints() }
                local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
                for i = 1, #verts, 2 do
                    x0, x1 = math.min(x0, verts[i]), math.max(x1, verts[i])
                    y0, y1 = math.min(y0, verts[i + 1]), math.max(y1, verts[i + 1])
                end
                local fy = main.fy or 1
                -- where the torso shows, top to bottom, in the body's frame
                local ta, tb = mask.top, mask.bottom
                if fy < 0 then ta, tb = 1 - tb, 1 - ta end
                return { mask = mask, corners = verts, x0 = x0, y0 = y0, x1 = x1, y1 = y1, fx = main.fx or 1, fy = fy,
                    top = y0 + (y1 - y0) * ta, bottom = y0 + (y1 - y0) * tb }
            end
        end
    end
end

-- one tube down an upper leg: from a little above the hip (into the seat) toward the knee
local function legTube(inst, torso, legName, kind, torsoW)
    local leg = partBody(inst, legName)
    if not leg then return nil end
    local _, _, hx, hy = jointBetween(torso, leg)
    local knee = partBody(inst, legName:sub(1, 1) .. 'lleg')
    local kx, ky
    if knee then kx, ky = jointBetween(leg, knee) end
    if not (hx and kx) then return nil end
    local dx, dy = kx - hx, ky - hy
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    dx, dy = dx / len, dy / len
    local nx, ny = -dy, dx
    local half = torsoW * kind.legW / 2
    local tx, ty = hx - dx * half * 0.8, hy - dy * half * 0.8
    local bx, by = hx + dx * len * kind.leg, hy + dy * len * kind.leg
    local f = half * kind.flare
    return { body = leg, poly = { tx + nx * half, ty + ny * half, bx + nx * f, by + ny * f,
        bx - nx * f, by - ny * f, tx - nx * half, ty - ny * half } }
end

-- the pants on this Mipo: the seat (the torso's skin below the waist), a tube per upper leg, the
-- band; or nil
local function pantsOn(inst, kind)
    local _, torso = hipTorso(inst)
    if not torso then return nil end
    -- the picture is on torso1 (a spine's too); the legs hang from the last band
    local skinBody = partBody(inst, 'torso1')
    local skin = skinBody and torsoSkin(skinBody)
    if not skin then return nil end
    local w, h = skin.x1 - skin.x0, skin.bottom - skin.top
    local waist = skin.top + h * kind.waist
    -- a potato head: the waistband stays below the mouth
    local lip = inst.dna.creation.isPotatoHead and decal(skinBody, 'lowerlip')
    if lip and lip.oy then waist = math.max(waist, lip.oy + h * 0.12) end
    local legs = {}
    for _, legName in ipairs({ 'luleg', 'ruleg' }) do
        legs[#legs + 1] = legTube(inst, torso, legName, kind, w * 0.85)
    end
    return { body = skinBody, skin = skin, waist = waist, bandH = h * 0.07, legs = legs, w = w * 0.85 }
end

-- where pants go on this Mipo: between its hips
local function hipsOf(inst)
    local _, torso = hipTorso(inst)
    if not torso then return nil end
    local l, r = partBody(inst, 'luleg'), partBody(inst, 'ruleg')
    if not (l and r) then return nil end
    local lx, ly = jointBetween(torso, l)
    local rx, ry = jointBetween(torso, r)
    if not (lx and rx) then return nil end
    local wx, wy = torso:getWorldPoint((lx + rx) / 2, (ly + ry) / 2)
    return torso, wx, wy, torso:getAngle(), math.max(60, math.abs(rx - lx) * 1.5)
end

---------------------------------------------------------------- items

local function spot(item, inst)
    if item.sort == 'pants' then
        local torso, wx, wy, a, reach = hipsOf(inst)
        if torso then return torso, wx, wy, a, reach * state.wearables.settings.snap end
        return nil
    end
    local head = headOf(inst)
    local wx, wy, a, sx
    if head then wx, wy, a, sx = fitOn(head) end
    if wx then return head, wx, wy, a, state.wearables.settings.snap * E0 * sx end
end

-- one of each sort on a Mipo
local function wornBy(b, sort, inst)
    for _, other in ipairs(b.items) do
        if other.sort == sort and other.wearer == inst then return other end
    end
end

local function addItem(b, sort, x, y, kindIndex)
    local list = sort == 'pants' and PANTS or KINDS
    local key = sort == 'pants' and 'nextPants' or 'nextGlasses'
    kindIndex = kindIndex or b[key]
    b[key] = kindIndex % #list + 1
    local kind = list[kindIndex]
    local w, h = 150, 110 -- pants
    if sort == 'glasses' then w, h = E0 + kind.w, kind.h * 0.8 end
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'dynamic', label = sort, density = 0.3 })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.6); fixture:setRestitution(0.2)
    end
    local item = { body = thing.body, sort = sort, kind = kindIndex, cooldown = 0, seed = love.math.random(1000) }
    b.items[#b.items + 1] = item
    return item
end

local function putOn(item, inst)
    local host, wx, wy, a = spot(item, inst)
    if host then
        wearables.wear(item, host, wx, wy, a)
        item.wearer = inst
    end
end

-- an item of this sort on every Mipo without one: a free one if there is, else a new one
local function dressAll(b, sort)
    for _, inst in ipairs(allMipos()) do
        if not wornBy(b, sort, inst) and spot({ sort = sort }, inst) then
            local free
            for _, item in ipairs(aliveItems(b)) do
                if item.sort == sort and not item.joint and not wearables.held(item) then free = item; break end
            end
            local x, y = partBody(inst, 'torso1'):getPosition()
            free = free or addItem(b, sort, x, y)
            if free then putOn(free, inst) end
        end
    end
end

local function staticBox(b, x, y, w, h)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = 'wearables-floor' })
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
    for _, item in ipairs(aliveItems(b)) do
        wearables.takeOff(item)
        objectManager.destroyBody(item.body)
    end
    b.items = {}
    for i = 1, #KINDS do addItem(b, 'glasses', -900 + (i - 1) * 450, -200, i) end
    for i = 1, #PANTS do addItem(b, 'pants', -700 + (i - 1) * 450, -100, i) end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = room()
    buildRoom(b)
    b.items = aliveItems(b)
    if #b.items == 0 then stock(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        for i = 1, 4 do spawnMipo(b, -1050 + i * 420, -700) end
    end
end

function s.onUnload()
    state.drawSplits = nil
    local b = state.wearables
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.update(dt)
    local b = state.wearables
    if not b then return end
    b.items = aliveItems(b)
    local set = b.settings
    local mipos = allMipos()
    local optsFor = {
        glasses = { mipos = mipos, spot = spot, grip = set.grip },
        pants = { mipos = mipos, spot = spot, grip = set.pantsGrip },
    }
    for _, opts in pairs(optsFor) do
        opts.taken = function(item, inst) return wornBy(b, item.sort, inst) ~= nil end
    end
    for _, item in ipairs(b.items) do
        local knocked = wearables.update(item, dt, optsFor[item.sort])
        if knocked then print(string.format('[wearables] %s off: jolt %d', item.sort, knocked)) end
        if item.joint and item.vel and item.vel[1] then
            local v, old = item.vel[1], item.vel[#item.vel]
            b.peak = math.max(b.peak * 0.995, math.sqrt((v[1] - old[1]) ^ 2 + (v[2] - old[2]) ^ 2))
        end
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = room()
    local mx, my = mouseWorldPos()
    if key == 'g' then addItem(b, 'glasses', mx, my)
    elseif key == 'u' then addItem(b, 'pants', mx, my)
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'r' then stock(b)
    elseif key == 'p' then b.showPanel = not b.showPanel
    elseif key == 'o' then
        for _, item in ipairs(aliveItems(b)) do if item.joint then wearables.takeOff(item, true) end end
    elseif key == 'w' then dressAll(b, 'glasses')
    elseif key == 'n' then dressAll(b, 'pants')
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

local function drawGlasses(b, item, x, y, angle, sx, sy)
    local kind = KINDS[item.kind]
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
        love.graphics.polygon('line', frameLine(l, kind, cx, item.seed + i))
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

-- a polygon of any shape filled (love's fill wants convex ones)
local function fillPoly(poly)
    if #poly < 6 then return end
    local ok, tris = pcall(love.math.triangulate, poly)
    if not ok then return end
    for _, t in ipairs(tris) do love.graphics.polygon('fill', t) end
end

local function onBody(body, fn)
    love.graphics.push()
    if body then
        love.graphics.translate(body:getPosition())
        love.graphics.rotate(body:getAngle())
    end
    fn()
    love.graphics.pop()
end

-- the pattern over one piece's box, in its own frame: dots in rows, or upright stripes
local function drawPattern(kind, poly, size)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #poly, 2 do
        x0, x1 = math.min(x0, poly[i]), math.max(x1, poly[i])
        y0, y1 = math.min(y0, poly[i + 1]), math.max(y1, poly[i + 1])
    end
    local step = size * 0.14
    love.graphics.setColor(kind.ink)
    if kind.pattern == 'dots' then
        local row = 0
        for y = y0, y1 + step, step do
            row = row + 1
            for x = x0 - step + (row % 2) * step / 2, x1 + step, step do
                love.graphics.circle('fill', x, y, size * 0.03)
            end
        end
    elseif kind.pattern == 'stripes' then
        for x = math.floor(x0 / step) * step, x1, step do
            love.graphics.rectangle('fill', x, y0, size * 0.045, y1 - y0)
        end
    end
end

-- a mask picture as a shape, only the rows between vMin and vMax (0..1 down the picture), its
-- edge (olStep in from it, in picture units) in lineColor. flip: the picture mirrored (the torso's
-- fx / fy), so the cut and the edge are where the drawn torso has them.
local cutShader = love.graphics.newShader([[
uniform float vMin;
uniform float vMax;
uniform vec2 olStep;
uniform vec4 lineColor;
uniform vec2 flip;
float inside(Image tex, vec2 p) { vec4 m = Texel(tex, p); return step(0.5, m.r * m.a); }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pc) {
    vec2 p = mix(uv, 1.0 - uv, flip);
    if (inside(tex, p) < 0.5 || p.y < vMin || p.y > vMax) discard;
    float edge = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7854;
        edge = max(edge, 1.0 - inside(tex, p + vec2(cos(a), sin(a)) * olStep));
    }
    return mix(color, lineColor, edge);
}
]])

-- the torso's mask between rows ya and yb (the body's frame, at rest), in the current colour, its
-- edge ol wide in lineColor. Bent like the torso picture when the torso is (lobes, a spine: the
-- same spineSkin grid the skin is drawn with, so the pants stay on what you see); else laid flat.
local function drawSeat(seat, ya, yb, lineColor, ol)
    local skin = seat.skin
    local w, h = skin.x1 - skin.x0, skin.y1 - skin.y0
    local va, vb = (ya - skin.y0) / h, (yb - skin.y0) / h
    if skin.fy < 0 then va, vb = 1 - vb, 1 - va end
    love.graphics.setShader(cutShader)
    cutShader:send('vMin', va)
    cutShader:send('vMax', vb)
    cutShader:send('olStep', { ol / w, ol / h })
    cutShader:send('lineColor', lineColor or { 0, 0, 0, 0 })
    cutShader:send('flip', { skin.fx < 0 and 1 or 0, skin.fy < 0 and 1 or 0 })
    local m = skin.mask
    local bones = spineSkin.torsoBones(seat.body)
    if bones and #skin.corners == 8 then
        if not lineColor then cutShader:send('lineColor', { love.graphics.getColor() }) end
        spineSkin.drawGrid(m.img, skin.corners, bones, seat.body, seat.key)
    else
        if not lineColor then cutShader:send('lineColor', { love.graphics.getColor() }) end
        onBody(seat.body, function()
            love.graphics.draw(m.img, (skin.x0 + skin.x1) / 2, (skin.y0 + skin.y1) / 2, 0,
                w / m.w * skin.fx, h / m.h * skin.fy, m.w / 2, m.h / 2)
        end)
    end
    love.graphics.setShader()
end

-- one garment: the leg pieces { body, poly } and, worn, the seat (the torso's skin below the
-- waist) or, loose, a polygon seat and band. The legs' outlines first, the seat (its edge its
-- outline), the legs' fills over it (so the seams don't show), the pattern clipped to each piece,
-- the band.
local function drawGarment(kind, g)
    local ol = g.size * 0.035
    local seat = g.seat
    local line = { OUTLINE[1], OUTLINE[2], OUTLINE[3], 1 }
    love.graphics.setLineJoin('bevel')
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(ol * 2)
    for _, p in ipairs(g.pieces) do onBody(p.body, function() love.graphics.polygon('line', p.poly) end) end
    love.graphics.setColor(kind.base)
    if seat then drawSeat(seat, seat.waist, seat.skin.y1, line, ol) end
    for _, p in ipairs(g.pieces) do onBody(p.body, function() fillPoly(p.poly) end) end
    if kind.pattern then
        for _, p in ipairs(g.pieces) do
            onBody(p.body, function()
                love.graphics.stencil(function() fillPoly(p.poly) end, 'replace', 1)
                love.graphics.setStencilTest('greater', 0)
                drawPattern(kind, p.poly, g.size)
                love.graphics.setStencilTest()
            end)
        end
        if seat then
            local sk = seat.skin
            love.graphics.stencil(function() drawSeat(seat, seat.waist, sk.y1, nil, 0) end, 'replace', 1)
            love.graphics.setStencilTest('greater', 0)
            -- the pattern doesn't bend with the torso; the stencil does (a seam where it's pulled)
            onBody(seat.body, function()
                drawPattern(kind, { sk.x0, seat.waist, sk.x1, seat.waist, sk.x1, sk.y1, sk.x0, sk.y1 }, g.size)
            end)
            love.graphics.setStencilTest()
            -- the edge again over the pattern
            love.graphics.setColor(1, 1, 1, 0)
            drawSeat(seat, seat.waist, sk.y1, line, ol)
        end
    end
    -- the waistband, its edge dark
    if seat then
        love.graphics.setColor(kind.band)
        drawSeat(seat, seat.waist, seat.waist + seat.bandH, line, ol * 0.6)
    elseif g.band then
        onBody(g.bandBody, function()
            love.graphics.setColor(kind.band)
            fillPoly(g.band)
            love.graphics.setColor(OUTLINE)
            love.graphics.setLineWidth(ol)
            love.graphics.polygon('line', g.band)
        end)
    end
    love.graphics.setLineWidth(1)
end

local function drawPantsOn(item)
    item.gridKey = item.gridKey or {} -- spineSkin.drawGrid keeps a mesh per key: the pants' own
    local inst = item.wearer
    local kind = PANTS[item.kind]
    local on = inst and pantsOn(inst, kind)
    if on then
        drawGarment(kind, { pieces = on.legs, size = on.w,
            seat = { body = on.body, skin = on.skin, waist = on.waist, bandH = on.bandH, key = item.gridKey } })
    end
end

-- loose pants: a flat pair, front on, on their own body
local LOOSE = {
    seat = { -75, -50, 75, -50, 80, 12, -80, 12 },
    left = { -80, 0, -4, 0, -10, 60, -82, 60 },
    right = { 4, 0, 80, 0, 82, 60, 10, 60 },
    band = { -75, -50, 75, -50, 76, -38, -76, -38 },
}
local function drawLoosePants(item)
    local kind = PANTS[item.kind]
    local short = kind.leg < 0.2 -- knickers, briefs: barely a leg
    local left = short and { -80, 0, -4, 0, -20, 26, -80, 26 } or LOOSE.left
    local right = short and { 4, 0, 80, 0, 80, 26, 20, 26 } or LOOSE.right
    local pieces = { { body = item.body, poly = LOOSE.seat }, { body = item.body, poly = left },
        { body = item.body, poly = right } }
    drawGarment(kind, { pieces = pieces, band = LOOSE.band, bandBody = item.body, size = 150 })
end

function s.drawBelow()
    local b = state.wearables
    if not b then return end
    -- the room into a canvas, and the canvas stays on: the game draws the Mipos into it too, so
    -- the lenses can bend them; s.draw puts it on the screen (as in the glass spike)
    local canvas = backdrop()
    b.before = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true }) -- the mouths and the pants clip with a stencil
    love.graphics.clear(0, 0, 0, 1)
    drawRoom()
    -- worn pants drawn in their Mipo's own layers
    local splits = {}
    for _, item in ipairs(aliveItems(b)) do
        if item.sort == 'pants' and item.joint and item.wearer then
            splits[#splits + 1] = { z = (item.wearer.zGroupOffset or 0) * 1000 + PANTS_Z,
                fn = function() drawPantsOn(item) end }
        end
    end
    table.sort(splits, function(p, q) return p.z < q.z end)
    state.drawSplits = #splits > 0 and splits or nil
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false -- the items' boxes would show
    end
    b.drawing = true
end

function s.draw()
    local b = state.wearables
    if not (b and b.drawing) then return end
    b.drawing = nil
    state.drawSplits = nil
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
    for _, item in ipairs(aliveItems(b)) do
        if item.sort == 'pants' then
            if not item.joint then drawLoosePants(item) end
        else
            local wx, wy, a, sx, sy
            if item.host and not item.host:isDestroyed() then
                wx, wy, a, sx, sy = fitOn(item.host) -- right on the face, whatever the weld does
            end
            if not wx then
                wx, wy = item.body:getPosition()
                a, sx, sy = item.body:getAngle(), 1, 1
            end
            drawGlasses(b, item, wx, wy, a, sx, sy)
        end
        -- held over a spot: a ring round it to say "let go"
        if item.near then
            love.graphics.setColor(1, 1, 1, 0.5 + 0.3 * math.sin(love.timer.getTime() * 8))
            love.graphics.setLineWidth(4)
            love.graphics.circle('line', item.near.x, item.near.y, item.sort == 'pants' and 90 or 70)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.wearables and room()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'lens', -0.5, 3 }, { 'bend', 0, 3 }, { 'shine', 0, 2 }, { 'glint', 0, 2 },
        { 'grip', 100, 3000 }, { 'pantsGrip', 100, 3000 }, { 'snap', 0.2, 2 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• wearables ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('wearables' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('jolt now %d px/s (off over grip)', math.floor(b.peak)))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'g glasses u pants m Mipo w/n all on o off r p')
    end)
end

return s
