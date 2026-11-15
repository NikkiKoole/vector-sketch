-- food: food in, food out: a Mipo eats, drinks, its belly fills, then it needs the potty (FOOD-IN-FOOD-OUT FO1)
-- Drag a food to its mouth: the mouth opens as it comes near, bites (a piece off the food, crumbs), chews with
-- full cheeks, swallows. The sprout it doesn't like: "blah", and the bite flies back out. Tip the cup at its mouth
-- to drink. The belly (the soft torso's lobes, SOFT-TORSO) gets rounder with what goes in; what's in turns
-- into a need over time: a wiggle and a worried face. Put it on the potty: pee, poop (a soft blob), "ahh".
-- The mouth is the scene's while eating (instance.mouthTakenBy: the feelings and the voice leave it alone).
-- Keys: r new food and a full cup, c clean up the potty, f feed it full (to try the potty), h the panel.
local s = {}

local GROUND_Y = 600
local MIPO_SCALE = 0.6       -- faces to read, like the emotions spike
local K = MIPO_SCALE / 0.3   -- sizes below are for a 0.3 Mipo
local POTTY_X = 800

-- r: radius, bites: how many to eat it all, fill: belly per whole food
local FOODS = {
    { kind = 'apple', r = 55, bites = 3, fill = 0.35, likes = true, color = { 0.86, 0.2, 0.17 } },
    { kind = 'cookie', r = 45, bites = 2, fill = 0.3, likes = true, color = { 0.82, 0.6, 0.34 } },
    { kind = 'berry', r = 20, bites = 1, fill = 0.08, likes = true, color = { 0.42, 0.16, 0.55 } },
    { kind = 'berry', r = 20, bites = 1, fill = 0.08, likes = true, color = { 0.42, 0.16, 0.55 } },
    { kind = 'sprout', r = 32, bites = 2, fill = 0, likes = false, color = { 0.36, 0.62, 0.24 } },
}
local KIND = {}
for _, f in ipairs(FOODS) do KIND[f.kind] = f end

-- the tuning (live, not saved): the panel's sliders write these
local function st()
    state.food = state.food or {
        showPanel = true, debug = false,
        digest = 1,      -- how quickly what's eaten turns into a need (x)
        belly = 1,       -- how much a full belly pushes the lobes out (x)
        open = 1,        -- how far the food is when the mouth starts opening (head widths)
        crumbs = {}, drops = {},
    }
    return state.food
end

-- per Mipo, on the instance (a hot swap keeps it)
local function tummy(inst)
    inst.tummy = inst.tummy or { food = 0, water = 0, pee = 0, poop = 0, phase = 'idle', t = 0, open = 0,
        look = { x = 0, y = 0 } }
    return inst.tummy
end

---------------------------------------------------------------- the world

local function mipos()
    local list = {}
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return list
end

local function bodiesLabelled(prefix)
    local out = {}
    for _, body in ipairs(world:getBodies()) do
        local ud = body:getUserData()
        local label = ud and ud.thing and ud.thing.label
        if label and label:sub(1, #prefix) == prefix then out[#out + 1] = body end
    end
    return out
end

local function ensureGround()
    if getObjectsByLabel('ground')[1] then return end
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 8000, height = 600,
        bodyType = 'static', label = 'ground' })
    if not thing then return end
    local tile = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    tile.main = tile.main or {}
    tile.main.bgURL, tile.opacity, tile.tileWidthM, tile.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
end

local function ensureMipo()
    if #mipos() > 0 then return end
    local inst = characterManager.createCharacter('humanoid', 0, GROUND_Y - 700, MIPO_SCALE)
    if not inst then return end
    characterManager.randomizeMipoConstrained(inst)
    characterManager.rebuildFromCreation(inst, { torsoLobes = true }) -- a belly that can fill
end

-- a table to put the food on, left of the Mipo
local TABLE = { x = -1050, w = 1200, h = 420, top = 30 }
local function ensureTable()
    if getObjectsByLabel('table')[1] then return end
    objectManager.addThing('rectangle', { x = TABLE.x, y = GROUND_Y - TABLE.h + TABLE.top / 2,
        width = TABLE.w, height = TABLE.top, bodyType = 'static', label = 'table' })
    objectManager.addThing('rectangle', { x = TABLE.x, y = GROUND_Y - (TABLE.h - TABLE.top) / 2,
        width = 60, height = TABLE.h - TABLE.top, bodyType = 'static', label = 'table-leg' })
