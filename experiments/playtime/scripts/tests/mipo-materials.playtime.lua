-- mipo-materials: Mipos wearing materials, a different one per part (brass legs, a velvet body), getting wet and drying
-- MATERIALS MT6 (docs/MATERIALS.md, 2026-11-06): the materials from material-check, now in the engine:
-- a part's `extra.material` (src/render/materials.lua) is drawn by the plasticine shader
-- (src/render/shaders.lua) under the scene's own lights, the part's colours and pattern kept. Wet
-- (src/wet.lua): spots that stick where they land and dry from the edge in, and a waterline.
-- The scene is light-grass-check's (its lights, stones, fence and three Mipos) at a fixed day,
-- without its clock and shadows.
-- The panel (right): which Mipo (or all), a material per part (click: the next one), the water's
-- height, rain, dry.
-- play mode (tab): drag the Mipos into the water and out again; carry the warm and cool lamps.
-- keys: w a wet spot at the mouse   d dry everything

local s = {}

-- a Mipo's parts by their body's label
local GROUPS = {
    { name = 'body', labels = { torso1 = true } },
    { name = 'head', labels = { head = true } },
    { name = 'ears', labels = { lear = true, rear = true } },
    { name = 'arms', labels = { luarm = true, llarm = true, ruarm = true, rlarm = true } },
    { name = 'hands', labels = { lhand = true, rhand = true } },
    { name = 'legs', labels = { luleg = true, llleg = true, ruleg = true, rlleg = true } },
    { name = 'feet', labels = { lfoot = true, rfoot = true } },
}
-- the mouth's parts (on the head, by their mouthCurve): the lips, the teeth, the inside
local MOUTH_GROUPS = { 'eyes', 'pupils', 'brows', 'nose', 'lips', 'teeth', 'inside' }
-- the face's stickers (decals) by their label
local DECAL_PART = { leye = 'eyes', reye = 'eyes', lpupil = 'pupils', rpupil = 'pupils', nose = 'nose',
    lbrow = 'brows', rbrow = 'brows' }
