-- mipo-face.lua
-- A Mipo's face comes alive: blinking, brows and mouth tweening between shapes, and a
-- click near a face pulls a face for a moment. Keeps its state on the face-owning part's
-- thing (eyesOpen, l/rbrowYOffset, l/rbrowVec, mouthShapeVec), which the decals read when
-- drawn. Moved out of box2d-draw-textured.lua: the renderer only draws.
local mouthShapes = require('src.mouth-shapes')
local utils = require('src.utils')
local subtypes = require('src.subtypes')
local mipoRegistry = require('src.mipo-registry')
local cam = require('src.camera').getInstance()

local lib = {}

-- Blink system. Keyed by body:getUserData().thing, using wall-clock time.
-- Weak keys: a thing that's rebuilt or destroyed takes its blink state with it.
local blinkStates = setmetatable({}, { __mode = 'k' })
local prevMouseDown = false
local closedNorm  -- lazy-init: normalized 'closed' mouth shape for tween start

local browTweenDuration = 0.1 -- seconds

-- Bend shapes as {p1, p2, p3} control point Y factors
lib.browBendVecs = { -- the brow decal's bend shapes (drawn in box2d-draw-textured)
    { 0,  0,  0 },   -- 1: flat
    { 1,  0, -1 },   -- 2: outer corners down
    {-1,  0,  1 },   -- 3: outer corners up
    { 1,  0,  1 },   -- 4: raised both ends
    {-1,  0, -1 },   -- 5: lowered both ends
    { 1,  0,  0 },   -- 6: left up
    {-1,  0,  0 },   -- 7: left down
    { 0, -1,  1 },   -- 8
    { 0,  1,  1 },   -- 9
    {-1,  1,  1 },   -- 10
}
local browBendOptions = { 1, 1, 2, 3, 4, 5 } -- weighted toward neutral/flat

local function initBrowState(thing)
    thing.lbrowYOffset = 0;  thing.lbrowYFrom = 0;  thing.lbrowYTarget = 0
    thing.rbrowYOffset = 0;  thing.rbrowYFrom = 0;  thing.rbrowYTarget = 0
    thing.lbrowVec = {0,0,0};  thing.lbrowVecFrom = {0,0,0};  thing.lbrowVecTarget = {0,0,0}
    thing.rbrowVec = {0,0,0};  thing.rbrowVecFrom = {0,0,0};  thing.rbrowVecTarget = {0,0,0}
    thing.browTweenStart = nil
end

local function setBrows(thing, lY, rY, bendIdx)
    local vec = lib.browBendVecs[bendIdx] or lib.browBendVecs[1]
    thing.lbrowYFrom = thing.lbrowYOffset or 0
    thing.rbrowYFrom = thing.rbrowYOffset or 0
    thing.lbrowYTarget = lY;  thing.rbrowYTarget = rY
    local lbrowVec = thing.lbrowVec or lib.browBendVecs[1]
    local rbrowVec = thing.rbrowVec or lib.browBendVecs[1]
    thing.lbrowVecFrom = { lbrowVec[1], lbrowVec[2], lbrowVec[3] }
    thing.rbrowVecFrom = { rbrowVec[1], rbrowVec[2], rbrowVec[3] }
    thing.lbrowVecTarget = vec;  thing.rbrowVecTarget = vec
    thing.browTweenStart = love.timer.getTime()
end

local function neutralBrows(thing)  setBrows(thing, 0, 0, 1) end