end

local function makeFood(def, x, y)
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = def.r * K, label = 'food-' .. def.kind })
    if not thing then return end
    thing.biteLeft = def.bites
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:getUserData() then fixture:setFriction(0.9) end
    end
end

local function resetFood()
    for _, body in ipairs(bodiesLabelled('food-')) do objectManager.destroyBody(body) end
    local x = TABLE.x - TABLE.w / 2 + 70
    for _, def in ipairs(FOODS) do
        makeFood(def, x + def.r * K, GROUND_Y - TABLE.h - def.r * K - 4)
        x = x + def.r * K * 2 + 30
    end
    for _, body in ipairs(bodiesLabelled('cup')) do objectManager.destroyBody(body) end
    props.makeCup(TABLE.x + TABLE.w / 2 - 150, GROUND_Y - TABLE.h - 85 * K, K)
end

-- a potty: a low U (no water), right of the Mipo
local function ensurePotty()
    if getObjectsByLabel('potty')[1] then return end
    local w, h, wall = 300 * K, 110 * K, 16 * K
    local x, y = POTTY_X, GROUND_Y - h / 2
    local hw, hh = w / 2, h / 2
    local thing = objectManager.addThing('custom', { x = x, y = y, bodyType = 'static', label = 'potty', vertices = {
        x - hw, y - hh, x - hw + wall, y - hh, x - hw + wall, y + hh - wall, x + hw - wall, y + hh - wall,
        x + hw - wall, y - hh, x + hw, y - hh, x + hw, y + hh, x - hw, y + hh } })
    return thing
end

---------------------------------------------------------------- sounds (made here, nothing to load)

local sounds = {}
local function makeSound(name, seconds, fn)
    local rate = 44100
    local n = math.floor(seconds * rate)
    local data = love.sound.newSoundData(n, rate, 16, 1)
    local prev = 0
    for i = 0, n - 1 do
        local v
        v, prev = fn(i / rate, i / n, prev)
        data:setSample(i, math.max(-1, math.min(1, v)))
    end
    sounds[name] = love.audio.newSource(data, 'static')
end

local function ensureSounds()
    if sounds.crunch or not (love.audio and love.sound) then return end
    -- a crunch: crackly noise, short, darker as it dies away
    makeSound('crunch', 0.11, function(t, u, prev)
        local crackle = (love.math.random() < 0.25) and (love.math.random() * 2 - 1) or 0
        local v = prev * 0.55 + crackle * 0.9
        return v * (1 - u) ^ 2, v
    end)
    -- a soft munch, for chewing
    makeSound('munch', 0.07, function(t, u, prev)
        local v = prev * 0.85 + (love.math.random() * 2 - 1) * 0.15
        return v * math.sin(u * math.pi) * 1.4, v
    end)
    -- a gulp: a falling bubble
    makeSound('gulp', 0.16, function(t, u)
        local f = 340 - 220 * u
        return math.sin(2 * math.pi * f * t) * math.sin(u * math.pi) * 0.5, 0
    end)
    -- a plop, for what lands in the potty
    makeSound('plop', 0.18, function(t, u)
        local f = 120 + 260 * u * u
        return math.sin(2 * math.pi * f * t) * (1 - u) ^ 1.5 * 0.6, 0
    end)
end

local function play(name, pitch, volume)
    local src = sounds[name]
    if not src then return end
    local c = src:clone()
    c:setPitch((pitch or 1) * (0.93 + love.math.random() * 0.14))
    c:setVolume((volume or 1) * (mipoVoice.volume or 1) * (mipoVoice.masterVolume or 1))
    c:play()
end

---------------------------------------------------------------- the mouth

-- the face's part (its thing carries mouthShapeVec), the upper lip, and the mouth in the world
local function mouthOf(inst)
    local part, lip = mipoVoice.findMouth(inst)
    if not (part and lip) then return nil end
    local x, y = part.body:getWorldPoint(lip.ox, lip.oy)
    return part, lip, x, y
