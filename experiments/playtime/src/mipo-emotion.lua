-- mipo-emotion.lua — Mipos showing how they feel with their faces (docs/EMOTIONS.md, a spike, 2026-11-11).
-- An emotion is a set of levers on the face: the brows (how high, their bend from outer end to inner end),
-- the mouth (a mix of mouth shapes, src/mouth-shapes.lua), how open the eyes are, the pupils' size, and a
-- blush on the cheeks. A Mipo holds a few at once with weights that glide (in quickly, out slowly: never a
-- snap), and the levers are the weighted mix over neutral (its own DNA face). Who it is (its eye, brow and
-- mouth pictures) stays; only the levers move, as dreamengine's peteyes keeps shape apart from feeling.
-- Writes onto the face owner's thing (head, or torso1 on a potato head), which the renderer reads:
-- l/rbrowYOffset, l/rbrowVec, mouthShapeVec (src/mipo-face.lua's fields), eyeScale, pupilScale, blush.
-- State on the instance (instance.emotion), so a hot swap keeps it.
local mipoRegistry = require('src.mipo-registry')
local mouthShapes = require('src.mouth-shapes')

local lib = {}

-- raise: brows up (-) or down (+), in quarters of the eye's height; bend: outer end, middle, inner end,
-- down (+) or up (-), in fifths of the brow's width; mouth: shape name = share (the rest is its own
-- mouth; a share over 1 goes past the shape, exaggerating it: the frown alone is mild); eye: how open
-- (1 as drawn); pupil: size; blush: 0..1
lib.EMOTIONS = {
    neutral   = { raise = 0, bend = { 0, 0, 0 }, mouth = {}, eye = 1, pupil = 1, blush = 0 },
    happy     = { raise = -0.4, bend = { 0.3, -0.6, 0.3 }, mouth = { smile = 1 }, eye = 0.7, pupil = 1.05,
                  blush = 0.45 },
    sad       = { raise = -0.3, bend = { 1.3, 0, -1.6 }, mouth = { frown = 1.8 }, eye = 0.8, pupil = 1.15, blush = 0 },
    angry     = { raise = 0.9, bend = { -1, 0, 1.9 }, mouth = { frown = 1.4 }, eye = 0.7, pupil = 0.8, blush = 0.6 },
    scared    = { raise = -1, bend = { 0.6, -0.3, -1.7 }, mouth = { O_U_agh = 0.7 }, eye = 1.3, pupil = 0.65,
                  blush = 0 },
    surprised = { raise = -1.3, bend = { 0.6, -0.9, 0.6 }, mouth = { O_U_W_Q = 1 }, eye = 1.35, pupil = 0.8,
                  blush = 0 },
    sleepy    = { raise = 0.3, bend = { 0.3, 0, 0 }, mouth = { mmm = 0.6 }, eye = 0.35, pupil = 1, blush = 0.15 },
    shy       = { raise = -0.3, bend = { 0.4, -0.3, -0.4 }, mouth = { mmm = 0.5, smile = 0.4 }, eye = 0.85,
                  pupil = 1.15, blush = 1 },
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
    local out = { raise = 0, bend = { 0, 0, 0 }, mouth = {}, eye = n.eye, pupil = n.pupil, blush = 0, total = 0 }
    for name, w in pairs(now) do
        local e = lib.EMOTIONS[name]
        if e and w > 0 then
            w = w * scale
            out.total = out.total + w
            out.raise = out.raise + w * e.raise
            for i = 1, 3 do out.bend[i] = out.bend[i] + w * e.bend[i] end
            out.eye = out.eye + w * (e.eye - n.eye)
            out.pupil = out.pupil + w * (e.pupil - n.pupil)
            out.blush = out.blush + w * e.blush
            for shape, share in pairs(e.mouth) do out.mouth[shape] = (out.mouth[shape] or 0) + w * share end
        end
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
    thing.mouthShapeVec = mouthVec(instance, owner, levers.mouth)
    thing.eyeScale, thing.pupilScale, thing.blush = levers.eye, levers.pupil, levers.blush
end

-- every frame: the weights glide toward the goals, a held feeling ends, the face follows
function lib.update(dt)
    local now = love.timer.getTime()
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

-- the blush: a soft disc on each cheek, below and outside the eyes (drawn before the nose by the renderer)
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

function lib.drawBlush(body)
    local ud = body:getUserData()
    local thing = ud and ud.thing
    local amount = thing and thing.blush
    if not amount or amount <= 0.01 then return end
    local eyes = {}
    for _, fixture in ipairs(body:getFixtures()) do
        local fud = fixture:getUserData()
        local e = fud and fud.subtype == 'decal' and fud.extra
        if e and e.isEye and not e.eyeW and e.ox then eyes[#eyes + 1] = e end
    end
    if #eyes == 0 then return end
    local cx = 0
    for _, e in ipairs(eyes) do cx = cx + e.ox end
    cx = cx / #eyes
    local img = blushDisc()
    local iw, ih = img:getDimensions()
    local r, g, b, a = love.graphics.getColor()
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
