-- maker: the Mipo maker's card with Puppetmaker 2's hand-drawn widgets (docs/MIPO-MAKER.md): one card
-- beside a live Mipo, the parts in a row on top, the shapes in a flickable grid, paint blobs, icon
-- sliders on a taped strip, a drawn toggle and the dice. Tap a part of the Mipo to pick it (a drag
-- still pokes). Widgets: src/ui/maker/drawn.lua (makerUI), drawings in textures/ui/maker/.
-- Parts: body, head, eyes, nose, mouth, teeth, brows, face patches, ears, hair, arms, hands, legs, feet, body hair, arm hair, leg hair.
-- Play mode only (./playtime.sh play maker; tab toggles the editor).
-- keys: r: a new Mipo   h: hide/show the card   d: the dev-only rows

local s = {}

local GROUND_Y = 900
local MIPO_X = -420
local ZOOM = 0.42
local SCALE = 0.42
local APPLY_EVERY = 0.12 -- s: a dragged slider rebuilds the Mipo at most this often
local TAP_TIME, TAP_MOVE = 0.3, 12 -- a tap on the Mipo: shorter than this, moved less (px)

-- a palette in Puppetmaker's spirit (16 blobs, 2 rows)
local PALETTE = {
    '020202', 'efebd8', 'f2c9a0', 'd9a066', '9c6b3f', '613d41', 'be193b', 'd6642f',
    'e6c800', '8fb35a', '3f7f5f', '4a90a8', '2f4f8f', '4f3166', 'c98fb8', 'f5f5f5',
}

local function check() -- on state: a script hot reload keeps the Mipo and what's picked
    state.makerSpike = state.makerSpike or { category = 'body', layer = 'fill', show = true,
        grid = { off = 0, vel = 0 }, lastApply = 0 }
    return state.makerSpike
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function hexToRGB(hex)
    if not hex or #hex < 6 then hex = 'ccccccff' end -- '' : a layer with no colour (hair without fill)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

local function numberOf(url) return tonumber(tostring(url):match('(%d+)%.?p?n?g?$')) end

local function partData(inst, name) return inst.dna.parts[name] end
local function skinOf(inst, name)
    local p = partData(inst, name)
    return p and p.appearance and p.appearance.skin and p.appearance.skin.main
end
local function faceOwner(inst) return inst.dna.creation.isPotatoHead and 'torso1' or 'head' end
local function face(inst)
    local p = partData(inst, faceOwner(inst))
    return p and p.appearance and p.appearance.face
end
local function haircut(inst)
    local p = partData(inst, faceOwner(inst))
    return p and p.appearance and p.appearance.haircut
end
local function torsos(inst)
    local names = {}
    for i = 1, inst.dna.creation.torsoSegments or 1 do names[i] = 'torso' .. i end
    return names
end

-- a part's shape and scale through the same call the editor's shape panel makes
local function setShape(inst, name, url, sx, sy)
    local p = partData(inst, name)
    if not p then return end
    if url and not url:match('%.png$') then url = url .. '.png' end -- the catalogs leave it off, shape8 keys have it
    characterManager.updatePart(name, { shape8URL = url or p.shape8URL, sx = sx or p.dims.sx or 1,
        sy = sy or p.dims.sy or 1 }, inst)
end

-- colour layers: which key of a texture block each one is (outline, fill, pattern)
local LAYER_KEY = { fill = 'fgHex', line = 'bgHex', pattern = 'pHex' }
local ALL_LAYERS = { 'fill', 'line', 'pattern' }
local FILL_LINE = { 'fill', 'line' }
-- hair is an outline only, but for the hair pictures with a mask (fill and pattern then too)
local function hairLayers(block)
    return block and block.fgURL and block.fgURL ~= '' and ALL_LAYERS or { 'line' }
end

local function setSkin(inst, names, key, hex)
    for _, name in ipairs(names) do characterManager.updateSkinOfPart(inst, name, { [key] = hex }) end
end

local function faceSet(inst, values) characterManager.updateFaceOfPart(inst, faceOwner(inst), values) end

-- The categories: what the card shows for each (later src/mipo-maker-catalog.lua, MM2).
-- shapes: the catalog, picked(inst) the url picked now, pick(inst, url); fill(inst) the colour the
-- cells and the icon get; colour(inst, layer, hex); sliders: { less, more, min, max, step, get, set }.
-- A position slider with 'up' on the right: positions count from the top (0 top, 1 bottom: the face
-- features lerp top to bottom, ear height measured too), so the slider shows them turned round.
local function upDown(lessIcon, moreIcon, min, max, step, get, set)
    return { less = lessIcon, more = moreIcon, min = min, max = max, step = step,
        get = function(inst) return min + max - (get(inst) or (min + max) / 2) end,
        set = function(inst, v) set(inst, min + max - v) end }
end

-- the face's size (dna.faceMagnitude): on the head, or the body of a potato (its face is there)
local function faceSize(onPotato)
    return { less = 'icons/face-small', more = 'icons/face-big', min = 0.5, max = 2, step = 0.1,
        hidden = function(inst) return (inst.dna.creation.isPotatoHead or false) ~= onPotato end,
        get = function(inst) return inst.dna.faceMagnitude or 1 end,
        set = function(inst, v) characterManager.updatePositioners(inst, { faceMagnitude = v }) end }
end

-- The Mipo's build (dna.creation): a change rebuilds it (as the editor's creation rows), but softness,
-- sway and jiggle, which are read live. Words where Puppetmaker has no drawing ('text:', MM12).
local function creation(inst) return inst.dna.creation end
local function rebuildWith(inst, patch) characterManager.rebuildFromCreation(inst, patch) end
local function liveSlider(less, more, key, min, max, step, default, onSet, extra)
    local sl = { less = less, more = more, min = min, max = max, step = step,
        get = function(inst) return creation(inst)[key] or default end,
        set = function(inst, v)
            creation(inst)[key] = v
            if onSet then onSet(inst) end
        end }
    for k, v in pairs(extra or {}) do sl[k] = v end
    return sl
