-- mole: dig the earth with your finger; the mole eats what comes loose, and likes some things more than others
-- DIGGING-SERIES DS3. Nikki 2026-11-16: "lets just have him eat stuff he finds, but without meaning, well he likes
-- certain things more then others"; "can i for now just draw with mouse". Dragging him dug too, tried and taken out
-- the same day (Nikki: "its much too easy to tunnel if you just drag the mipo around").
-- No hunger, no score: the kid digs, things come loose, he tastes them. His tastes are seeded (n: a new mole, new
-- tastes): two kinds he loves, two he likes, two are fine, two he spits out. Stones, bones and buttons aren't food:
-- he sniffs them and pushes them away. Rare: a golden worm deep down (always loved), a giant carrot hanging in.
-- Made of:
--   the earth   scripts/spikes/burrow.playtime.lua (its own state 'moleField', a den to start in), a big field
--               (Nikki 2026-11-16, "a much larger playing field": 4x wider and deeper than burrow's, ~16 screens
--               each way at this zoom, bounded: bedrock at the bottom). The finger digs only within REACH of the
--               mole, and the camera follows him: to dig further, carry him into the tunnel (option c).
--   the finds   scripts/spikes/mole-finds.lua (what's in the earth and its look)
--   eating      the food spike's mouth (scripts/spikes/food.playtime.lua: open, chomp, chew, gulp, spit), copied
--               here with the taste scale; the belly, drinking and the potty left out
-- play mode (tab): drag on the earth to dig (the ring is the size). Drag a find to his mouth, or him to it.
-- keys: n a new mole   r reset (earth, finds, mole)   h the panel   (the burrow's own: t o b i looks)
local s = {}

local finds = love.filesystem.load('scripts/spikes/mole-finds.lua')()

local MOLE_SCALE = 0.3
local DEN = { x = 0, y = 700, w = 1500, h = 1000, r = 350 } -- the den he starts in, just under the grass
local FIELD = { w = 38400, h = 19200, y0 = -1200, rocks = 120, layerScale = 5 }
local FIELD_ID = 2 -- the field's version on state: another one (a bigger field) starts the finds and the mole over
local REACH = 1100 -- how far from the mole the finger digs
local SNIFF_AGAIN = 4 -- seconds before he sniffs the same not-food again

-- the taste scale: how he eats each (chew: seconds, rate: munches a second, wide: the cheeks)
local TASTES = {
    loves = { chew = 0.9, rate = 4, wide = 1.3 },
    likes = { chew = 1.4, rate = 3, wide = 1.22 },
    fine = { chew = 2.2, rate = 1.6, wide = 1.08 },
    dislikes = { chew = 0.5, rate = 3, wide = 1.15 },
}
local DEAL = { 'loves', 'loves', 'likes', 'likes', 'fine', 'fine', 'dislikes', 'dislikes' }

local function st()
    state.mole = state.mole or { showPanel = true, showTastes = false, digAnywhere = false, tasteSeed = 1,
        crumbs = {}, hearts = {} }
    state.mole.spat = state.mole.spat or {}
    return state.mole
end

-- his tastes: the food kinds dealt over DEAL, shuffled by the seed; the rare ones always loved
local function tasteOf(kind)
    local c = st()
    if finds.KINDS[kind].rare then return 'loves' end
    if c.tastesFor ~= c.tasteSeed then
        local rng = love.math.newRandomGenerator(7000 + c.tasteSeed)
        local deal = {}
        for i, t in ipairs(DEAL) do deal[i] = t end
        for i = #deal, 2, -1 do
            local j = rng:random(1, i)
            deal[i], deal[j] = deal[j], deal[i]
        end
        c.tastes = {}
        for i, k in ipairs(finds.FOODS) do c.tastes[k] = deal[i] end
        c.tastesFor = c.tasteSeed
    end
    return c.tastes[kind]
end

---------------------------------------------------------------- the earth

-- the mole panel's rectangle on screen (drawUI keeps it), so a press on it doesn't dig
local molePanelRect
local function overMolePanel()
    local r = molePanelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

-- the finger digs near the mole only (or anywhere, the panel's testing switch)
local mole
local function inReach(x, y)
    local inst = mole()
    if not inst then return false end
    local tx, ty = inst.parts.torso1.body:getPosition()
    return (x - tx) ^ 2 + (y - ty) ^ 2 < REACH * REACH
end

local function canDig(x, y)
    if overMolePanel() then return false end
    return st().digAnywhere or inReach(x, y)
end

-- the scene names the burrow uses (loaded with love.filesystem.load it runs in the plain globals)
local function earthEnv()
    return { state = state, world = world, cam = cam, camera = camera, ui = ui, objectManager = objectManager,
        fixtures = fixtures, shape8Dict = shape8Dict, characterManager = characterManager, worldState = worldState,
        mouseWorldPos = mouseWorldPos, getInteractedWithPointer = getInteractedWithPointer, love = love,
        math = math, table = table, string = string, pairs = pairs, ipairs = ipairs, unpack = unpack,
        print = print, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall }
end

-- loaded at each start: state and world reach a scene's names only then (scene-loader's setEnv)
local earth
local function loadEarth()
    return love.filesystem.load('scripts/spikes/burrow.playtime.lua')({
        env = earthEnv(),
        stateKey = 'moleField', w = FIELD.w, h = FIELD.h, y0 = FIELD.y0, rocks = FIELD.rocks,
        layerScale = FIELD.layerScale, noMipos = true,
        hollow = function(x, y, _, room) return room(x, y, DEN.x, DEN.y, DEN.w, DEN.h, DEN.r) end,
        canDig = function(x, y) return canDig(x, y) end,
        sharedFrame = true,
    })
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
    makeSound('crunch', 0.11, function(_, u, prev)
        local crackle = (love.math.random() < 0.25) and (love.math.random() * 2 - 1) or 0
        local v = prev * 0.55 + crackle * 0.9
        return v * (1 - u) ^ 2, v
    end)
    makeSound('munch', 0.07, function(_, u, prev)
        local v = prev * 0.85 + (love.math.random() * 2 - 1) * 0.15
        return v * math.sin(u * math.pi) * 1.4, v
    end)
    makeSound('gulp', 0.16, function(t, u)
        local f = 340 - 220 * u
        return math.sin(2 * math.pi * f * t) * math.sin(u * math.pi) * 0.5, 0
    end)
    -- digging: a dull scrape of earth
    makeSound('scrape', 0.09, function(_, u, prev)
        local v = prev * 0.92 + (love.math.random() * 2 - 1) * 0.12
        return v * math.sin(u * math.pi) * 1.6, v
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

---------------------------------------------------------------- the mole

function mole()
    local inst = st().mole
    if inst and mipoKit.isAlive(inst) then return inst end
    return nil
end

local function spawnMole(x, y)
    local c = st()
    local old = mole()
    if old then
        for _, part in pairs(old.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
    end
    local inst = characterManager.createCharacter('humanoid', x or DEN.x, y or DEN.y, MOLE_SCALE)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    c.mole = inst
    if inst then camera.follow(inst.parts.torso1.body) end
    return inst
end

local function crumbs(x, y, color, n, size, speed)
    local c = st()
    for _ = 1, n do
        local a = -math.pi / 2 + (love.math.random() - 0.5) * 2.6
        local v = (150 + love.math.random() * 300) * (speed or 1)
        c.crumbs[#c.crumbs + 1] = { x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v,
            r = (3 + love.math.random() * 5) * (size or 1), life = 0.6 + love.math.random() * 0.5, color = color }
    end
end


-- Clumps of dirt: bits of the earth that was dug, real Box2D bodies (Nikki 2026-11-16: "lets just make it real
-- box2d shapes, and make them bigger"): they tumble down the tunnel, pile up, bump the mole, can be dragged.
-- At most CLUMP_MAX: past that the oldest goes; one lying still for CLUMP_LIE seconds fades and goes.
local CLUMP_MAX, CLUMP_LIE, CLUMP_FADE = 120, 12, 1
local CLUMP_COLORS = { { 0.36, 0.25, 0.16 }, { 0.3, 0.2, 0.13 }, { 0.62, 0.44, 0.28 }, { 0.5, 0.38, 0.3 },
    { 0.44, 0.31, 0.2 } }

local function clumpList()
    local c = st()
    c.clumps = c.clumps or {}
    return c.clumps
end

local function dropClump(list, i)
    local p = table.remove(list, i)
    if p and p.body and not p.body:isDestroyed() then objectManager.destroyBody(p.body) end
end

-- n clumps out of the earth inside the circle (where there still is earth: what this stroke takes away)
local function looseClumps(x, y, r, n)
    local list = clumpList()
    local size = math.max(14, math.min(70, r * 0.3))
    for _ = 1, n do
        for _ = 1, 4 do -- a few tries to start inside earth
            local a, d = love.math.random() * math.pi * 2, math.sqrt(love.math.random()) * r * 0.8
            local px, py = x + math.cos(a) * d, y + math.sin(a) * d
            if earth.earthAt(px, py) > 0.5 then
                local verts = {}
                local k, sz = love.math.random(5, 7), size * (0.6 + love.math.random() * 0.7)
                for i = 1, k do
                    local ang = (i - 1 + love.math.random() * 0.4) / k * math.pi * 2
                    local rr = sz * (0.8 + love.math.random() * 0.3)
                    verts[#verts + 1], verts[#verts + 2] = math.cos(ang) * rr, math.sin(ang) * rr
                end
                local thing = objectManager.addThing('custom', { x = px, y = py, vertices = verts, label = 'clump' })
                if thing then
                    local body = thing.body
                    for _, fixture in ipairs(body:getFixtures()) do
                        fixture:setDensity(0.8)
                        fixture:setFriction(0.9)
                        fixture:setRestitution(0.05)
                    end
                    body:resetMassData()
                    body:setAngle(love.math.random() * math.pi * 2)
                    local perM = love.physics.getMeter() / 100 -- speeds as at 100 px per metre
                    body:setLinearVelocity((love.math.random() - 0.5) * 150 * perM, -love.math.random() * 150 * perM)
                    body:setAngularVelocity((love.math.random() - 0.5) * 6)
                    if #list >= CLUMP_MAX then dropClump(list, 1) end
                    list[#list + 1] = { body = body, still = 0,
                        color = CLUMP_COLORS[love.math.random(1, #CLUMP_COLORS)] }
                end
                break
            end
        end
    end
end

local function clumpsUpdate(dt)
    local list = clumpList()
    for i = #list, 1, -1 do
        local p = list[i]
        local body = p.body
        if not body or body:isDestroyed() then
            table.remove(list, i)
        else
            local vx, vy = body:getLinearVelocity()
            if vx * vx + vy * vy < 400 then -- hardly moving: lying
                p.still = p.still + dt
            else
                p.still = 0
            end
            local _, y = body:getPosition()
            if p.still > CLUMP_LIE + CLUMP_FADE or y > 6000 then dropClump(list, i) end
        end
    end
end

-- the finger digging (the burrow's own stroke): clumps come off what it takes away
local function fingerClumps()
    local b = state.moleField
    if not (b and b.stroke) then return end
    local digging = (b.fill == true) == love.keyboard.isDown('lshift', 'rshift') -- shift does the other one
    if not digging then return end
    local mx, my = mouseWorldPos()
    local c = st()
    local last = c.fingerAt or { mx, my }
    local moved = math.sqrt((mx - last[1]) ^ 2 + (my - last[2]) ^ 2)
    c.fingerAt = { mx, my }
    c.fingerOwed = (c.fingerOwed or 0.5) + moved / math.max(20, b.brush * 0.6) -- a clump every so far moved
    local n = math.min(2, math.floor(c.fingerOwed))
    if n > 0 then
        c.fingerOwed = c.fingerOwed - n
        play('scrape', 0.8 + love.math.random() * 0.4, 0.7)
        looseClumps(mx, my, b.brush, n)
    end
end

---------------------------------------------------------------- the finds in the earth

local function radiusOf(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() and fixture:getShape():getType() == 'circle' then
            return fixture:getShape():getRadius(), fixture
        end
    end
    return 0
end

local function hold(body, held)
    if held then
        body:setType('kinematic')
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    else
        body:setType('dynamic')
        body:setAwake(true)
    end
end

local function makeFindBody(f)
    local def = finds.KINDS[f.kind]
    local thing = objectManager.addThing('circle', { x = f.x, y = f.y, radius = f.r or def.r,
        label = 'find-' .. f.kind, bodyType = 'dynamic' })
    if not thing then return end
    thing.body:setAngle(f.angle or 0)
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:getUserData() then
            fixture:setFriction(0.8)
            fixture:setDensity(0.6)
        end
    end
    thing.body:resetMassData()
    thing.find = f
    f.body = thing.body
    f.bitesLeft = f.bitesLeft or def.bites
    hold(thing.body, not f.loose)
end

local function destroyFinds(c)
    for _, f in ipairs(c.finds or {}) do
        if f.body and not f.body:isDestroyed() then objectManager.destroyBody(f.body) end
        f.body = nil
    end
end

-- seeded: the same earth gets the same finds (r puts them back)
local function placeFinds(c)
    destroyFinds(c)
    c.finds = {}
    local field = state.moleField
    local rocks = (field and field.rocks) or {}
    local rng = love.math.newRandomGenerator(3100 + ((field and field.seed) or 0))
    local function free(x, y, r)
        if earth.earthAt(x, y) < 0.9 then return false end
        if (x - DEN.x) ^ 2 + (y - DEN.y) ^ 2 < (DEN.w * 0.75) ^ 2 then return false end
        for _, rock in ipairs(rocks) do
            if (rock.x - x) ^ 2 + (rock.y - y) ^ 2 < (rock.r + r + 60) ^ 2 then return false end
        end
        for _, o in ipairs(c.finds) do
            if (o.x - x) ^ 2 + (o.y - y) ^ 2 < (o.r * 2 + r * 2 + 80) ^ 2 then return false end
        end
        return true
    end
    local function place(kind, yMin, yMax)
        local r = finds.KINDS[kind].r
        for _ = 1, 200 do
            local x = -FIELD.w / 2 + 400 + rng:random() * (FIELD.w - 800)
            local y = yMin + rng:random() * (yMax - yMin)
            if free(x, y, r) then
                c.finds[#c.finds + 1] = { kind = kind, x = x, y = y, r = r, angle = rng:random() * math.pi * 2 }
                return
            end
        end
    end
    local kinds = {}
    for kind in pairs(finds.BANDS) do kinds[#kinds + 1] = kind end
    table.sort(kinds) -- pairs' order isn't fixed: sorted, the seed gives the same earth
    for _, kind in ipairs(kinds) do
        local band = finds.BANDS[kind]
        for _ = 1, band[1] do place(kind, band[2], band[3]) end
    end
    -- the giant carrot hangs in from the grass, a little way from the den, tip down
    c.finds[#c.finds + 1] = { kind = 'bigcarrot', x = 1700, y = 230, r = finds.KINDS.bigcarrot.r, angle = math.pi / 2 }
    for _, f in ipairs(c.finds) do makeFindBody(f) end
end

-- held while the earth holds it; once the earth round it is mostly dug away, loose (and it falls)
local function findsUpdate(c)
    for _, f in ipairs(c.finds or {}) do
        local body = f.body
        if body and not body:isDestroyed() then
            f.x, f.y = body:getPosition()
            f.angle = body:getAngle()
            if not f.loose then
                local r = radiusOf(body) * 1.25
                local n, held = 8, 0
                for k = 0, n - 1 do
                    local a = k / n * math.pi * 2
                    if earth.earthAt(f.x + math.cos(a) * r, f.y + math.sin(a) * r) > 0.5 then held = held + 1 end
                end
                if held / n < 0.5 then
                    f.loose = true
                    hold(body, false)
                end
            end
        end
    end
end

local function findOf(body)
    local ud = body and not body:isDestroyed() and body:getUserData()
    return ud and ud.thing and ud.thing.find
end

---------------------------------------------------------------- the mouth (the food spike's)

local function mouthOf(inst)
    local part, lip = mipoVoice.findMouth(inst)
    if not (part and lip) then return nil end
    local x, y = part.body:getWorldPoint(lip.ox, lip.oy)
    return part, lip, x, y
end

local function headRadius(inst)
    local owner = inst.dna.creation.isPotatoHead and 'torso1' or 'head'
    local _, r = mipoFacing.headBox(inst, owner)
    return r or 150
end

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
    if part then part.mouthShapeVec = nil end
end

local function mipoGroup(inst)
    for _, fixture in ipairs(inst.parts.head and inst.parts.head.body:getFixtures() or {}) do
        if not fixture:isSensor() then return fixture:getGroupIndex() end
    end
    return 0
end

-- loose finds near his face pass in front of it (his collision group), so they can reach the mouth
local function passFace(inst, R, mx, my)
    local group = mipoGroup(inst)
    if group >= 0 then return end
    for _, f in ipairs(st().finds or {}) do
        local body = f.body
        if body and not body:isDestroyed() and f.loose then
            local x, y = body:getPosition()
            local want = ((x - mx) ^ 2 + (y - my) ^ 2 < (R * 3) ^ 2) and group or 0
            for _, fixture in ipairs(body:getFixtures()) do
                if not fixture:getUserData() and fixture:getGroupIndex() ~= want then fixture:setGroupIndex(want) end
            end
        end
    end
end

-- the nearest loose find (food or not) to the mouth: its body, how far its edge is
local function nearestFind(mx, my, reach, food)
    local best, bestD = nil, reach
    for _, f in ipairs(st().finds or {}) do
        local body = f.body
        if body and not body:isDestroyed() and f.loose and (finds.KINDS[f.kind].food == true) == food then
            local x, y = body:getPosition()
            local d = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2) - radiusOf(body)
            if d < bestD then best, bestD = body, d end
        end
    end
    return best, bestD
end

-- a bite off it: smaller (the same body, so a drag carries on), or gone with the last bite
local function bite(body)
    local f = findOf(body)
    f.bitesLeft = (f.bitesLeft or 1) - 1
    if f.bitesLeft <= 0 then
        objectManager.destroyBody(body)
        f.body, f.eaten = nil, true
        return
    end
    local r, fixture = radiusOf(body)
    local newR = r * math.sqrt(f.bitesLeft / (f.bitesLeft + 1))
    local density, friction, group = fixture:getDensity(), fixture:getFriction(), fixture:getGroupIndex()
    fixture:destroy()
    local nf = love.physics.newFixture(body, love.physics.newCircleShape(newR), density)
    nf:setFriction(friction)
    nf:setGroupIndex(group)
    body:getUserData().thing.radius = newR
    f.r = newR
end

-- a piece spat out: a small body thrown forward, gone after a while
local function spit(inst, x, y, kind)
    local def = finds.KINDS[kind]
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = def.r * 0.5, label = 'spat-' .. kind })
    if not thing then return end
    local facing = (mipoFacing.angle and mipoFacing.angle(inst) or 0) < 0 and -1 or 1
    local m, perM = thing.body:getMass(), love.physics.getMeter() / 100 -- speeds as at 100 px per metre
    thing.body:applyLinearImpulse(m * facing * 300 * perM, m * -250 * perM)
    local spat = st().spat
    spat[#spat + 1] = { body = thing.body, kind = kind, at = love.timer.getTime() }
end

local function hearts(x, y, n)
    local c = st()
    for _ = 1, n do
        c.hearts[#c.hearts + 1] = { x = x + (love.math.random() - 0.5) * 60, y = y,
            vx = (love.math.random() - 0.5) * 80, vy = -120 - love.math.random() * 120,
            r = 9 + love.math.random() * 7, life = 1.2 + love.math.random() * 0.6 }
    end
end

local function feel(inst, name, amount, holdFor) mipoEmotion.set(inst, name, amount, holdFor, false) end

---------------------------------------------------------------- eating, each frame

local function eatTick(inst, dt)
    local c = st()
    c.eat = c.eat or { phase = 'idle', t = 0, open = 0, look = { x = 0, y = 0 }, sniffed = {} }
    local e = c.eat
    local part, lip, mx, my = mouthOf(inst)
    if not part then return end
    local R = headRadius(inst)
    e.t = e.t + dt
    passFace(inst, R, mx, my)

    if e.phase == 'idle' then
        local food, d = nearestFind(mx, my, R * 2, true)
        local thing, td = nearestFind(mx, my, R * 0.7, false)
        local now = love.timer.getTime()
        if thing and not (food and d < td) and now - (e.sniffed[thing] or -99) > SNIFF_AGAIN then
            -- not food: a sniff, a puzzled look, then pushed away
            e.sniffed[thing] = now
            e.phase, e.t, e.body = 'sniff', 0, thing
            local x, y = thing:getPosition()
            e.look.x, e.look.y = x, y
            mipoActions.lookAt(inst, e.look)
            mipoVoice.squeak(inst, 'curious')
            feel(inst, 'surprised', 0.45, 1.2)
        elseif food then
            local fx, fy = food:getPosition()
            e.look.x, e.look.y = fx, fy
            mipoActions.lookAt(inst, e.look)
            local near = 1 - mathutils.clamp(d / (R * 2), 0, 1)
            e.open = e.open + (near - e.open) * math.min(1, dt * 10)
            takeMouth(inst, part, mouthVec(lip, 'A_I', e.open, 1 + 0.15 * e.open))
            if d < R * 0.15 and e.open > 0.6 then
                local kind = findOf(food).kind
                e.phase, e.t, e.body, e.kind, e.taste = 'chomp', 0, food, kind, tasteOf(kind)
            end
        else
            e.open = e.open * math.max(0, 1 - dt * 8)
            if e.open > 0.03 then
                takeMouth(inst, part, mouthVec(lip, 'A_I', e.open))
            else
                e.open = 0
                giveMouthBack(inst, part)
                if inst._lookTarget == e.look then mipoActions.stopLooking(inst) end
            end
        end
    elseif e.phase == 'sniff' then
        -- a little sniffing O, then a nudge away and a tsk
        local u = math.min(1, e.t / 0.2)
        takeMouth(inst, part, mouthVec(lip, 'O_U_W_Q', 0.35 * u + 0.1 * math.sin(e.t * 30) * u))
        if e.t > 0.9 then
            local body = e.body
            if body and not body:isDestroyed() then
                local x, y = body:getPosition()
                local dx, dy = x - mx, y - my
                local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                local m, perM = body:getMass(), love.physics.getMeter() / 100
                body:applyLinearImpulse(m * dx / len * 260 * perM, m * (dy / len - 0.6) * 260 * perM)
            end
            mipoVoice.squeak(inst, 'annoyed')
            e.phase, e.t, e.body, e.open = 'after', 0, nil, 0
            giveMouthBack(inst, part)
        end
    elseif e.phase == 'chomp' then
        local u = math.min(1, e.t / 0.09)
        takeMouth(inst, part, mouthVec(lip, 'A_I', (1 - u) * e.open, 1.15))
        if u >= 1 then
            local def = finds.KINDS[e.kind]
            if e.body and not e.body:isDestroyed() then
                play('crunch', def.rare and 0.8 or 1, 0.9)
                crumbs(mx, my, def.color, 6)
                bite(e.body)
            end
            e.body, e.open = nil, 0
            e.phase, e.t, e.chews = 'chew', 0, 0
        end
    elseif e.phase == 'chew' then
        local how = TASTES[e.taste]
        local w = 0.5 - 0.5 * math.cos(e.t * 2 * math.pi * how.rate)
        takeMouth(inst, part, mouthVec(lip, 'mmm', w * 0.8, how.wide))
        local chews = math.floor(e.t * how.rate)
        if chews > e.chews then
            e.chews = chews
            play('munch', e.taste == 'fine' and 0.8 or 1, 0.6)
            if e.taste == 'dislikes' and chews >= 1 then -- that's not nice
                play('crunch', 0.7, 0.5)
                crumbs(mx, my, finds.KINDS[e.kind].color, 10, 1.4)
                spit(inst, mx, my, e.kind)
                mipoVoice.say(inst, 'fx', 'blah' .. love.math.random(3))
                feel(inst, 'angry', 0.55, 1.5)
                e.phase, e.t = 'after', 0
            end
        end
        if e.phase == 'chew' and e.t > how.chew then e.phase, e.t = 'swallow', 0 end
    elseif e.phase == 'swallow' then
        takeMouth(inst, part, mouthVec(lip, 'closed', 1, 1.0))
        if e.t > 0.15 and not e.gulped then
            e.gulped = true
            play('gulp', 1, 0.8)
        end
        if e.t > 0.45 then
            e.gulped = nil
            giveMouthBack(inst, part)
            local rare = finds.KINDS[e.kind].rare
            if e.taste == 'loves' then
                feel(inst, 'happy', 1, rare and 4 or 2.5)
                mipoVoice.squeak(inst, 'happy')
                hearts(mx, my - R, rare and 9 or 4)
                mipoActions.jump(inst) -- a happy hop (only from the ground)
            elseif e.taste == 'likes' then
                feel(inst, 'happy', 0.6, 1.5)
                mipoVoice.squeak(inst, 'curious')
            else -- fine: a flat "hm"
                mipoVoice.say(inst, 'fx', love.math.random() < 0.5 and 'huh' or 'huh2', 0.85)
            end
            e.phase, e.t = 'after', 0
        end
    elseif e.phase == 'after' then
        if e.t > 0.35 then e.phase, e.t = 'idle', 0 end
    end
end

---------------------------------------------------------------- hooks

local function clearClumps()
    local list = clumpList()
    for i = #list, 1, -1 do dropClump(list, i) end
end

local function reset()
    local c = st()
    clearClumps()
    earth.onKeyPress('r') -- the burrow's reset: the earth as it started, its rocks
    placeFinds(c)
    spawnMole()
    c.eat = nil
end

function s.onStart()
    worldState.paused = false
    local c = st()
    earth = loadEarth()
    if not c.panelFolded then -- the burrow's big panel folded at first
        state.scriptPanels = state.scriptPanels or {}
        state.scriptPanels['•• burrow ••'] = true
        c.panelFolded = true
    end
    local old = state.moleEarth
    if old then
        -- the small earth from before the big field: its chunks and rocks go; its settings come along
        love.filesystem.load('scripts/spikes/burrow.playtime.lua')({ env = earthEnv(), stateKey = 'moleEarth' })
            .onUnload()
        state.moleField = state.moleField or { cell = old.cell, brush = old.brush, plane = old.plane, rim = old.rim }
        state.moleEarth = nil
    end
    if c.field ~= FIELD_ID then
        destroyFinds(c)
        c.finds, c.field = nil, FIELD_ID
        clearClumps()
        local inst = mole()
        if inst then
            for _, part in pairs(inst.parts) do
                if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
            end
            c.mole = nil
        end
    end
    earth.onStart()
    -- the tunnel's back wall far back (Nikki 2026-11-16: 0.99), unless set on the burrow panel
    local b = state.moleField
    b.plane = b.plane or {}
    if b.plane.tunnel == nil then b.plane.tunnel = 0.99 end
    if not c.finds then
        placeFinds(c)
    else
        for _, f in ipairs(c.finds) do
            if not f.eaten and (not f.body or f.body:isDestroyed()) then makeFindBody(f) end
        end
    end
    if not mole() then spawnMole() else camera.follow(mole().parts.torso1.body) end
    c.eat = nil
    ensureSounds()
    cam:setScale(0.35)
    cam:setTranslation(DEN.x, DEN.y + 300)
end

function s.onUnload()
    local c = st()
    local inst = mole()
    if inst then inst.mouthTakenBy = nil end
    if earth then earth.onUnload() end
    destroyFinds(c)
    clearClumps()
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local c = st()
    if key == 'n' then
        c.tasteSeed = c.tasteSeed + 1
        local inst = mole()
        local x, y
        if inst then x, y = inst.parts.torso1.body:getPosition() end
        spawnMole(x, y)
        c.eat = nil
    elseif key == 'r' then
        reset()
    elseif key == 'h' then
        c.showPanel = not c.showPanel
    elseif key == 't' or key == 'o' or key == 'b' or key == 'i' or key == '[' or key == ']' then
        earth.onKeyPress(key)
    end
end

local function stepParticles(list, dt, gravity)
    for i = #list, 1, -1 do
        local p = list[i]
        p.vy = p.vy + gravity * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(list, i) end
    end
end

function s.update(dt)
    if not earth then return end
    local c = st()
    ensureSounds()
    local inst = mole()
    if state.moleField and state.moleField.stroke then fingerClumps() else c.fingerAt = nil end
    earth.update(dt) -- digs the finger's stroke, rebuilds what was dug
    clumpsUpdate(dt)
    findsUpdate(c)
    if inst then eatTick(inst, dt) end
    stepParticles(c.crumbs, dt, 1800)
    stepParticles(c.hearts, dt, -60)
    -- spat-out bites go after a while
    local now = love.timer.getTime()
    for i = #c.spat, 1, -1 do
        local p = c.spat[i]
        if p.body:isDestroyed() or now - p.at > 6 then
            if not p.body:isDestroyed() then objectManager.destroyBody(p.body) end
            table.remove(c.spat, i)
        end
    end
end

---------------------------------------------------------------- drawing

local function drawFinds(buried)
    local t = love.timer.getTime()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    for _, f in ipairs(st().finds or {}) do
        local body = f.body
        if body and not body:isDestroyed() and (not f.loose) == buried and f.x > x1 - 300 and f.x < x2 + 300
            and f.y > y1 - 300 and f.y < y2 + 300 then
            local x, y = body:getPosition()
            finds.draw(f.kind, x, y, radiusOf(body), body:getAngle(), f.loose and t or 0, buried and 0.35 or 0)
        end
    end
end

-- behind him: the earth, and what's still in it
function s.drawBelow()
    if not earth then return end
    earth.drawBelow()
    drawFinds(true)
end

local function heart(x, y, r)
    love.graphics.circle('fill', x - r * 0.5, y, r * 0.6)
    love.graphics.circle('fill', x + r * 0.5, y, r * 0.6)
    love.graphics.polygon('fill', x - r * 1.05, y + r * 0.2, x + r * 1.05, y + r * 0.2, x, y + r * 1.3)
end

-- in front of him: the grass blades in front, what's loose, crumbs and hearts
function s.draw()
    if not earth then return end
    earth.draw()
    -- out of his reach the burrow draws no ring: a faint one, and how far he reaches
    local b, inst = state.moleField, mole()
    if state.playMode and b and inst and not overMolePanel() then
        local mx, my = mouseWorldPos()
        if not canDig(mx, my) then
            local tx, ty = inst.parts.torso1.body:getPosition()
            love.graphics.setLineWidth(4)
            love.graphics.setColor(1, 1, 1, 0.18)
            love.graphics.circle('line', mx, my, b.brush)
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.circle('line', tx, ty, REACH)
            love.graphics.setLineWidth(1)
        end
    end
    drawFinds(false)
    local c = st()
    for _, p in ipairs(c.spat) do
        if not p.body:isDestroyed() then
            local x, y = p.body:getPosition()
            finds.draw(p.kind, x, y, radiusOf(p.body), p.body:getAngle(), 0, 0)
        end
    end
    for _, p in ipairs(c.clumps or {}) do
        local body = p.body
        if body and not body:isDestroyed() then
            local fade = math.max(0, math.min(1, (CLUMP_LIE + CLUMP_FADE - p.still) / CLUMP_FADE))
            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()
                if shape:getType() == 'polygon' then
                    local pts = { body:getWorldPoints(shape:getPoints()) }
                    love.graphics.setColor(p.color[1], p.color[2], p.color[3], fade)
                    love.graphics.polygon('fill', pts)
                    love.graphics.setColor(0.16, 0.1, 0.07, fade * 0.85)
                    love.graphics.setLineWidth(4)
                    love.graphics.polygon('line', pts)
                end
            end
        end
    end
    love.graphics.setLineWidth(1)
    for _, p in ipairs(c.crumbs) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], math.min(1, p.life * 3))
        love.graphics.circle('fill', p.x, p.y, p.r)
    end
    for _, p in ipairs(c.hearts) do
        love.graphics.setColor(0.95, 0.4, 0.5, math.min(1, p.life * 2))
        heart(p.x, p.y, p.r)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------- the panel

local PANEL = { w = 300, row = 32, pad = 6 }
local ORDER = { 'loves', 'likes', 'fine', 'dislikes' }

function s.drawUI()
    if state.playMode then ui.startFrame() end -- once a frame, for both panels
    if earth then earth.drawUI() end
    local c = st()
    molePanelRect = nil
    if not (c.showPanel and state.playMode) then return end
    local rows = 6 + (c.showTastes and #ORDER or 0)
    local sw = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, 12
    molePanelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• mole ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local x, y = row()
        if ui.button(x, y, w - PANEL.pad * 2, 'a new mole (new tastes)') then s.onKeyPress('n') end
        x, y = row()
        if ui.button(x, y, w - PANEL.pad * 2, 'reset: earth, finds, mole') then reset() end
        x, y = row()
        local changed, v = ui.checkbox(x, y, c.digAnywhere, 'dig anywhere (testing)')
        if changed then c.digAnywhere = v end
        -- the finger's size (the burrow's brush; the ring round the mouse shows it)
        local b = state.moleField
        x, y = row()
        if b then
            local size = ui.sliderWithInput('molebrush', x, y, 150, 15, 800, b.brush, nil, 1)
            if size then b.brush = size end
            ui.label(x + 248, y + 4, 'size')
        end
        x, y = row()
        changed, v = ui.checkbox(x, y, c.showTastes, 'show his tastes')
        if changed then c.showTastes = v end
        if c.showTastes then
            tasteOf('worm')
            for _, taste in ipairs(ORDER) do
                local names = {}
                for _, k in ipairs(finds.FOODS) do if c.tastes[k] == taste then names[#names + 1] = k end end
                x, y = row()
                ui.label(x, y + 4, taste .. ': ' .. table.concat(names, ', '))
            end
        end
        x, y = row()
        ui.label(x, y + 4, 'n mole  r reset  [ ] size  h panel')
    end)
end

return s
