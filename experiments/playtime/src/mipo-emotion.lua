-- mipo-emotion.lua — Mipos showing how they feel with their faces (docs/EMOTIONS.md, a spike, 2026-11-11).
-- An emotion is a set of levers on the face: the brows (how high, their bend from outer end to inner end),
-- the mouth (a mix of mouth shapes, src/mouth-shapes.lua), how open the eyes are, the pupils' size, and a
-- blush on the cheeks. A Mipo holds a few at once with weights that glide (in quickly, out slowly: never a
-- snap), and the levers are the weighted mix over neutral (its own DNA face). Who it is (its eye, brow and
-- mouth pictures) stays; only the levers move, as dreamengine's peteyes keeps shape apart from feeling.
-- Writes onto the face owner's thing (head, or torso1 on a potato head), which the renderer reads:
-- l/rbrowYOffset, l/rbrowVec, mouthShapeVec (src/mipo-face.lua's fields), eyeScale, pupilScale, blush.
-- State on the instance (instance.emotion), so a hot swap keeps it.
-- An engine system (src/systems.lua, EMO5): every scene's Mipos feel what happens to them, unless the scene
-- turns it off (the settings panel's 'mipos' section, saved with the scene: lib.save / lib.load).
local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')

local lib = {}

-- raise: brows up (-) or down (+), in quarters of the eye's height; bend: outer end, middle, inner end,
-- down (+) or up (-), in fifths of the brow's width; mouth: shape name = share (the rest is its own
-- mouth; a share over 1 goes past the shape, exaggerating it: the frown alone is mild); eye: how open
-- (1 as drawn); pupil: size; brow: how thick (1 as the renderer draws it, EMO4); blush: 0..1 (the cheeks);
-- flush: { r, g, b, how strongly } over the whole
-- face, inside the head's outline (EMO3: red angry, pink shy, pale scared, a little blue sad, warm happy)
lib.EMOTIONS = {
    neutral   = { raise = 0, bend = { 0, 0, 0 }, mouth = {}, eye = 1, pupil = 1, brow = 1, blush = 0 },
    happy     = { raise = -0.4, bend = { 0.3, -0.6, 0.3 }, mouth = { smile = 1 }, eye = 0.7, pupil = 1.05,
                  brow = 1.05, blush = 0.45, flush = { 1, 0.62, 0.45, 0.12 } },
    sad       = { raise = -0.3, bend = { 1.3, 0, -1.6 }, mouth = { frown = 1.8 }, eye = 0.8, pupil = 1.15,
                  brow = 1.2, blush = 0,
                  flush = { 0.5, 0.62, 0.95, 0.18 } },
    angry     = { raise = 0.9, bend = { -1, 0, 1.9 }, mouth = { frown = 1.4 }, eye = 0.7, pupil = 0.8,
                  brow = 1.45, blush = 0.6,
                  flush = { 1, 0.12, 0.08, 0.45 } },
    scared    = { raise = -1, bend = { 0.6, -0.3, -1.7 }, mouth = { O_U_agh = 0.7 }, eye = 1.3, pupil = 0.65,
                  brow = 1.2, blush = 0, flush = { 0.9, 0.95, 1, 0.4 } },
    surprised = { raise = -1.3, bend = { 0.6, -0.9, 0.6 }, mouth = { O_U_W_Q = 1 }, eye = 1.35, pupil = 0.8,
                  brow = 1.2, blush = 0 },
    sleepy    = { raise = 0.3, bend = { 0.3, 0, 0 }, mouth = { mmm = 0.6 }, eye = 0.35, pupil = 1, brow = 0.85,
                  blush = 0.15 },
    shy       = { raise = -0.3, bend = { 0.4, -0.3, -0.4 }, mouth = { mmm = 0.5, smile = 0.4 }, eye = 0.85,
                  pupil = 1.15, brow = 1, blush = 1, flush = { 1, 0.4, 0.5, 0.3 } },
}
lib.NAMES = { 'happy', 'sad', 'angry', 'scared', 'surprised', 'sleepy', 'shy' }
lib.IN, lib.OUT = 0.25, 0.7 -- seconds to glide most of the way in, and back out
lib.BLUSH = { 0.95, 0.35, 0.42 } -- the blush's colour
lib.BLUSH_ALPHA = 0.55          -- at blush 1

local function stateOf(instance)
    instance.emotion = instance.emotion or { now = {}, goal = {} }
    return instance.emotion
end

-- Feel `name` this much (0..1, default 1); for `hold` seconds, then back to neutral (nil: until changed).
-- Other feelings glide out unless `mix` is true. 'neutral' lets all of them go.
function lib.set(instance, name, amount, hold, mix)
    local st = stateOf(instance)
    if not mix then
        for k in pairs(st.goal) do st.goal[k] = nil end
    end
    if name ~= 'neutral' and lib.EMOTIONS[name] then st.goal[name] = amount or 1 end
    st.holdUntil = hold and (love.timer.getTime() + hold) or nil
end

function lib.clear(instance) lib.set(instance, 'neutral') end

-- what it feels now: name = weight (glides toward the goal)
function lib.feelings(instance) return stateOf(instance).now end

local function faceOwner(instance)
    local owner = instance.dna and instance.dna.creation and instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = instance.parts and instance.parts[owner]
    if not (part and part.body and not part.body:isDestroyed()) then return nil end
    local ud = part.body:getUserData()
    return ud and ud.thing, part.body, owner
end

-- the mouth shape points by name (normalized, 16 numbers)
local shapePoints
local function pointsOf(name)
    if not shapePoints then
        shapePoints = {}
        for _, s in ipairs(mouthShapes.normalized) do shapePoints[s.name] = s.points end
    end
    return shapePoints[name]
end

-- an eye's height on this body (the brows move in quarters of it), from its eye decal
local function eyeHeight(body)
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        local e = ud and ud.subtype == 'decal' and ud.extra
        if e and e.isEye and not e.eyeW and e.h then return e.h end
    end
    return 20
end

-- the levers now: the weighted mix over neutral (weights over 1 in all are scaled down to 1)
local function blend(now)
    local total = 0
    for _, w in pairs(now) do total = total + w end
    local scale = total > 1 and 1 / total or 1
    local n = lib.EMOTIONS.neutral
    local out = { raise = 0, bend = { 0, 0, 0 }, mouth = {}, eye = n.eye, pupil = n.pupil, brow = n.brow, blush = 0,
        total = 0, flush = { 0, 0, 0, 0 } }
    for name, w in pairs(now) do
        local e = lib.EMOTIONS[name]
        if e and w > 0 then
            w = w * scale
            out.total = out.total + w
            out.raise = out.raise + w * e.raise
            for i = 1, 3 do out.bend[i] = out.bend[i] + w * e.bend[i] end
            out.eye = out.eye + w * (e.eye - n.eye)
            out.pupil = out.pupil + w * (e.pupil - n.pupil)
            out.brow = out.brow + w * ((e.brow or 1) - n.brow)
            out.blush = out.blush + w * e.blush
            for shape, share in pairs(e.mouth) do out.mouth[shape] = (out.mouth[shape] or 0) + w * share end
            if e.flush then -- colours weighted by how strongly each flushes
                local a = w * e.flush[4]
                for i = 1, 3 do out.flush[i] = out.flush[i] + a * e.flush[i] end
                out.flush[4] = out.flush[4] + a
            end
        end
    end
    if out.flush[4] > 0 then
        for i = 1, 3 do out.flush[i] = out.flush[i] / out.flush[4] end
    end
    return out
end
lib._blend = blend -- for specs

-- the mouth: its own rest shape for what's left, the emotions' shapes for their shares
local function mouthVec(instance, owner, shares)
    local part = instance.dna.parts[owner]
    local face = part and part.appearance and part.appearance.face
    local restIndex = face and face.mouth and face.mouth.shape or mouthShapes.indexOf('closed')
    local rest = mouthShapes.normalized[restIndex] and mouthShapes.normalized[restIndex].points or pointsOf('closed')
    local left = 1 -- below 0 when the shares go past their shapes (from the rest, beyond them)
    for _, share in pairs(shares) do left = left - share end
    local vec = {}
    for i = 1, 16 do vec[i] = rest[i] * left end
    for name, share in pairs(shares) do
        local pts = pointsOf(name)
        if pts then
            for i = 1, 16 do vec[i] = vec[i] + pts[i] * share end
        end
    end
    return vec
end

local function apply(instance, levers)
    local thing, body, owner = faceOwner(instance)
    if not thing then return end
    local st = instance.emotion
    if levers.total < 0.002 then
        if not st.clean then -- all let go: the face is its own again
            thing.lbrowYOffset, thing.rbrowYOffset = 0, 0
            thing.lbrowVec, thing.rbrowVec = { 0, 0, 0 }, { 0, 0, 0 }
            thing.mouthShapeVec, thing.eyeScale, thing.pupilScale, thing.blush = nil, nil, nil, nil
            thing.flush, thing.browScale = nil, nil
            st.clean = true
        end
        return
    end
    st.clean = false
    -- a pulled face (mipo-face: a click near the head) or a tween would fight these: the emotion leads
    thing.pulledFaceUntil, thing.browIsRandom, thing.browTweenStart, thing.mouthTweenStart = nil, false, nil, nil
    thing.mouthLetGo = nil
    local raise = levers.raise * eyeHeight(body) * 0.25
    thing.lbrowYOffset, thing.rbrowYOffset = raise, raise
    thing.lbrowVec = { levers.bend[1], levers.bend[2], levers.bend[3] }
    thing.rbrowVec = { levers.bend[1], levers.bend[2], levers.bend[3] }
    local voice = package.loaded['src.mipo-voice']
    if not (voice and voice.isFlapping and voice.isFlapping(instance)) then -- talking: the voice has the mouth
        thing.mouthShapeVec = mouthVec(instance, owner, levers.mouth)
    end
    thing.eyeScale, thing.pupilScale, thing.blush = levers.eye, levers.pupil, levers.blush
    thing.flush = levers.flush[4] > 0.005 and levers.flush or nil
    -- in twentieths: the brow's strip is rebuilt when its thickness changes, so only a few times a glide
    thing.browScale = math.floor(levers.brow * 20 + 0.5) / 20
end

-- Feelings from play (EMOTIONS EMO2): watched each frame, nothing hooked in elsewhere. Picked up: surprised
-- for a moment, then happy while held. Let go: scared when thrown fast, a little happy when put down
-- gently. Dazed by a hard hit (mipo-actions' daze): sad while it lasts, and a moment after. Still a long
-- while with nothing to feel: sleepy; moved again, woken with a little surprise. Only on changes, so a
-- feeling set by hand stays until something happens. Speeds at 100 px per metre (src/physics-units.lua).
lib.REACT = {
    surprise = 0.5,     -- seconds surprised when picked up, then happy
    heldHappy = 0.8,    -- how happy while held
    throwSpeed = 900,   -- let go faster than this: thrown, scared
    scaredFor = 1.4,
    putDownFor = 1.5,   -- happy this long after a gentle put-down
    sadAfterDaze = 1.2, -- sad a moment longer after the daze
    stillSpeed = 60,    -- slower than this on average (over about a second) counts as still: a standing
                        -- Mipo breathes and balances at 2-60, a moment over 25 now and then
    sleepAfter = 12,    -- seconds still before sleepy
    wakeSpeed = 120,    -- a sleepy one moved faster than this wakes
}
local units = require('src.physics-units')

-- the spike's numbers, live in the settings panel's 'tuning' section (src/tuning.lua): how they react, how
-- quickly a feeling glides, and each feeling's levers (mouth shares as the feeling has them)
local tuning = require('src.tuning')
lib.tuning = {
    { label = 'reactions', target = function() return lib.REACT end, rows = tuning.numbers({
        { 'surprise', 0, 3, 0.05 }, { 'heldHappy', 0, 1, 0.05 }, { 'throwSpeed', 100, 3000, 10 },
        { 'scaredFor', 0, 5, 0.1 }, { 'putDownFor', 0, 5, 0.1 }, { 'sadAfterDaze', 0, 5, 0.1 },
        { 'stillSpeed', 0, 300, 1 }, { 'sleepAfter', 1, 60, 1 }, { 'wakeSpeed', 0, 600, 5 } }) },
    { label = 'glide', target = function() return lib end, rows = tuning.numbers({
        { 'IN', 0.02, 2, 0.01 }, { 'OUT', 0.02, 3, 0.01 }, { 'BLUSH_ALPHA', 0, 1, 0.05 } }) },
}
for _, name in ipairs(lib.NAMES) do
    local e = lib.EMOTIONS[name]
    local spec = { { 'raise', -2, 2, 0.05 }, { 'bend.1', -3, 3, 0.05 }, { 'bend.2', -3, 3, 0.05 },
        { 'bend.3', -3, 3, 0.05 }, { 'eye', 0.1, 2, 0.05 }, { 'pupil', 0.3, 2, 0.05 }, { 'brow', 0.5, 2, 0.05 },
        { 'blush', 0, 1, 0.05 } }
    local shapes = {}
    for shape in pairs(e.mouth) do shapes[#shapes + 1] = shape end
    table.sort(shapes)
    for _, shape in ipairs(shapes) do spec[#spec + 1] = { 'mouth.' .. shape, 0, 3, 0.05 } end
    if e.flush then spec[#spec + 1] = { 'flush.4', 0, 1, 0.01 } end
    lib.tuning[#lib.tuning + 1] = { label = name, target = function() return lib.EMOTIONS[name] end,
        rows = tuning.numbers(spec) }
end

local function torsoSpeed(instance)
    local torso = instance.parts and instance.parts.torso1
    if not (torso and torso.body and not torso.body:isDestroyed()) then return 0 end
    local vx, vy = torso.body:getLinearVelocity()
    return units.toReferenceSpeed(math.sqrt(vx * vx + vy * vy))
end

local function heldMipos()
    local held = {}
    local pointer = package.loaded['src.physics.box2d-pointerjoints']
    if not pointer then return held end
    for _, body in ipairs(pointer.getInteractedWithPointer()) do
        local instance = mipoRegistry.getFromBody(body)
        if instance then held[instance] = true end
    end
    return held
end

local function react(instance, held, dt, now)
    local R = lib.REACT
    local r = instance._feelPlay or { still = 0, avg = 0 }
    instance._feelPlay = r
    local speed = torsoSpeed(instance)
    r.avg = (r.avg or 0) + (speed - (r.avg or 0)) * (1 - math.exp(-dt)) -- over about a second
    local dazed = instance._dazedUntil and now < instance._dazedUntil
    if held and not r.held then -- picked up
        lib.set(instance, 'surprised', 1, R.surprise)
        r.heldSince, r.sleeping = now, false
    elseif held and r.heldSince and now - r.heldSince > R.surprise then
        lib.set(instance, 'happy', R.heldHappy)
        r.heldSince = nil
    elseif not held and r.held then -- let go
        if speed > R.throwSpeed then
            lib.set(instance, 'scared', 1, R.scaredFor)
        else
            lib.set(instance, 'happy', 0.6, R.putDownFor)
        end
    end
    r.held = held
    if dazed and not r.dazed then
        lib.set(instance, 'sad', 1)
    elseif not dazed and r.dazed then
        lib.set(instance, 'sad', 0.7, R.sadAfterDaze)
    end
    r.dazed = dazed
    -- sleepy when left alone long enough; woken when moved
    if held or dazed or r.avg > R.stillSpeed then r.still = 0 else r.still = r.still + dt end
    if r.sleeping and (held or speed > R.wakeSpeed) then
        r.sleeping = false
        if not held then lib.set(instance, 'surprised', 0.7, 0.6) end
    elseif not r.sleeping and r.still > R.sleepAfter and next(stateOf(instance).goal) == nil then
        lib.set(instance, 'sleepy', 0.9)
        r.sleeping = true
    end
end

-- the scene's setting: do its Mipos feel what happens to them (on unless the scene says no)
local function settings()
    state.mipoFeel = state.mipoFeel or { play = true }
    return state.mipoFeel
end
lib.settings = settings
function lib.isOn() return settings().play ~= false end
-- from a scene file (nil: on)
function lib.load(saved) state.mipoFeel = { play = not (saved and saved.play == false) } end
-- for a scene file: nothing when it's on, so files stay as they were
function lib.save()
    if lib.isOn() then return nil end
    return { play = false }
end
-- the settings panel's rows (src/ui/world-settings.lua, src/ui/inspector.lua)
lib.rows = {
    { key = 'feel what happens', kind = 'bool',
      get = function(s) return s.play ~= false end,
      set = function(s, v) s.play = v and true or false end },
}

-- every frame: the weights glide toward the goals, a held feeling ends, the face follows. fromPlay: the
-- Mipos also feel what happens to them (picked up, thrown, dazed, left alone)
function lib.update(dt, fromPlay)
    local now = love.timer.getTime()
    if fromPlay then
        local held = heldMipos()
        for _, instance in pairs(mipoRegistry.getAll()) do
            if instance.parts and instance.parts.torso1 then react(instance, held[instance] == true, dt, now) end
        end
    end
    local kIn, kOut = 1 - math.exp(-dt * 3 / lib.IN), 1 - math.exp(-dt * 3 / lib.OUT)
    for _, instance in pairs(mipoRegistry.getAll()) do
        local st = instance.emotion
        if st then
            if st.holdUntil and now >= st.holdUntil then
                for k in pairs(st.goal) do st.goal[k] = nil end
                st.holdUntil = nil
            end
            for name in pairs(st.goal) do st.now[name] = st.now[name] or 0 end
            for name, w in pairs(st.now) do
                local goal = st.goal[name] or 0
                w = w + (goal - w) * (goal > w and kIn or kOut)
                if goal == 0 and w < 0.002 then w = nil end
                st.now[name] = w
            end
            apply(instance, blend(st.now))
        end
    end
end

-- the blush: a soft disc on each cheek, below and outside the eyes; and the flush (drawn by the renderer
-- just before the left eye, so both lie on the skin under the eyes, brows, nose and mouth)
local disc
local function blushDisc()
    if disc then return disc end
    local size = 64
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
        local d = math.min(1, math.sqrt(dx * dx + dy * dy))
        local a = (1 - d * d) ^ 2
        return 1, 1, 1, a
    end)
    disc = love.graphics.newImage(data)
    return disc
end

-- the flush: a wide soft wash centred a little under the eyes, inside the head's skin (EMO3)
local function drawFlush(body, flush, cx, cy, span)
    local textured = package.loaded['src.physics.box2d-draw-textured']
    if not (textured and textured.drawInsideSkin) then return end
    local img = blushDisc()
    local iw, ih = img:getDimensions()
    local wx, wy = body:getWorldPoint(cx, cy)
    textured.drawInsideSkin(body, function()
        love.graphics.setColor(flush[1], flush[2], flush[3], math.min(1, flush[4]))
        love.graphics.draw(img, wx, wy, body:getAngle(), span * 3.2 / iw, span * 2.6 / ih, iw / 2, ih / 2)
    end)
end

function lib.drawBlush(body)
    local ud = body:getUserData()
    local thing = ud and ud.thing
    local amount = thing and thing.blush or 0
    local flush = thing and thing.flush
    if amount <= 0.01 and not flush then return end
    local eyes = {}
    for _, fixture in ipairs(body:getFixtures()) do
        local fud = fixture:getUserData()
        local e = fud and fud.subtype == 'decal' and fud.extra
        if e and e.isEye and not e.eyeW and e.ox then eyes[#eyes + 1] = e end
    end
    if #eyes == 0 then return end
    local cx, cy, span = 0, 0, 0
    for _, e in ipairs(eyes) do cx, cy = cx + e.ox, cy + (e.oy or 0) end
    cx, cy = cx / #eyes, cy / #eyes
    for _, e in ipairs(eyes) do span = math.max(span, math.abs(e.ox - cx) + (e.w or 20) / 2) end
    local r, g, b, a = love.graphics.getColor()
    if flush then drawFlush(body, flush, cx, cy + span * 0.35, span) end
    love.graphics.setColor(r, g, b, a)
    if amount <= 0.01 then return end
    local img = blushDisc()
    local iw, ih = img:getDimensions()
    love.graphics.setColor(lib.BLUSH[1], lib.BLUSH[2], lib.BLUSH[3], lib.BLUSH_ALPHA * math.min(1, amount))
    for _, e in ipairs(eyes) do
        local w, h = e.w or 20, e.h or 20
        local x, y = cx + (e.ox - cx) * 1.25, (e.oy or 0) + h * 0.85
        local wx, wy = body:getWorldPoint(x, y)
        love.graphics.draw(img, wx, wy, body:getAngle(), w * 1.0 / iw, w * 0.6 / ih, iw / 2, ih / 2)
    end
    love.graphics.setColor(r, g, b, a)
end

return lib