end

local function headRadius(inst)
    local owner = inst.dna.creation.isPotatoHead and 'torso1' or 'head'
    local _, r = mipoFacing.headBox(inst, owner)
    return r or 150 * K
end


-- its own mouth (from the lip's curve points, as the voice does), mixed toward `name` by `amount`,
-- `wide` stretches it across (full cheeks)
local function mouthVec(lip, name, amount, wide)
    local cp, vec = lip.curvePoints, {}
    local target = mipoVoice.shapeByName(name) or mipoVoice.shapeByName('closed')
    for i = 1, 16, 2 do
        local rx = (cp[i] - lip.mouthX) / lip.mouthScaleX
        local ry = (cp[i + 1] - lip.mouthY) / lip.mouthScaleY
        vec[i] = (rx + (target[i] - rx) * amount) * (wide or 1)
        vec[i + 1] = ry + (target[i + 1] - ry) * amount
    end
    return vec
end

local function takeMouth(inst, part, vec)
    inst.mouthTakenBy = 'food'
    part.mouthShapeVec = vec
end

local function giveMouthBack(inst, part)
    if inst.mouthTakenBy ~= 'food' then return end
    inst.mouthTakenBy = nil
    if part then part.mouthShapeVec = nil end -- its own mouth; the feelings take over from here
end

---------------------------------------------------------------- food

local function foodDef(body)
    local label = body:getUserData().thing.label
    return KIND[label:sub(6)]
end

local function radiusOf(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() and fixture:getShape():getType() == 'circle' then
            return fixture:getShape():getRadius(), fixture
        end
    end
    return 0
end

local function crumbs(x, y, color, n, size)
    local c = st()
    for _ = 1, n do
        local a = -math.pi / 2 + (love.math.random() - 0.5) * 2.4
        local v = (150 + love.math.random() * 300) * K
        c.crumbs[#c.crumbs + 1] = { x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v,
            r = (3 + love.math.random() * 4) * K * (size or 1), life = 0.8 + love.math.random() * 0.5,
            color = color }
    end
end

-- a bite off the food: smaller (the same body, so a drag carries on), or gone with the last bite
local function bite(body, def)
    local thing = body:getUserData().thing
    thing.biteLeft = (thing.biteLeft or def.bites) - 1
    if thing.biteLeft <= 0 then
        objectManager.destroyBody(body)
        return true
    end
    local r, fixture = radiusOf(body)
    local newR = r * math.sqrt(thing.biteLeft / (thing.biteLeft + 1))
    local density, friction = fixture:getDensity(), fixture:getFriction()
    fixture:destroy()
    local f = love.physics.newFixture(body, love.physics.newCircleShape(newR), density)
    f:setFriction(friction)
    thing.radius = newR
    return false
end

-- a piece spat out: a small body thrown forward, gone after a while
local function spit(inst, x, y, def)
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = def.r * K * 0.45,
        label = 'spat-' .. def.kind })
    if not thing then return end
    local facing = (mipoFacing.angle and mipoFacing.angle(inst) or 0) < 0 and -1 or 1
    local m, perM = thing.body:getMass(), love.physics.getMeter() / 100 -- speeds as at 100 px per metre
    thing.body:applyLinearImpulse(m * facing * 300 * perM, m * -250 * perM)
    thing.spatAt = love.timer.getTime()
end

---------------------------------------------------------------- the belly

