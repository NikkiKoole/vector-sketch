-- face-patches.lua — skin colouring on a Mipo's face, as a teddy's: eye hollows (darker), cheeks
-- (warmer), a snout (lighter), coloured from the Mipo's own skin; under the fur and hair, the eyes,
-- nose and mouth on top (docs/MIPO-BREEDS.md B10).
--
-- One decal per face ('facepatches') holds them all: drawn between the skin (z 200) and its hair
-- (210), clipped to the skin's inside, its mask less its outline (box2d-draw-textured
-- drawFacePatches, one stencil a face), turned with the face (mipo-facing applyFace). Placed from
-- the face's own decals (eyes, nose, mouth). Tried baked into the skin picture first (2026-11-08):
-- a turning face slid off them.
--
-- A Mipo has them while instance.facePatches holds its settings (lib.defaults()); rebuildTextures
-- puts them back after it remakes the face. Not saved yet: a spike (breeds, facing).
--
-- Each kind (eye, cheek, snout) can have a look of its own, as Puppetmaker 2's patches did
-- (set.looks[kind]: shape, fgHex fill, bgHex outline, pHex + pURL + pr / psx / psy pattern; the Mipo
-- maker sets them). Without one a patch is its mask tinted from the skin, as before. With an outline
-- or a pattern showing it's baked like a part's skin (omp-bake bakePreview), at the frame's start
-- (lib.bakePending, from omp-bake makeCombinedImages: never while drawing), and drawn as that picture.
local fixtures = require('src.fixtures')

local lib = {}

lib.Z = 205
lib.SHAPES = { 'mipo/patch/patch-01', 'mipo/patch/patch-02', 'mipo/patch/patch-03', 'mipo/patch/patch-04' }

function lib.defaults()
    return { eyes = true, cheeks = false, snout = true, shape = 1, alpha = 0.9,
        eyeDark = 0.35, eyeSize = 1.8, cheekBlush = 0.5, cheekSize = 1.0, snoutLight = 0.35, snoutSize = 1.0,
        snoutPink = 0.5 }
end

local function clamp01(v) return math.max(0, math.min(1, v)) end