local MOUTH_PART = { upper = 'lips', lower = 'lips', teeth = 'teeth' }
-- the inside's colour: as the Mipo has it, then a few
local INSIDE_COLOURS = { false, '000000cc', '5a1e2acc', 'b5546acc', '2a3a6acc' }
local INSIDE_NAMES = { 'as is', 'black', 'dark red', 'pink', 'deep blue' }
-- the light on the mouth: as on the parts, without the baked form (the lips are strips)
local MOUTH_LIT = { plasticineLightAdd = true, plasticineLightGain = 0.5, plasticineLightZ = 0.35 }
-- clay, then the presets (src/render/materials.lua)
local CHOICES = { false }
for _, name in ipairs(materials.NAMES) do CHOICES[#CHOICES + 1] = name end

-- the light liked in light-grass-check: lights add up, a strong swing, from the side, baked round
local LIT = { plasticine = true, plasticineLightAdd = true, plasticineLightGain = 0.5, plasticineLightZ = 0.35,
    plasticineFormRadius = 0.35, plasticineFormBaked = true, plasticineFormRise = 1 }
local LIT_PARTS = { texfixture = true, ['connected-texture'] = true, ['trace-vertices'] = true }

-- a day: the sun high on the left, the sky light, a faint back light, the rest off
local DAY = {
    sun = { 'fff2d9ff', 1.2 }, ['sky light'] = { '9cc8ffff', 0.6 }, ['back light'] = { 'ffffffff', 0.6 },
    moon = { 'a8c0ffff', 0 }, ['warm lamp'] = { nil, 0 }, ['cool lamp'] = { nil, 0 }, ['turning lamp'] = { nil, 0 },
}
local WATER_TOP = { low = 450, high = -150 } -- world y: the ground's top (no water) .. up to their heads
local WATER_X = { -1700, 1700 }

local function mm()
    state.mipoMaterials = state.mipoMaterials or { which = 0, choice = {}, water = 0 }
    return state.mipoMaterials
end

local function lightOf(label)
    for _, thing in ipairs(getObjectsByLabel(label)) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'light' then return thing.body, ud.extra end
        end
    end
end

-- the Mipos, in the order they're found (1, 2, 3)
local function mipoIds()
    local ids, seen = {}, {}
    for _, body in ipairs(world:getBodies()) do
        local thing = body:getUserData() and body:getUserData().thing
        if thing and thing.mipoId and not seen[thing.mipoId] then
            seen[thing.mipoId] = true
            ids[#ids + 1] = thing.mipoId
        end
    end
    table.sort(ids)
    return ids
end

local function groupOf(label)
    for _, g in ipairs(GROUPS) do
        if g.labels[label] then return g.name end
    end
end

-- a Mipo's choice for a group (index into CHOICES); a Mipo with none follows 'all'
-- each lower lip's own inside colour, from before the panel changed it (a plain table: no setmetatable in
-- the script sandbox; it goes with the script on a reload)
local originalInside = {}

local function choiceFor(mipoId, group)
    local c = mm()
    local own = c.choice[mipoId]
    local all = c.choice.all or {}
    return (own and own[group]) or all[group] or 1
end

-- every frame (a Mipo rebuilt from its DNA has new parts): lit, and its material per part
local function dressMipos()
    for _, body in ipairs(world:getBodies()) do
        local thing = body:getUserData() and body:getUserData().thing
        if thing and thing.mipoId then
            local group = groupOf(thing.label)
            local material = group and CHOICES[choiceFor(thing.mipoId, group)] or false
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                local extra = ud and ud.extra
                local mouthGroup = extra and MOUTH_PART[extra.mouthCurve]
                local decalGroup = ud and ud.subtype == 'decal' and DECAL_PART[ud.label]
                if decalGroup then
                    for k, v in pairs(MOUTH_LIT) do extra[k] = v end
                    extra.material = CHOICES[choiceFor(thing.mipoId, decalGroup)] or nil
                elseif mouthGroup then
                    for k, v in pairs(MOUTH_LIT) do extra[k] = v end
                    extra.material = CHOICES[choiceFor(thing.mipoId, mouthGroup)] or nil
                    if extra.mouthCurve == 'lower' then
                        extra.innerMaterial = CHOICES[choiceFor(thing.mipoId, 'inside')] or nil
                        if originalInside[extra] == nil then originalInside[extra] = extra.backdropHex or false end
                        local colour = INSIDE_COLOURS[choiceFor(thing.mipoId, 'inside colour')]
                        extra.backdropHex = colour or originalInside[extra] or nil
                    end
                elseif ud and LIT_PARTS[ud.subtype] and extra and extra.main then
                    for k, v in pairs(LIT) do extra[k] = v end
                    extra.material = material or nil
                end
            end
        end
    end
end

function s.onStart()
    worldState.paused = false
    for label, look in pairs(DAY) do
        local _, extra = lightOf(label)
        if extra then
            if look[1] then extra.colorHex = look[1] end
            extra.intensity = look[2]
        end
    end
    -- the carried lamps float where they're let go and push nothing (as in light-grass-check)
    for _, label in ipairs({ 'warm lamp', 'cool lamp' }) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            thing.body:setGravityScale(0)
            thing.body:setLinearDamping(4)
            thing.body:setFixedRotation(true)
            for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setSensor(true) end
        end
    end
end

function s.onUnload()
    wet.clear()
end

local function waterY()
    local c = mm()
    if c.water <= 0 then return nil end
    return WATER_TOP.low + (WATER_TOP.high - WATER_TOP.low) * c.water
end

-- rain: a few wet spots on random Mipo parts
local function rain()
    local bodies = {}
    for _, body in ipairs(world:getBodies()) do
        local thing = body:getUserData() and body:getUserData().thing
        if thing and thing.mipoId then bodies[#bodies + 1] = body end
    end
    for _ = 1, 8 do
        local body = bodies[love.math.random(#bodies)]
        if body then
            local x, y = body:getPosition()
            wet.splash(x + love.math.random(-20, 20), y + love.math.random(-20, 20), love.math.random(25, 55), 1)
        end
    end
end

function s.update(dt)
    dressMipos()
    wet.setWaterline(waterY())
    wet.update(dt or 0)
end

function s.onKeyPress(key)
    if key == 'w' then
        local x, y = mouseWorldPos()
        wet.splash(x, y, 55, 1)
    elseif key == 'd' then
        wet.clear()
    end
end

-- the water: see-through blue over what's in it, a bright line on top
function s.draw()
    local y = waterY()
    if not y then return end
    love.graphics.setColor(0.35, 0.6, 0.85, 0.35)
    love.graphics.rectangle('fill', WATER_X[1], y, WATER_X[2] - WATER_X[1], 900)
    love.graphics.setColor(0.85, 0.95, 1, 0.8)
    love.graphics.setLineWidth(6)
    love.graphics.line(WATER_X[1], y, WATER_X[2], y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local PANEL = { w = 330, row = 36, pad = 6 }

function s.drawUI()
    local c = mm()
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local ids = mipoIds()
    local rows = #GROUPS + #MOUTH_GROUPS + 6
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    local half = (w - PANEL.pad * 3) / 2
    ui.panel(x0, y0, w, h, '•• mipo materials ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local function button(x, y, text, width) return ui.button(x, y, width or half, text, PANEL.row - 6) end
        -- which Mipo the part buttons change (0: all of them)
        local x, y = row()
        local whichName = c.which == 0 and 'all Mipos' or ('Mipo ' .. c.which)
        if button(x, y, whichName) then c.which = (c.which + 1) % (#ids + 1) end
        if button(x + half + PANEL.pad, y, 'all clay') then
            local key = c.which == 0 and 'all' or ids[c.which]
            if c.which == 0 then c.choice = {} else c.choice[key] = nil end
        end
        local key = c.which == 0 and 'all' or ids[c.which]
        c.choice[key] = c.choice[key] or {}
        for _, g in ipairs(GROUPS) do
            x, y = row()
            ui.label(x, y + 4, g.name)
            local index = c.choice[key][g.name] or (c.which ~= 0 and (c.choice.all or {})[g.name]) or 1
            local text = CHOICES[index] or 'clay'
            if button(x + 90, y, text, w - 90 - PANEL.pad * 2) then
                c.choice[key][g.name] = index % #CHOICES + 1
            end
        end
        for _, name in ipairs(MOUTH_GROUPS) do
            x, y = row()
            ui.label(x, y + 4, name)
            local index = c.choice[key][name] or (c.which ~= 0 and (c.choice.all or {})[name]) or 1
            if button(x + 90, y, CHOICES[index] or 'clay', w - 90 - PANEL.pad * 2) then
                c.choice[key][name] = index % #CHOICES + 1
            end
        end
        x, y = row()
        ui.label(x, y + 4, 'its colour')
        local ci = c.choice[key]['inside colour'] or (c.which ~= 0 and (c.choice.all or {})['inside colour']) or 1
        if button(x + 90, y, INSIDE_NAMES[ci], w - 90 - PANEL.pad * 2) then
            c.choice[key]['inside colour'] = ci % #INSIDE_COLOURS + 1
        end
        x, y = row()
        ui.label(x, y + 4, 'water')
        local v = ui.sliderWithInput('mm-water', x + 90, y - 2, 130, 0, 1, c.water, nil, 0.01)
        if v then c.water = v + 0 end
        x, y = row()
        if button(x, y, 'rain') then rain() end
        if button(x + half + PANEL.pad, y, 'dry') then wet.clear() end
        x, y = row()
        ui.label(x, y + 4, 'w: a wet spot at the mouse   d: dry')
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

return s