local function randomizeBrows(thing)
    setBrows(thing,
        math.random(-20, 20),
        math.random(-20, 20),
        browBendOptions[math.random(#browBendOptions)]
    )
end

local function tickBrowLerp(thing, _dt)
    if not thing.browTweenStart then return end
    local t = math.min((love.timer.getTime() - thing.browTweenStart) / browTweenDuration, 1)
    local function lerp(a, b) return a + (b - a) * t end
    thing.lbrowYOffset = lerp(thing.lbrowYFrom or 0, thing.lbrowYTarget or 0)
    thing.rbrowYOffset = lerp(thing.rbrowYFrom or 0, thing.rbrowYTarget or 0)
    local lf, lt = thing.lbrowVecFrom or lib.browBendVecs[1], thing.lbrowVecTarget or lib.browBendVecs[1]
    local rf, rt = thing.rbrowVecFrom or lib.browBendVecs[1], thing.rbrowVecTarget or lib.browBendVecs[1]
    thing.lbrowVec = { lerp(lf[1], lt[1]), lerp(lf[2], lt[2]), lerp(lf[3], lt[3]) }
    thing.rbrowVec = { lerp(rf[1], rt[1]), lerp(rf[2], rt[2]), lerp(rf[3], rt[3]) }
    if t >= 1 then thing.browTweenStart = nil end
end

local mouthTweenDuration = 0.15
local mouthNormalized = mouthShapes.normalized

local function setMouthShape(thing, shapeIdx)
    local shape = mouthNormalized[shapeIdx]
    if not shape then return end
    if thing.mouthShapeVec then
        thing.mouthShapeFrom = { unpack(thing.mouthShapeVec) }
    else
        if not closedNorm then
            for _, s in ipairs(mouthNormalized) do
                if s.name == 'closed' then closedNorm = s; break end
            end
        end
        thing.mouthShapeFrom = closedNorm and closedNorm.points or shape.points
    end
    thing.mouthShapeTarget = shape.points
    thing.mouthTweenStart = love.timer.getTime()
end

-- Back to the Mipo's own rest mouth (its DNA), then drop the override so the
-- lip decal draws the DNA mouth again (and an edit in the Mipo editor shows).
-- Was: back to 'closed', kept forever.
local function restMouth(thing, body)
    local instance = mipoRegistry.getFromBody(body)
    local part = instance and instance.dna and instance.dna.parts[thing.label]
    local face = part and part.appearance and part.appearance.face
    setMouthShape(thing, face and face.mouth and face.mouth.shape or mouthShapes.indexOf('closed'))
    thing.mouthLetGo = true
    thing.mouthIsRandom = false
end

local function randomizeMouth(thing)
    setMouthShape(thing, math.random(#mouthNormalized))
    thing.mouthLetGo = nil
    thing.mouthIsRandom = true
end

-- A click near a Mipo's face pulls a face (random brows + mouth) for this long,
-- then it goes back to its own. It used to stay until the next click, and
-- grabbing a Mipo by the head is a click: half of them were left pulling faces,
-- mostly open-mouthed.
local PULLED_FACE_SECONDS = 2

local function tickMouthTween(thing)
    if not thing.mouthTweenStart then return end
    local t = math.min((love.timer.getTime() - thing.mouthTweenStart) / mouthTweenDuration, 1)
    local from = thing.mouthShapeFrom
    local to   = thing.mouthShapeTarget
    if not from or not to then return end
    local vec = {}
    for i = 1, 16 do vec[i] = from[i] + (to[i] - from[i]) * t end
    thing.mouthShapeVec = vec
    if t >= 1 then
        thing.mouthTweenStart = nil
        if thing.mouthLetGo then
            thing.mouthShapeVec, thing.mouthShapeTarget, thing.mouthLetGo = nil, nil, nil
        end
    end
end

local function lsq1D(nx, wy)
    local n = #nx
    local snx, swy = 0, 0
    for i = 1, n do snx = snx + nx[i]; swy = swy + wy[i] end
    local mnx, mwy = snx / n, swy / n
    local num, den = 0, 0
    for i = 1, n do
        local dx = nx[i] - mnx
        num = num + dx * (wy[i] - mwy); den = den + dx * dx
    end
    local scale = den > 0.001 and (num / den) or 1
    return scale, mwy - scale * mnx
end

local function initFaceDecals(body)
    if not closedNorm then
        for _, s in ipairs(mouthNormalized) do
            if s.name == 'closed' then closedNorm = s; break end
        end
    end
    for _, f in ipairs(body:getFixtures()) do
        local fud = f:getUserData()
        if fud and fud.subtype == subtypes.DECAL then
            if fud.extra.eyeW then fud.extra.lookAtMouse = true end
            local l = fud.label
            if l == 'leye' or l == 'reye' or l == 'lpupil' or l == 'rpupil' then
                fud.extra.isEye = true
            end
            -- Migrate old mouth decals missing scale transform
            if fud.extra.mouthCurve and closedNorm then
                local cp = fud.extra.curvePoints
                if cp and #cp == 16 and not fud.extra.mouthScaleX then
                    local nx, wx = {}, {}
                    for ci = 1, 16, 2 do
                        nx[#nx + 1] = closedNorm.points[ci]
                        wx[#wx + 1] = cp[ci]
                    end
                    local scaleX, offX = lsq1D(nx, wx)
                    local sumy = 0
                    for ci = 2, 8, 2 do sumy = sumy + cp[ci] end
                    fud.extra.mouthScaleX = scaleX
                    fud.extra.mouthScaleY = scaleX
                    fud.extra.mouthX = offX
                    fud.extra.mouthY = sumy / 4
                end
                if fud.extra.mouthCurve == 'lower' then
                    fud.extra.backdropHex = '00000099'
                end
            end
        end
    end
end

local function isFaceOwner(label)
    return label == 'head' or label == 'torso1'
end

-- Blinks, brow and mouth tweens, and a click near a face pulls one. Every update (also
-- while paused), not from the draw: it reads the mouse and changes the Mipos' things.
function lib.update(world, dt)
    local now = love.timer.getTime()
    for _, body in ipairs(world:getBodies()) do
        local thing = utils.thingOf(body)
        if thing then
            local s = blinkStates[thing]
            if not s then
                s = { expiresAt = now + 2 + math.random() * 4 }
                blinkStates[thing] = s
                if isFaceOwner(thing.label) then
                    initFaceDecals(body)
                    initBrowState(thing)
                end
            end
            if now >= s.expiresAt then
                -- trigger a blink: squish down then back up
                s.expiresAt = now + 2 + math.random() * 4
                s.blinkStart = now
            end
            if s.blinkStart then
                local elapsed = now - s.blinkStart
                local closeTime, openTime = 0.08, 0.12
                if elapsed < closeTime then
                    thing.eyesOpen = 1 - (elapsed / closeTime)
                elseif elapsed < closeTime + openTime then
                    thing.eyesOpen = (elapsed - closeTime) / openTime
                else
                    thing.eyesOpen = 1
                    s.blinkStart = nil
                end
            else
                thing.eyesOpen = 1
            end
            if isFaceOwner(thing.label) then
                -- (a face pulled before faces were temporary has no end time: end it now)
                if thing.browIsRandom and not thing.pulledFaceUntil then thing.pulledFaceUntil = now end
                if thing.pulledFaceUntil and now >= thing.pulledFaceUntil then
                    thing.pulledFaceUntil, thing.browIsRandom = nil, false
                    neutralBrows(thing)
                    restMouth(thing, body)
                end
                tickBrowLerp(thing, dt)
                tickMouthTween(thing)
            end
        end
    end

    -- Click on head/torso1 (potato head) → randomize brows + mouth
    local mouseDown = love.mouse.isDown(1)
    if mouseDown and not prevMouseDown then
        local mx, my = love.mouse.getPosition()
        local wmx, wmy = cam:getWorldCoordinates(mx, my)
        for _, body in ipairs(world:getBodies()) do
            local thing = utils.thingOf(body)
            if thing and isFaceOwner(thing.label) then
                local bx, by = body:getPosition()
                local dx, dy = wmx - bx, wmy - by
                if dx * dx + dy * dy < 200 * 200 then
                    randomizeBrows(thing)
                    randomizeMouth(thing)
                    thing.browIsRandom = true
                    thing.pulledFaceUntil = love.timer.getTime() + PULLED_FACE_SECONDS
                end
            end
        end
    end
    prevMouseDown = mouseDown
end

lib._test = { blinkStates = blinkStates } -- for specs, not part of the API

return lib