-- Belly pressure: each lower lobe pushed out and down (the belly rounds and sags), up to 1.6 lobe radii at
-- `amount` 1, against its
-- springs, and the torso pushed back as hard (a force inside the Mipo, so it can't tip it over). The lobes'
-- ropes get that much longer to let them go (their own length kept on the joint's userData the first time).
local function setBelly(inst, amount)
    local torso = inst.parts.torso1.body
    for i = 1, torsoLobes.MAX do
        local part = inst.parts['lobe' .. i]
        local body = part and part.body
        if body and not body:isDestroyed() then
            local r = radiusOf(body)
            local ax, ay = torso:getLocalPoint(body:getWorldCenter())
            local push, hz = ay > 0 and amount * 1.6 * r or 0, 0 -- the lower lobes only: not the chest
            for _, joint in ipairs(body:getJoints()) do
                local ud = joint:getUserData()
                if joint:getType() == 'rope' and type(ud) == 'table' then
                    ud.foodRest = ud.foodRest or joint:getMaxLength()
                    joint:setMaxLength(ud.foodRest + push * 1.2)
                elseif joint:getType() == 'distance' then
                    hz = hz + joint:getFrequency() -- two springs: their stiffness adds
                end
            end
            local lx, ly = body:getWorldCenter()
            local dx, dy = torso:getWorldVector(ax > 0 and 0.7 or -0.7, 0.7) -- out and down, in the torso's frame
            if push > 0 and hz > 0 then
                local w = 2 * math.pi * hz / math.sqrt(2)
                local f = body:getMass() * w * w * push
                body:applyForce(dx * f, dy * f)
                torso:applyForce(-dx * f, -dy * f, lx, ly)
            end
        end
    end
end

---------------------------------------------------------------- the potty

local function onPotty(inst)
    local potty = getObjectsByLabel('potty')[1]
    if not potty then return false end
    local px, py = potty.body:getPosition()
    local tx, ty = inst.parts.torso1.body:getPosition()
    local vx, vy = inst.parts.torso1.body:getLinearVelocity()
    return math.abs(tx - px) < 150 * K and ty < py and ty > py - 900 * K and vx * vx + vy * vy < (200 * K) ^ 2
end

local function bottomOf(inst)
    local torso = inst.parts.torso1
    local lowest, lx, ly = -math.huge, torso.body:getPosition()
    for _, fixture in ipairs(torso.body:getFixtures()) do
        if not fixture:getUserData() then
            local _, _, _, y2 = fixture:getBoundingBox()
            if y2 > lowest then lowest, ly = y2, y2 end
        end
    end
    return lx, ly
end

local function makePoop(x, y)
    local thing = props.makeBlob(x, y, 70 * K)
    if not thing then return end
    thing.label = 'poop'
    local fixture
    for _, f in ipairs(thing.body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.subtype == 'softbody' then fixture = f end
    end
    if fixture then
        local extra = fixture:getUserData().extra
        extra.main.fgHex, extra.main.pHex, extra.main.pURL = '7a4e2cff', '5c3a20ff', 'type0.png'
        extra.dirty = true
    end
end

---------------------------------------------------------------- each Mipo, each frame

-- Food near a Mipo's face passes in front of it (its Mipo's collision group) instead of bumping the head,
-- so it can reach the mouth; further off it collides with everything again.
local function mipoGroup(inst)
    for _, fixture in ipairs(inst.parts.head and inst.parts.head.body:getFixtures() or {}) do
        if not fixture:isSensor() then return fixture:getGroupIndex() end
    end
    return 0
end

local function passFace(inst, R, mx, my)
    local group = mipoGroup(inst)
    if group >= 0 then return end
    local list = bodiesLabelled('food-')
    for _, cup in ipairs(bodiesLabelled('cup')) do list[#list + 1] = cup end
    for _, body in ipairs(list) do
        local x, y = body:getPosition()
        local near = (x - mx) ^ 2 + (y - my) ^ 2 < (R * 3) ^ 2
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:getUserData() then
                local want = near and group or 0
                if fixture:getGroupIndex() ~= want then fixture:setGroupIndex(want) end
            end
        end
    end
end

local function nearestFood(mx, my, reach)
    local best, bestD = nil, reach
    for _, body in ipairs(bodiesLabelled('food-')) do
        local x, y = body:getPosition()
        local d = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2) - radiusOf(body)
        if d < bestD then best, bestD = body, d end
    end
    return best, bestD
end

-- the nearest cup with water: how far its rim's low corner is from the mouth
local function nearestCup(mx, my, reach)
    local best = reach
    for _, body in ipairs(bodiesLabelled('cup')) do
        for _, fixture in ipairs(body:getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'liquid' and (ud.extra.fill or 0) > 0.02 then
                local cx, cy = liquid.mouthPoint(ud.extra, body)
                local d = cx and math.sqrt((cx - mx) ^ 2 + (cy - my) ^ 2)
                if d and d < best then best = d end
            end
        end
    end
    return best < reach and best or nil
end

-- What spills over a cup's rim near a Mipo's mouth is drunk (src/liquid.lua's state.liquidDrinkHook):
-- the cup empties as fast as it's tipped. Returns what's left to spill.
function s.onDrink(extra, body, spilled)
    local cx, cy = liquid.mouthPoint(extra, body)
    if not cx then return spilled end
    for _, inst in ipairs(mipos()) do
        local part, _, mx, my = mouthOf(inst)
        local R = part and headRadius(inst)
        if R and (cx - mx) ^ 2 + (cy - my) ^ 2 < (R * 1.2) ^ 2 then
            local c = liquid.container(extra, body)
            local full = liquid.volume(c.hull, c.holes)
            local tm = tummy(inst)
            tm.water = tm.water + (full > 0 and spilled / full or 0) * 2
            tm.sipAt = love.timer.getTime()
            return 0
        end
    end
    return spilled
end

local function feel(inst, name, amount, hold) mipoEmotion.set(inst, name, amount, hold, false) end

local function tick(inst, dt)
    local c, tm = st(), tummy(inst)
    local part, lip, mx, my = mouthOf(inst)
    if not part then return end
    local R = headRadius(inst)
    tm.t = tm.t + dt
    passFace(inst, R, mx, my)

    -- inside: what's eaten and drunk turns into a need, slowly
    local rate = 0.02 * c.digest * dt
    local fromFood, fromWater = math.min(tm.food, rate), math.min(tm.water, rate * 2)
    tm.food, tm.water = tm.food - fromFood, tm.water - fromWater
    tm.poop, tm.pee = tm.poop + fromFood * 1.6, tm.pee + fromWater * 1.6
    -- the belly glides to how full it is (a jump at once pushed the lobes hard enough to tip a Mipo over)
    local full = math.min(1.2, tm.food + tm.water * 0.7) * c.belly
    tm.bellyShown = (tm.bellyShown or 0) + (full - (tm.bellyShown or 0)) * math.min(1, dt * 1.5)
    setBelly(inst, tm.bellyShown)

    local phase = tm.phase
    if phase == 'idle' then
        local food, d = nearestFood(mx, my, R * 2 * c.open)
        local cupD = nearestCup(mx, my, R * 2 * c.open)
        if tm.sipAt and love.timer.getTime() - tm.sipAt < 0.1 then
            tm.phase, tm.t = 'drink', 0
        elseif cupD and not (food and d < cupD) then -- a cup coming: an O to drink from
            local near = 1 - mathutils.clamp(cupD / (R * 2 * c.open), 0, 1)
            tm.open = tm.open + (near - tm.open) * math.min(1, dt * 10)
            takeMouth(inst, part, mouthVec(lip, 'O_U_W_Q', tm.open))
        elseif food then
            local def = foodDef(food)
            local fx, fy = food:getPosition()
            tm.look.x, tm.look.y = fx, fy
            mipoActions.lookAt(inst, tm.look)
            local near = 1 - mathutils.clamp(d / (R * 2 * c.open), 0, 1)
            tm.open = tm.open + (near - tm.open) * math.min(1, dt * 10)
            takeMouth(inst, part, mouthVec(lip, 'A_I', tm.open, 1 + 0.15 * tm.open))
            if d < R * 0.15 and tm.open > 0.6 then
                tm.phase, tm.t, tm.food_body, tm.def = 'chomp', 0, food, def
            end
        else
            tm.open = tm.open * math.max(0, 1 - dt * 8)
            if tm.open > 0.03 then
                takeMouth(inst, part, mouthVec(lip, 'A_I', tm.open))
            else
                tm.open = 0
                giveMouthBack(inst, part)
                if inst._lookTarget == tm.look then mipoActions.stopLooking(inst) end
            end
        end
        -- needing to go: a wiggle, a worried face, a hum now and then
        if (tm.pee > 1 or tm.poop > 1) and tm.phase == 'idle' then
            if onPotty(inst) then
                tm.phase, tm.t = 'potty', 0
                feel(inst, 'shy', 0.6)
            else
                local torso = inst.parts.torso1.body
                torso:applyTorque(torso:getInertia() * 30 * math.sin(tm.t * 13))
                if not tm.worried then feel(inst, 'scared', 0.45) tm.worried = true end
                tm.humAt = tm.humAt or 0
                if tm.t - tm.humAt > 3.5 then
                    tm.humAt = tm.t
                    mipoVoice.squeak(inst, 'oof')
                end
            end
        end
    elseif phase == 'chomp' then
        -- the mouth snaps shut on it
        local u = math.min(1, tm.t / 0.09)
        takeMouth(inst, part, mouthVec(lip, 'A_I', (1 - u) * tm.open, 1.15))
        if u >= 1 then
            local def = tm.def
            if tm.food_body and not tm.food_body:isDestroyed() then
                play('crunch', 1, 0.9)
                crumbs(mx, my, def.color, 6)
                bite(tm.food_body, def)
                if def.likes then tm.food = tm.food + def.fill / def.bites end
            end
            tm.food_body, tm.open = nil, 0
            tm.phase, tm.t, tm.chews = 'chew', 0, 0
        end
    elseif phase == 'chew' then
        -- full cheeks, the jaw going: mmm, closed, mmm
        local w = 0.5 - 0.5 * math.cos(tm.t * 2 * math.pi * 3)
        takeMouth(inst, part, mouthVec(lip, 'mmm', w * 0.8, 1.22))
        local chews = math.floor(tm.t * 3)
        if chews > tm.chews then
            tm.chews = chews
            play('munch', 1, 0.6)
            if not tm.def.likes and chews >= 1 then -- that's not nice
                play('crunch', 0.7, 0.5)
                crumbs(mx, my, tm.def.color, 10, 1.4)
                spit(inst, mx, my, tm.def)
                mipoVoice.say(inst, 'fx', 'blah' .. love.math.random(3))
                feel(inst, 'angry', 0.55, 1.5)
                tm.phase, tm.t = 'after', 0
            end
        end
        if tm.phase == 'chew' and tm.t > 1.4 then tm.phase, tm.t = 'swallow', 0 end
    elseif phase == 'swallow' then
        takeMouth(inst, part, mouthVec(lip, 'closed', 1, 1.0))
        if tm.t > 0.15 and not tm.gulped then
            tm.gulped = true
            play('gulp', 1, 0.8)
        end
        if tm.t > 0.45 then
            tm.gulped = nil
            feel(inst, 'happy', 0.8, 1.2)
            tm.phase, tm.t = 'after', 0
            giveMouthBack(inst, part)
            mipoVoice.squeak(inst, 'curious')
        end
    elseif phase == 'drink' then
        -- drinking while water comes (s.onDrink), a gulp now and then; done when it stops
        if not tm.sipAt or love.timer.getTime() - tm.sipAt > 0.4 then
            tm.phase, tm.t, tm.open = 'swallow', 0.15, 0
        else
            takeMouth(inst, part, mouthVec(lip, 'O_U_W_Q', 0.9))
            tm.gulpAt = tm.gulpAt or 0
            if tm.gulpAt > tm.t then tm.gulpAt = 0 end
            if tm.t - tm.gulpAt > 0.45 then
                tm.gulpAt = tm.t
                play('gulp', 1.2, 0.7)
            end
        end
    elseif phase == 'after' then -- a moment before the next bite
        if tm.t > 0.35 then tm.phase, tm.t = 'idle', 0 end
    elseif phase == 'potty' then
        -- sitting still a moment, then what has to come out
        if not onPotty(inst) and tm.t < 1 then tm.phase, tm.t = 'idle', 0 return end
        if tm.t > 0.8 and tm.pee > 0.5 and not tm.peeing then tm.peeing = tm.t end
        if tm.peeing then
            local bx, by = bottomOf(inst)
            local c2 = st()
            for _ = 1, 2 do
                c2.drops[#c2.drops + 1] = { x = bx + (love.math.random() - 0.5) * 8 * K, y = by,
                    vx = (love.math.random() - 0.5) * 30 * K, vy = 80 * K, life = 1.2 }
            end
            tm.pee = math.max(0, tm.pee - dt * 0.8)
            if tm.pee <= 0 then tm.peeing = nil end
        end
        if tm.t > 1.4 and tm.poop > 0.5 and not tm.peeing then
            -- into the potty, between the feet (dropped from the bottom it caught on the knees)
            local potty = getObjectsByLabel('potty')[1]
            local bx = bottomOf(inst)
            local _, py = potty.body:getPosition()
            makePoop(bx, py - 10 * K)
            play('plop', 1, 0.9)
            tm.poop = 0
        end
        if tm.t > 2 and not tm.peeing and tm.poop < 0.5 then
            tm.pee, tm.worried = 0, nil
            feel(inst, 'happy', 1, 2)
            mipoVoice.say(inst, 'fx', 'humdown' .. love.math.random(4), 0.9) -- ahh
            tm.phase, tm.t = 'after', 0
        end
    end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    st()
    ensureGround()
    ensureTable()
    ensurePotty()
    ensureMipo()
    if #bodiesLabelled('food-') == 0 then resetFood() end
    ensureSounds()
    state.liquidDrinkHook = function(...)
        local script = state.scene.sceneScript
        if script and script.onDrink then return script.onDrink(...) end
    end
end

function s.onSceneUnload()
    for _, inst in ipairs(mipos()) do inst.mouthTakenBy = nil end
    state.liquidDrinkHook = nil
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'r' then resetFood() end
    if key == 'c' then
        for _, body in ipairs(bodiesLabelled('poop')) do objectManager.destroyBody(body) end
        for _, body in ipairs(bodiesLabelled('spat-')) do objectManager.destroyBody(body) end
        c.drops = {}
    end
    if key == 'f' then
        for _, inst in ipairs(mipos()) do
            local tm = tummy(inst)
            tm.food, tm.water, tm.poop, tm.pee = 0.8, 0.5, 1.1, 1.1
        end
    end
end

local function stepParticles(list, dt, gravity, floorY)
    for i = #list, 1, -1 do
        local p = list[i]
        p.vy = p.vy + gravity * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.life = p.life - dt
        if p.y > floorY then p.y, p.vx, p.vy = floorY, p.vx * 0.3, 0 end
        if p.life <= 0 then table.remove(list, i) end
    end
end

function s.update(dt)
    local c = st()
    ensureSounds()
    for _, inst in ipairs(mipos()) do tick(inst, dt) end
    stepParticles(c.crumbs, dt, 1800 * K, GROUND_Y - 4)
    stepParticles(c.drops, dt, 2400 * K, GROUND_Y - 4)
    -- spat-out bites go after a while
    for _, body in ipairs(bodiesLabelled('spat-')) do
        local thing = body:getUserData().thing
        if thing.spatAt and love.timer.getTime() - thing.spatAt > 6 then objectManager.destroyBody(body) end
    end
end

---------------------------------------------------------------- drawing

local function drawFood(body, def, spat)
    local x, y = body:getPosition()
    local r = radiusOf(body)
    local a = body:getAngle()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(a)
    local col = def.color
    local lw = 4 * K
    love.graphics.setLineWidth(lw)
    if def.kind == 'apple' then
        love.graphics.setColor(col)
        love.graphics.ellipse('fill', -r * 0.35, 0, r * 0.7, r * 0.9)
        love.graphics.ellipse('fill', r * 0.35, 0, r * 0.7, r * 0.9)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.ellipse('fill', -r * 0.45, -r * 0.35, r * 0.18, r * 0.28)
        love.graphics.setColor(0.35, 0.22, 0.1)
        love.graphics.line(0, -r * 0.75, r * 0.1, -r * 1.15)
        love.graphics.setColor(0.35, 0.6, 0.2)
        love.graphics.ellipse('fill', r * 0.35, -r * 1.05, r * 0.3, r * 0.14)
    elseif def.kind == 'cookie' then
        love.graphics.setColor(col)
        love.graphics.circle('fill', 0, 0, r)
        love.graphics.setColor(0.35, 0.2, 0.1)
        for i = 1, 6 do
            local ca = i * 2.1
            love.graphics.circle('fill', math.cos(ca) * r * 0.55, math.sin(ca) * r * 0.55, r * 0.12)
        end
    elseif def.kind == 'berry' then
        love.graphics.setColor(col)
        love.graphics.circle('fill', 0, 0, r)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.circle('fill', -r * 0.35, -r * 0.35, r * 0.25)
    elseif def.kind == 'sprout' then
        love.graphics.setColor(col)
        love.graphics.circle('fill', 0, 0, r)
        love.graphics.setColor(0.22, 0.45, 0.14)
        love.graphics.arc('line', 'open', 0, 0, r * 0.65, -2.4, -0.7)
        love.graphics.arc('line', 'open', 0, 0, r * 0.65, 0.7, 2.4)
        love.graphics.line(0, -r, 0, r)
    end
    love.graphics.setColor(0.1, 0.07, 0.05, spat and 0.5 or 0.8)
    if def.kind ~= 'apple' then love.graphics.circle('line', 0, 0, r) end
    love.graphics.pop()
end

-- the potty: painted plastic over its outline, behind the Mipo (its feet stand inside)
function s.drawBelow()
    local potty = getObjectsByLabel('potty')[1]
    if not potty then return end
    local px, py = potty.body:getPosition()
    local w, h = 300 * K, 110 * K
    love.graphics.setColor(0.98, 0.78, 0.82)
    love.graphics.rectangle('fill', px - w / 2, py - h / 2, w, h, 30 * K)
    love.graphics.setColor(0.9, 0.62, 0.7)
    love.graphics.rectangle('fill', px - w / 2 - 10 * K, py - h / 2 - 8 * K, w + 20 * K, 22 * K, 10 * K)
    love.graphics.setColor(1, 1, 1)
end

function s.draw()
    local c = st()
    for _, body in ipairs(bodiesLabelled('food-')) do drawFood(body, foodDef(body)) end
    for _, body in ipairs(bodiesLabelled('spat-')) do
        drawFood(body, KIND[body:getUserData().thing.label:sub(6)], true)
    end
    for _, p in ipairs(c.crumbs) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], math.min(1, p.life * 3))
        love.graphics.circle('fill', p.x, p.y, p.r)
    end
    for _, p in ipairs(c.drops) do
        love.graphics.setColor(0.98, 0.92, 0.5, math.min(0.8, p.life * 2))
        love.graphics.circle('fill', p.x, p.y, 5 * K)
    end
    if c.debug then
        for _, inst in ipairs(mipos()) do
            local _, _, mx, my = mouthOf(inst)
            if mx then
                local R = headRadius(inst)
                love.graphics.setColor(1, 0, 0, 0.6)
                love.graphics.circle('line', mx, my, R * 2 * c.open)
                love.graphics.circle('fill', mx, my, 8)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- the panel, bottom right: what's inside, and the tuning
local PANEL = { w = 320, row = 32, pad = 6 }
local SLIDERS = {
    { 'digest', 'digest', 0, 4, 0.1 }, { 'belly', 'belly', 0, 3, 0.1 }, { 'open', 'opens at', 0.5, 3, 0.1 },
}
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local rows = #SLIDERS + 4
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    ui.panel(x0, y0, w, h, '•• food in, food out ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local inst = mipos()[1]
        local tm = inst and tummy(inst)
        local x, y = row()
        ui.label(x, y + 4, tm and string.format('belly %.2f  water %.2f', tm.food, tm.water) or 'no Mipo')
        x, y = row()
        ui.label(x, y + 4, tm and string.format('poop %.2f  pee %.2f  (%s)', tm.poop, tm.pee, tm.phase) or '')
        for _, sl in ipairs(SLIDERS) do
            x, y = row()
            ui.label(x, y + 4, sl[2])
            local v = ui.sliderWithInput('food-' .. sl[1], x + 90, y - 2, 130, sl[3], sl[4], c[sl[1]], nil, sl[5])
            if v then c[sl[1]] = v + 0 end
        end
        x, y = row()
        local dc, dv = ui.checkbox(x, y, c.debug, 'show the mouth')
        if dc then c.debug = dv end
        x, y = row()
        ui.label(x, y + 4, 'r food  c clean  f full  h panel')
    end)
end

return s