local function hexRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function rgbToHsl(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local l = (mx + mn) / 2
    if mx == mn then return 0, 0, l end
    local d = mx - mn
    local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    local h
    if mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    return h * 60, s, l
end

local function hslToRgb(h, s, l)
    h = (h % 360) / 360
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    local function channel(t)
        t = t % 1
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    return channel(h + 1 / 3), channel(h), channel(h - 1 / 3)
end

local function tint(h, s, l, a)
    local r, g, b = hslToRgb(h, clamp01(s), clamp01(l))
    return { r, g, b, a }
end

-- the colours from the skin's fill: darker hollows, warmer (toward red) cheeks, a lighter snout,
-- pinker by snoutPink (toward a pink's hue, and its colour kept as it lightens)
local function tints(skinHex, set)
    local h, s, l = rgbToHsl(hexRGB(skinHex or 'A07744FF'))
    local toRed = ((350 - h + 540) % 360) - 180
    local pink = set.snoutPink or 0
    return {
        eye = tint(h, s, l * (1 - set.eyeDark), set.alpha),
        cheek = tint(h + toRed * set.cheekBlush, s + 0.35 * set.cheekBlush, l + 0.05 * set.cheekBlush, set.alpha),
        snout = tint(h + toRed * pink, s * (1 - 0.4 * set.snoutLight) * (1 - pink) + math.max(s, 0.55) * pink,
            l + (1 - l) * set.snoutLight, set.alpha),
    }
end

-- each patch, front-on, in the face part's own frame, from the face's decals (their front-on places)
local function places(face, set)
    local list = {}
    local lp, rp = face.lpupil, face.rpupil
    if not (lp and rp) then return list end
    local function eye(p) return p.baseOx or p.ox, p.oy, p.baseEyeW or p.eyeW, p.eyeH end
    local lx, ly, ew, eh = eye(lp)
    local rx, ry = eye(rp)
    local nose, lip = face.nose, face.upperlip or face.lowerlip
    local mouthY = lip and lip.oy or (ly + eh * 2)
    local function add(ox, oy, w, h, mirror, kind)
        list[#list + 1] = { ox = ox, oy = oy, w = w, h = h, mirror = mirror, kind = kind }
    end
    if set.eyes then
        add(lx, ly, ew * set.eyeSize, eh * set.eyeSize, true, 'eye')
        add(rx, ry, ew * set.eyeSize, eh * set.eyeSize, false, 'eye')
    end
    if set.cheeks then
        local cy = ly + (mouthY - ly) * 0.75
        local cw = ew * set.cheekSize
        add(lx * 1.25, cy, cw, cw * 0.75, true, 'cheek')
        add(rx * 1.25, cy, cw, cw * 0.75, false, 'cheek')
    end
    if set.snout and nose then
        local gap = rx - lx
        local h = math.max((mouthY - nose.oy) * 2.4, gap * 0.6) * set.snoutSize
        add(nose.baseOx or nose.ox, (nose.oy + mouthY) / 2 + h * 0.1, gap * 0.9 * set.snoutSize, h, false, 'snout')
    end
    return list
end

-- the face's decals by label, the skin's fixture, and the patches decal
local function faceParts(body)
    local face, skinFixture, patches = {}, nil, nil
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if ud and ud.subtype == 'decal' and ud.label == 'facepatches' then patches = fixture
        elseif ud and ud.subtype == 'decal' and ud.label then face[ud.label] = ud.extra
        elseif ud and ud.subtype == 'texfixture' and ud.extra and ud.extra.OMP and ud.extra.main then
            skinFixture = fixture
        end
    end
    return face, skinFixture, patches
end

local function faceBody(instance)
    local name = instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = instance.parts and instance.parts[name]
    return part and part.body and not part.body:isDestroyed() and part.body or nil
end

-- Put the patches on (again) from instance.facePatches; without settings, take them off. turn:
-- turn them with the face now (rebuildTextures turns the whole face itself afterwards).
local function hexOf(rgba)
    local function b(v) return math.floor(clamp01(v) * 255 + 0.5) end
    return string.format('%02x%02x%02x%02x', b(rgba[1]), b(rgba[2]), b(rgba[3]), b(rgba[4] or 1))
end
local function shows(hex) return hex and #hex >= 8 and tonumber(hex:sub(7, 8), 16) > 0 end

-- a patch's own look (set.looks[kind]) onto it: its picture, its fill, and a bake when it has an
-- outline or a pattern to show
local function applyLook(patch, set, derived)
    local look = set.looks and set.looks[patch.kind]
    local base = lib.SHAPES[look and look.shape or set.shape] or lib.SHAPES[1]
    patch.url = base .. '-mask.png'
    patch.tint = derived
    patch.bake, patch.image = nil, nil
    if not look then return end
    if look.fgHex then
        local r, g, b = tonumber(look.fgHex:sub(1, 2), 16) / 255, tonumber(look.fgHex:sub(3, 4), 16) / 255,
            tonumber(look.fgHex:sub(5, 6), 16) / 255
        patch.tint = { r, g, b, derived[4] }
    end
    if shows(look.bgHex) or shows(look.pHex) then
        local fill = hexOf({ patch.tint[1], patch.tint[2], patch.tint[3], 1 })
        local b = { fgHex = fill, bgHex = look.bgHex or '00000000', pHex = look.pHex or '00000000',
            pURL = look.pURL, pr = look.pr, psx = look.psx, psy = look.psy }
        patch.bake = { outline = base .. '.png', mask = base .. '-mask.png', look = b,
            key = table.concat({ base, b.fgHex, b.bgHex, b.pHex, b.pURL or '', b.pr or 0, b.psx or 1, b.psy or 1 },
                '|') }
    end
end

-- Baked patch pictures, by look (shared by Mipos with the same one). Dropped oldest first past
-- BAKED_MAX, not released: a Mipo may still draw it (the GC frees it when none does).
local BAKED_MAX = 32
local baked, bakedOrder = {}, {}
local pending = {} -- decal extras whose patches want a bake

function lib.bakePending()
    if not next(pending) then return end
    local ompBake = require('src.render.omp-bake') -- here: omp-bake calls this module
    for extra in pairs(pending) do
        for _, patch in ipairs(extra.facePatches or {}) do
            local job = patch.bake
            if job then
                local img = baked[job.key]
                if not img then
                    img = ompBake.bakePreview(job.outline, job.mask, job.look)
                    baked[job.key] = img
                    bakedOrder[#bakedOrder + 1] = job.key
                    if #bakedOrder > BAKED_MAX then baked[table.remove(bakedOrder, 1)] = nil end
                end
                patch.image = img
            end
        end
        pending[extra] = nil
    end
end

function lib.place(instance, turn)
    local body = faceBody(instance)
    if not body then return end
    local face, skinFixture, fixture = faceParts(body)
    local set = instance.facePatches
    if not (set and skinFixture and face.lpupil) then
        if fixture then fixtures.destroyFixture(fixture) end
        return
    end
    local list = places(face, set)
    local colours = tints(skinFixture:getUserData().extra.main.fgHex, set)
    local wantsBake = false
    for _, patch in ipairs(list) do
        applyLook(patch, set, colours[patch.kind])
        wantsBake = wantsBake or patch.bake ~= nil
    end
    if not fixture then
        fixture = fixtures.createSFixture(body, 0, 0, 'decal', { radius = 10 })
        fixture:getUserData().label = 'facepatches'
    end
    local e = fixture:getUserData().extra
    e.facePatches, e.skinFixture = list, skinFixture
    if wantsBake then pending[e] = true end
    e.zOffset, e.zGroupOffset = lib.Z, instance.zGroupOffset or face.lpupil.zGroupOffset
    if turn then require('src.mipo-facing').applyFace(instance) end
end

return lib