end
local function springs(inst) torsoLobes.setSprings(inst) end
local BUILD_SLIDERS = {
    { less = 'text:1', more = 'text:5', min = 1, max = 5, step = 1, -- torso segments (a spine needs 2)
        get = function(inst) return creation(inst).torsoSegments or 1 end,
        set = function(inst, v)
            if creation(inst).torsoSpine then v = math.max(2, v) end
            rebuildWith(inst, { torsoSegments = v })
        end },
    { less = 'text:flat', more = 'text:bend', min = 0, max = 45, step = 1,
        hidden = function(inst) return not creation(inst).torsoSpine end,
        get = function(inst) return creation(inst).spineBend or 15 end,
        set = function(inst, v) rebuildWith(inst, { spineBend = v }) end },
    liveSlider('text:still', 'text:sway', 'spineSway', 0, 1, 0.05, 0.3, nil,
        { dev = true, hidden = function(inst) return not creation(inst).torsoSpine end }),
    { less = 'text:thin', more = 'text:deep', min = 0.15, max = 0.6, step = 0.05,
        hidden = function(inst) return not creation(inst).torsoLobes end,
        get = function(inst) return creation(inst).lobeDepth or 0.35 end,
        set = function(inst, v) rebuildWith(inst, { lobeDepth = v }) end },
    { less = 'text:firm', more = 'text:jelly', min = 0, max = 1, step = 0.05,
        hidden = function(inst) return not creation(inst).torsoLobes end,
        get = function(inst) return creation(inst).softness or 0.5 end,
        set = function(inst, v)
            torsoLobes.applySoftness(creation(inst), v)
            springs(inst)
        end },
    liveSlider('text:slow', 'text:fast', 'lobeSpring', 0.5, 10, 0.25, 5.5, springs,
        { dev = true, hidden = function(inst) return not creation(inst).torsoLobes end }),
    liveSlider('text:bouncy', 'text:damped', 'lobeDamping', 0, 1, 0.05, 0.38, springs,
        { dev = true, hidden = function(inst) return not creation(inst).torsoLobes end }),
    liveSlider('text:calm', 'text:wobbly', 'jiggleAmount', 0, 3, 0.1, 0.4, nil,
        { hidden = function(inst) return not creation(inst).torsoJiggle end }),
    liveSlider('text:slow', 'text:fast', 'jiggleSpring', 0.5, 8, 0.25, 3, nil,
        { dev = true, hidden = function(inst) return not creation(inst).torsoJiggle end }),
    liveSlider('text:bouncy', 'text:damped', 'jiggleDamping', 0, 1, 0.05, 0.15, nil,
        { dev = true, hidden = function(inst) return not creation(inst).torsoJiggle end }),
}
local BUILD_SWITCHES = {
    { label = 'potato', get = function(inst) return creation(inst).isPotatoHead end,
        set = function(inst, on) rebuildWith(inst, { isPotatoHead = on }) end },
    { label = 'spine', get = function(inst) return creation(inst).torsoSpine end,
        set = function(inst, on)
            local patch = { torsoSpine = on }
            if on and (creation(inst).torsoSegments or 1) < 2 then patch.torsoSegments = 2 end
            rebuildWith(inst, patch)
        end },
    { label = 'lobes', get = function(inst) return creation(inst).torsoLobes end,
        set = function(inst, on) rebuildWith(inst, { torsoLobes = on }) end },
    { label = 'jiggle', get = function(inst) return creation(inst).torsoJiggle end,
        set = function(inst, on) creation(inst).torsoJiggle = on end }, -- read live
}

local CATEGORIES = {
    {
        name = 'body', icon = 'icons/body',
        shapes = shapeCatalogs.torsoHeadShapes,
        picked = function(inst) return partData(inst, 'torso1').shape8URL end,
        pick = function(inst, url) setShape(inst, 'torso1', url) end,
        skin = function(inst) return torsos(inst) end,
        sliders = {
            { less = 'icons/body-narrow', more = 'icons/body-wide', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'torso1').dims.sx or 1 end,
                set = function(inst, v) setShape(inst, 'torso1', nil, v, nil) end },
            { less = 'icons/body-small', more = 'icons/body-tall', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'torso1').dims.sy or 1 end,
                set = function(inst, v) setShape(inst, 'torso1', nil, nil, v) end },
            faceSize(true),
        },
        build = true, -- + BUILD_SLIDERS, BUILD_SWITCHES
        switches = BUILD_SWITCHES,
    },
    {
        name = 'head', icon = 'icons/head',
        hidden = function(inst) return inst.dna.creation.isPotatoHead end,
        shapes = shapeCatalogs.torsoHeadShapes,
        picked = function(inst) return partData(inst, 'head').shape8URL end,
        pick = function(inst, url) setShape(inst, 'head', url) end,
        skin = function() return { 'head' } end,
        sliders = {
            { less = 'icons/head-narrow', more = 'icons/head-wide', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'head').dims.sx or 1 end,
                set = function(inst, v) setShape(inst, 'head', nil, v, nil) end },
            { less = 'icons/head-small', more = 'icons/head-tall', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'head').dims.sy or 1 end,
                set = function(inst, v) setShape(inst, 'head', nil, nil, v) end },
            faceSize(false),
        },
    },
    {
        name = 'eyes', icon = 'icons/eyes', textures = true,
        shapes = shapeCatalogs.eyeShapes,
        picked = function(inst) return face(inst).eye.shape end,
        pick = function(inst, url) faceSet(inst, { eyeShape = numberOf(url) }) end,
        fill = function(inst) return face(inst).eye.fgHex end,
        layers = FILL_LINE,
        colour = function(inst, layer, hex) faceSet(inst, layer == 'line' and { eyeBgHex = hex } or { eyeFgHex = hex }) end,
        sliders = {
            { less = 'icons/eye-small', more = 'icons/eye-wide', min = 0.25, max = 2, step = 0.25,
                get = function(inst) return face(inst).eye.wMul end,
                set = function(inst, v) faceSet(inst, { eyeWMul = v }) end },
            { less = 'icons/eye-small2', more = 'icons/eye-tall', min = 0.25, max = 2, step = 0.25,
                get = function(inst) return face(inst).eye.hMul end,
                set = function(inst, v) faceSet(inst, { eyeHMul = v }) end },
            { less = 'icons/eye-close', more = 'icons/eye-far', min = 0, max = 0.5, step = 0.05,
                get = function(inst) return face(inst).positioners.eye.x end,
                set = function(inst, v) faceSet(inst, { eyeX = v }) end },
            upDown('icons/eye-down', 'icons/eye-up', 0, 1, 0.05,
                function(inst) return face(inst).positioners.eye.y end,
                function(inst, v) faceSet(inst, { eyeY = v }) end),
            { less = 'icons/eye-ccw', more = 'icons/eye-cw', min = -1, max = 1, step = 0.1,
                get = function(inst) return face(inst).positioners.eye.r or 0 end,
                set = function(inst, v) faceSet(inst, { eyeR = v }) end },
        },
    },
    {
        name = 'nose', icon = 'icons/nose', textures = true,
        shapes = shapeCatalogs.noseShapes,
        picked = function(inst) return face(inst).nose.shape end,
        pick = function(inst, url) faceSet(inst, { noseShape = numberOf(url) }) end,
        fill = function(inst) return face(inst).nose.fgHex end,
        layers = FILL_LINE,
        colour = function(inst, layer, hex) faceSet(inst, layer == 'line' and { noseBgHex = hex } or { noseFgHex = hex }) end,
        sliders = {
            { less = 'icons/nose-narrow', more = 'icons/nose-wide', min = 0.5, max = 3, step = 0.25,
                get = function(inst) return face(inst).nose.wMul end,
                set = function(inst, v) faceSet(inst, { noseWMul = v }) end },
            { less = 'icons/nose-small', more = 'icons/nose-tall', min = 0.5, max = 3, step = 0.25,
                get = function(inst) return face(inst).nose.hMul end,
                set = function(inst, v) faceSet(inst, { noseHMul = v }) end },
            upDown('icons/nose-down', 'icons/nose-up', 0, 1, 0.05,
                function(inst) return face(inst).positioners.nose.y end,
                function(inst, v) faceSet(inst, { noseY = v }) end),
        },
    },
    {
        name = 'ears', icon = 'icons/ears',
        hidden = function(inst) return not partData(inst, 'lear') end,
        shapes = shapeCatalogs.earShapes,
        picked = function(inst) return partData(inst, 'lear').shape8URL end,
        pick = function(inst, url)
            setShape(inst, 'lear', url)
            setShape(inst, 'rear', url)
        end,
        skin = function() return { 'lear', 'rear' } end,
        sliders = {
            { less = 'icons/ear-small', more = 'icons/ear-big', min = 0.5, max = 2.5, step = 0.25,
                get = function(inst) return partData(inst, 'lear').dims.sy or 1 end,
                set = function(inst, v)
                    for _, n in ipairs({ 'lear', 'rear' }) do setShape(inst, n, nil, nil, v) end
                end },
            upDown('icons/ear-down', 'icons/ear-up', 0, 1, 0.05,
                function(inst) return inst.dna.positioners.ear.y end,
                function(inst, v)
                    characterManager.updatePositioners(inst, { earY = v })
                    characterManager.rebuildFromCreation(inst, {})
                end),
            -- the ears' tilt, mirrored: lear at -90deg + t, rear at 90deg - t (the editor's defaults: t = 36deg).
            -- t 0: straight out sideways; below: drooping; ~1.5: upright (past it they crossed over the head).
            -- The icons show a right ear: ear-cw leaning out and down, ear-ccw standing up (Puppetmaker's order).
            { less = 'icons/ear-cw', more = 'icons/ear-ccw', min = -0.7, max = 1.5, step = 0.1,
                get = function(inst) return (partData(inst, 'lear').stanceAngle or (-math.pi / 2 + math.pi / 5)) + math.pi / 2 end,
                set = function(inst, v)
                    partData(inst, 'lear').stanceAngle = -math.pi / 2 + v
                    if partData(inst, 'rear') then partData(inst, 'rear').stanceAngle = math.pi / 2 - v end
                    characterManager.rebuildFromCreation(inst, {})
                end },
        },
    },
    {
        name = 'hair', icon = 'icons/hair', outlineOnly = true,
        hidden = function(inst) return not haircut(inst) end,
        shapes = shapeCatalogs.haircutTextures,
        picked = function(inst) return haircut(inst).main and haircut(inst).main.bgURL end,
        pick = function(inst, url)
            url = url .. '.png'
            local fg = shapeCatalogs.hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
            characterManager.updateHaircutOfPart(inst, faceOwner(inst), { bgURL = url, fgURL = fg })
        end,
        fill = function(inst) return haircut(inst).main and haircut(inst).main.bgHex end,
        layers = function(inst) return hairLayers(haircut(inst).main) end,
        colour = function(inst, layer, hex)
            characterManager.updateHaircutOfPart(inst, faceOwner(inst), { [LAYER_KEY[layer]] = hex })
        end,
        setBlock = function(inst, values) -- straight into main: the haircut setter files turn / scale elsewhere
            local main = haircut(inst).main
            for k, v in pairs(values) do main[k] = v end
            main.cached = nil
        end,
        sliders = {
            { less = 'icons/hair-thin', more = 'icons/hair-thick', min = 50, max = 800, step = 50,
                get = function(inst) return haircut(inst).width or 250 end,
                set = function(inst, v) characterManager.updateHaircutOfPart(inst, faceOwner(inst), { width = v }) end },
        },
    },
}

-- Limbs. Arms and legs are capsules (dims.h the length, dims.w the physics width) drawn by a
-- connected-skin ribbon owned by the upper segment (luarm, luleg); hands and feet are shape8 parts.
local LIMBS = {
    arms = { owners = { 'luarm', 'ruarm' }, segments = { 'luarm', 'llarm', 'ruarm', 'rlarm' } },
    legs = { owners = { 'luleg', 'ruleg' }, segments = { 'luleg', 'llleg', 'ruleg', 'rlleg' } },
}
local function ribbon(inst, limb)
    local p = partData(inst, LIMBS[limb].owners[1])
    local cs = p and p.appearance and p.appearance['connected-skin']
    return cs and cs.main
end
local function setRibbon(inst, limb, values)
    for _, owner in ipairs(LIMBS[limb].owners) do
        if partData(inst, owner) then characterManager.updateConnectedAppearance(inst, owner, 'connected-skin', values) end
    end
end
local function setLength(inst, limb, h)
    for _, name in ipairs(LIMBS[limb].segments) do
        if partData(inst, name) then characterManager.updatePart(name, { h = h }, inst) end
    end
end

local function limbCategory(limb, icon, iconPrefix, extra)
    local cat = {
        name = limb, icon = icon,
        hidden = function(inst) return not ribbon(inst, limb) end,
        shapes = shapeCatalogs.limbSkinTextures,
        picked = function(inst) return ribbon(inst, limb).bgURL end,
        pick = function(inst, url) setRibbon(inst, limb, { bgURL = url .. '.png', fgURL = url .. '-mask.png' }) end,
        look = function(inst) return ribbon(inst, limb) end,
        layers = ALL_LAYERS,
        colour = function(inst, layer, hex) setRibbon(inst, limb, { [LAYER_KEY[layer]] = hex }) end,
        setBlock = function(inst, values) setRibbon(inst, limb, values) end,
        sliders = {
            { less = iconPrefix .. '-short', more = iconPrefix .. '-long', min = 150, max = 1200, step = 50,
                get = function(inst) return partData(inst, LIMBS[limb].segments[1]).dims.h end,
                set = function(inst, v) setLength(inst, limb, v) end },
            { less = iconPrefix .. '-thin', more = iconPrefix .. '-thick', min = 0.25, max = 3, step = 0.25,
                get = function(inst) return ribbon(inst, limb).wmul or inst.scale or 1 end,
                set = function(inst, v) setRibbon(inst, limb, { wmul = v }) end },
        },
    }
    for _, sl in ipairs(extra or {}) do cat.sliders[#cat.sliders + 1] = sl end
    return cat
end

-- hands and feet: shapes on both, the same scale on both
local function pairCategory(name, icon, left, right, shapes, iconPrefix)
    local function setBoth(inst, url, sx, sy)
        for _, n in ipairs({ left, right }) do setShape(inst, n, url, sx, sy) end
    end
    return {
        name = name, icon = icon,
        hidden = function(inst) return not partData(inst, left) end,
        shapes = shapes,
        picked = function(inst) return partData(inst, left).shape8URL end,
        pick = function(inst, url) setBoth(inst, url) end,
        skin = function() return { left, right } end,
        sliders = {
            { less = iconPrefix .. '-narrow', more = iconPrefix .. '-wide', min = 0.5, max = 2.5, step = 0.25,
                get = function(inst) return partData(inst, left).dims.sx or 1 end,
                set = function(inst, v) setBoth(inst, nil, v, nil) end },
            { less = iconPrefix .. '-short', more = iconPrefix .. '-tall', min = 0.5, max = 2.5, step = 0.25,
                get = function(inst) return partData(inst, left).dims.sy or 1 end,
                set = function(inst, v) setBoth(inst, nil, nil, v) end },
        },
    }
end

CATEGORIES[#CATEGORIES + 1] = limbCategory('arms', 'icons/arm', 'icons/arms')
CATEGORIES[#CATEGORIES + 1] = pairCategory('hands', 'icons/hands', 'lhand', 'rhand', shapeCatalogs.handShapes, 'icons/hand')
CATEGORIES[#CATEGORIES + 1] = limbCategory('legs', 'icons/leg', 'icons/legs', {
    { less = 'icons/legs-stance1', more = 'icons/legs-stance2', min = 0, max = 1, step = 0.1,
        get = function(inst) return inst.dna.positioners.leg.x end,
        set = function(inst, v)
            characterManager.updatePositioners(inst, { legX = v })
            characterManager.rebuildFromCreation(inst, {})
        end },
})
CATEGORIES[#CATEGORIES + 1] = pairCategory('feet', 'icons/feet', 'lfoot', 'rfoot', shapeCatalogs.feetShapes, 'icons/foot')

-- Body hair: a picture laid along each torso segment's outline (all segments alike), grown out
-- from it by growfactor. 'none' clears it, as the editor's x cell does.
local function bodyhair(inst, name)
    local p = partData(inst, name or 'torso1')
    return p and p.appearance and p.appearance.bodyhair
end
local function setBodyhair(inst, values)
    for _, name in ipairs(torsos(inst)) do
        if bodyhair(inst, name) then characterManager.updateBodyhairOfPart(inst, name, values) end
    end
end
CATEGORIES[#CATEGORIES + 1] = {
    name = 'bodyhair', icon = 'icons/chesthair', allowNone = true,
    hidden = function(inst) return not (bodyhair(inst) and bodyhair(inst).main) end,
    shapes = shapeCatalogs.bodyhairTextures,
    picked = function(inst) return bodyhair(inst).main.bgURL end,
    pick = function(inst, url)
        if not url then
            for _, name in ipairs(torsos(inst)) do
                local main = bodyhair(inst, name) and bodyhair(inst, name).main
                if main then main.bgURL, main.fgURL, main.cached = nil, nil, nil end
            end
            return
        end
        setBodyhair(inst, { bgURL = url .. '.png', fgURL = url .. '-mask.png' })
    end,
    look = function(inst) return bodyhair(inst).main end,
    layers = FILL_LINE,
    colour = function(inst, layer, hex) setBodyhair(inst, { [LAYER_KEY[layer]] = hex }) end,
    sliders = {
        { less = 'icons/chesthair-inner', more = 'icons/chesthair-outer', min = 0.5, max = 2.5, step = 0.25,
            get = function(inst) return bodyhair(inst).growfactor or 1.2 end,
            set = function(inst, v)
                for _, name in ipairs(torsos(inst)) do
                    if bodyhair(inst, name) then bodyhair(inst, name).growfactor = v end
                end
                characterManager.rebuildFromCreation(inst, {})
            end },
    },
}

-- Arm and leg hair: a ribbon along the limb (connected-hair on the upper segment, both sides).
-- Outline only, but for the two hair pictures with a mask (fill then too).
local function limbHair(inst, limb)
    local p = partData(inst, LIMBS[limb].owners[1])
    local ch = p and p.appearance and p.appearance['connected-hair']
    return ch and ch.main
end
local function setLimbHair(inst, limb, values)
    for _, owner in ipairs(LIMBS[limb].owners) do
        if partData(inst, owner) then characterManager.updateConnectedAppearance(inst, owner, 'connected-hair', values) end
    end
end
local function limbHairCategory(name, icon, limb)
    return {
        name = name, icon = icon, allowNone = true, outlineOnly = true,
        hidden = function(inst) return not limbHair(inst, limb) end,
        shapes = shapeCatalogs.limbHairTextures,
        picked = function(inst) return limbHair(inst, limb).bgURL end,
        pick = function(inst, url)
            if not url then return setLimbHair(inst, limb, { bgURL = '', fgURL = '' }) end
            url = url .. '.png'
            local fg = shapeCatalogs.hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
            setLimbHair(inst, limb, { bgURL = url, fgURL = fg })
        end,
        look = function(inst) return limbHair(inst, limb) end,
        layers = function(inst) return hairLayers(limbHair(inst, limb)) end,
        colour = function(inst, layer, hex) setLimbHair(inst, limb, { [LAYER_KEY[layer]] = hex }) end,
        setBlock = function(inst, values) setLimbHair(inst, limb, values) end,
        sliders = {
            { less = 'icons/hair-thin', more = 'icons/hair-thick', min = 0.25, max = 4, step = 0.25,
                get = function(inst) return limbHair(inst, limb).wmul or inst.scale or 1 end,
                set = function(inst, v) setLimbHair(inst, limb, { wmul = v }) end },
        },
    }
end
CATEGORIES[#CATEGORIES + 1] = limbHairCategory('armhair', 'icons/armhair', 'arms')
CATEGORIES[#CATEGORIES + 1] = limbHairCategory('leghair', 'icons/leghair', 'legs')

-- Mouth and brows (face features, like eyes and nose), placed after the nose in the row.
local function mouthLook(inst) return { fgHex = face(inst).mouth.lipHex, bgHex = '020202ff' } end
local MOUTH = {
    name = 'mouth', icon = 'icons/mouth',
    shapes = shapeCatalogs.upperLipShapes,
    picked = function(inst) return face(inst).mouth.upperLipShape end,
    pick = function(inst, url) -- the lower lip of the same number, when there is one
        local n = numberOf(url)
        local lower = shapeCatalogs.lowerLipShapes[n] and n or nil
        faceSet(inst, { mouthUpperLipShape = n, mouthLowerLipShape = lower })
    end,
    look = mouthLook,
    layers = { 'fill' },
    colour = function(inst, _, hex) faceSet(inst, { mouthLipHex = hex }) end,
    sliders = {
        { less = 'icons/mouth-narrow', more = 'icons/mouth-wide', min = 0.25, max = 2.5, step = 0.25,
            get = function(inst) return face(inst).mouth.wMul end,
            set = function(inst, v) faceSet(inst, { mouthWMul = v }) end },
        { less = 'icons/mouth-small', more = 'icons/mouth-tall', min = 0.25, max = 2.5, step = 0.25,
            get = function(inst) return face(inst).mouth.hMul end,
            set = function(inst, v) faceSet(inst, { mouthHMul = v }) end },
        upDown('icons/mouth-down', 'icons/mouth-up', 0.5, 0.95, 0.05,
            function(inst) return face(inst).positioners.mouth.y end,
            function(inst, v) faceSet(inst, { mouthY = v }) end),
    },
}
local BROWS = {
    name = 'brows', icon = 'icons/brows', outlineOnly = true,
    shapes = shapeCatalogs.browShapes,
    picked = function(inst) return face(inst).brow.shape end,
    pick = function(inst, url) faceSet(inst, { browShape = numberOf(url) }) end,
    look = function(inst) return { bgHex = face(inst).brow.bgHex, fgHex = '' } end,
    layers = { 'line' },
    colour = function(inst, _, hex) faceSet(inst, { browBgHex = hex }) end,
    sliders = {
        { less = 'icons/brow-narrow', more = 'icons/brow-wide', min = 0.25, max = 2, step = 0.25,
            get = function(inst) return face(inst).brow.wMul end,
            set = function(inst, v) faceSet(inst, { browWMul = v }) end },
        { less = 'icons/brow-thin', more = 'icons/brow-thick', min = 0.25, max = 2, step = 0.25,
            get = function(inst) return face(inst).brow.hMul end,
            set = function(inst, v) faceSet(inst, { browHMul = v }) end },
        upDown('icons/brows-down', 'icons/brows-up', 0.1, 0.5, 0.05,
            function(inst) return face(inst).positioners.brow.y end,
            function(inst, v) faceSet(inst, { browY = v }) end),
    },
}
-- Teeth: a shape (0: none), colours, size, and two switches: over the lip, and the gum.
local function teeth(inst) return face(inst).teeth end
local TEETH = {
    name = 'teeth', icon = 'icons/teeth', allowNone = true,
    shapes = shapeCatalogs.teethShapes,
    picked = function(inst) return teeth(inst).shape end,
    pick = function(inst, url) faceSet(inst, { teethShape = url and numberOf(url) or 0 }) end,
    look = function(inst) return teeth(inst) end,
    layers = FILL_LINE,
    colour = function(inst, layer, hex) faceSet(inst, layer == 'line' and { teethBgHex = hex } or { teethFgHex = hex }) end,
    sliders = {
        { less = 'icons/mouth-narrow', more = 'icons/mouth-wide', min = 0.5, max = 2.5, step = 0.25,
            get = function(inst) return teeth(inst).wMul end,
            set = function(inst, v) faceSet(inst, { teethWMul = v }) end },
        { less = 'icons/mouth-small', more = 'icons/mouth-tall', min = 0.5, max = 3, step = 0.25,
            get = function(inst) return teeth(inst).hMul end,
            set = function(inst, v) faceSet(inst, { teethHMul = v }) end },
    },
    switches = {
        { label = 'over lip', get = function(inst) return teeth(inst).stickOut end,
            set = function(inst, on) faceSet(inst, { teethStickOut = on }) end },
        { label = 'gum', get = function(inst) return teeth(inst).gum end,
            set = function(inst, on) faceSet(inst, { teethGum = on }) end },
    },
}

-- Face patches (src/face-patches.lua, MIPO-BREEDS B10): eye hollows, cheeks, a snout, coloured from
-- the skin (so no paint blobs). Settings on instance.facePatches, not in the DNA yet (not saved).
-- The grid: the patch picture ('none': all off). Three patch buttons: tap to turn one on and pick it,
-- tap the picked one to turn it off. The sliders: the picked patch's size and strength.
-- Cheeks borrow Puppetmaker's second eye-patch icon: it has none for cheeks.
local PATCH_KINDS = {
    { key = 'eyes', kind = 'eye', icon = 'icons/skinpatchEye1', size = { 'eyeSize', 1, 3 }, strength = { 'eyeDark', 0, 1 } },
    { key = 'cheeks', kind = 'cheek', icon = 'icons/skinpatchEye2', size = { 'cheekSize', 0.5, 2.5 }, strength = { 'cheekBlush', 0, 1 } },
    { key = 'snout', kind = 'snout', icon = 'icons/skinpatchSnout', size = { 'snoutSize', 0.5, 2 }, strength = { 'snoutLight', 0, 1 } },
}
local function patchesNow(inst, make)
    if not inst.facePatches and make then
        inst.facePatches = facePatches.defaults()
        inst.facePatches.eyes, inst.facePatches.cheeks, inst.facePatches.snout = false, false, false
    end
    return inst.facePatches
end
local function placePatches(inst) facePatches.place(inst, true) end
local function patchKind()
    local key = check().patchKind or 'eyes'
    for _, k in ipairs(PATCH_KINDS) do if k.key == key then return k end end
    return PATCH_KINDS[1]
end
-- the picked patch's own look (face-patches set.looks[kind]: Puppetmaker 2's per-patch picture,
-- colours and pattern), made when first changed
local function kindLook(inst, make)
    local set = patchesNow(inst, make)
    if not set then return nil end
    set.looks = set.looks or {}
    local kind = patchKind().kind
    if make and not set.looks[kind] then set.looks[kind] = {} end
    return set.looks[kind]
end
-- the fill it has now: its own, else the one face-patches made from the skin (on the face's decal)
local function patchFill(inst)
    local look = kindLook(inst)
    if look and look.fgHex then return look.fgHex end
    local body = inst.parts[faceOwner(inst)] and inst.parts[faceOwner(inst)].body
    for _, f in ipairs(body and body:getFixtures() or {}) do
        local ud = f:getUserData()
        if ud and ud.label == 'facepatches' then
            for _, p in ipairs(ud.extra.facePatches or {}) do
                if p.kind == patchKind().kind then
                    local t = p.tint
                    return string.format('%02x%02x%02xff', t[1] * 255, t[2] * 255, t[3] * 255)
                end
            end
        end
    end
    local skin = skinOf(inst, faceOwner(inst))
    return skin and skin.fgHex or 'ccccccff'
end
local function setKindLook(inst, values)
    local look = kindLook(inst, true)
    for k, v in pairs(values) do look[k] = v end
    inst.facePatches[patchKind().key] = true -- changing a patch shows it
    placePatches(inst)
end
local PATCHES = {
    name = 'patches', icon = 'icons/patches',
    shapes = facePatches.SHAPES, allowNone = true,
    picked = function(inst)
        local look = kindLook(inst)
        return inst.facePatches and (look and look.shape or inst.facePatches.shape)
    end,
    pick = function(inst, url)
        if not url then
            inst.facePatches = nil
            placePatches(inst)
        else
            setKindLook(inst, { shape = numberOf(url) })
        end
    end,
    look = function(inst)
        local look = kindLook(inst) or {}
        return { fgHex = patchFill(inst), bgHex = look.bgHex or '00000000', pHex = look.pHex or '00000000',
            pURL = look.pURL, pr = look.pr, psx = look.psx, psy = look.psy }
    end,
    layers = ALL_LAYERS,
    colour = function(inst, layer, hex) setKindLook(inst, { [LAYER_KEY[layer]] = hex }) end,
    setBlock = function(inst, values) setKindLook(inst, values) end,
    kinds = PATCH_KINDS,
    slidersFor = function(inst)
        local k = patchKind()
        local set = inst.facePatches
        if not (set and set[k.key]) then return {} end
        local function slider(def, less, more)
            return { id = k.key .. def[1], less = less, more = more, min = def[2], max = def[3], step = (def[3] - def[2]) / 20,
                get = function(i) return i.facePatches and i.facePatches[def[1]] or def[2] end,
                set = function(i, v)
                    if i.facePatches then i.facePatches[def[1]] = v end
                    placePatches(i)
                end }
        end
        return { slider(k.size, 'icons/patch-ScaleXless', 'icons/patch-ScaleXmore'),
            slider(k.strength, 'icons/pattern-transparent', 'icons/pattern-opaque') }
    end,
    sliders = {},
}

for i, cat in ipairs(CATEGORIES) do
    if cat.name == 'nose' then
        table.insert(CATEGORIES, i + 1, MOUTH)
        table.insert(CATEGORIES, i + 2, TEETH)
        table.insert(CATEGORIES, i + 3, BROWS)
        table.insert(CATEGORIES, i + 4, PATCHES)
        break
    end
end

-- Patterns: every picture in textures/pat/. A part's pattern is its block's pURL, pHex (its colour and,
-- in the alpha, how solid it is) and pr / psx / psy (turn, scale). 'None' is the alpha at 0.
local PATTERNS = {}
for _, file in ipairs(love.filesystem.getDirectoryItems('textures/pat')) do
    if file:match('%.png$') then PATTERNS[#PATTERNS + 1] = file end
end
table.sort(PATTERNS)

local function alphaOf(hex) return (hex and #hex >= 8) and tonumber(hex:sub(7, 8), 16) / 255 or 1 end
local function withAlpha(hex, a)
    hex = (hex and #hex >= 6) and hex:sub(1, 6) or '000000'
    return hex .. string.format('%02x', math.floor(math.max(0, math.min(1, a)) * 255 + 0.5))
end

-- Neck: the strip from the top torso segment to the head (its connected-skin, set on every segment so
-- a change of count keeps it), 0..5 segments. 'None': no neck segments (Puppetmaker's neck-no);
-- picking a skin with none gives it one. Not on a potato.
local function neckSkin(inst)
    local top = partData(inst, 'torso' .. (creation(inst).torsoSegments or 1))
    local cs = top and top.appearance and top.appearance['connected-skin']
    return cs and cs.main
end
local function setNeck(inst, values)
    for i = 1, creation(inst).torsoSegments or 1 do
        characterManager.updateConnectedAppearance(inst, 'torso' .. i, 'connected-skin', values)
    end
end
local NECK = {
    name = 'neck', icon = 'icons/neck', allowNone = true,
    hidden = function(inst) return creation(inst).isPotatoHead or not neckSkin(inst) end,
    shapes = shapeCatalogs.limbSkinTextures,
    picked = function(inst) return (creation(inst).neckSegments or 0) > 0 and neckSkin(inst).bgURL or '' end,
    pick = function(inst, url)
        if not url then return rebuildWith(inst, { neckSegments = 0 }) end
        setNeck(inst, { bgURL = url .. '.png', fgURL = url .. '-mask.png' })
        if (creation(inst).neckSegments or 0) == 0 then rebuildWith(inst, { neckSegments = 1 }) end
    end,
    look = function(inst) return neckSkin(inst) end,
    layers = ALL_LAYERS,
    colour = function(inst, layer, hex) setNeck(inst, { [LAYER_KEY[layer]] = hex }) end,
    setBlock = function(inst, values) setNeck(inst, values) end,
    sliders = {
        { less = 'icons/neck-no', more = 'icons/neck-yes', min = 1, max = 5, step = 1, -- segments
            hidden = function(inst) return (creation(inst).neckSegments or 0) == 0 end,
            get = function(inst) return creation(inst).neckSegments end,
            set = function(inst, v) rebuildWith(inst, { neckSegments = v }) end },
        { less = 'icons/neck-short', more = 'icons/neck-long', min = 10, max = 500, step = 10,
            hidden = function(inst) return (creation(inst).neckSegments or 0) == 0 end,
            get = function(inst) return partData(inst, 'neck1') and partData(inst, 'neck1').dims.h or 150 end,
            set = function(inst, v)
                for i = 1, creation(inst).neckSegments or 0 do characterManager.updatePart('neck' .. i, { h = v }, inst) end
            end },
        { less = 'icons/neck-thin', more = 'icons/neck-thick', min = 0.25, max = 4, step = 0.25,
            get = function(inst) return neckSkin(inst).wmul or inst.scale or 1 end,
            set = function(inst, v) setNeck(inst, { wmul = v }) end },
    },
}

-- Pupils: shape, colour (one: the editor's 'pupil color'), size (width and height together)
local function pupil(inst) return face(inst).pupil end
local PUPILS = {
    name = 'pupils', icon = 'icons/pupil', outlineOnly = true,
    shapes = shapeCatalogs.pupilShapes,
    picked = function(inst) return pupil(inst).shape end,
    pick = function(inst, url) faceSet(inst, { pupilShape = numberOf(url) }) end,
    look = function(inst) return { bgHex = pupil(inst).bgHex, fgHex = '' } end,
    layers = { 'line' },
    colour = function(inst, _, hex) faceSet(inst, { pupilBgHex = hex }) end,
    sliders = {
        { less = 'icons/pupil-small', more = 'icons/pupil-big', min = 0.1, max = 1, step = 0.05,
            get = function(inst) return pupil(inst).wMul end,
            set = function(inst, v)
                local p = pupil(inst)
                local ratio = (p.hMul or v) / math.max(0.01, p.wMul or v)
                faceSet(inst, { pupilWMul = v, pupilHMul = math.min(1, v * ratio) })
            end },
    },
}
for i, cat in ipairs(CATEGORIES) do
    if cat.name == 'head' then table.insert(CATEGORIES, i + 1, NECK) break end
end
for i, cat in ipairs(CATEGORIES) do
    if cat.name == 'eyes' then table.insert(CATEGORIES, i + 1, PUPILS) break end
end

local BY_NAME = {}
for _, cat in ipairs(CATEGORIES) do BY_NAME[cat.name] = cat end

-- which category a tapped Mipo part picks
local function categoryOfPart(inst, partName)
    if partName:match('^torso') then return 'body' end
    if partName == 'head' then return 'head' end
    if partName == 'lear' or partName == 'rear' then return 'ears' end
    if partName:match('^nose') then return 'nose' end
    if partName:match('arm$') then return 'arms' end
    if partName:match('leg$') then return 'legs' end
    if partName:match('hand$') then return 'hands' end
    if partName:match('foot$') then return 'feet' end
    return nil
end

local function fillOf(inst, cat)
    if cat.fill then return cat.fill(inst) end
    if cat.look then return cat.look(inst).fgHex end
    local skin = cat.skin and skinOf(inst, cat.skin(inst)[1])
    return skin and skin.fgHex
end

-- the texture block a category's pictures are drawn with (colours, pattern), for the shape cells
local function lookOf(inst, cat)
    if cat.skin then return skinOf(inst, cat.skin(inst)[1]) end
    if cat.look then return cat.look(inst) end
    if cat.name == 'eyes' then return face(inst).eye end
    if cat.name == 'nose' then return face(inst).nose end
    if cat.name == 'hair' then return haircut(inst).main end
end

-- the colour layers a part has: skin parts all three, others as their category says
local function layersOf(inst, cat)
    local layers = cat.layers or (cat.skin and ALL_LAYERS) or FILL_LINE
    if type(layers) == 'function' then layers = layers(inst) end
    return layers
end

-- the layer the blobs paint: the one picked, if this part has it, else its first
local function layerFor(inst, cat, picked)
    local layers = layersOf(inst, cat)
    for _, l in ipairs(layers) do if l == picked then return l end end
    return layers[1]
end

local function colourOf(inst, cat, layer)
    local block = lookOf(inst, cat)
    return block and block[LAYER_KEY[layer]]
end

local function setColour(inst, cat, layer, hex)
    if cat.skin then setSkin(inst, cat.skin(inst), LAYER_KEY[layer], hex)
    else cat.colour(inst, layer, hex) end
end

-- edits: done now (a tap) or at most every APPLY_EVERY (a drag); the textures after
local function apply(fn)
    local c = check()
    c.pending, c.live = nil, nil
    fn()
    characterManager.rebuildTextures(c.mipo)
    c.lastApply = love.timer.getTime()
end
local function applySoon(fn) check().pending = fn end

local function newMipo()
    local c = check()
    if alive(c.mipo) then characterManager.removeCharacter(c.mipo) end
    c.mipo = characterManager.createCharacter('humanoid', MIPO_X, GROUND_Y - 600, SCALE)
    if c.mipo then characterManager.randomizeMipo(c.mipo) end
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(4000, 100)):setFriction(0.9)
end

local function frame()
    cam:setScale(ZOOM)
    cam:setTranslation(MIPO_X + 380, GROUND_Y - 420)
    check().hold = true
end

function s.onStart()
    check().categories = CATEGORIES -- so the bridge can try every pick and slider (the spike's test)
    worldState.paused = false
    makeGround()
    if not alive(check().mipo) then newMipo() end
    frame()
end

function s.update()
    local c = check()
    if c.pending and love.timer.getTime() - c.lastApply > APPLY_EVERY then apply(c.pending) end
    makerUI.update() -- the shape cells' pictures, baked here and not while drawing
    -- the grid's flick
    local g = c.grid
    if not g.drag and math.abs(g.vel) > 0.5 then
        g.off = g.off + g.vel * love.timer.getDelta()
        g.vel = g.vel * math.exp(-love.timer.getDelta() * 5)
    end
    if c.hold and (love.mouse.isDown(2, 3) or cam.scale ~= ZOOM) then c.hold = false end
end

-- a tap on the Mipo picks its part; a drag pokes it as ever
function s.onPressed(things)
    local c = check()
    c.press = nil
    if not alive(c.mipo) then return end
    for _, thing in ipairs(things or {}) do
        for name, part in pairs(c.mipo.parts) do
            if part.body == thing.body then
                local mx, my = love.mouse.getPosition()
                c.press = { part = name, at = love.timer.getTime(), x = mx, y = my }
                return
            end
        end
    end
end

function s.onReleased()
    local c = check()
    local p = c.press
    c.press = nil
    if not p then return end
    local mx, my = love.mouse.getPosition()
    if love.timer.getTime() - p.at > TAP_TIME or math.abs(mx - p.x) + math.abs(my - p.y) > TAP_MOVE then return end
    local cat = categoryOfPart(c.mipo, p.part)
    if cat and BY_NAME[cat] then
        c.category, c.grid.off, c.grid.vel = cat, 0, 0
        mipoVoice.edited(c.mipo)
    end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then newMipo() end
    if key == 'h' then c.show = not c.show end
    if key == 'd' then c.dev = not c.dev end -- the dev-only rows (sway, springs, damping)
end

-- the shapes grid: flick it up and down; a tap picks (not at the end of a flick)
-- write keys into a part's texture block (skin: through the setter; others: the category's own)
local function setBlock(inst, cat, values)
    if cat.skin then
        for k, v in pairs(values) do setSkin(inst, cat.skin(inst), k, v) end
    elseif cat.setBlock then
        cat.setBlock(inst, values)
    end
end

-- the pattern's sliders, the same for every part with a pattern (made once per part)
local function patternSliders(cat)
    if cat._patternSliders then return cat._patternSliders end
    local function block(inst) return lookOf(inst, cat) end
    cat._patternSliders = {
        -- a bigger scale repeats the pattern more often: finer
        { less = 'icons/pattern-coarse', more = 'icons/pattern-fine', min = 0.25, max = 3, step = 0.25,
            get = function(inst) return block(inst).psx or 1 end,
            set = function(inst, v) setBlock(inst, cat, { psx = v, psy = v }) end },
        { less = 'icons/pattern-ccw', more = 'icons/pattern-cw', min = 0, max = 6.2, step = 0.2,
            get = function(inst) return block(inst).pr or 0 end,
            set = function(inst, v) setBlock(inst, cat, { pr = v }) end },
        { less = 'icons/pattern-transparent', more = 'icons/pattern-opaque', min = 0, max = 1, step = 0.1,
            get = function(inst) return alphaOf(block(inst).pHex) end,
            set = function(inst, v) setBlock(inst, cat, { pHex = withAlpha(block(inst).pHex, v) }) end },
    }
    return cat._patternSliders
end

local function drawGrid(c, inst, cat, layer, x, y, w, h)
    local cols = 4
    local cell = w / cols
    local patterns = layer == 'pattern' -- the pattern button picked: the grid holds the patterns
    local items = {}
    if cat.allowNone or patterns then items[1] = false end -- false: the 'none' cell
    for _, url in ipairs(patterns and PATTERNS or cat.shapes or {}) do items[#items + 1] = url end
    local rows = math.ceil(#items / cols)
    local g = c.grid
    local maxOff = math.max(0, rows * cell - h)
    local over = ui.mouseX >= x and ui.mouseX <= x + w and ui.mouseY >= y and ui.mouseY <= y + h
    if over and ui.mousePressed then g.drag = { y = ui.mouseY, off = g.off, lastY = ui.mouseY, moved = false } end
    if g.drag then
        if ui.mouseIsDown then
            local dy = ui.mouseY - g.drag.y
            if math.abs(dy) > 8 then g.drag.moved = true end
            if g.drag.moved then
                g.off = g.drag.off - dy
                g.vel = -(ui.mouseY - g.drag.lastY) / math.max(love.timer.getDelta(), 1 / 120)
            end
            g.drag.lastY = ui.mouseY
        else
            g.flicked = g.drag.moved
            g.drag = nil
        end
    end
    if g.off < 0 then g.off, g.vel = 0, 0 end
    if g.off > maxOff then g.off, g.vel = maxOff, 0 end

    local look = lookOf(inst, cat)
    local picked = cat.picked(inst)
    if patterns then picked = alphaOf(look.pHex) > 0 and look.pURL or '' end
    ui.pushClip(x, y, w, h)
    for i, url in ipairs(items) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx, cy = x + col * cell, y + row * cell - g.off
        if cy + cell > y and cy < y + h then
            local tapped
            if url == false then
                tapped = makerUI.noneCell('maker-cell-none', cx, cy, cell, picked == nil or picked == '' or picked == 0)
            elseif patterns then
                local pat = hexToRGB(look.pHex)
                pat[4] = math.max(alphaOf(look.pHex), 0.6) -- 'none' picked: the circles still show their pattern
                tapped = makerUI.patternCell('maker-pat-' .. i, cx, cy, cell, url, hexToRGB(look.fgHex), pat,
                    hexToRGB(look.bgHex), look.pr, look.psx, picked == url)
            else
                local isPicked = picked == url .. '.png' or picked == url or picked == numberOf(url)
                tapped = makerUI.partCell('maker-cell-' .. i, cx, cy, cell, url, look, isPicked,
                    cat.outlineOnly and not shapeCatalogs.hairsWithMask[url .. '.png'])
            end
            if tapped and not g.flicked and over then
                if patterns then
                    apply(function()
                        if url then -- a pattern: solid again if it was 'none'
                            local a = alphaOf(look.pHex)
                            setBlock(inst, cat, { pURL = url, pHex = withAlpha(look.pHex, a > 0 and a or 1) })
                        else
                            setBlock(inst, cat, { pHex = withAlpha(look.pHex, 0) })
                        end
                    end)
                else
                    apply(function() cat.pick(inst, url) end)
                end
                mipoVoice.edited(inst)
            end
        end
    end
    ui.popClip()
    if not ui.mouseIsDown then g.flicked = false end
end

function s.drawUI()
    local c = check()
    local inst = c.mipo
    local W, H = love.graphics.getDimensions()
    if not state.playMode then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print('maker spike: play mode shows the card (tab)', 20, H - 30)
        return
    end
    if not (c.show and alive(inst)) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame

    local cw = math.min(440, W * 0.37)
    local cx, cy, ch = W - cw - 16, 16, H - 32
    makerUI.card(cx, cy, cw, ch)
    if c.dev then
        love.graphics.setColor(0.6, 0.2, 0.1)
        love.graphics.print('dev', cx + cw - 46, cy + 10)
        love.graphics.setColor(1, 1, 1)
    end
    local m = cw * 0.08
    local x, w = cx + m, cw - m * 2
    local y = cy + ch * 0.06

    -- the parts in a row
    local shown = {}
    for _, cat in ipairs(CATEGORIES) do
        if not (cat.hidden and cat.hidden(inst)) then shown[#shown + 1] = cat end
    end
    if not BY_NAME[c.category] or (BY_NAME[c.category].hidden and BY_NAME[c.category].hidden(inst)) then
        c.category = 'body'
    end
    local perRow = 10 -- nineteen parts: two rows (a flickable row is MM4's)
    local isize = w / perRow
    for i, cat in ipairs(shown) do
        local fill = hexToRGB(fillOf(inst, cat))
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        if makerUI.iconButton('maker-cat-' .. cat.name, x + col * isize, y + row * isize * 0.85, isize, cat.icon,
                { mask = fill, picked = c.category == cat.name, paper = (i % 7) + 1, bare = true }) then
            c.category, c.grid.off, c.grid.vel = cat.name, 0, 0
            mipoVoice.edited(inst)
        end
    end
    y = y + isize * (1 + 0.85 * (math.ceil(#shown / perRow) - 1)) + m * 0.3
    local cat = BY_NAME[c.category]

    -- dice and the colour layer
    local dsize = isize * 0.9
    if makerUI.iconButton('maker-dice', x, y, dsize, 'big-button-dice', { mask = { 0.95, 0.75, 0.4 }, bare = true }) then
        characterManager.randomizeMipo(inst)
        mipoVoice.dice(inst)
    end
    -- the colour layers this part has (fill / line / pattern, Puppetmaker's uifill / uiline / uipattern),
    -- each showing its colour now; none when it has only one
    local layers = layersOf(inst, cat)
    local layer = layerFor(inst, cat, c.layer) or 'none'
    if cat.kinds then -- face patches: one button per patch, next to the dice: on / off, and which one
        local set = inst.facePatches
        local skin = hexToRGB(fillOf(inst, cat))
        for i, k in ipairs(cat.kinds) do
            local on = set and set[k.key]
            local bx = x + i * dsize
            if makerUI.iconButton('maker-patch-' .. k.key, bx, y, dsize, k.icon,
                    { mask = on and skin or nil, picked = on and c.patchKind == k.key, dim = not on, paper = i + 2, bare = true }) then
                apply(function()
                    local s2 = patchesNow(inst, true)
                    if s2[k.key] and c.patchKind == k.key then s2[k.key] = false
                    else s2[k.key] = true end
                    c.patchKind = k.key
                    placePatches(inst)
                end)
                mipoVoice.edited(inst)
            end
        end
    end
    if #layers > 1 then
        for i, l in ipairs(layers) do
            local bx = x + w - (#layers - i + 1) * dsize
            if makerUI.iconButton('maker-layer-' .. l, bx, y, dsize, 'colorpick/ui' .. l,
                    { mask = hexToRGB(colourOf(inst, cat, l)), picked = l == layer, paper = i + 2, bare = true }) then
                c.layer = l
                mipoVoice.edited(inst)
            end
        end
    end
    y = y + dsize + m * 0.4

    -- the sliders on a taped strip, at the bottom
    local sliders = {}
    local source = layer == 'pattern' and patternSliders(cat) or (cat.slidersFor and cat.slidersFor(inst)) or cat.sliders
    local function take(list)
        for _, sl in ipairs(list) do
            if not (sl.hidden and sl.hidden(inst)) and not (sl.dev and not c.dev) then sliders[#sliders + 1] = sl end
        end
    end
    take(source)
    if cat.build and layer ~= 'pattern' then take(BUILD_SLIDERS) end
    local columns = #sliders > 3 and 2 or 1 -- more than three: two columns, smaller
    local colW = (w - (columns - 1) * m * 0.5) / columns
    local ssize = math.min(48, colW / (columns == 2 and 4.2 or 7))
    local rowH = ssize * 1.25
    local switches = layer ~= 'pattern' and cat.switches or {}
    local switchRows = math.ceil(#switches / 2)
    local slidersH = (math.ceil(#sliders / columns) + switchRows) * rowH + m * 0.6
    local blobSize = w / 8
    local blobsH = #layers > 0 and (blobSize * 2 + m * 0.4) or 0 -- no colours of its own (patches): no blobs
    local bottom = cy + ch - m * 0.9
    local sy0 = bottom - slidersH
    local by0 = sy0 - blobsH

    if c.gridFor ~= cat.name .. layer then c.gridFor, c.grid.off, c.grid.vel = cat.name .. layer, 0, 0 end
    drawGrid(c, inst, cat, layer, x, y, w, by0 - y - m * 0.3)

    -- paint blobs
    local current = colourOf(inst, cat, layer)
    for i, hex in ipairs(#layers > 0 and PALETTE or {}) do
        local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
        local isPicked = current and current:sub(1, 6):lower() == hex
        if makerUI.blob('maker-blob-' .. i, x + col * blobSize, by0 + row * blobSize, blobSize, hexToRGB(hex), i, isPicked) then
            apply(function() setColour(inst, cat, layer, hex .. 'ff') end)
            mipoVoice.edited(inst)
        end
    end

    makerUI.tape(x - m * 0.4, sy0, w + m * 0.8, slidersH)
    for i, sl in ipairs(sliders) do
        local id = 'maker-' .. cat.name .. '-' .. (sl.id or sl.less)
        local shownValue = (c.live and c.live[id]) or sl.get(inst) or sl.min -- dragged, not applied yet
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local v, amount = makerUI.iconSlider(id, x + col * (colW + m * 0.5), sy0 + m * 0.3 + row * rowH,
            colW, ssize, shownValue, sl.min, sl.max, sl.step, sl.less, sl.more)
        if v then
            c.live = c.live or {}
            c.live[id] = v
            applySoon(function() sl.set(inst, v) end)
            mipoVoice.edited(inst, amount)
        end
    end
    -- on/off settings (teeth over the lip, the gum): drawn switches in one row under the sliders
    local swY = sy0 + m * 0.3 + math.ceil(#sliders / columns) * rowH
    local swW = w / math.min(2, math.max(1, #switches)) -- two to a row
    for i, sw in ipairs(switches) do
        local sx = x + ((i - 1) % 2) * swW
        local rowY = swY + math.floor((i - 1) / 2) * rowH
        local tw, th = ssize * 1.6, ssize * 0.7
        local on = makerUI.toggle('maker-sw-' .. cat.name .. '-' .. i, sx, rowY + (rowH - th) / 2 - ssize * 0.1, tw, th,
            sw.get(inst) and true or false)
        if on ~= nil then
            apply(function() sw.set(inst, on) end)
            mipoVoice.edited(inst)
        end
        love.graphics.setColor(0.2, 0.15, 0.12)
        love.graphics.print(sw.label, sx + tw + 8, rowY + rowH / 2 - 10)
        love.graphics.setColor(1, 1, 1)
    end

    -- a slider let go: its last value now
    if c.pending and not ui.mouseIsDown then apply(c.pending) end
end

return s
