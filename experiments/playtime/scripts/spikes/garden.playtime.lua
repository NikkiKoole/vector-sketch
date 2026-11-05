-- garden: critters next to the Mipos: worm, snake, bee, butterfly, ladybird, spider, dog, cat, giraffe,
-- walker, chicken.
-- The small ones have two pupils (no whites); the dog, the cat and the walker wear a Mipo's head.
-- Critters are much simpler than Mipos: a handful of bodies, one way of moving, eyes that follow you.
-- - worm: a chain of circles on soft distance joints, skinned with Mipo leg-05 (the ringed one). It crawls like an
--   earthworm: a wave of stretch and squeeze runs down the links while each segment touching
--   something grips against sliding back. Rears up and flops over to turn; rears up to look at you.
-- - bee: one circle, no gravity, steering towards flowers, curious about the pointer. Its body is an
--   OMP (outline + mask + pattern, like a Mipo part): a round outline, yellow, bee-stripes.png (crayon
--   bands across, made from lijnen.png's crayon grain: a placeholder for drawn stripes), chesthair-01
--   over it faintly for fuzz. Throw it into something: dazed, it drops for a moment.
-- Forces are written at 100 px per metre and scaled by the world's meter, as src/physics-units does.
--
-- later: a fish, a turtle (Nikki, 2026-11-05)
--
-- play mode (tab): drag the critters about.
-- keys: r new critters   m new Mipo   b the bee's next outline   w its next wings   p its pupils
--   1-9 one more at the mouse: worm / bee / ladybird / spider / dog / cat / walker / snake /
--       butterfly (or the + buttons at the top)
--   l new ladybirds   n new spider   d new dog   c new cat   u new walker   k new snake   f butterflies   g giraffe
--   j chicken (+ chicken button)
--   h the panel of numbers to tweak
--   (tap a ladybird: it flips over)

local s = {}

local GROUND_Y = 900
local DROP = 350 -- critters start at least this far above the ground and drop in (none start in it)
local HALF_W = 2200
local ZOOM = 0.42
local PUPIL = { 0.12, 0.09, 0.09 }

local BEE_SKINS = { -- outline (+ mask) for the bee's round body; fuzz = chesthair over it
    { url = 'mipo/patch/patch-01.png', fuzz = true },
    { url = 'mipo/body/body-03.png', fuzz = true },
    { url = 'mipo/patch/patch-01.png', fuzz = false },
}

local FLOWERS = { -- x, height, petal colour
    { x = -1500, h = 380, c = { 0.95, 0.55, 0.6 } },
    { x = -800, h = 470, c = { 0.98, 0.92, 0.85 } },
    { x = 650, h = 420, c = { 0.65, 0.6, 0.95 } },
    { x = 1350, h = 340, c = { 0.98, 0.75, 0.35 } },
}

-- the numbers to tweak, on the panel (h hides it): key, min, max, default, what it is
local TUNE = {
    { 'eyeSize', 0.5, 2, 1, 'pupil size' },
    { 'eyeReach', 0, 3, 1, 'how far the pupils look' },
    { 'wormWaveHz', 0, 3, 0.8, 'worm: squeezes per second' },
    { 'wormStretch', 0, 0.6, 0.3, 'worm: how much a link grows/shrinks' },
    { 'wormGrip', 0, 40, 10, 'worm: grip against sliding back' },
    { 'wormStiff', 1, 20, 7, 'worm: link stiffness (Hz)' },
    { 'wormSpine', 0, 6, 1.6, 'worm: straightness (Hz)' },
    { 'wormRear', 0.5, 2.5, 1.25, 'worm: rearing up (x gravity)' },
    { 'wormWidth', 0.6, 2.5, 1.3, 'worm: skin width (x radius)' },
    { 'beeSpeed', 50, 1200, 420, 'bee: speed' },
    { 'beeSteer', 0.5, 10, 3, 'bee: how quick it turns' },
    { 'beeBob', 0, 250, 70, 'bee: bob up and down' },
    { 'beeWander', 0, 200, 40, 'bee: wander sideways' },
    { 'beeCurious', 0, 1500, 600, 'bee: comes to look from' },
    { 'beeDaze', 200, 3000, 700, 'bee: hit this hard, dazed' },
    { 'wingSpeed', 5, 80, 22, 'bee: wing flaps' },
    { 'throwBoost', 0.3, 1.5, 0.9, 'throw: speed kept on letting go' },
    { 'throwMax', 100, 2000, 780, 'throw: fastest it can leave' },
    { 'throwCoast', 0, 2, 0.35, 'throw: seconds it flies on its own' },
    { 'throwDrag', 0, 6, 2.5, 'throw: air drag while flying off' },
    { 'throwGravity', 0, 1, 0, 'throw: gravity while flying off' },
    { 'recoverTime', 0.1, 3, 0.9, 'throw: seconds to steer back in' },
    { 'ladySpeed', 0, 300, 80, 'ladybird: walking speed' },
    { 'ladyStick', 0, 3, 1.4, 'ladybird: sticks to surfaces (x gravity)' },
    { 'ladyFlySpeed', 50, 800, 350, 'ladybird: flying speed' },
    { 'ladyFlyChance', 0, 1, 0.15, 'ladybird: how often it flies off' },
    { 'spiderSpeed', 0, 600, 260, 'spider: scuttle speed' },
    { 'spiderHeight', 0.5, 1.5, 1, 'spider: how high it stands' },
    { 'spiderFootPull', 2, 40, 14, 'spider: feet pulled to their spots' },
    { 'spiderStride', 10, 200, 60, 'spider: steps when a foot is this far behind' },
    { 'spiderStep', 0.05, 0.6, 0.16, 'spider: seconds a step takes' },
    { 'spiderLegWidth', 0.5, 5, 2.8, 'spider: leg thickness' },
    { 'dogSpeed', 50, 800, 300, 'dog: trotting speed' },
    { 'dogKeep', 150, 900, 380, 'dog: how far from the Mipo it stays' },
    { 'dogWag', 0, 40, 14, 'dog: tail wagging' },
    { 'dogTailWidth', 0.5, 4, 1.8, 'dog: tail thickness' },
    { 'catSpeed', 30, 600, 160, 'cat: walking speed' },
    { 'dogMuscle', 0.1, 3, 1, 'dog & cat: leg strength' },
    { 'dogStride', 0, 0.8, 0.35, 'dog & cat: leg swing walking (radians)' },
    { 'dogWaist', 0, 3, 1, 'dog & cat: waist stiffness' },
    { 'dogBodyWidth', 0.6, 1.6, 1, 'dog & cat: body picture thickness' },
    { 'walkerSpeed', 30, 600, 200, 'walker: walking speed' },
    { 'walkerSteps', 0.3, 4, 1.6, 'walker: steps per second' },
    { 'walkerStride', 0, 1, 0.45, 'walker: leg swing (radians)' },
    { 'walkerMuscle', 0.1, 3, 1, 'walker: leg strength' },
    { 'butterflyFlaps', 0.5, 8, 3, 'butterfly: flaps per second' },
    { 'butterflyLift', 0.3, 2, 1, 'butterfly: lift of a flap (1 = holds itself up)' },
    { 'butterflySpeed', 30, 600, 220, 'butterfly: flying speed' },
    { 'butterflyPerch', 0.5, 15, 5, 'butterfly: seconds on a flower' },
    { 'butterflyWide', 0.5, 3, 1.9, 'butterfly: wing width' },
    { 'chickenSpeed', 30, 600, 230, 'chicken: walking speed' },
    { 'chickenPeck', 0, 1.4, 1.1, 'chicken: how far it pecks down (radians)' },
    { 'flyPitch', 0, 1.5, 0.6, 'bee: nose follows its path' },
    { 'flyLean', 0, 1, 0.3, 'bee: leans into speeding up' },
    { 'flyTurn', 1, 20, 6, 'bee: how quick it turns its body' },
    { 'wingSize', 0.5, 4, 2.4, 'bee: wing length (x radius)' },
    { 'wingLean', -0.5, 1.5, 0.45, 'bee: wings lean back' },
    { 'wingAlpha', 0, 1, 0.9, 'bee: wings see-through' },
    { 'fuzzSize', 1.5, 4, 2.7, 'bee: fuzz around it (x radius)' },
}

local function garden()
    state.garden = state.garden or
        { worms = {}, bees = {}, mipos = {}, time = 0, beeSkin = 1, wingKind = 1, showPanel = false }
    local g = state.garden
    g.settings = g.settings or {}
    if g.throwVersion ~= 4 then -- the first throw catapulted: its numbers go back to the new defaults
        for _, row in ipairs(TUNE) do
            if row[1]:find('^throw') then g.settings[row[1]] = nil end
        end
        g.throwVersion = 4
    end
    if g.wingVersion ~= 2 then g.settings.wingSpeed, g.wingVersion = nil, 2 end -- slower wings
    for _, row in ipairs(TUNE) do -- new rows after a hot reload get their default
        if g.settings[row[1]] == nil then g.settings[row[1]] = row[4] end
    end
    return g
end

-- the meter's factors (src/physics-units.lua): accelerations * k, speeds and rates * root
local function factors()
    local k = love.physics.getMeter() / 100
    return k, math.sqrt(k)
end

local function gravityY()
    local _, gy = world:getGravity()
    return gy
end

local function len(x, y) return math.sqrt(x * x + y * y) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

local function touching(body)
    for _, contact in ipairs(body:getContacts()) do
        if contact:isTouching() then return true end
    end
    return false
end

-- the pointer, when it's been about lately (a mouse that hasn't moved for a while is forgotten)
local function pointer(g)
    local wx, wy = mouseWorldPos()
    local mx, my = love.mouse.getPosition()
    local touches = love.touch.getTouches()
    if #touches > 0 then
        wx, wy = cam:getWorldCoordinates(love.touch.getPosition(touches[1]))
        g.pointerSeen = g.time
    elseif g.lastMouseX ~= mx or g.lastMouseY ~= my or love.mouse.isDown(1) then
        g.pointerSeen = g.time
    end
    g.lastMouseX, g.lastMouseY = mx, my
    if g.pointerSeen and g.time - g.pointerSeen < 3 then return wx, wy end
end

---------------------------------------------------------------- eyes
-- Two pupils, no whites. They look towards (tx, ty) by sliding a little inside where the eye would
-- be, and blink now and then (squashed flat for a moment).

local function newEyes()
    return { nextBlink = 1 + love.math.random() * 3, blink = 0, lx = 0, ly = 0 }
end

local function updateEyes(eyes, dt, dirX, dirY)
    eyes.nextBlink = eyes.nextBlink - dt
    if eyes.nextBlink < 0 then
        eyes.blink = 0.13
        eyes.nextBlink = 1.5 + love.math.random() * 4
    end
    eyes.blink = math.max(0, eyes.blink - dt)
    local l = len(dirX, dirY)
    if l > 0 then dirX, dirY = dirX / l, dirY / l end
    local follow = 1 - math.exp(-dt * 12)
    eyes.lx = eyes.lx + (dirX - eyes.lx) * follow
    eyes.ly = eyes.ly + (dirY - eyes.ly) * follow
end

-- pupils of radius r at (x1, y1) and (x2, y2), sliding up to `reach` towards where the eyes look
-- The Mipos' own pupils (textures/mipo/pupil, white crayon drawings tinted dark; Mipos start on
-- pupil-01). `p` picks the next one for the bee.
local PUPIL_COUNT = 11
local pupilImages = {}
local function pupilImage(n)
    n = ((n or 1) - 1) % PUPIL_COUNT + 1
    if not pupilImages[n] then
        pupilImages[n] = love.graphics.newImage(string.format('textures/mipo/pupil/pupil-%02d.png', n))
    end
    return pupilImages[n]
end

-- image: a pupil picture (nil: a plain dot), drawn r across
local function drawEyes(eyes, x1, y1, x2, y2, r, reach, dazed, image)
    r = r * garden().settings.eyeSize
    reach = reach * garden().settings.eyeReach
    love.graphics.setColor(PUPIL)
    local squash = eyes.blink > 0 and 0.15 or 1
    for k = 1, 2 do
        local x, y = (k == 1) and x1 or x2, (k == 1) and y1 or y2
        local ox, oy = eyes.lx * reach, eyes.ly * reach
        if dazed then -- round and round
            local a = garden().time * 9 + k * math.pi
            ox, oy = math.cos(a) * reach, math.sin(a) * reach
        end
        if image then
            local iw, ih = image:getDimensions()
            local sc = r * 2 / math.max(iw, ih)
            -- each eye turned its own way, so the two crayon drawings aren't the same
            love.graphics.draw(image, x + ox, y + oy, k * 2.1, sc, sc * squash, iw / 2, ih / 2)
        else
            love.graphics.ellipse('fill', x + ox, y + oy, r, r * squash)
        end
    end
end

---------------------------------------------------------------- the worm

local WORM = {
    segments = 10, radius = 20, gap = 30, headScale = 1.05, taper = 0.35, taperPower = 2,
    waveMul = 1, rearSegments = 2, rearMul = 1,
    color = { 0.93, 0.58, 0.58 }, band = { 0.84, 0.44, 0.48 }, ink = { 0.36, 0.17, 0.17 },
}

-- The snake: the worm's way of moving (snakes do crawl like this: concertina), longer and thinner,
-- tapering from a broad head to a thin tail, quicker, rearing up high like a cobra to look at you,
-- a forked tongue flicking now and then. Skin: Mipo leg-02 in green with a dark scribble.
local SNAKE = {
    segments = 18, radius = 24, gap = 30, headScale = 1.15, taper = 0.7, taperPower = 1,
    waveMul = 1.7, rearSegments = 4, rearMul = 1.15, tongue = true,
    -- leg-02, an outline round an open middle: the green and its scribble show (leg-01, one solid
    -- stroke, came out all outline: near black)
    skinURL = 'textures/mipo/leg/leg-02',
    skin = { bgHex = '1F2A14FF', fgHex = '86BE55FF', pHex = '2E4A1C99', pURL = 'type5.png' },
    version = 2, -- a change that needs the snakes built again: count it up
}

local function makeWorm(x, y, dir, kind)
    local K = kind or WORM
    local _, root = factors()
    local group = -30000 - love.math.random(1, 999) -- its own segments don't collide
    local w = { bodies = {}, links = {}, spines = {}, dir = dir, phase = 0, state = 'crawl', kind = K,
        stateTime = 4 + love.math.random() * 4, eyes = newEyes(), group = group, tongue = 0 }
    for i = 1, K.segments do
        local body = love.physics.newBody(world, x - (i - 1) * K.gap * dir, y, 'dynamic')
        local r = K.radius * (i == 1 and K.headScale
            or (1 - K.taper * ((i - 1) / (K.segments - 1)) ^ K.taperPower))
        local fixture = love.physics.newFixture(body, love.physics.newCircleShape(r), 1)
        fixture:setFriction(0.15)
        fixture:setGroupIndex(group)
        body:setLinearDamping(0.3)
        body:setAngularDamping(3)
        w.bodies[i] = body
    end
    for i = 1, K.segments - 1 do
        local a, b = w.bodies[i], w.bodies[i + 1]
        local ax, ay = a:getPosition()
        local bx, by = b:getPosition()
        local joint = love.physics.newDistanceJoint(a, b, ax, ay, bx, by, false)
        joint:setFrequency(7 * root)
        joint:setDampingRatio(0.6)
        w.links[i] = joint
        if i < K.segments - 1 then -- a softer one over two links keeps the worm from folding up
            local c = w.bodies[i + 2]
            local cx, cy = c:getPosition()
            local spine = love.physics.newDistanceJoint(a, c, ax, ay, cx, cy, false)
            spine:setFrequency(1.6 * root)
            spine:setDampingRatio(0.3)
            w.spines[i] = spine
        end
    end
    return w
end

local function wormAlive(w)
    for _, body in ipairs(w.bodies) do if body:isDestroyed() then return false end end
    return true
end

local function destroyWorm(w)
    for _, body in ipairs(w.bodies) do
        if not body:isDestroyed() then body:destroy() end
    end
end

-- where the head points: from the third segment to the first
local function wormHeading(w)
    local hx, hy = w.bodies[1]:getPosition()
    local tx, ty = w.bodies[3]:getPosition()
    local dx, dy = hx - tx, hy - ty
    local l = len(dx, dy)
    if l < 1e-3 then return w.dir, 0 end
    return dx / l, dy / l
end

local function wormHeld(w)
    for _, body in ipairs(w.bodies) do
        if getPJAttachedTo(body) then return true end
    end
    return false
end

local function updateWorm(g, w, dt, px, py)
    local _, root = factors()
    local gy = gravityY()
    local hx, hy = wormHeading(w)
    local headX, headY = w.bodies[1]:getPosition()
    local held = wormHeld(w)
    local set = g.settings
    local K = w.kind or WORM
    for _, joint in ipairs(w.links) do joint:setFrequency(set.wormStiff * root) end
    for _, spine in ipairs(w.spines) do spine:setFrequency(set.wormSpine * root) end

    w.stateTime = w.stateTime - dt
    local near = px and len(px - headX, py - headY) < 500
    if held then
        w.state = 'held'
    elseif w.state == 'held' then
        w.state, w.stateTime = 'crawl', 3
    elseif near and w.state == 'crawl' then
        w.state, w.stateTime = 'look', 1.5
    elseif w.stateTime <= 0 then
        if w.state == 'turn' or w.state == 'look' then
            w.state, w.stateTime = 'crawl', 3 + love.math.random() * 5
        elseif w.state == 'crawl' then
            local edge = math.abs(headX) > HALF_W - 500 and (headX > 0) == (hx > 0)
            if edge or love.math.random() < 0.3 then
                w.state, w.stateTime = 'turn', 1.6
                w.turnTo = hx > 0 and -1 or 1
            else
                w.state, w.stateTime = 'rest', 0.8 + love.math.random()
            end
        elseif w.state == 'rest' then
            w.state, w.stateTime = 'crawl', 3 + love.math.random() * 5
        end
    end
    if w.state == 'look' and near then w.stateTime = math.max(w.stateTime, 0.5) end

    -- the squeeze wave: crawling and wriggling when held; resting, the links ease back to their length
    local moving = w.state == 'crawl' or w.state == 'held'
    if moving then
        w.phase = w.phase + dt * set.wormWaveHz * K.waveMul * (w.state == 'held' and 2.5 or 1) * math.pi * 2
    end
    for i, joint in ipairs(w.links) do
        local wave = moving and math.sin(w.phase - i * 0.9) or 0
        joint:setLength(K.gap * (1 + set.wormStretch * wave))
    end
    for i, spine in ipairs(w.spines) do
        local wave = moving and math.sin(w.phase - i * 0.9 - 0.45) or 0
        spine:setLength(2 * K.gap * (1 + set.wormStretch * wave))
    end

    -- grip: a segment touching something slides forward easily, not back
    if w.state == 'crawl' then
        for _, body in ipairs(w.bodies) do
            if touching(body) then
                local vx, vy = body:getLinearVelocity()
                local along = vx * hx + vy * hy
                if along < 0 then
                    local f = -along * body:getMass() * set.wormGrip * root
                    body:applyForce(hx * f, hy * f)
                end
            end
        end
    end

    local head = w.bodies[1]
    local m = 0 -- the front that rears: a worm's head and neck, a snake's first few
    for i = 1, K.rearSegments do m = m + w.bodies[i]:getMass() end
    if w.state == 'look' and px then -- rear up, the head leaning towards you
        local lean = clamp((px - headX) / 400, -1, 1)
        head:applyForce(lean * 0.5 * gy * head:getMass(), -set.wormRear * K.rearMul * gy * m)
    elseif w.state == 'turn' and w.stateTime > 0.7 then -- rear up and over, to the other side
        head:applyForce(w.turnTo * 0.9 * gy * m, -(set.wormRear * K.rearMul + 0.05) * gy * m)
    elseif w.state == 'held' then -- wriggle: push the segments sideways in a wave
        for i, body in ipairs(w.bodies) do
            local f = math.sin(w.phase * 1.3 - i * 0.8) * 0.6 * gy * body:getMass()
            local nx, ny = -hy, hx
            body:applyForce(nx * f, ny * f)
        end
    end

    -- a snake's tongue: out and in now and then, more often while it looks at you
    if K.tongue then
        w.tongueWait = (w.tongueWait or 1) - dt
        if w.tongueWait <= 0 then
            w.tongueOut = 0.35
            w.tongueWait = (w.state == 'look' and 0.6 or 2) + love.math.random() * 2
        end
        w.tongueOut = math.max(0, (w.tongueOut or 0) - dt)
    end

    -- the eyes: at you when you're about, else where it's going
    local lookX, lookY = hx, hy
    if px then lookX, lookY = px - headX, py - headY end
    updateEyes(w.eyes, dt, lookX, lookY)
end

local drawWormTube -- below

-- The worm's skin: Mipo leg-05 (the ladder one, its rungs make the rings) baked as an OMP, pink with
-- dark ink, laid along the chain as a strip. Baked once in update (a bake draws to canvases).
local WORM_SKIN = 'textures/mipo/leg/leg-05'
local wormImage
local function bakeWormSkin()
    if wormImage then return end
    local blank = love.image.newImageData(1, 1)
    local imageData = ompBake.makeTexturedCanvas(
        love.graphics.newImage(WORM_SKIN .. '.png'), love.graphics.newImage(WORM_SKIN .. '-mask.png'),
        WORM.color, 1, love.graphics.newImage(blank), WORM.ink, 0, 0, 1, 1, 0, 0, WORM.ink, 1, 1, 1)
    wormImage = love.graphics.newImage(imageData)
    wormImage:setWrap('clamp', 'clamp')
    imageData:release()
end

-- a smooth line through the segments (Catmull-Rom, `sub` points per link), the ends pushed out by
-- their radius so the picture's rounded ends sit at the tip of the head and the tail
local function wormSpine(pts, sub)
    local n = #pts
    local ext = {}
    local function out(a, b, r) -- a pushed away from b by r
        local dx, dy = a.x - b.x, a.y - b.y
        local l = len(dx, dy)
        if l < 1e-3 then return { x = a.x, y = a.y, r = a.r } end
        return { x = a.x + dx / l * r, y = a.y + dy / l * r, r = a.r }
    end
    ext[1] = out(pts[1], pts[2], pts[1].r)
    for i = 1, n do ext[i + 1] = pts[i] end
    ext[n + 2] = out(pts[n], pts[n - 1], pts[n].r)
    local line = {}
    for i = 1, #ext - 1 do
        local p0, p1, p2, p3 = ext[math.max(1, i - 1)], ext[i], ext[i + 1], ext[math.min(#ext, i + 2)]
        for k = 0, sub - 1 do
            local t = k / sub
            local t2, t3 = t * t, t * t * t
            local function cr(a, b, c, d)
                return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
            end
            line[#line + 1] = { x = cr(p0.x, p1.x, p2.x, p3.x), y = cr(p0.y, p1.y, p2.y, p3.y),
                r = p1.r + (p2.r - p1.r) * t }
        end
    end
    line[#line + 1] = ext[#ext]
    return line
end

-- a baked picture laid along a line of points ({ x, y, r }), r * widthScale wide each side
local function drawSkinStrip(image, pts, widthScale)
    local line = wormSpine(pts, 4)
    local total, cum = 0, { 0 }
    for i = 2, #line do
        total = total + len(line[i].x - line[i - 1].x, line[i].y - line[i - 1].y)
        cum[i] = total
    end
    local verts = {}
    for i, p in ipairs(line) do
        local a, b = line[math.max(1, i - 1)], line[math.min(#line, i + 1)]
        local dx, dy = b.x - a.x, b.y - a.y
        local l = len(dx, dy)
        local nx, ny = 0, 1
        if l > 1e-4 then nx, ny = -dy / l, dx / l end
        local half = p.r * widthScale
        local v = total > 0 and cum[i] / total or 0
        verts[#verts + 1] = { p.x + nx * half, p.y + ny * half, 0, v }
        verts[#verts + 1] = { p.x - nx * half, p.y - ny * half, 1, v }
    end
    local mesh = love.graphics.newMesh(verts, 'strip', 'stream')
    mesh:setTexture(image)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mesh)
    mesh:release()
end

-- image: the skin to lay along it (the worm's leg-05, a snake's rope); nil: the drawn tube
local function drawWorm(w, image)
    local pts = {}
    for i, body in ipairs(w.bodies) do
        local x, y = body:getPosition()
        local r = body:getFixtures()[1]:getShape():getRadius()
        pts[i] = { x = x, y = y, r = r }
    end
    if image then
        drawSkinStrip(image, pts, garden().settings.wormWidth)
    else
        drawWormTube(pts)
    end
    local K = w.kind or WORM

    -- the eyes: on the head, on its upper side
    local hx, hy = wormHeading(w)
    local ux, uy = -hy, hx
    if uy > 0 then ux, uy = -ux, -uy end
    local h = pts[1]
    local r = h.r
    drawEyes(w.eyes,
        h.x + hx * r * 0.45 + ux * r * 0.3, h.y + hy * r * 0.45 + uy * r * 0.3,
        h.x - hx * r * 0.1 + ux * r * 0.38, h.y - hy * r * 0.1 + uy * r * 0.38,
        r * (K.tongue and 0.26 or 0.21), r * 0.12, false, K.tongue and pupilImage(1) or nil)

    -- a snake's forked tongue, out from the tip of the head
    if K.tongue and (w.tongueOut or 0) > 0 then
        local out = math.sin(w.tongueOut / 0.35 * math.pi) * r * 1.6
        local bx, by = h.x + hx * r * 1.1, h.y + hy * r * 1.1
        local tx, ty = bx + hx * out, by + hy * out
        local wiggle = math.sin(garden().time * 40) * 0.25
        love.graphics.setColor(0.75, 0.15, 0.2)
        love.graphics.setLineWidth(3)
        love.graphics.line(bx, by, tx, ty)
        for _, side in ipairs({ -1, 1 }) do
            local a = math.atan2(hy, hx) + side * 0.45 + wiggle
            love.graphics.line(tx, ty, tx + math.cos(a) * r * 0.45, ty + math.sin(a) * r * 0.45)
        end
    end
end

-- the first look, drawn in code: a pink tube with a saddle and ring strokes (until the skin is baked)
drawWormTube = function(pts)
    local function tube(extra, color)
        love.graphics.setColor(color)
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            love.graphics.setLineWidth((a.r + b.r) + extra * 2)
            love.graphics.line(a.x, a.y, b.x, b.y)
        end
        for _, p in ipairs(pts) do love.graphics.circle('fill', p.x, p.y, p.r + extra) end
    end
    local lw = love.graphics.getLineWidth()
    tube(3.5, WORM.ink)
    tube(0, WORM.color)
    -- the saddle (clitellum), a few segments behind the head
    love.graphics.setColor(WORM.band)
    for i = 3, 4 do love.graphics.circle('fill', pts[i].x, pts[i].y, pts[i].r * 0.98) end
    -- the rings: short strokes across the body between segments
    love.graphics.setLineWidth(2)
    love.graphics.setColor(WORM.ink[1], WORM.ink[2], WORM.ink[3], 0.35)
    for i = 2, #pts - 1 do
        local a, b = pts[i - 1], pts[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local l = len(dx, dy)
        if l > 0 then
            local nx, ny = -dy / l * pts[i].r * 0.75, dx / l * pts[i].r * 0.75
            love.graphics.line(pts[i].x + nx, pts[i].y + ny, pts[i].x - nx, pts[i].y - ny)
        end
    end
    love.graphics.setLineWidth(lw)
end

---------------------------------------------------------------- the bee

local BEE = {
    radius = 42,
    yellow = 'F2C641FF', stripes = '2A1E16FF', ink = '2A1E16FF',
}

local function skinBee(bee, g)
    local body = bee.body
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if ud and ud.subtype == 'texfixture' then fixture:destroy() end
    end
    local skin = BEE_SKINS[g.beeSkin] or BEE_SKINS[1]
    local entry = shape8Dict[skin.url]
    local iw, ih = 189, 198
    if entry and entry.dimensions then iw, ih = entry.dimensions[1], entry.dimensions[2] end
    local w = BEE.radius * 2.35
    local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', { width = w, height = w * ih / iw })
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.zOffset = 0
    ud.extra.main = {
        bgURL = skin.url, bgHex = BEE.ink,
        fgURL = skin.url:gsub('%.png', '-mask.png'), fgHex = BEE.yellow,
        pURL = 'bee-stripes.png', pHex = BEE.stripes,
        pr = 0, psx = 1, psy = 1, -- OMP patterns don't repeat: turned or scaled up they clamp
    }
    bee.fuzz = skin.fuzz
end

local function makeBee(x, y, g)
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = BEE.radius,
        label = 'garden-bee', bodyType = 'dynamic', density = 0.5 })
    if not thing then return end
    local body = thing.body
    body:setGravityScale(0)
    body:setFixedRotation(true)
    body:setLinearDamping(0.8)
    for _, fixture in ipairs(body:getFixtures()) do
        fixture:setRestitution(0.4)
        fixture:setFriction(0.3)
    end
    local bee = { body = body, eyes = newEyes(), face = 1, flower = love.math.random(1, #FLOWERS),
        dwell = 0, daze = 0, lastSpeed = 0, wing = 0 }
    skinBee(bee, g)
    return bee
end

local function beeAlive(bee) return bee.body and not bee.body:isDestroyed() end

local function flowerHead(f) return f.x, GROUND_Y - f.h end

local function updateBee(g, bee, dt, px, py)
    local _, root = factors()
    local body = bee.body
    local x, y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local speed = len(vx, vy)
    local held = getPJAttachedTo(body) ~= nil
    local set = g.settings
    bee.attitude, bee.ax, bee.prevVx = bee.attitude or 0, bee.ax or 0, bee.prevVx or vx
    bee.thrown, bee.recover = bee.thrown or 0, bee.recover or 1

    -- let go: it flies off on its own (more drag, capped speed), then catches itself: the steering
    -- comes back in over recoverTime
    if bee.wasHeld and not held and speed > 150 * root then
        local keep = set.throwBoost
        if speed * keep > set.throwMax * root then keep = set.throwMax * root / speed end
        vx, vy, speed = vx * keep, vy * keep, speed * keep
        body:setLinearVelocity(vx, vy)
        bee.lastSpeed = speed -- the cap isn't a hit
        bee.thrown = set.throwCoast
        bee.recover = 0
    elseif bee.wasHeld and not held then
        bee.recover = 0
        bee.lastSpeed = speed
    end
    bee.wasHeld = held

    -- dazed: speed lost all at once (it hit something)
    if not held and bee.lastSpeed - speed > set.beeDaze * root then
        bee.daze = 1.6
        bee.thrown = 0
    end
    bee.lastSpeed = speed

    if held then
        bee.thrown, bee.recover = 0, 1
    elseif bee.daze > 0 then
        bee.daze = bee.daze - dt
        bee.recover = 0
    elseif bee.thrown > 0 then
        bee.thrown = bee.thrown - dt
        if speed < 120 * root then bee.thrown = 0 end
    else
        bee.recover = math.min(1, bee.recover + dt / set.recoverTime)
    end
    local flying = bee.thrown > 0
    body:setGravityScale(bee.daze > 0 and 1 or (flying and set.throwGravity or 0))
    body:setLinearDamping(flying and set.throwDrag or 0.8)

    -- where to: the pointer when it's near, else a flower (hovering above it a while)
    local tx, ty
    local fx, fy = flowerHead(FLOWERS[bee.flower])
    if px and len(px - x, py - y) < set.beeCurious then
        local side = x < px and -1 or 1
        tx, ty = px + side * 160, py - 60
    else
        tx, ty = fx, fy - 90
        if len(tx - x, ty - y) < 80 then
            bee.dwell = bee.dwell + dt
            if bee.dwell > 2.5 + love.math.random() * 3 then
                bee.dwell = 0
                local next = love.math.random(1, #FLOWERS - 1)
                bee.flower = next >= bee.flower and next + 1 or next
            end
        end
    end

    if not held and bee.daze <= 0 and not flying then
        local ease = bee.recover * bee.recover * (3 - 2 * bee.recover)
        local dx, dy = tx - x, ty - y
        local dist = len(dx, dy)
        local want = math.min(set.beeSpeed * root, dist * 2.2 * root)
        local wx, wy = 0, 0
        if dist > 1 then wx, wy = dx / dist * want, dy / dist * want end
        -- a bee's bob and wander
        wy = wy + math.sin(g.time * 5 + x * 0.01) * set.beeBob * root
        wx = wx + math.sin(g.time * 1.7 + y * 0.013) * set.beeWander * root
        local m = body:getMass()
        local k = set.beeSteer * root * m * ease
        body:applyForce((wx - vx) * k, (wy - vy) * k)
    end

    -- facing: the way it flies, or towards what it's looking at when slow
    local faceTo = vx
    if math.abs(vx) < 40 * root then faceTo = tx - x end
    if math.abs(faceTo) > 1 then
        local f = faceTo > 0 and 1 or -1
        bee.face = bee.face + (f - bee.face) * (1 - math.exp(-dt * 8))
    end

    -- the body's attitude: the nose follows its path (dipping into a dive, up on a climb), leans
    -- forward speeding up and sits back braking; hovering it rights itself with a slight wobble
    local f = bee.face >= 0 and 1 or -1
    local fast = clamp(speed / (set.beeSpeed * root), 0, 1)
    local pitch = clamp(math.atan2(vy, math.abs(vx)), -1.2, 1.2) * fast * set.flyPitch
    if dt > 0 then bee.ax = bee.ax + ((vx - bee.prevVx) / dt - bee.ax) * (1 - math.exp(-dt * 6)) end
    bee.prevVx = vx
    local lean = clamp(bee.ax * f / (set.beeSpeed * root * 3), -1, 1) * set.flyLean
    local wobble = math.sin(g.time * 2.3) * 0.04 * (1 - fast)
    local target = f * (pitch + lean) + wobble
    bee.attitude = bee.attitude + (target - bee.attitude) * (1 - math.exp(-dt * set.flyTurn))
    body:setAngle(bee.attitude) -- the OMP skin turns with it (fixed rotation: physics doesn't turn it)
    local frantic = (held or flying) and 1.6 or (1 + (1 - bee.recover) * 0.8)
    bee.wing = bee.wing + dt * frantic * set.wingSpeed

    local lookX, lookY = tx - x, ty - y
    if px then lookX, lookY = px - x, py - y end
    updateEyes(bee.eyes, dt, lookX, lookY)
end

local fuzzImage

-- The wings: Mipo pieces drawn see-through (the mask pale blue, the outline in ink), hinged at the
-- picture's bottom middle (where an ear sits on a head), leaning back, flapping by foreshortening.
local WINGS = { 'textures/mipo/ear/ear-06', 'textures/mipo/ear/ear-05', 'textures/mipo/ear/ear-04',
    'textures/mipo/eye/eye-02' }
local wingImages = {} -- url -> the baked wing (a Mipo mask keeps its shape in red, not alpha: bake it)
local function bakeWings()
    local blank = love.graphics.newImage(love.image.newImageData(1, 1))
    for _, url in ipairs(WINGS) do
        if not wingImages[url] then
            local imageData = ompBake.makeTexturedCanvas(
                love.graphics.newImage(url .. '.png'), love.graphics.newImage(url .. '-mask.png'),
                { 0.86, 0.94, 1 }, 0.6, blank, { 0, 0, 0 }, 0, 0, 1, 1, 0, 0, { 0.16, 0.12, 0.09 }, 1, 1, 1)
            wingImages[url] = love.graphics.newImage(imageData)
            imageData:release()
        end
    end
end

-- one wing, in the bee's own space (facing +x): base at (bx, by), lean (radians back from upright)
local function drawWing(g, bx, by, lean, flap, alpha)
    local image = wingImages[WINGS[g.wingKind] or WINGS[1]]
    if not image then return end
    local iw, ih = image:getDimensions()
    local set = g.settings
    local sc = BEE.radius * set.wingSize / ih
    love.graphics.push()
    love.graphics.translate(bx, by)
    love.graphics.rotate(-lean)
    love.graphics.scale(sc, sc * flap)
    love.graphics.setColor(1, 1, 1, set.wingAlpha * alpha)
    love.graphics.draw(image, 0, 0, 0, 1, 1, iw / 2, ih)
    love.graphics.pop()
end

local function wingFlap(bee, offset)
    return 0.3 + 0.7 * math.abs(math.sin(bee.wing + offset))
end

local function drawBeeBehind(bee, g) -- the fuzz and the far wing, behind the body
    local x, y = bee.body:getPosition()
    local r = BEE.radius
    love.graphics.push()
    love.graphics.translate(x, y)
    if bee.fuzz then -- a hairy fringe sticking out around the outline
        fuzzImage = fuzzImage or love.graphics.newImage('textures/mipo/chesthair/chesthair-01.png')
        local iw = fuzzImage:getWidth()
        local sc = r * g.settings.fuzzSize / iw
        love.graphics.setColor(0.3, 0.21, 0.12, 0.8)
        love.graphics.draw(fuzzImage, 0, 0, g.time * 0.05 + (bee.attitude or 0), sc, sc, iw / 2,
            fuzzImage:getHeight() / 2)
    end
    love.graphics.rotate(bee.attitude or 0)
    love.graphics.scale(bee.face, 1)
    drawWing(g, -r * 0.3, -r * 0.6, g.settings.wingLean + 0.35, wingFlap(bee, 0), 0.8)
    love.graphics.pop()
end

local function drawBee(bee, g)
    local x, y = bee.body:getPosition()
    local r = BEE.radius
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(bee.attitude or 0)
    love.graphics.scale(bee.face, 1)
    -- the near wing, over the body
    drawWing(g, -r * 0.05, -r * 0.65, g.settings.wingLean, wingFlap(bee, 0.4), 1)
    love.graphics.pop()
    -- the eyes, at the front, turned with the body
    local f = bee.face
    local c, sn = math.cos(bee.attitude or 0), math.sin(bee.attitude or 0)
    local function at(lx, ly) return x + lx * c - ly * sn, y + lx * sn + ly * c end
    local e1x, e1y = at(f * r * 0.55, -r * 0.18)
    local e2x, e2y = at(f * r * 0.2, -r * 0.22)
    drawEyes(bee.eyes, e1x, e1y, e2x, e2y, r * 0.16, r * 0.09, bee.daze > 0, pupilImage(g.beePupil))
end

---------------------------------------------------------------- the ladybird
-- One body: a dome (the shell's top) on a short flat block (where the legs reach), so on its back
-- it rocks on the dome. The shell is an OMP: body-16 (the wide oval) red, ladybird-spots.png black.
-- Walking it sticks to whatever is under its feet (a ray down from its middle): pressed onto the
-- surface, turned to stand square on it, driven along it. A surface ahead (a wall, a Mipo's foot)
-- becomes the new floor, so it walks up walls. On its back it kicks and rocks until it flips
-- itself over, or opens its wing cases and flies off. Tap it: it flips over.

local LADY = {
    a = 48, b = 34,     -- the shell's half width and half height
    belly = 0.7,        -- the flat underside, as a fraction of b below the middle
    leg = 16,           -- how far the legs reach below the belly
    outline = 'mipo/body/body-16.png',
    red = 'D9412EFF', ink = '2A1E16FF', spots = '1E1612FF',
}

local function ladyVertices()
    local a, b = LADY.a, LADY.b
    local start = math.pi - math.asin(LADY.belly) -- where the shell meets the belly, left
    local sweep = math.pi + 2 * math.asin(LADY.belly)
    local verts = {}
    for k = 0, 5 do -- over the top, left to right (y is down: the top is at 3pi/2)
        local t = start + sweep * k / 5
        verts[#verts + 1] = a * math.cos(t)
        verts[#verts + 1] = b * math.sin(t)
    end
    local footY = b * LADY.belly + LADY.leg
    verts[#verts + 1] = a * 0.55
    verts[#verts + 1] = footY
    verts[#verts + 1] = -a * 0.55
    verts[#verts + 1] = footY
    return verts
end

local function makeLadybird(x, y)
    local thing = objectManager.addThing('shape8', { x = x, y = y, vertices = ladyVertices(),
        label = 'garden-ladybird', bodyType = 'dynamic' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            fixture:setDensity(1)
            fixture:setFriction(0.4)
            fixture:setRestitution(0.1)
        end
    end
    body:resetMassData()
    body:setAngularDamping(1)
    local iw, ih = 558, 323
    local entry = shape8Dict[LADY.outline]
    if entry and entry.dimensions then iw, ih = entry.dimensions[1], entry.dimensions[2] end
    local w = LADY.a * 2 * 1.12
    local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', { width = w, height = w * ih / iw })
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.zOffset = 0
    ud.extra.main = {
        bgURL = LADY.outline, bgHex = LADY.ink,
        fgURL = LADY.outline:gsub('%.png', '-mask.png'), fgHex = LADY.red,
        pURL = 'ladybird-spots.png', pHex = LADY.spots, pr = 0, psx = 1, psy = 1,
    }
    return { body = body, face = love.math.random() < 0.5 and -1 or 1, state = 'walk', stateTime = 3,
        gait = 0, kick = 0, eyes = newEyes(), wing = 0, struggle = 0 }
end

local function ladyAlive(lb) return lb.body and not lb.body:isDestroyed() end

-- the nearest surface along a ray from (x1, y1) to (x2, y2), not the ladybird itself, not sensors
local function castFrom(own, x1, y1, x2, y2)
    local best
    world:rayCast(x1, y1, x2, y2, function(fixture, hx, hy, nx, ny, fraction)
        if fixture:getBody() == own or fixture:isSensor() then return -1 end
        best = { x = hx, y = hy, nx = nx, ny = ny, f = fraction }
        return fraction
    end)
    return best
end

local function wrapAngle(a) return (a + math.pi) % (math.pi * 2) - math.pi end

-- turn the body towards angle `target` with a spring (rate w0, 1/s), critically damped
local function steerAngle(body, target, w0)
    local err = wrapAngle(target - body:getAngle())
    body:applyTorque(body:getInertia() * (w0 * w0 * err - 2 * w0 * body:getAngularVelocity()))
end

local function updateLadybird(g, lb, dt, px, py)
    local k, root = factors()
    local set = g.settings
    local body = lb.body
    local x, y = body:getPosition()
    local a = body:getAngle()
    local vx, vy = body:getLinearVelocity()
    local m = body:getMass()
    local gy = gravityY()
    local upX, upY = math.sin(a), -math.cos(a)
    local rightX, rightY = math.cos(a), math.sin(a)
    local held = getPJAttachedTo(body) ~= nil

    -- a tap (pressed and let go quickly, hardly moved): it flips over
    if held and not lb.wasHeld then lb.pressedAt, lb.pressX, lb.pressY = g.time, x, y end
    if lb.wasHeld and not held and lb.pressedAt and g.time - lb.pressedAt < 0.25
        and len(x - lb.pressX, y - lb.pressY) < 25 then
        body:applyLinearImpulse(0, -m * 330 * root)
        body:applyAngularImpulse(body:getInertia() * 13 * root * (love.math.random() < 0.5 and -1 or 1))
        lb.state, lb.stateTime = 'tumble', 0.4
    end
    lb.wasHeld = held

    -- what's under its feet, and ahead of it
    local reach = LADY.b * LADY.belly + LADY.leg + 18
    local ground = castFrom(body, x, y, x - upX * reach, y - upY * reach)
    local fx, fy = rightX * lb.face, rightY * lb.face
    local ahead = castFrom(body, x, y, x + fx * (LADY.a + 14), y + fy * (LADY.a + 14))
    local onBack = math.cos(a) < -0.3
    lb.grounded = ground ~= nil

    lb.stateTime = lb.stateTime - dt
    if held then
        lb.state = 'held'
    elseif lb.state == 'held' then
        lb.state, lb.stateTime = 'tumble', 0.3
    end

    if lb.state == 'fly' then
        body:setGravityScale(0)
        local tx, ty = lb.flyX, lb.flyY
        local dx, dy = tx - x, ty - y
        local dist = len(dx, dy)
        local want = math.min(set.ladyFlySpeed * root, dist * 2 * root)
        local wx, wy = 0, 0
        if dist > 1 then wx, wy = dx / dist * want, dy / dist * want end
        wy = wy + math.sin(g.time * 4) * 50 * root
        body:applyForce((wx - vx) * 3 * root * m, (wy - vy) * 3 * root * m)
        if math.abs(vx) > 30 * root then lb.face = vx > 0 and 1 or -1 end
        steerAngle(body, clamp(vx / (set.ladyFlySpeed * root), -1, 1) * 0.35, 8 * root)
        if dist < 70 or lb.stateTime <= 0 then
            lb.state, lb.stateTime = 'tumble', 0.2
            body:setGravityScale(1)
        end
    else
        body:setGravityScale(1)
    end

    if lb.state ~= 'held' and lb.state ~= 'fly' then
        if ground and not onBack and lb.state ~= 'walk' and lb.state ~= 'pause' and lb.stateTime <= 0 then
            lb.state, lb.stateTime = 'walk', 3 + love.math.random() * 5
        elseif onBack and not ground and lb.state ~= 'back' and lb.stateTime <= 0
            and len(vx, vy) < 200 * root and #body:getContacts() > 0 then
            lb.state, lb.struggle = 'back', 1.2 + love.math.random() * 2
        end
    end

    -- walking it drives itself along the surface it's pressed onto: no friction then (pressed on
    -- that hard, friction outpulled the legs); tumbling, on its back or held it has its grip
    local walking = (lb.state == 'walk' or lb.state == 'pause') and ground ~= nil
    if walking ~= lb.slippery then
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:isSensor() then fixture:setFriction(walking and 0 or 0.4) end
        end
        for _, contact in ipairs(body:getContacts()) do -- a contact keeps the friction it began with
            contact:resetFriction()
        end
        lb.slippery = walking
    end

    if (lb.state == 'walk' or lb.state == 'pause') and ground then
        -- the surface it stands on: the one ahead when there's one (a wall becomes the floor)
        local nx, ny = ground.nx, ground.ny
        if ahead and lb.state == 'walk' then nx, ny = ahead.nx, ahead.ny end
        body:applyForce(-nx * m * gy * set.ladyStick, -ny * m * gy * set.ladyStick)
        steerAngle(body, math.atan2(nx, -ny), 10 * root)
        local tx, ty = -ny * lb.face, nx * lb.face -- along the surface, the way it faces
        local along = vx * tx + vy * ty
        local want = lb.state == 'walk' and set.ladySpeed * root or 0
        body:applyForce(tx * m * (want - along) * 6 * root, ty * m * (want - along) * 6 * root)
        lb.gait = lb.gait + math.abs(along) * dt / 9

        if lb.stateTime <= 0 then
            if lb.state == 'pause' then
                lb.state, lb.stateTime = 'walk', 3 + love.math.random() * 5
                if love.math.random() < 0.4 then lb.face = -lb.face end
            elseif love.math.random() < set.ladyFlyChance then
                lb.state, lb.stateTime = 'open', 0.6
            else
                lb.state, lb.stateTime = 'pause', 0.8 + love.math.random() * 1.5
            end
        end
        if math.abs(x) > HALF_W - 150 and (x > 0) == (fx > 0) and math.abs(ny) > 0.7 then
            lb.face = -lb.face -- near a garden wall on the floor: don't just climb out of view
        end
    elseif lb.state == 'walk' or lb.state == 'pause' then
        lb.state, lb.stateTime = 'tumble', 0 -- lost its footing
    end

    if lb.state == 'back' then -- kick and rock, harder and harder, then over it goes (or off it flies)
        lb.struggle = lb.struggle - dt
        lb.kick = lb.kick + dt * 14
        local rock = (5 + 6 * (2 - math.max(0, lb.struggle))) * k
        body:applyTorque(body:getInertia() * rock * math.sin(lb.kick * 0.45))
        if lb.struggle <= 0 then
            if love.math.random() < set.ladyFlyChance * 4 then
                lb.state, lb.stateTime = 'open', 0.5
                body:applyLinearImpulse(0, -m * 200 * root)
            else
                local side = wrapAngle(a) > 0 and 1 or -1
                body:applyLinearImpulse(0, -m * 260 * root)
                body:applyAngularImpulse(body:getInertia() * side * 9 * root)
                lb.state, lb.stateTime = 'tumble', 0.6
            end
        end
    end

    if lb.state == 'open' then -- the wing cases lift, then it flies
        body:setGravityScale(0.3)
        lb.open = math.min(1, (lb.open or 0) + dt * 3)
        if lb.stateTime <= 0 then
            lb.state, lb.stateTime = 'fly', 6
            local side = love.math.random() < 0.5 and -1 or 1
            lb.flyX = clamp(x + side * (600 + love.math.random() * 900), -HALF_W + 300, HALF_W - 300)
            lb.flyY = GROUND_Y - 80
            lb.face = lb.flyX > x and 1 or -1
        end
    elseif lb.state == 'fly' then
        lb.open = 1
    else
        lb.open = math.max(0, (lb.open or 0) - dt * 3)
    end
    lb.wing = lb.wing + dt * set.wingSpeed * 1.4

    local lookX, lookY = fx, fy
    if px then lookX, lookY = px - x, py - y end
    updateEyes(lb.eyes, dt, lookX, lookY)
end

-- in the ladybird's own space (facing +x, belly down): legs, head and feelers, behind the shell
local function drawLadybirdBehind(lb, g)
    local x, y = lb.body:getPosition()
    local a, b = LADY.a, LADY.b
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(lb.body:getAngle())
    love.graphics.scale(lb.face, 1)
    local ink = { 0.16, 0.12, 0.09 }
    -- the flying wings, out from under the wing cases
    if (lb.open or 0) > 0.5 then
        local image = wingImages[WINGS[g.wingKind] or WINGS[1]]
        if image then
            local iw, ih = image:getDimensions()
            local sc = a * 1.6 / ih
            local flap = 0.3 + 0.7 * math.abs(math.sin(lb.wing))
            love.graphics.setColor(1, 1, 1, g.settings.wingAlpha)
            love.graphics.draw(image, -a * 0.1, -b * 0.6, -0.6, sc, sc * flap, iw / 2, ih)
        end
    end
    -- the head, a dark bump at the front, and its feelers
    love.graphics.setColor(ink)
    local hx, hy = a * 0.82, b * 0.25
    love.graphics.circle('fill', hx, hy, b * 0.42)
    love.graphics.setLineWidth(3)
    for k = 0, 1 do
        local sway = math.sin(g.time * 3 + k * 1.7) * 3
        local tipX, tipY = hx + b * (0.75 + 0.15 * k), hy - b * (0.75 - 0.1 * k) + sway
        love.graphics.line(hx + b * 0.1, hy - b * 0.2, tipX, tipY)
        love.graphics.circle('fill', tipX, tipY, 3.5)
    end
    -- three legs (the near side), walking in a ripple; kicking in the air on its back or held
    local footY = b * LADY.belly + LADY.leg
    local busy = lb.state == 'back' or lb.state == 'held' or lb.state == 'fly' or lb.state == 'open'
    love.graphics.setLineWidth(4)
    for i = -1, 1 do
        local hipX, hipY = i * a * 0.42, b * LADY.belly - 2
        local phase = lb.gait + i * 2.1
        local fx, fy
        if busy then
            local kick = (lb.state == 'back' or lb.state == 'held') and lb.kick * 1.6 or g.time * 4
            fx = hipX + math.sin(kick + i * 1.3) * 9
            fy = hipY + LADY.leg * (0.5 + 0.4 * math.cos(kick * 1.3 + i))
        else
            fx = hipX + math.sin(phase) * 8 + 4
            fy = footY - math.max(0, math.cos(phase)) * 6
        end
        local kneeX, kneeY = (hipX + fx) / 2 + 6, (hipY + fy) / 2 - 3
        love.graphics.line(hipX, hipY, kneeX, kneeY, fx, fy)
    end
    love.graphics.pop()
end

local function drawLadybird(lb, g)
    local x, y = lb.body:getPosition()
    local ang = lb.body:getAngle()
    local a, b = LADY.a, LADY.b
    -- the wing cases lifting: the shell's back half, tipped up over the body
    if (lb.open or 0) > 0 then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(ang)
        love.graphics.scale(lb.face, 1)
        love.graphics.translate(-a * 0.05, -b * 0.55)
        love.graphics.rotate(-0.9 * lb.open)
        love.graphics.setColor(0.85, 0.25, 0.18)
        love.graphics.arc('fill', 'pie', -a * 0.45, 0, a * 0.55, math.pi, math.pi * 2)
        love.graphics.setColor(0.16, 0.12, 0.09)
        love.graphics.setLineWidth(3)
        love.graphics.arc('line', 'open', -a * 0.45, 0, a * 0.55, math.pi, math.pi * 2)
        love.graphics.circle('fill', -a * 0.55, -a * 0.25, 6)
        love.graphics.pop()
    end
    -- the eyes on the front of the shell, turned with it
    local c, sn = math.cos(ang), math.sin(ang)
    local function at(lx, ly) lx = lx * lb.face; return x + lx * c - ly * sn, y + lx * sn + ly * c end
    local e1x, e1y = at(a * 0.55, -b * 0.15)
    local e2x, e2y = at(a * 0.3, -b * 0.22)
    drawEyes(lb.eyes, e1x, e1y, e2x, e2y, b * 0.2, b * 0.1, lb.state == 'back', pupilImage(g.ladyPupil or 1))
end

---------------------------------------------------------------- the spider
-- A round body about a Mipo head big, with six real legs (three a side): each a thigh and a shin
-- (thin bodies)
-- on hinges, knees that only fold one way, the legs not colliding with each other or the body.
-- Standing, a spring holds the body at its height and each foot is pulled to its own spot on the
-- ground; walking, the legs take turns in two tripods, as insects walk (a foot steps when the body has gone on
-- past it). Picked up (by the body or a leg) it's loose: the legs dangle and flail. Like a real
-- spider it freezes when the pointer comes close, then scuttles off in a quick burst.

local SPIDER = {
    radius = 80,
    color = '6E5F78FF', ink = '1E1820FF',
    legWidth = 10,
    legsPerSide = 3,
}

-- leg j (0 = nearest the middle .. legsPerSide - 1 = outermost), side (-1 left, 1 right): where it
-- sits on the body and its rest pose (the thigh out and up, the shin out and down)
local function legPose(side, j)
    local R = SPIDER.radius
    local t = SPIDER.legsPerSide > 1 and j / (SPIDER.legsPerSide - 1) or 0 -- 0 inner .. 1 outer
    return {
        hipX = side * R * (0.15 + 0.3 * t), hipY = R * 0.4,
        thigh = 115 + 40 * t, thighAngle = math.rad(55 - 25 * t),
        shin = 170, shinAngle = math.rad(75 - 12 * t),
    }
end

-- the body's height above the ground standing: where the rest pose puts the feet (on average)
local function spiderStandHeight()
    local sum = 0
    for j = 0, SPIDER.legsPerSide - 1 do
        local p = legPose(1, j)
        sum = sum + p.hipY - p.thigh * math.sin(p.thighAngle) + p.shin * math.sin(p.shinAngle)
    end
    return sum / SPIDER.legsPerSide
end

-- a thin segment body from (x1, y1) to (x2, y2): its local +y runs along it
local function segmentBody(x1, y1, x2, y2, group)
    local dx, dy = x2 - x1, y2 - y1
    local L = len(dx, dy)
    local body = love.physics.newBody(world, (x1 + x2) / 2, (y1 + y2) / 2, 'dynamic')
    body:setAngle(math.atan2(dy, dx) - math.pi / 2)
    local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(SPIDER.legWidth, L), 0.4)
    fixture:setGroupIndex(group)
    fixture:setFriction(0.9)
    body:setAngularDamping(2)
    return body, L
end

local function makeSpider(x, groundY)
    local R = SPIDER.radius
    local y = groundY - spiderStandHeight()
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = R,
        label = 'garden-spider', bodyType = 'dynamic', density = 0.6 })
    if not thing then return end
    local body = thing.body
    local group = -31000 - love.math.random(1, 999)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then fixture:setGroupIndex(group) end
    end
    body:setAngularDamping(3)
    local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
        { width = R * 2.3, height = R * 2.3 * 198 / 189 })
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.zOffset = 0
    ud.extra.main = {
        bgURL = 'mipo/patch/patch-01.png', bgHex = SPIDER.ink,
        fgURL = 'mipo/patch/patch-01-mask.png', fgHex = SPIDER.color,
        pURL = 'type7.png', pHex = '4A3E5470', -- a faint crayon scribble over the grey-purple
    }

    local sp = { body = body, legs = {}, group = group, face = 1, state = 'still', stateTime = 1.5,
        eyes = newEyes(), flail = 0 }
    for _, side in ipairs({ -1, 1 }) do
        for j = 0, SPIDER.legsPerSide - 1 do
            local p = legPose(side, j)
            local hx, hy = x + p.hipX, y + p.hipY
            local kx = hx + side * p.thigh * math.cos(p.thighAngle)
            local ky = hy - p.thigh * math.sin(p.thighAngle)
            local tx = kx + side * p.shin * math.cos(p.shinAngle)
            local ty = ky + p.shin * math.sin(p.shinAngle)
            local thigh = segmentBody(hx, hy, kx, ky, group)
            local shin = segmentBody(kx, ky, tx, ty, group)
            local hip = love.physics.newRevoluteJoint(body, thigh, hx, hy, false)
            hip:setLimitsEnabled(true)
            hip:setLimits(-0.9, 0.9)
            local knee = love.physics.newRevoluteJoint(thigh, shin, kx, ky, false)
            knee:setLimitsEnabled(true)
            -- the knee folds one way only: the shin can swing in under the thigh, not up past it
            if side > 0 then knee:setLimits(-0.4, 1.1) else knee:setLimits(-1.1, 0.4) end
            sp.legs[#sp.legs + 1] = {
                s = side, j = j, pose = p, thigh = thigh, shin = shin,
                homeX = tx - x, -- where its foot stands, from the body's middle
                footX = tx, footY = ty, fromX = tx, fromY = ty, toX = tx, toY = ty, step = 1,
                -- two groups take turns, crosswise: with three a side, two tripods
                group = ((j % 2 == 0) == (side < 0)) and 1 or 2,
            }
        end
    end
    return sp
end

local function spiderAlive(sp)
    if not (sp.body and not sp.body:isDestroyed()) then return false end
    for _, leg in ipairs(sp.legs) do
        if leg.thigh:isDestroyed() or leg.shin:isDestroyed() then return false end
    end
    return true
end

local function destroySpider(sp)
    for _, leg in ipairs(sp.legs or {}) do
        if not leg.shin:isDestroyed() then leg.shin:destroy() end
        if not leg.thigh:isDestroyed() then leg.thigh:destroy() end
    end
    if sp.body and not sp.body:isDestroyed() then objectManager.destroyBody(sp.body) end
end

local function spiderHeld(sp)
    if getPJAttachedTo(sp.body) then return true end
    for _, leg in ipairs(sp.legs) do
        if getPJAttachedTo(leg.thigh) or getPJAttachedTo(leg.shin) then return true end
    end
    return false
end

-- the ground under x (from height y), nil when there's none near
local function groundBelow(sp, x, y, depth)
    local best
    world:rayCast(x, y, x, y + depth, function(fixture, _, hy, _, _, fraction)
        if fixture:isSensor() or fixture:getGroupIndex() == sp.group then return -1 end
        best = hy
        return fraction
    end)
    return best
end

local function updateSpider(g, sp, dt, px, py)
    local _, root = factors()
    local set = g.settings
    local body = sp.body
    local x, y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local gy = gravityY()
    local held = spiderHeld(sp)
    local stand = spiderStandHeight() * set.spiderHeight
    local floorY = groundBelow(sp, x, y, stand * 1.8)
    local upright = math.cos(body:getAngle()) > 0.4
    local standing = not held and floorY and upright

    -- what it wants: freeze when the pointer comes close, then a quick scuttle away; else now and
    -- then a scuttle somewhere, between long stills
    sp.stateTime = sp.stateTime - dt
    local near = px and len(px - x, py - y) < 450
    if near and sp.state ~= 'freeze' and sp.state ~= 'flee' then
        sp.state, sp.stateTime = 'freeze', 0.5 + love.math.random() * 0.6
    elseif sp.stateTime <= 0 then
        if sp.state == 'freeze' then
            sp.state, sp.stateTime = 'flee', 0.7 + love.math.random() * 0.5
            sp.face = (px and px > x) and -1 or 1
        elseif sp.state == 'still' then
            sp.state, sp.stateTime = 'scuttle', 0.6 + love.math.random()
            if love.math.random() < 0.5 then sp.face = -sp.face end
        else
            sp.state, sp.stateTime = 'still', 1 + love.math.random() * 2.5
        end
    end
    if math.abs(x) > HALF_W - 450 and (x > 0) == (sp.face > 0) then sp.face = -sp.face end
    local moving = sp.state == 'scuttle' or sp.state == 'flee'
    local want = moving and set.spiderSpeed * root * (sp.state == 'flee' and 1.4 or 1) * sp.face or 0

    local legMass = 0
    for _, leg in ipairs(sp.legs) do legMass = legMass + leg.thigh:getMass() + leg.shin:getMass() end
    local m = body:getMass()

    if standing then
        -- the body: held at its height (carrying the legs' weight too), upright, moving as it wants
        local w0 = 9 * root
        local err = (floorY - stand) - y
        local carried = m + legMass * 0.5
        local lift = -carried * gy + carried * (w0 * w0 * err - 2 * w0 * vy)
        body:applyForce((want - vx) * m * 6 * root, lift)
        steerAngle(body, 0, 10 * root)
    end

    -- the legs
    local someoneStepping = { false, false }
    for _, leg in ipairs(sp.legs) do
        if leg.step < 1 then someoneStepping[leg.group] = true end
    end
    for _, leg in ipairs(sp.legs) do
        local shinLen = leg.pose.shin
        local tipX, tipY = leg.shin:getWorldPoint(0, shinLen / 2)
        if standing then
            -- where this foot belongs: its home under the body, a little ahead when walking
            local homeX = x + leg.homeX + vx * 0.12
            local homeY = groundBelow(sp, homeX, y, stand * 2.2) or (floorY or y + stand)
            local other = leg.group == 1 and 2 or 1
            if leg.step >= 1 and not someoneStepping[other]
                and math.abs(leg.toX - homeX) > set.spiderStride then
                leg.fromX, leg.fromY = leg.toX, leg.toY
                leg.toX, leg.toY = homeX + (homeX - leg.toX) * 0.4, homeY
                leg.step = 0
                someoneStepping[leg.group] = true
            end
            if leg.step < 1 then
                leg.step = math.min(1, leg.step + dt / set.spiderStep)
                local t = leg.step
                leg.footX = leg.fromX + (leg.toX - leg.fromX) * t
                leg.footY = leg.fromY + (leg.toY - leg.fromY) * t - math.sin(t * math.pi) * 45
            else
                leg.footX, leg.footY = leg.toX, leg.toY
            end
            -- pull the foot to its spot; lift the knee a little so it stays up
            local shinMass = leg.shin:getMass()
            local w0 = set.spiderFootPull * root
            local tvx, tvy = leg.shin:getLinearVelocityFromWorldPoint(tipX, tipY)
            leg.shin:applyForce(shinMass * (w0 * w0 * (leg.footX - tipX) - 2 * w0 * tvx),
                shinMass * (w0 * w0 * (leg.footY - tipY) - 2 * w0 * tvy), tipX, tipY)
            local kx, ky = leg.thigh:getWorldPoint(0, leg.pose.thigh / 2)
            leg.thigh:applyForce(0, -leg.thigh:getMass() * gy * 1.2, kx, ky)
        else
            -- loose: the feet forget their spots (they land wherever) and the legs flail
            leg.toX, leg.toY, leg.footX, leg.footY, leg.step = tipX, tipY, tipX, tipY, 1
            local shinMass = leg.shin:getMass()
            local wave = math.sin(g.time * 13 + leg.j * 1.7 + leg.s)
            leg.shin:applyForce(shinMass * gy * 1.4 * wave * leg.s, shinMass * gy * 0.6 * wave, tipX, tipY)
        end
    end

    -- on its back on something (not held): a twist back over
    if not held and not upright and #body:getContacts() + (floorY and 1 or 0) > 0 then
        body:applyTorque(body:getInertia() * 30 * root * root * (wrapAngle(body:getAngle()) > 0 and -1 or 1))
    end

    local lookX, lookY = sp.face, 0.2
    if px then lookX, lookY = px - x, py - y end
    updateEyes(sp.eyes, dt, lookX, lookY)
end

-- The legs' skin: Mipo leg-01 (the plain crayon stroke) baked dark, laid along hip, knee and foot.
-- Baked once in update (a bake draws to canvases); plain lines until then.
local spiderLegImage
local function bakeSpiderLegs()
    if spiderLegImage then return end
    local url = 'textures/mipo/leg/leg-01'
    local ink = { 0.12, 0.09, 0.12 }
    local blank = love.graphics.newImage(love.image.newImageData(1, 1))
    local imageData = ompBake.makeTexturedCanvas(love.graphics.newImage(url .. '.png'),
        love.graphics.newImage(url .. '-mask.png'), ink, 1, blank, ink, 0, 0, 1, 1, 0, 0, ink, 1, 1, 1)
    spiderLegImage = love.graphics.newImage(imageData)
    spiderLegImage:setWrap('clamp', 'clamp')
    imageData:release()
end

local function drawSpiderLegs(sp, g)
    love.graphics.setColor(0.12, 0.09, 0.12)
    for _, leg in ipairs(sp.legs) do
        local hx, hy = sp.body:getWorldPoint(leg.pose.hipX, leg.pose.hipY)
        local kx, ky = leg.thigh:getWorldPoint(0, leg.pose.thigh / 2)
        local tx, ty = leg.shin:getWorldPoint(0, leg.pose.shin / 2)
        local w = 10
        if spiderLegImage then
            local r = w / 2
            drawSkinStrip(spiderLegImage, { { x = hx, y = hy, r = r }, { x = kx, y = ky, r = r },
                { x = tx, y = ty, r = r * 0.8 } }, g.settings.spiderLegWidth)
        else
            love.graphics.setLineWidth(w)
            love.graphics.line(hx, hy, kx, ky, tx, ty)
        end
    end
end

local function drawSpiderEyes(sp, g)
    local x, y = sp.body:getPosition()
    local R = SPIDER.radius
    local ang = sp.body:getAngle()
    local c, sn = math.cos(ang), math.sin(ang)
    local function at(lx, ly) return x + lx * c - ly * sn, y + lx * sn + ly * c end
    local e1x, e1y = at(sp.face * R * 0.38, -R * 0.12)
    local e2x, e2y = at(sp.face * R * 0.02, -R * 0.15)
    drawEyes(sp.eyes, e1x, e1y, e2x, e2y, R * 0.26, R * 0.1, false, pupilImage(g.spiderPupil or 1))
end

---------------------------------------------------------------- the dog
-- A little Mipo dachshund that follows the Mipo around. Its head is a Mipo head: the garden Mipo's
-- head shape and skin, and the Mipo face itself (mipoTextures.addFaceDecals: eyes, pupils, brows,
-- nose, lips as on a Mipo; the head's thing is labelled 'head' so src/mipo-face.lua blinks it and a
-- tap near it pulls a face). A long oval body in the Mipo's colours, four stumpy legs (one piece
-- each) trotting in diagonal pairs, the Mipo's ears hanging floppy from the top of the head, a
-- short wagging tail (the rope, Mipo leg-01, in the Mipo's arm colours). Physics bodies can't be
-- mirrored and Nikki didn't like the hop that rebuilt it turned round (2026-11-05): the other way
-- it backs up.

local DOG = {
    label = 'garden-dog', behaviour = 'follow',
    length = 440, height = 165, -- the body's oval
    legLength = 95, legWidth = 36, hipY = 0.22,
    tailSegments = 5, tailGap = 16, tailRadius = 9, tailLift = 1.3, tailSway = 2.5,
    torsoURL = 'mipo/body/body-16.png', legURL = 'mipo/leg/leg-02.png',
    headScale = 1, -- ears: the Mipo's own, hanging
    groupBase = -32000, -- its parts' collision groups: -32001 .. -32999 (sweepKind finds them by it)
    version = 7, -- a change that needs the dogs and cats built again: count it up (a reload rebuilds)
}

-- The cat: built the same way, more elegant. The same Mipo head a little smaller, pointy ears
-- standing up, a slimmer body high on long thin legs, a long tail held up in a curve. It doesn't
-- follow: it wanders about on its own and stops now and then.
local CAT = {
    label = 'garden-cat', behaviour = 'wander',
    length = 330, height = 105,
    legLength = 150, legWidth = 24, hipY = 0.25,
    tailSegments = 9, tailGap = 17, tailRadius = 7, tailLift = 2.1, tailSway = 0.9,
    torsoURL = 'mipo/body/body-16.png', legURL = 'mipo/leg/leg-03.png',
    headScale = 0.82, earURL = 'mipo/ear/ear-14.png', earSize = 0.5, -- ear height, x the head's
    groupBase = -33000,
}

-- The tiny giraffe: a short body high on long thin legs, a neck of segments rising up and forward
-- (each joint a muscle), the Mipo head small at the top with two knobbed horns; its own skin,
-- yellow with brown patches (the ladybird's spots). It wanders like the cat.
local GIRAFFE = {
    label = 'garden-giraffe', behaviour = 'wander',
    length = 250, height = 105,
    legLength = 175, legWidth = 22, hipY = 0.25,
    tailSegments = 4, tailGap = 14, tailRadius = 5, tailLift = 0.4, tailSway = 1.2,
    torsoURL = 'mipo/body/body-16.png', legURL = 'mipo/leg/leg-03.png',
    headScale = 0.6, earURL = 'mipo/ear/ear-03.png', earSize = 0.35, horns = true,
    neckSegments = 4, neckLength = 62, neckWidth = 30, neckRise = math.rad(68),
    skin = { bgHex = '2A1E16FF', fgHex = 'EBBE55FF', pHex = '8A5228FF', pURL = 'ladybird-spots.png' },
    groupBase = -35000,
}

-- every body of a kind still in the world, found by its collision group (a dog half rebuilt when
-- something went wrong is in no list; its head is labelled 'head' like a Mipo's, so not by label)
local function sweepKind(K)
    for _, body in ipairs(world:getBodies()) do
        local mine = false
        for _, fixture in ipairs(body:getFixtures()) do
            local gi = fixture:getGroupIndex()
            if gi < K.groupBase and gi > K.groupBase - 1000 then mine = true end
        end
        if mine and not body:isDestroyed() then
            local ud = body:getUserData()
            if ud and ud.thing then objectManager.destroyBody(body) else body:destroy() end
        end
    end
end

local function deepCopy(t) -- (scene scripts have no `type`: a table prints as 'table: ...')
    if tostring(t):sub(1, 6) ~= 'table:' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

-- what the dog borrows from a Mipo: head shape and size, skins, face, ears
local function dogLooks(g)
    local inst = g.mipos and g.mipos[1]
    local dna = inst and inst.dna
    if not dna then return nil end
    local potato = dna.creation and dna.creation.isPotatoHead
    local headPart = potato and dna.parts.torso1 or dna.parts.head
    local torsoPart = dna.parts.torso1
    local earPart = dna.parts.lear
    if not (headPart and headPart.shape8URL and shape8Dict[headPart.shape8URL]) then return nil end
    local function skin(part)
        local main = part and part.appearance and part.appearance.skin and part.appearance.skin.main
        return main and { bgHex = main.bgHex, fgHex = main.fgHex, pHex = main.pHex, pURL = main.pURL }
    end
    return {
        scale = inst.scale or 0.3,
        faceMagnitude = dna.faceMagnitude or 1,
        headURL = headPart.shape8URL,
        headSX = math.abs(headPart.dims.sx or 1), headSY = math.abs(headPart.dims.sy or 1),
        headSkin = skin(headPart), torsoSkin = skin(torsoPart) or skin(headPart),
        face = deepCopy(headPart.appearance and headPart.appearance.face),
        earURL = earPart and earPart.shape8URL, earSX = earPart and math.abs(earPart.dims.sx or 1),
        earSY = earPart and math.abs(earPart.dims.sy or 1), earSkin = skin(earPart),
        armSkin = (function()
            local arm = dna.parts.luarm
            local main = arm and arm.appearance and arm.appearance['connected-skin']
                and arm.appearance['connected-skin'].main
            return main and { bgHex = main.bgHex, fgHex = main.fgHex, pHex = main.pHex, pURL = main.pURL }
        end)(),
    }
end

local function skinOf(body, url, w, h, colours, zOffset)
    local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', { width = w, height = h })
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.zOffset = zOffset or 0
    ud.extra.main = {
        bgURL = url, bgHex = colours.bgHex or '000000ff',
        fgURL = url:gsub('%.png', '-mask.png'), fgHex = colours.fgHex or 'D9A066FF',
        pURL = colours.pURL or '', pHex = colours.pHex or 'ffffff00',
    }
end

local function shapeBody(url, sx, sy, x, y, label, group, density)
    local entry = shape8Dict[url]
    local verts = {}
    for k = 1, #entry.vertices, 2 do
        verts[k], verts[k + 1] = entry.vertices[k] * sx, entry.vertices[k + 1] * sy
    end
    local thing = objectManager.addThing('shape8', { x = x, y = y, vertices = verts, label = label,
        bodyType = 'dynamic' })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:isSensor() then
            fixture:setGroupIndex(group)
            fixture:setDensity(density or 1)
            fixture:setFriction(0.6)
        end
    end
    thing.body:resetMassData()
    return thing.body, entry.dimensions[1] * sx, entry.dimensions[2] * sy
end

-- a dog (or a cat: kind = CAT) built facing `face` (1 right, -1 left) with its body's middle at (cx, cy)
local function makeDog(g, cx, cy, face, kind)
    local K = kind or DOG
    local looks = dogLooks(g)
    if not looks then return end
    if K.skin then -- a kind with its own colours (the giraffe): body, legs, head, ears, tail
        looks.torsoSkin, looks.headSkin, looks.earSkin, looks.armSkin = K.skin, K.skin, K.skin, K.skin
    end
    local group = K.groupBase - love.math.random(1, 999)
    local L, H = K.length, K.height
    local dog = { face = face, parts = {}, legs = {}, tail = {}, ears = {}, looks = looks, kind = K,
        state = 'stand', group = group, wag = love.math.random() * 10 }
    local function keep(body) dog.parts[#dog.parts + 1] = body; return body end

    -- the body: two halves on a waist hinge (with a muscle), each kept level as a Mipo keeps its
    -- parts (the KEEP_ANGLE behaviour, src/keep-angle.lua; it lets go while held), one picture over
    -- both: the oval in the Mipo's body skin, bent at the waist (drawDogBody)
    local function half(x)
        local thing = objectManager.addThing('capsule', { x = x, y = cy, width = L * 0.56, height = H,
            width2 = 2.2, label = K.label, bodyType = 'dynamic', density = 1 })
        for _, fixture in ipairs(thing.body:getFixtures()) do
            if not fixture:isSensor() then
                fixture:setGroupIndex(group)
                fixture:setFriction(0.6)
            end
        end
        thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0 } }
        thing.body:setAngularDamping(4)
        return keep(thing.body)
    end
    dog.front = half(cx + face * L * 0.25)
    dog.back = half(cx - face * L * 0.25)
    dog.torso = dog.front
    local waist = love.physics.newRevoluteJoint(dog.back, dog.front, cx, cy, false)
    waist:setLimitsEnabled(true)
    waist:setLimits(-0.35, 0.35)
    waist:setMotorEnabled(true)
    dog.waist = waist

    -- legs: near and far at the front and the back, hanging from the belly
    for _, spot in ipairs({ { x = 0.3, near = true }, { x = 0.3, near = false },
                            { x = -0.3, near = true }, { x = -0.3, near = false } }) do
        local hipX = cx + face * (spot.x * L + (spot.near and 0 or 14))
        local hipY = cy + H * K.hipY
        local thing = objectManager.addThing('rectangle', { x = hipX, y = hipY + K.legLength / 2,
            width = K.legWidth, height = K.legLength, label = K.label, bodyType = 'dynamic' })
        local leg = keep(thing.body)
        for _, fixture in ipairs(leg:getFixtures()) do
            if not fixture:isSensor() then
                fixture:setGroupIndex(group)
                fixture:setFriction(0.9)
            end
        end
        leg:setAngularDamping(3)
        skinOf(leg, K.legURL, K.legWidth * 1.5, K.legLength * 1.12, looks.torsoSkin or {},
            spot.near and 5 or -5)
        local hip = love.physics.newRevoluteJoint(spot.x > 0 and dog.front or dog.back, leg, hipX, hipY, false)
        hip:setLimitsEnabled(true)
        hip:setLimits(-0.8, 0.8)
        hip:setMotorEnabled(true)
        dog.legs[#dog.legs + 1] = { body = leg, hip = hip, front = spot.x > 0, near = spot.near,
            -- trotting: front-near with back-far, front-far with back-near
            pair = ((spot.x > 0) == spot.near) and 1 or 2 }
    end

    -- the head: the Mipo's, up at the front on a stiff, springy neck
    local sc = looks.scale * K.headScale
    local hEntry = shape8Dict[looks.headURL]
    local headW, headH = hEntry.dimensions[1] * looks.headSX * sc, hEntry.dimensions[2] * looks.headSY * sc
    local neckX, neckY = cx + face * L * 0.4, cy - H * 0.2
    -- a long neck (the giraffe): segments up and forward from the body, the head on the last
    local neckBase = dog.front
    if K.neckSegments then
        dog.neckJoints, dog.neckSegs = {}, {}
        local dx, dy = face * math.cos(K.neckRise), -math.sin(K.neckRise)
        for i = 1, K.neckSegments do
            local x1, y1 = neckX + dx * K.neckLength * (i - 1), neckY + dy * K.neckLength * (i - 1)
            local seg = love.physics.newBody(world, x1 + dx * K.neckLength / 2, y1 + dy * K.neckLength / 2,
                'dynamic')
            seg:setAngle(math.atan2(dy, dx) - math.pi / 2)
            local fixture = love.physics.newFixture(seg,
                love.physics.newRectangleShape(K.neckWidth * (1 - 0.25 * i / K.neckSegments), K.neckLength), 0.5)
            fixture:setGroupIndex(group)
            seg:setAngularDamping(3)
            local joint = love.physics.newRevoluteJoint(neckBase, seg, x1, y1, false)
            joint:setLimitsEnabled(true)
            joint:setLimits(-0.45, 0.45)
            joint:setMotorEnabled(true)
            dog.neckJoints[i], dog.neckSegs[i] = joint, seg
            neckBase = seg
        end
        neckX, neckY = neckX + dx * K.neckLength * K.neckSegments, neckY + dy * K.neckLength * K.neckSegments
    end
    local hx, hy = neckX + face * headW * 0.2, neckY - headH * 0.32
    local head = keep(shapeBody(looks.headURL, looks.headSX * sc, looks.headSY * sc, hx, hy, 'head', group, 0.6))
    skinOf(head, looks.headURL, headW * 1.1, headH * 1.1, looks.headSkin or {}, 20)
    head:setAngularDamping(4)
    dog.head, dog.headW, dog.headH = head, headW, headH
    local neck = love.physics.newRevoluteJoint(neckBase, head, neckX, neckY, false)
    neck:setLimitsEnabled(true)
    neck:setLimits(-0.45, 0.45)
    neck:setMotorEnabled(true)
    dog.neck = neck
    if looks.face then
        mipoTextures.addFaceDecals(head, 'head', { shape8URL = looks.headURL,
            dims = { sx = looks.headSX, sy = looks.headSY } }, looks.face,
            { dna = { creation = { isPotatoHead = false }, faceMagnitude = looks.faceMagnitude } }, sc)
    end

    -- ears: a cat's own pointy ones standing up; else the Mipo's, hanging from the top corners
    if K.earURL and shape8Dict[K.earURL] then
        local eEntry = shape8Dict[K.earURL]
        local earH = headH * K.earSize
        local esc = earH / eEntry.dimensions[2]
        local earW = eEntry.dimensions[1] * esc
        for _, side in ipairs({ -1, 1 }) do
            local ax, ay = hx + side * headW * 0.3, hy - headH * 0.36
            local ear = keep(shapeBody(K.earURL, esc, esc, ax, ay - earH / 2, K.label, group, 0.2))
            skinOf(ear, K.earURL, earW * 1.1, earH * 1.1, looks.earSkin or looks.headSkin or {}, 15)
            ear:setAngle(side * 0.25) -- leaning out a little
            ear:setAngularDamping(2)
            local joint = love.physics.newRevoluteJoint(head, ear, ax, ay, false)
            joint:setLimitsEnabled(true)
            joint:setLimits(-0.3, 0.3)
            joint:setMotorEnabled(true)
            dog.ears[#dog.ears + 1] = { body = ear, joint = joint }
        end
    elseif looks.earURL and shape8Dict[looks.earURL] then
        local eEntry = shape8Dict[looks.earURL]
        local esx, esy = looks.earSX * sc * 0.8, looks.earSY * sc * 0.8
        local earW, earH = eEntry.dimensions[1] * esx, eEntry.dimensions[2] * esy
        for _, side in ipairs({ -1, 1 }) do
            local ax, ay = hx + side * headW * 0.38, hy - headH * 0.3
            local ear = keep(shapeBody(looks.earURL, esx, esy, ax, ay + earH / 2, K.label, group, 0.2))
            ear:setAngle(math.pi) -- the picture's base (its bottom) up at the head: it hangs
            ear:setPosition(ax, ay + earH / 2)
            skinOf(ear, looks.earURL, earW * 1.1, earH * 1.1, looks.earSkin or looks.headSkin or {}, 15)
            ear:setAngularDamping(1)
            local joint = love.physics.newRevoluteJoint(head, ear, ax, ay, false)
            joint:setLimitsEnabled(true)
            joint:setLimits(-0.9, 0.9)
        end
    end

    -- the tail: a short chain up from the back
    local prev = dog.back
    local px0, py0 = cx - face * L * 0.47, cy - H * 0.1
    for i = 1, K.tailSegments do
        local tx, ty = px0 - face * i * K.tailGap * 0.7, py0 - i * K.tailGap * 0.7
        local seg = love.physics.newBody(world, tx, ty, 'dynamic')
        local fixture = love.physics.newFixture(seg, love.physics.newCircleShape(math.max(3, 9 - i)), 0.3)
        fixture:setGroupIndex(group)
        local jx, jy = tx + face * K.tailGap * 0.35, ty + K.tailGap * 0.35
        local joint = love.physics.newRevoluteJoint(prev, seg, jx, jy, false)
        joint:setLimitsEnabled(true)
        joint:setLimits(-0.5, 0.5)
        joint:setMotorEnabled(true)
        dog.tail[i] = seg
        dog.tailJoints = dog.tailJoints or {}
        dog.tailJoints[i] = joint
        prev = seg
    end
    return dog
end

local function dogAlive(dog)
    if not dog or not dog.torso or dog.torso:isDestroyed() or not dog.back then return false end
    for _, body in ipairs(dog.parts) do if body:isDestroyed() then return false end end
    return true
end

local function destroyDog(dog)
    for _, seg in ipairs(dog.tail or {}) do if not seg:isDestroyed() then seg:destroy() end end
    for _, seg in ipairs(dog.neckSegs or {}) do if not seg:isDestroyed() then seg:destroy() end end
    for _, body in ipairs(dog.parts or {}) do
        if not body:isDestroyed() then objectManager.destroyBody(body) end
    end
end

local function dogHeld(dog)
    for _, body in ipairs(dog.parts) do if getPJAttachedTo(body) then return true end end
    for _, seg in ipairs(dog.neckSegs or {}) do if getPJAttachedTo(seg) then return true end end
    for _, seg in ipairs(dog.tail) do if getPJAttachedTo(seg) then return true end end
    return false
end

local function dogStandHeight(K) K = K or DOG; return K.height * K.hipY + K.legLength end

-- where the Mipo is: its torso, nil without a Mipo
local function mipoSpot(g)
    local inst = g.mipos and g.mipos[1]
    local part = inst and inst.parts and inst.parts.torso1
    if part and part.body and not part.body:isDestroyed() then return part.body:getPosition() end
end

-- A joint motor as a muscle: turning the joint towards `target` (radians, as built = 0) at a
-- speed that grows with how far off it is, with at most `torque`. Pushed harder, it gives.
local function muscle(joint, target, rate, torque)
    joint:setMaxMotorTorque(torque)
    joint:setMotorSpeed((target - joint:getJointAngle()) * rate)
end

-- The dog and the cat are physics objects with muscles, nothing more: their legs are held
-- straight by the hip motors (they stand on them like a table), swung in diagonal pairs to walk,
-- the head, a cat's ears and the tail held by their joints' motors. Lifted they hang, dropped
-- they fall, knocked over they lie there. The one push from outside: while a foot is on the
-- ground the body is nudged along the way it walks (as the worm's grip does), gently.
local function updateDog(g, dog, dt)
    local _, root = factors()
    local set = g.settings
    local K = dog.kind or DOG
    local torso = dog.torso
    local x = torso:getPosition()
    local gy = gravityY()
    local held = dogHeld(dog)

    local footDown = false
    for _, leg in ipairs(dog.legs) do
        for _, contact in ipairs(leg.body:getContacts()) do
            if contact:isTouching() then footDown = true end
        end
    end

    -- where it wants to go: a dog after the Mipo (about a dog-length away, on its side), a cat to a
    -- spot it picks now and then. It can't turn round: the other way it backs up, slowly.
    local want = 0
    if K.behaviour == 'wander' then
        dog.wanderTime = (dog.wanderTime or 0) - dt
        if not dog.wanderX or dog.wanderTime <= 0 then
            dog.wanderX = clamp(x + (love.math.random() - 0.5) * 1800, -HALF_W + 400, HALF_W - 400)
            dog.wanderTime = 5 + love.math.random() * 6
        end
        local dx = dog.wanderX - x
        if math.abs(dx) > 40 then want = clamp(dx * 2, -set.catSpeed, set.catSpeed) * root end
    else
        local mx = mipoSpot(g)
        if mx then
            local side = x < mx and -1 or 1
            local dx = mx + side * set.dogKeep - x
            if math.abs(dx) > 40 then want = clamp(dx * 2.5, -set.dogSpeed, set.dogSpeed) * root end
        end
    end
    if want * dog.face < 0 then want = want * 0.35 end
    local walking = not held and footDown and math.abs(want) > 1

    local mass = 0
    for _, body in ipairs(dog.parts) do mass = mass + body:getMass() end
    if walking then
        for _, half in ipairs({ dog.front, dog.back }) do
            local hvx = half:getLinearVelocity()
            half:applyForce((want - hvx) * half:getMass() * 3 * root, 0)
        end
    end
    muscle(dog.waist, 0, 8 * root, mass * gy * K.length * 0.25 * set.dogWaist)

    -- the legs: straight and stiff standing, swinging in pairs walking, paddling when held
    local stepRate = math.abs(want) / (K.legLength * 0.9) -- a step for about each leg-length
    dog.gait = (dog.gait or 0) + dt * (walking and math.max(4, stepRate * 2) or 0) * (want >= 0 and 1 or -1) * dog.face
    local legTorque = mass * gy * K.legLength * set.dogMuscle
    for i, leg in ipairs(dog.legs) do
        local target = 0
        if held then
            target = math.sin(g.time * 9 + i * 1.7) * 0.6
        elseif walking then
            target = math.sin(dog.gait + (leg.pair == 1 and 0 or math.pi)) * set.dogStride
        end
        muscle(leg.hip, target, 12 * root, legTorque)
    end

    -- the head held level on the neck (a nod walking); a cat's ears up; the tail as built, wagging
    local head = dog.head
    muscle(dog.neck, walking and math.sin(dog.gait) * 0.06 or 0, 8 * root, head:getMass() * gy * K.length * 0.5)
    for _, ear in ipairs(dog.ears) do
        muscle(ear.joint, 0, 10 * root, ear.body:getMass() * gy * K.length * 0.3)
    end
    for i, joint in ipairs(dog.neckJoints or {}) do -- the neck held up: each joint carries what's above
        local above = head:getMass()
        for j = i, #dog.neckSegs do above = above + dog.neckSegs[j]:getMass() end
        muscle(joint, 0, 9 * root, above * gy * K.neckLength * (#dog.neckSegs - i + 1.5) * set.dogMuscle)
    end
    dog.wag = dog.wag + dt * (K.behaviour == 'wander' and 2 or (walking and set.dogWag * 0.5 or set.dogWag))
    for i, joint in ipairs(dog.tailJoints or {}) do
        local seg = dog.tail[i]
        local sway = math.sin(dog.wag + i * 0.6) * 0.12 * K.tailSway
        muscle(joint, sway, 10 * root, seg:getMass() * gy * K.tailGap * (#dog.tail - i + 1) * 2)
    end
end

-- The tail's skin: the rope (Mipo leg-01, as Mipo arms are drawn) in the Mipo's arm colours,
-- baked once per colouring (a bake draws to canvases: from update, not draw).
local TAIL_URL = 'textures/mipo/leg/leg-01'
-- a Mipo picture baked as an OMP in a skin's colours (outline, fill, pattern), once per picture and
-- colouring; returns the key it's kept under in skinImages
local skinImages = {}
local function bakeSkin(url, c)
    c = c or {}
    local key = url .. (c.bgHex or '') .. (c.fgHex or '') .. (c.pHex or '') .. (c.pURL or '')
    if skinImages[key] then return key end
    local function rgb(hex, fallback)
        hex = (hex and #hex >= 6) and hex or fallback
        return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255 }, (#hex >= 8 and tonumber(hex:sub(7, 8), 16) / 255 or 1)
    end
    local line = rgb(c.bgHex, '000000ff')
    local fill = rgb(c.fgHex, 'D9A066ff')
    local pat, patAlpha = rgb(c.pHex, 'ffffff00')
    local pattern
    if c.pURL and c.pURL ~= '' and love.filesystem.getInfo('textures/pat/' .. c.pURL) then
        pattern = love.graphics.newImage('textures/pat/' .. c.pURL)
    else
        pattern, patAlpha = love.graphics.newImage(love.image.newImageData(1, 1)), 0
    end
    local imageData = ompBake.makeTexturedCanvas(love.graphics.newImage(url .. '.png'),
        love.graphics.newImage(url .. '-mask.png'), fill, 1, pattern, pat, patAlpha, 0, 1, 1, 0, 0,
        line, 1, 1, 1)
    skinImages[key] = love.graphics.newImage(imageData)
    skinImages[key]:setWrap('clamp', 'clamp')
    imageData:release()
    return key
end

local function bakeDogTail(dog)
    dog.tailKey = bakeSkin(TAIL_URL, dog.looks.armSkin or dog.looks.torsoSkin)
    local K = dog.kind or DOG
    dog.bodyKey = bakeSkin('textures/' .. K.torsoURL:gsub('%.png$', ''), dog.looks.torsoSkin)
    if K.neckSegments then dog.neckKey = bakeSkin('textures/mipo/leg/leg-02', dog.looks.torsoSkin) end
end

-- a long neck's skin along its segments, from the body up to the head; a giraffe's horns
local function drawDogNeck(dog)
    local K = dog.kind or DOG
    if not dog.neckSegs then return end
    local image = dog.neckKey and skinImages[dog.neckKey]
    local pts = {}
    local x0, y0 = dog.neckJoints[1]:getAnchors()
    pts[1] = { x = x0, y = y0, r = K.neckWidth * 0.5 }
    for i, seg in ipairs(dog.neckSegs) do
        local x, y = seg:getWorldPoint(0, K.neckLength / 2)
        pts[#pts + 1] = { x = x, y = y, r = K.neckWidth * 0.5 * (1 - 0.25 * i / #dog.neckSegs) }
    end
    if image then drawSkinStrip(image, pts, 1.9) end
    if K.horns then
        love.graphics.setColor(0.42, 0.26, 0.12)
        love.graphics.setLineWidth(6)
        for _, side in ipairs({ -1, 1 }) do
            local bx, by = dog.head:getWorldPoint(side * dog.headW * 0.16, -dog.headH * 0.4)
            local tx, ty = dog.head:getWorldPoint(side * dog.headW * 0.2, -dog.headH * 0.68)
            love.graphics.line(bx, by, tx, ty)
            love.graphics.circle('fill', tx, ty, 8)
        end
    end
end

-- the body's picture over both halves: a strip along back end, back middle, waist, front middle,
-- front end, the picture's width along it and its height across
local function drawDogBody(dog, g)
    local image = dog.bodyKey and skinImages[dog.bodyKey]
    if not image then return end
    local K = dog.kind or DOG
    local f, q = dog.face, K.length / 4
    local bx1, by1 = dog.back:getWorldPoint(-f * q * 1.05, 0)
    local bx2, by2 = dog.back:getWorldPoint(0, 0)
    local wx1, wy1 = dog.back:getWorldPoint(f * q, 0)
    local wx2, wy2 = dog.front:getWorldPoint(-f * q, 0)
    local fx2, fy2 = dog.front:getWorldPoint(0, 0)
    local fx1, fy1 = dog.front:getWorldPoint(f * q * 1.05, 0)
    local spine = { { bx1, by1 }, { bx2, by2 }, { (wx1 + wx2) / 2, (wy1 + wy2) / 2 }, { fx2, fy2 }, { fx1, fy1 } }
    local half = K.height * 0.54 * g.settings.dogBodyWidth
    local verts = {}
    for i, p in ipairs(spine) do
        local a, b = spine[math.max(1, i - 1)], spine[math.min(#spine, i + 1)]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local l = len(dx, dy)
        local ux, uy = 0, -1
        if l > 1e-4 then
            if f > 0 then ux, uy = dy / l, -dx / l else ux, uy = -dy / l, dx / l end
        end
        local u = (i - 1) / (#spine - 1)
        if f < 0 then u = 1 - u end
        verts[#verts + 1] = { p[1] + ux * half, p[2] + uy * half, u, 0 }
        verts[#verts + 1] = { p[1] - ux * half, p[2] - uy * half, u, 1 }
    end
    local mesh = love.graphics.newMesh(verts, 'strip', 'stream')
    mesh:setTexture(image)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mesh)
    mesh:release()
end

local function drawDogTail(dog, g)
    local pts = {}
    local K = dog.kind or DOG
    local x0, y0 = dog.torso:getWorldPoint(-dog.face * K.length * 0.44, -K.height * 0.08)
    local r = K.tailRadius
    pts[1] = { x = x0, y = y0, r = r }
    for i, seg in ipairs(dog.tail) do
        local x, y = seg:getPosition()
        pts[#pts + 1] = { x = x, y = y, r = r * (1 - 0.5 * i / #dog.tail) }
    end
    local image = dog.tailKey and skinImages[dog.tailKey]
    if image then
        drawSkinStrip(image, pts, g.settings.dogTailWidth)
    else
        love.graphics.setColor(0.08, 0.06, 0.06)
        love.graphics.setLineWidth(14)
        local flat = {}
        for _, p in ipairs(pts) do flat[#flat + 1] = p.x; flat[#flat + 1] = p.y end
        love.graphics.line(flat)
    end
end

---------------------------------------------------------------- the walker
-- A simplified Mipo: the Mipo head (its face, kept upright with KEEP_ANGLE as a Mipo keeps its
-- parts) on two rope legs, no torso, no arms, no hands or feet. Each leg a thigh and a shin on
-- hip and knee joints with muscles (motors); drawn as the rope in the Mipo's leg colours. Walking
-- the legs swing in turn, the knee bending on the way forward, and while a foot is down the head is
-- nudged along (as the dog). Its face looks out at you, so it walks either way without turning.
-- Lifted it dangles, dropped it falls.

local WALKER = {
    label = 'garden-walker', thigh = 115, shin = 120, legWidth = 16, hipSpread = 0.22,
    groupBase = -34000,
}

local function walkerLegSkin(g)
    local inst = g.mipos and g.mipos[1]
    local leg = inst and inst.dna and inst.dna.parts.luleg
    local skin = leg and leg.appearance and leg.appearance['connected-skin']
    local main = skin and skin.main
    return main and { bgHex = main.bgHex, fgHex = main.fgHex, pHex = main.pHex, pURL = main.pURL }
end

local function walkerStandHeight(headH) return WALKER.thigh + WALKER.shin + headH * 0.35 end

local function makeWalker(g, x, groundY)
    local looks = dogLooks(g)
    if not looks then return end
    local group = WALKER.groupBase - love.math.random(1, 999)
    local sc = looks.scale
    local hEntry = shape8Dict[looks.headURL]
    local headW, headH = hEntry.dimensions[1] * looks.headSX * sc, hEntry.dimensions[2] * looks.headSY * sc
    local y = groundY - walkerStandHeight(headH)
    local w = { parts = {}, legs = {}, looks = looks, legSkin = walkerLegSkin(g), group = group,
        dir = love.math.random() < 0.5 and -1 or 1, gait = 0, headH = headH }
    local head = shapeBody(looks.headURL, looks.headSX * sc, looks.headSY * sc, x, y, 'head', group, 0.6)
    w.head = head
    w.parts[1] = head
    skinOf(head, looks.headURL, headW * 1.1, headH * 1.1, looks.headSkin or {}, 20)
    head:getUserData().thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0 } }
    if looks.face then
        mipoTextures.addFaceDecals(head, 'head', { shape8URL = looks.headURL,
            dims = { sx = looks.headSX, sy = looks.headSY } }, looks.face,
            { dna = { creation = { isPotatoHead = false }, faceMagnitude = looks.faceMagnitude } }, sc)
    end
    for i, side in ipairs({ -1, 1 }) do
        local hx, hy = x + side * headW * WALKER.hipSpread, y + headH * 0.35
        local kx, ky = hx, hy + WALKER.thigh
        local fy = ky + WALKER.shin
        local thigh = love.physics.newBody(world, hx, (hy + ky) / 2, 'dynamic')
        local f1 = love.physics.newFixture(thigh,
            love.physics.newRectangleShape(WALKER.legWidth, WALKER.thigh), 0.5)
        local shin = love.physics.newBody(world, kx, (ky + fy) / 2, 'dynamic')
        local f2 = love.physics.newFixture(shin,
            love.physics.newRectangleShape(WALKER.legWidth, WALKER.shin), 0.5)
        for _, f in ipairs({ f1, f2 }) do
            f:setGroupIndex(group)
            f:setFriction(0.9)
        end
        local hip = love.physics.newRevoluteJoint(head, thigh, hx, hy, false)
        hip:setLimitsEnabled(true)
        hip:setLimits(-1, 1)
        hip:setMotorEnabled(true)
        local knee = love.physics.newRevoluteJoint(thigh, shin, kx, ky, false)
        knee:setLimitsEnabled(true)
        knee:setLimits(-1.3, 1.3)
        knee:setMotorEnabled(true)
        w.legs[i] = { thigh = thigh, shin = shin, hip = hip, knee = knee, side = side }
    end
    return w
end

local function walkerAlive(w)
    if not w or not w.head or w.head:isDestroyed() then return false end
    for _, leg in ipairs(w.legs) do
        if leg.thigh:isDestroyed() or leg.shin:isDestroyed() then return false end
    end
    return true
end

local function destroyWalker(w)
    for _, leg in ipairs(w.legs or {}) do
        if not leg.shin:isDestroyed() then leg.shin:destroy() end
        if not leg.thigh:isDestroyed() then leg.thigh:destroy() end
    end
    if w.head and not w.head:isDestroyed() then objectManager.destroyBody(w.head) end
end

local function updateWalker(g, w, dt)
    local _, root = factors()
    local set = g.settings
    w.legKey = bakeSkin(w.legURL or TAIL_URL, w.legSkin or w.looks.torsoSkin) -- (a bake: from update)
    local thighLen, shinLen = w.thighLen or WALKER.thigh, w.shinLen or WALKER.shin
    local head = w.head
    local x = head:getPosition()
    local vx = head:getLinearVelocity()
    local gy = gravityY()
    local held = getPJAttachedTo(head) ~= nil
    local footDown = false
    for _, leg in ipairs(w.legs) do
        held = held or getPJAttachedTo(leg.thigh) ~= nil or getPJAttachedTo(leg.shin) ~= nil
        for _, contact in ipairs(leg.shin:getContacts()) do
            if contact:isTouching() then footDown = true end
        end
    end

    -- wander: a spot somewhere, walked to, a while there, then another
    w.wanderTime = (w.wanderTime or 0) - dt
    if not w.wanderX or w.wanderTime <= 0 then
        w.wanderX = clamp(x + (love.math.random() - 0.5) * 1600, -HALF_W + 300, HALF_W - 300)
        w.wanderTime = 4 + love.math.random() * 6
    end
    local dx = w.wanderX - x
    local speed = w.speed and set[w.speed] or set.walkerSpeed
    local want = math.abs(dx) > 40 and clamp(dx * 2, -speed, speed) * root or 0
    if w.pecking then want = 0 end
    local walking = not held and footDown and math.abs(want) > 1
    w.held, w.footDown, w.walking = held, footDown, walking
    if walking then
        head:applyForce((want - vx) * head:getMass() * 3 * root, 0)
        w.dir = want > 0 and 1 or -1
    end

    local mass = head:getMass()
    for _, leg in ipairs(w.legs) do mass = mass + leg.thigh:getMass() + leg.shin:getMass() end
    w.gait = w.gait + dt * (walking and set.walkerSteps * math.pi * 2 or 0)
    local legLen = thighLen + shinLen
    for i, leg in ipairs(w.legs) do
        local hipT, kneeT = 0, 0
        if held then
            hipT = math.sin(g.time * 7 + i * 2) * 0.5
            kneeT = math.sin(g.time * 9 + i) * 0.6
        elseif walking then
            local phase = w.gait + (i - 1) * math.pi
            hipT = -math.sin(phase) * set.walkerStride * w.dir -- the leg swings the way it walks
            kneeT = math.max(0, math.cos(phase)) * 0.9 * w.dir -- bent on the way forward
        end
        muscle(leg.hip, hipT, 12 * root, mass * gy * legLen * set.walkerMuscle)
        muscle(leg.knee, kneeT, 12 * root, mass * gy * shinLen * set.walkerMuscle)
    end
end

local function drawWalkerLegs(w)
    local image = w.legKey and skinImages[w.legKey]
    local thighLen, shinLen = w.thighLen or WALKER.thigh, w.shinLen or WALKER.shin
    for _, leg in ipairs(w.legs) do
        local hx, hy = leg.thigh:getWorldPoint(0, -thighLen / 2)
        local kx, ky = leg.thigh:getWorldPoint(0, thighLen / 2)
        local fx, fy = leg.shin:getWorldPoint(0, shinLen / 2)
        local r = (w.legWidth or WALKER.legWidth) / 2
        if image then
            drawSkinStrip(image, { { x = hx, y = hy, r = r }, { x = kx, y = ky, r = r },
                { x = fx, y = fy, r = r } }, 1.6)
        end
        if w.toes then -- a chicken's three toes
            love.graphics.setColor(0.85, 0.5, 0.15)
            love.graphics.setLineWidth(5)
            for _, a in ipairs({ -0.5, 0, 0.5 }) do
                local dir = w.dir or 1
                love.graphics.line(fx, fy, fx + dir * math.cos(a) * 22, fy + 2 + math.sin(a) * 6)
            end
            love.graphics.line(fx, fy, fx - (w.dir or 1) * 12, fy + 2)
        end
    end
end

---------------------------------------------------------------- the chicken
-- The walker's legs and wandering under a round body (white crayon, Mipo body-03, kept upright with
-- KEEP_ANGLE), shorter orange legs (Mipo leg-02) with three toes. A small round head on top on a neck
-- joint with a muscle: standing about it pecks at the ground now and then (the neck swings the head
-- down and up). The head sits on top and the body is round, so which way it looks is only the
-- drawing: beak, comb, wattle and pupils on the side it walks to. A wing on its side flaps when it
-- hurries or is held.

local CHICKEN = {
    label = 'garden-chicken', radius = 58, headRadius = 25, thigh = 55, shin = 62, legWidth = 13,
    groupBase = -36000,
    skin = { bgHex = '2A1E16FF', fgHex = 'F6F1E4FF', pHex = 'C9B79A66', pURL = 'type3_.png' },
    legSkin = { bgHex = '6A3A10FF', fgHex = 'EE9B38FF' },
}

local function makeChicken(_, x, groundY)
    local R = CHICKEN.radius
    local y = groundY - (CHICKEN.thigh + CHICKEN.shin + R * 0.7)
    local group = CHICKEN.groupBase - love.math.random(1, 999)
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = R, label = CHICKEN.label,
        bodyType = 'dynamic', density = 0.8 })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then fixture:setGroupIndex(group) end
    end
    thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0 } }
    skinOf(body, 'mipo/body/body-03.png', R * 2.25, R * 2.25 * 422 / 370, CHICKEN.skin, 0)
    local w = { head = body, parts = { body }, legs = {}, group = group, dir = 1, gait = 0,
        legSkin = CHICKEN.legSkin, legURL = 'textures/mipo/leg/leg-02', thighLen = CHICKEN.thigh,
        shinLen = CHICKEN.shin, legWidth = CHICKEN.legWidth, toes = true, speed = 'chickenSpeed',
        looks = { torsoSkin = CHICKEN.skin }, eyes = newEyes(), peckWait = 2, flap = 0 }
    -- the head, on top, on a neck joint
    local hr = CHICKEN.headRadius
    local head = love.physics.newBody(world, x, y - R - hr * 0.6, 'dynamic')
    local hf = love.physics.newFixture(head, love.physics.newCircleShape(hr), 0.5)
    hf:setGroupIndex(group)
    head:setAngularDamping(3)
    local neck = love.physics.newRevoluteJoint(body, head, x, y - R * 0.8, false)
    neck:setLimitsEnabled(true)
    neck:setLimits(-1.4, 1.4)
    neck:setMotorEnabled(true)
    w.chickHead, w.neck = head, neck
    for i, side in ipairs({ -1, 1 }) do
        local hx, hy = x + side * R * 0.3, y + R * 0.7
        local kx, ky = hx, hy + CHICKEN.thigh
        local fy = ky + CHICKEN.shin
        local thigh = love.physics.newBody(world, hx, (hy + ky) / 2, 'dynamic')
        local f1 = love.physics.newFixture(thigh, love.physics.newRectangleShape(CHICKEN.legWidth, CHICKEN.thigh), 0.5)
        local shin = love.physics.newBody(world, kx, (ky + fy) / 2, 'dynamic')
        local f2 = love.physics.newFixture(shin, love.physics.newRectangleShape(CHICKEN.legWidth, CHICKEN.shin), 0.5)
        for _, f in ipairs({ f1, f2 }) do
            f:setGroupIndex(group)
            f:setFriction(0.9)
        end
        local hip = love.physics.newRevoluteJoint(body, thigh, hx, hy, false)
        hip:setLimitsEnabled(true)
        hip:setLimits(-1, 1)
        hip:setMotorEnabled(true)
        local knee = love.physics.newRevoluteJoint(thigh, shin, kx, ky, false)
        knee:setLimitsEnabled(true)
        knee:setLimits(-1.3, 1.3)
        knee:setMotorEnabled(true)
        w.legs[i] = { thigh = thigh, shin = shin, hip = hip, knee = knee, side = side }
    end
    return w
end

local function chickenAlive(w)
    return walkerAlive(w) and w.chickHead and not w.chickHead:isDestroyed()
end

local function destroyChicken(w)
    if w.chickHead and not w.chickHead:isDestroyed() then w.chickHead:destroy() end
    destroyWalker(w)
end

local function updateChicken(g, w, dt, px, py)
    local _, root = factors()
    local set = g.settings
    w.headKey = bakeSkin('textures/mipo/patch/patch-01', CHICKEN.skin)
    w.wingKey = bakeSkin('textures/mipo/ear/ear-04', CHICKEN.skin)
    updateWalker(g, w, dt)
    local held = w.held or getPJAttachedTo(w.chickHead) ~= nil
    -- pecking: standing about, now and then the head goes down to the ground and back up
    w.peckWait = w.peckWait - dt
    if w.peckTime then
        w.peckTime = w.peckTime - dt
        if w.peckTime <= 0 then w.peckTime, w.pecking = nil, nil end
    elseif w.peckWait <= 0 and w.footDown and not held then
        w.peckWait = 1 + love.math.random() * 3
        w.peckTime = 0.22 + love.math.random() * 0.1
        w.pecking = true
    end
    local target = w.peckTime and w.dir * set.chickenPeck or 0
    local gy = gravityY()
    muscle(w.neck, target, 16 * root, w.chickHead:getMass() * gy * CHICKEN.radius * 6)
    w.flap = w.flap + dt * ((held or w.walking) and 30 or 0)
    local hx, hy = w.chickHead:getPosition()
    local lookX, lookY = w.dir, 0.3
    if px then lookX, lookY = px - hx, py - hy end
    updateEyes(w.eyes, dt, lookX, lookY)
end

local function drawChickenTail(w)
    local body = w.head
    love.graphics.setColor(0.97, 0.95, 0.9)
    love.graphics.setLineWidth(14)
    local d = -(w.dir or 1)
    for k = -1, 1 do
        local bx, by = body:getWorldPoint(d * CHICKEN.radius * 0.7, -CHICKEN.radius * 0.1)
        local tx, ty = body:getWorldPoint(d * CHICKEN.radius * (1.2 + 0.1 * k), -CHICKEN.radius * (0.7 - 0.25 * k))
        love.graphics.setColor(0.16, 0.12, 0.09)
        love.graphics.setLineWidth(18)
        love.graphics.line(bx, by, tx, ty)
        love.graphics.setColor(0.97, 0.95, 0.9)
        love.graphics.setLineWidth(12)
        love.graphics.line(bx, by, tx, ty)
    end
end

local function drawChicken(w)
    local d = w.dir or 1
    local body = w.head
    -- the wing, on its side
    local wing = w.wingKey and skinImages[w.wingKey]
    if wing then
        local iw, ih = wing:getDimensions()
        local bx, by = body:getWorldPoint(-d * CHICKEN.radius * 0.15, -CHICKEN.radius * 0.05)
        local flap = math.sin(w.flap) * 0.5
        local sc = CHICKEN.radius * 1.1 / ih
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(wing, bx, by, body:getAngle() + d * (1.9 + flap), sc * 1.3, sc, iw / 2, ih)
    end
    -- the head: a round white head, a red comb on top, beak and wattle the way it looks
    local head = w.chickHead
    local x, y = head:getPosition()
    local a = head:getAngle()
    local hr = CHICKEN.headRadius
    local function at(lx, ly)
        local c, sn = math.cos(a), math.sin(a)
        return x + lx * c - ly * sn, y + lx * sn + ly * c
    end
    love.graphics.setColor(0.85, 0.15, 0.15)
    for k = -1, 1 do
        local cx, cy = at(k * hr * 0.35, -hr * 1.05)
        love.graphics.circle('fill', cx, cy, hr * 0.32)
    end
    local wx, wy = at(d * hr * 0.75, hr * 0.75)
    love.graphics.ellipse('fill', wx, wy, hr * 0.22, hr * 0.38)
    local headImage = w.headKey and skinImages[w.headKey]
    if headImage then
        local iw, ih = headImage:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(headImage, x, y, a, hr * 2.3 / iw, hr * 2.3 / ih, iw / 2, ih / 2)
    end
    local b1x, b1y = at(d * hr * 0.85, -hr * 0.25)
    local b2x, b2y = at(d * hr * 0.85, hr * 0.3)
    local tx, ty = at(d * hr * 1.6, hr * 0.05)
    love.graphics.setColor(0.93, 0.6, 0.15)
    love.graphics.polygon('fill', b1x, b1y, b2x, b2y, tx, ty)
    love.graphics.setColor(0.4, 0.22, 0.05)
    love.graphics.setLineWidth(2)
    love.graphics.polygon('line', b1x, b1y, b2x, b2y, tx, ty)
    local e1x, e1y = at(d * hr * 0.35, -hr * 0.25)
    local e2x, e2y = at(d * hr * 0.0, -hr * 0.3)
    drawEyes(w.eyes, e1x, e1y, e2x, e2y, hr * 0.2, hr * 0.08, false, pupilImage(1))
end

---------------------------------------------------------------- the butterfly
-- Seen from the front: a small dark body (feelers, Mipo pupils) and four wings, Mipo ear-04 baked as
-- OMPs in a colouring of its own with a dotted pattern, closing and opening with each flap. Flying is
-- flapping: gravity is on, each flap a kick up that also steers it towards where it's going, so it
-- bobs and flutters. It goes from flower to flower and sits on a flower's head a while, wings slowly
-- opening and closing; the pointer coming close sends it off. Held, it flaps like mad.

local BUTTERFLY = {
    radius = 14, wingURL = 'textures/mipo/ear/ear-04', wing = 95, -- an upper wing's length
    colourings = { -- the wings, and (bodyHex) the body and head in a colour that goes with them
        { bgHex = '2A1E16FF', fgHex = 'F2A33AFF', pHex = '2A1E16CC', pURL = 'type1.png', bodyHex = 'B98A5EFF' },
        { bgHex = '1E2340FF', fgHex = '7FB6F0FF', pHex = '1E2340AA', pURL = 'type1.png', bodyHex = '9AA6C8FF' },
        { bgHex = '3A1630FF', fgHex = 'F2C9E0FF', pHex = 'B0407088', pURL = 'type1.png', bodyHex = 'C7A0B6FF' },
        { bgHex = '2A2A12FF', fgHex = 'F4E46AFF', pHex = '2A2A12AA', pURL = 'type1.png', bodyHex = 'C9B97AFF' },
    },
    bodyURL = 'textures/mipo/body/body-14', headURL = 'textures/mipo/patch/patch-01',
}

local function makeButterfly(x, y)
    local body = love.physics.newBody(world, x, y, 'dynamic')
    local fixture = love.physics.newFixture(body, love.physics.newCircleShape(BUTTERFLY.radius), 0.3)
    fixture:setRestitution(0.2)
    body:setFixedRotation(true)
    body:setLinearDamping(1.6)
    return { body = body, colouring = BUTTERFLY.colourings[love.math.random(1, #BUTTERFLY.colourings)],
        flower = love.math.random(1, #FLOWERS), state = 'fly', stateTime = 0, flapAt = 0, flapPhase = 1,
        eyes = newEyes(), slow = 0 }
end

local function butterflyAlive(b) return b.body and not b.body:isDestroyed() end
local function destroyButterfly(b) if butterflyAlive(b) then b.body:destroy() end end

local function updateButterfly(g, b, dt, px, py)
    local _, root = factors()
    local set = g.settings
    local body = b.body
    local x, y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local gy = gravityY()
    local held = getPJAttachedTo(body) ~= nil
    b.wingKey = bakeSkin(BUTTERFLY.wingURL, b.colouring) -- (bakes: from update, not draw)
    local bodySkin = { bgHex = b.colouring.bgHex, fgHex = b.colouring.bodyHex }
    b.bodyKey = bakeSkin(BUTTERFLY.bodyURL, bodySkin)
    b.headKey = bakeSkin(BUTTERFLY.headURL, bodySkin)

    local fx, fy = flowerHead(FLOWERS[b.flower])
    local perchX, perchY = fx, fy - 32
    local near = px and len(px - x, py - y) < 260
    b.stateTime = b.stateTime - dt
    if held then
        b.state = 'held'
    elseif b.state == 'held' then
        b.state = 'fly'
    elseif b.state == 'perch' and (near or b.stateTime <= 0) then
        b.state = 'fly' -- off to another flower
        local next = love.math.random(1, #FLOWERS - 1)
        b.flower = next >= b.flower and next + 1 or next
        b.flapAt = 0
    elseif b.state == 'fly' and len(perchX - x, perchY - y) < 40 and not near then
        b.state, b.stateTime = 'perch', set.butterflyPerch * (0.6 + love.math.random() * 0.8)
    end

    if b.state == 'perch' then
        -- sitting on the flower's head: held there by its feet (the head sways), wings slow
        body:setGravityScale(0)
        body:setLinearVelocity((perchX - x) * 8, (perchY - y) * 8)
        b.slow = b.slow + dt * 1.3
        b.open = 0.55 + 0.45 * math.sin(b.slow)
    else
        body:setGravityScale(1)
        b.flapAt = b.flapAt - dt
        local hz = set.butterflyFlaps * (held and 2.5 or 1)
        if b.flapAt <= 0 and not held then
            -- a flap: a kick that sets it rising or sinking towards where it's going (plus half a
            -- beat of gravity, so it's there at mid-beat) and turns its speed that way, with a wander
            b.flapAt = (1 / hz) * (0.8 + love.math.random() * 0.4)
            local tx, ty = perchX, perchY - 60
            if near then tx, ty = x + (x - px) * 2, y - 300 end
            local wantVx = clamp((tx - x) * 1.5, -set.butterflySpeed, set.butterflySpeed) * root
                + (love.math.random() - 0.5) * 160 * root
            local wantVy = clamp((ty - y) * 2, -450, 450) * root - gy / (hz * 2) * set.butterflyLift
            body:setLinearVelocity(vx + (wantVx - vx) * 0.7, wantVy)
            b.flapPhase = 0
        end
        if held then b.flapAt = 0 end
        b.flapPhase = math.min(1, b.flapPhase + dt * hz * (held and 1 or 1.6))
        b.open = held and (0.5 + 0.5 * math.sin(g.time * 40)) or math.abs(math.cos(b.flapPhase * math.pi))
    end

    local lookX, lookY = vx, vy
    if px then lookX, lookY = px - x, py - y end
    updateEyes(b.eyes, dt, lookX, lookY)
end

local function drawButterfly(b, g)
    local x, y = b.body:getPosition()
    local image = b.wingKey and skinImages[b.wingKey]
    local open = 0.12 + 0.88 * (b.open or 1)
    if image then
        local iw, ih = image:getDimensions()
        love.graphics.setColor(1, 1, 1)
        for _, side in ipairs({ -1, 1 }) do
            -- upper wings up and out, lower wings down and out, smaller; closing = narrower
            local sc = BUTTERFLY.wing / ih
            local wide = g.settings.butterflyWide -- ear-04 is a narrow teardrop: widened, a butterfly's wing
            love.graphics.draw(image, x, y - 4, side * 0.8, sc * wide * open * side, sc, iw / 2, ih)
            love.graphics.draw(image, x, y + 4, side * 2.3, sc * 0.75 * wide * open * side, sc * 0.7, iw / 2, ih)
        end
    end
    -- feelers, then the body (a tall oval) and the head (a round one), Mipo pictures in its
    -- colour, and two pupils on the head
    love.graphics.setColor(0.16, 0.12, 0.1)
    love.graphics.setLineWidth(3)
    local headY = y - 26
    for _, side in ipairs({ -1, 1 }) do
        local tx, ty = x + side * 20, headY - 34 + math.sin(g.time * 3 + side) * 2
        love.graphics.line(x + side * 5, headY - 10, x + side * 12, headY - 26, tx, ty)
        love.graphics.circle('fill', tx, ty, 4)
    end
    love.graphics.setColor(1, 1, 1)
    local bodyImage = b.bodyKey and skinImages[b.bodyKey]
    if bodyImage then
        local iw, ih = bodyImage:getDimensions()
        love.graphics.draw(bodyImage, x, y + 6, 0, 26 / iw, 62 / ih, iw / 2, ih / 2)
    end
    local headImage = b.headKey and skinImages[b.headKey]
    if headImage then
        local iw, ih = headImage:getDimensions()
        love.graphics.draw(headImage, x, headY, 0, 34 / iw, 34 / ih, iw / 2, ih / 2)
    end
    drawEyes(b.eyes, x - 6, headY - 1, x + 6, headY - 1, 4.5, 2, false, pupilImage(1))
end

---------------------------------------------------------------- the garden

local function makeGround(g)
    if g.ground and not g.ground:isDestroyed() then return end
    g.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(g.ground, love.physics.newRectangleShape(HALF_W * 2, 100)):setFriction(0.9)
    for _, side in ipairs({ -1, 1 }) do
        love.physics.newFixture(g.ground,
            love.physics.newRectangleShape(side * (HALF_W + 50), -1000, 100, 2000)):setFriction(0.5)
    end
end

local function removeCritters(g)
    for _, w in ipairs(g.worms) do destroyWorm(w) end
    for _, bee in ipairs(g.bees) do
        if beeAlive(bee) then objectManager.destroyBody(bee.body) end
    end
    for _, lb in ipairs(g.ladybirds or {}) do
        if ladyAlive(lb) then objectManager.destroyBody(lb.body) end
    end
    for _, label in ipairs({ 'garden-bee', 'garden-ladybird' }) do -- a saved scene's copies
        for _, thing in ipairs(getObjectsByLabel(label)) do
            if thing.body and not thing.body:isDestroyed() then objectManager.destroyBody(thing.body) end
        end
    end
    for _, sp in ipairs(g.spiders or {}) do destroySpider(sp) end
    for _, thing in ipairs(getObjectsByLabel('garden-spider')) do
        if thing.body and not thing.body:isDestroyed() then objectManager.destroyBody(thing.body) end
    end
    for _, dog in ipairs(g.dogs or {}) do if dogAlive(dog) then destroyDog(dog) end end
    for _, cat in ipairs(g.cats or {}) do if dogAlive(cat) then destroyDog(cat) end end
    for _, gi in ipairs(g.giraffes or {}) do if dogAlive(gi) then destroyDog(gi) end end
    g.giraffes = {}
    for _, label in ipairs({ 'garden-dog', 'garden-cat', 'garden-giraffe' }) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            if thing.body and not thing.body:isDestroyed() then objectManager.destroyBody(thing.body) end
        end
    end
    for _, w in ipairs(g.walkers or {}) do if walkerAlive(w) then destroyWalker(w) end end
    for _, w in ipairs(g.snakes or {}) do destroyWorm(w) end
    for _, b in ipairs(g.butterflies or {}) do destroyButterfly(b) end
    g.butterflies = {}
    for _, c in ipairs(g.chickens or {}) do if chickenAlive(c) then destroyChicken(c) end end
    g.chickens = {}
    g.worms, g.bees, g.ladybirds, g.spiders, g.dogs, g.cats, g.walkers = {}, {}, {}, {}, {}, {}, {}
    g.snakes = {}
end

local function makeChickens(g)
    for _, c in ipairs(g.chickens or {}) do if chickenAlive(c) then destroyChicken(c) end end
    sweepKind(CHICKEN)
    g.chickens = { makeChicken(g, 1500, GROUND_Y - DROP) }
end

local function makeButterflies(g)
    for _, b in ipairs(g.butterflies or {}) do destroyButterfly(b) end
    g.butterflies = { makeButterfly(-1200, GROUND_Y - 700), makeButterfly(900, GROUND_Y - 800) }
end

local function makeSnakes(g)
    for _, w in ipairs(g.snakes or {}) do destroyWorm(w) end
    g.snakes = { makeWorm(300, GROUND_Y - DROP, -1, SNAKE) }
end

local function makeWalkers(g)
    for _, w in ipairs(g.walkers or {}) do if walkerAlive(w) then destroyWalker(w) end end
    sweepKind(WALKER)
    g.walkers = { makeWalker(g, -1500, GROUND_Y - DROP) }
end

local function makeGiraffes(g)
    for _, gi in ipairs(g.giraffes or {}) do if dogAlive(gi) then destroyDog(gi) end end
    sweepKind(GIRAFFE)
    g.giraffes = { makeDog(g, -300, GROUND_Y - dogStandHeight(GIRAFFE) - DROP, 1, GIRAFFE) }
end

local function makeCats(g)
    for _, cat in ipairs(g.cats or {}) do if dogAlive(cat) then destroyDog(cat) end end
    sweepKind(CAT)
    g.cats = { makeDog(g, 1200, GROUND_Y - dogStandHeight(CAT) - DROP, -1, CAT) }
end

local function makeDogs(g)
    for _, dog in ipairs(g.dogs or {}) do if dogAlive(dog) then destroyDog(dog) end end
    sweepKind(DOG)
    g.dogs = { makeDog(g, -900, GROUND_Y - dogStandHeight() - DROP, 1) }
end

local function makeSpiders(g)
    for _, sp in ipairs(g.spiders or {}) do destroySpider(sp) end
    g.spiders = { makeSpider(-500, GROUND_Y - DROP) }
end

local function makeLadybirds(g)
    for _, lb in ipairs(g.ladybirds or {}) do
        if ladyAlive(lb) then objectManager.destroyBody(lb.body) end
    end
    g.ladybirds = { makeLadybird(-1100, GROUND_Y - DROP), makeLadybird(1700, GROUND_Y - DROP) }
end

local function makeCritters(g)
    removeCritters(g)
    g.worms[1] = makeWorm(-300, GROUND_Y - DROP, 1)
    g.worms[2] = makeWorm(1000, GROUND_Y - DROP, -1)
    g.bees[1] = makeBee(-700, GROUND_Y - 700, g)
    makeLadybirds(g)
    makeSpiders(g)
end

local function alive(inst)
    if not inst or not inst.parts then return false end
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() then return true end
    end
    return false
end

local function makeMipo(g)
    for _, inst in ipairs(g.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    g.mipos = {}
    local inst = characterManager.createCharacter('humanoid', 150, GROUND_Y - 500, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    g.mipos[1] = inst
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 500)
end

function s.onStart()
    worldState.paused = false
    local g = garden()
    makeGround(g)
    local critters = #g.worms > 0
    for _, w in ipairs(g.worms) do critters = critters and wormAlive(w) end
    for _, bee in ipairs(g.bees) do critters = critters and beeAlive(bee) end
    if not critters or #g.bees == 0 then makeCritters(g) end
    local ladies = g.ladybirds and #g.ladybirds > 0
    for _, lb in ipairs(g.ladybirds or {}) do ladies = ladies and ladyAlive(lb) end
    if not ladies then makeLadybirds(g) end
    local spiders = g.spiders and #g.spiders > 0
    for _, sp in ipairs(g.spiders or {}) do spiders = spiders and spiderAlive(sp) end
    if not spiders or g.spiderLegs ~= SPIDER.legsPerSide then
        makeSpiders(g)
        g.spiderLegs = SPIDER.legsPerSide
    end
    local anyMipo = false
    for _, inst in ipairs(g.mipos) do anyMipo = anyMipo or alive(inst) end
    if not anyMipo then makeMipo(g) end
    local dogs = g.dogs and #g.dogs > 0
    for _, dog in ipairs(g.dogs or {}) do dogs = dogs and dogAlive(dog) end
    local cats = g.cats and #g.cats > 0
    for _, cat in ipairs(g.cats or {}) do cats = cats and dogAlive(cat) end
    if not dogs or g.dogVersion ~= DOG.version then makeDogs(g) end
    if not cats or g.dogVersion ~= DOG.version then makeCats(g) end
    local giraffes = g.giraffes and #g.giraffes > 0
    for _, gi in ipairs(g.giraffes or {}) do giraffes = giraffes and dogAlive(gi) end
    if not giraffes or g.dogVersion ~= DOG.version then makeGiraffes(g) end
    g.dogVersion = DOG.version
    local walkers = g.walkers and #g.walkers > 0
    for _, w in ipairs(g.walkers or {}) do walkers = walkers and walkerAlive(w) end
    if not walkers then makeWalkers(g) end
    local snakes = g.snakes and #g.snakes > 0
    for _, w in ipairs(g.snakes or {}) do snakes = snakes and wormAlive(w) end
    local flutter = g.butterflies and #g.butterflies > 0
    for _, b in ipairs(g.butterflies or {}) do flutter = flutter and butterflyAlive(b) end
    if not flutter then makeButterflies(g) end
    local hens = g.chickens and #g.chickens > 0
    for _, c in ipairs(g.chickens or {}) do hens = hens and chickenAlive(c) end
    if not hens then makeChickens(g) end
    if not snakes or g.snakeVersion ~= SNAKE.version then
        makeSnakes(g)
        g.snakeVersion = SNAKE.version
    end
    camera.settings().follow = false -- the whole garden in view; pan and zoom as you like
    lookAtAll()
end

function s.onUnload()
    local g = state.garden
    if not g then return end
    removeCritters(g)
    if g.ground and not g.ground:isDestroyed() then g.ground:destroy() end
    g.ground = nil
end

function s.update(dt)
    local g = garden()
    dt = dt or love.timer.getDelta()
    g.time = g.time + dt
    bakeWormSkin()
    bakeWings()
    bakeSpiderLegs()
    local px, py = pointer(g)
    for _, w in ipairs(g.worms) do
        if wormAlive(w) then updateWorm(g, w, dt, px, py) end
    end
    for _, b in ipairs(g.butterflies or {}) do
        if butterflyAlive(b) then updateButterfly(g, b, dt, px, py) end
    end
    for _, c in ipairs(g.chickens or {}) do
        if chickenAlive(c) then updateChicken(g, c, dt, px, py) end
    end
    for _, w in ipairs(g.snakes or {}) do
        if wormAlive(w) then
            w.skinKey = bakeSkin(SNAKE.skinURL, SNAKE.skin) -- (a bake: from update, not draw)
            updateWorm(g, w, dt, px, py)
        end
    end
    for _, bee in ipairs(g.bees) do
        if beeAlive(bee) then updateBee(g, bee, dt, px, py) end
    end
    for _, lb in ipairs(g.ladybirds or {}) do
        if ladyAlive(lb) then updateLadybird(g, lb, dt, px, py) end
    end
    for _, sp in ipairs(g.spiders or {}) do
        if spiderAlive(sp) then updateSpider(g, sp, dt, px, py) end
    end
    for _, w in ipairs(g.walkers or {}) do
        if walkerAlive(w) then updateWalker(g, w, dt) end
    end
    for _, list in ipairs({ g.dogs or {}, g.cats or {}, g.giraffes or {} }) do
        for _, dog in ipairs(list) do
            if dogAlive(dog) then
                bakeDogTail(dog)
                updateDog(g, dog, dt)
            end
        end
    end
end

local function drawFlower(f, t)
    local hx, hy = flowerHead(f)
    local sway = math.sin(t * 0.8 + f.x) * 8
    love.graphics.setColor(0.3, 0.5, 0.22)
    love.graphics.setLineWidth(9)
    love.graphics.line(f.x, GROUND_Y, f.x + sway * 0.5, GROUND_Y - f.h * 0.5, hx + sway, hy)
    love.graphics.ellipse('fill', f.x + 30, GROUND_Y - f.h * 0.35, 34, 12)
    love.graphics.setColor(f.c)
    for k = 0, 5 do
        local a = k / 6 * math.pi * 2 + t * 0.05
        love.graphics.circle('fill', hx + sway + math.cos(a) * 38, hy + math.sin(a) * 38, 30)
    end
    love.graphics.setColor(0.55, 0.38, 0.15)
    love.graphics.circle('fill', hx + sway, hy, 26)
end

-- under the bodies: sky, ground, flowers, the bee's far wing. In play mode the physics outlines
-- are hidden (put back in draw), as in the wild scene.
function s.drawBelow()
    local g = garden()
    love.graphics.setColor(0.86, 0.91, 0.88)
    love.graphics.rectangle('fill', -HALF_W * 3, GROUND_Y - 6000, HALF_W * 6, 6000)
    love.graphics.setColor(0.47, 0.64, 0.33)
    love.graphics.rectangle('fill', -HALF_W, GROUND_Y, HALF_W * 2, 1200)
    love.graphics.setColor(0.36, 0.5, 0.25)
    love.graphics.rectangle('fill', -HALF_W, GROUND_Y, HALF_W * 2, 14)
    for _, f in ipairs(FLOWERS) do drawFlower(f, g.time) end
    for _, bee in ipairs(g.bees) do
        if beeAlive(bee) then drawBeeBehind(bee, g) end
    end
    for _, lb in ipairs(g.ladybirds or {}) do
        if ladyAlive(lb) then drawLadybirdBehind(lb, g) end
    end
    for _, sp in ipairs(g.spiders or {}) do
        if spiderAlive(sp) then drawSpiderLegs(sp, g) end
    end
    for _, list in ipairs({ g.dogs or {}, g.cats or {}, g.giraffes or {} }) do
        for _, dog in ipairs(list) do
            if dogAlive(dog) then
                drawDogTail(dog, g)
                drawDogBody(dog, g)
                drawDogNeck(dog)
            end
        end
    end
    for _, w in ipairs(g.walkers or {}) do
        if walkerAlive(w) then drawWalkerLegs(w) end
    end
    for _, c in ipairs(g.chickens or {}) do
        if chickenAlive(c) then
            drawChickenTail(c)
            drawWalkerLegs(c)
        end
    end
    if state.playMode then
        g.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    g.drawing = true
end

function s.draw()
    local g = garden()
    if g.drawing and g.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = g.savedDrawBodies
        g.savedDrawBodies = nil
    end
    g.drawing = nil
    for _, w in ipairs(g.worms) do
        if wormAlive(w) then drawWorm(w, wormImage) end
    end
    for _, w in ipairs(g.snakes or {}) do
        if wormAlive(w) then drawWorm(w, w.skinKey and skinImages[w.skinKey]) end
    end
    for _, b in ipairs(g.butterflies or {}) do
        if butterflyAlive(b) then drawButterfly(b, g) end
    end
    for _, c in ipairs(g.chickens or {}) do
        if chickenAlive(c) then drawChicken(c) end
    end
    for _, bee in ipairs(g.bees) do
        if beeAlive(bee) then drawBee(bee, g) end
    end
    for _, lb in ipairs(g.ladybirds or {}) do
        if ladyAlive(lb) then drawLadybird(lb, g) end
    end
    for _, sp in ipairs(g.spiders or {}) do
        if spiderAlive(sp) then drawSpiderEyes(sp, g) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- one more critter at (x, y): a worm lying there, a bee or a ladybird there, a spider standing on
-- what's under it. At most MAX_EACH of a kind: the oldest goes.
local MAX_EACH = 12
local SPAWN = {
    { key = '1', label = 'worm', list = 'worms', remove = destroyWorm,
      make = function(_, x, y) return makeWorm(x, y, love.math.random() < 0.5 and -1 or 1) end },
    { key = '2', label = 'bee', list = 'bees', make = function(g, x, y) return makeBee(x, y, g) end,
      remove = function(bee) if beeAlive(bee) then objectManager.destroyBody(bee.body) end end },
    { key = '3', label = 'ladybird', list = 'ladybirds', make = function(_, x, y) return makeLadybird(x, y) end,
      remove = function(lb) if ladyAlive(lb) then objectManager.destroyBody(lb.body) end end },
    { key = '4', label = 'spider', list = 'spiders',
      make = function(_, x, y) return makeSpider(x, y + spiderStandHeight()) end, remove = destroySpider }, -- body at y
    { key = '5', label = 'dog', list = 'dogs', make = function(g, x, y) return makeDog(g, x, y, 1) end,
      remove = function(dog) if dogAlive(dog) then destroyDog(dog) end end },
    { key = '6', label = 'cat', list = 'cats', make = function(g, x, y) return makeDog(g, x, y, 1, CAT) end,
      remove = function(cat) if dogAlive(cat) then destroyDog(cat) end end },
    { key = '8', label = 'snake', list = 'snakes', remove = destroyWorm,
      make = function(_, x, y) return makeWorm(x, y, love.math.random() < 0.5 and -1 or 1, SNAKE) end },
    { key = '9', label = 'butterfly', list = 'butterflies', remove = destroyButterfly,
      make = function(_, x, y) return makeButterfly(x, y) end },
    { key = '0', label = 'giraffe', list = 'giraffes',
      remove = function(gi) if dogAlive(gi) then destroyDog(gi) end end,
      make = function(g, x, y) return makeDog(g, x, y, 1, GIRAFFE) end },
    { label = 'chicken', list = 'chickens', remove = function(c) if chickenAlive(c) then destroyChicken(c) end end,
      make = function(g, x, y) return makeChicken(g, x, y + 300) end },
    { key = '7', label = 'walker', list = 'walkers', make = function(g, x, y) return makeWalker(g, x, y + 350) end,
      remove = function(w) if walkerAlive(w) then destroyWalker(w) end end },
}

local function spawn(g, kind, x, y)
    g[kind.list] = g[kind.list] or {}
    local list = g[kind.list]
    local critter = kind.make(g, x, y)
    if not critter then return end
    list[#list + 1] = critter
    while #list > MAX_EACH do kind.remove(table.remove(list, 1)) end
end

function s.onKeyPress(key)
    local g = garden()
    for _, kind in ipairs(SPAWN) do
        if key == kind.key then
            local x, y = mouseWorldPos()
            y = math.min(y, GROUND_Y - DROP - 200) -- the mouse in the ground: drop it from up high
            spawn(g, kind, x, y)
            return
        end
    end
    if key == 'r' then
        makeCritters(g)
    elseif key == 'm' then
        makeMipo(g)
    elseif key == 'b' then
        g.beeSkin = g.beeSkin % #BEE_SKINS + 1
        for _, bee in ipairs(g.bees) do
            if beeAlive(bee) then skinBee(bee, g) end
        end
    elseif key == 'l' then
        makeLadybirds(g)
    elseif key == 'n' then
        makeSpiders(g)
    elseif key == 'd' then
        makeDogs(g)
    elseif key == 'c' then
        makeCats(g)
    elseif key == 'u' then
        makeWalkers(g)
    elseif key == 'k' then
        makeSnakes(g)
    elseif key == 'f' then
        makeButterflies(g)
    elseif key == 'g' then
        makeGiraffes(g)
    elseif key == 'j' then
        makeChickens(g)
    elseif key == 'p' then
        g.beePupil = (g.beePupil or 1) % PUPIL_COUNT + 1
    elseif key == 'w' then
        g.wingKind = (g.wingKind or 1) % #WINGS + 1
    elseif key == 'h' then
        g.showPanel = not g.showPanel
    end
end

function s.drawUI()
    local g = garden()
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.print('garden   1-9 add one at the mouse   r new critters   m new Mipo   b bee outline   w wings'
        .. '   p pupils   h panel', 20, love.graphics.getHeight() - 30)
    ui.startFrame()
    -- the spawn bar, two rows: one more in the middle of the view, dropped in from up high
    local bw, gap = 130, 10
    local perRow = math.ceil(#SPAWN / 2)
    for i, kind in ipairs(SPAWN) do
        local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
        local inRow = math.min(perRow, #SPAWN - row * perRow)
        local bx = (love.graphics.getWidth() - (inRow * (bw + gap) - gap)) / 2
        if ui.button(bx + col * (bw + gap), 14 + row * 44, bw, '+ ' .. kind.label) then
            local cx = cam:getWorldCoordinates(love.graphics.getWidth() / 2, 0)
            cx = clamp(cx + love.math.random(-200, 200), -HALF_W + 300, HALF_W - 300)
            local y = GROUND_Y - DROP - 250
            spawn(g, kind, cx, y)
        end
    end
    if not g.showPanel then return end
    local BH, pad, colW = 30, 5, 560
    local perColumn = math.ceil((#TUNE + 1) / 2)
    local h = (BH + pad) * perColumn + pad + 24
    local x0, y0 = 20, 110 -- under the two rows of + buttons
    ui.panel(x0, y0, colW * 2 + pad, h, '•• garden critters ••', function()
        local function slot(i) -- two columns, top to bottom
            local col, rowIndex = math.floor((i - 1) / perColumn), (i - 1) % perColumn
            return x0 + pad + col * colW, y0 + pad + 20 + rowIndex * (BH + pad)
        end
        for i, row in ipairs(TUNE) do
            local key = row[1]
            local x, y = slot(i)
            local step = (row[3] - row[2]) > 50 and 1 or 0.01
            local v = ui.sliderWithInput('garden' .. key, x, y, 160, row[2], row[3], g.settings[key], nil, step)
            if v then g.settings[key] = v + 0 end
            ui.label(x + 260, y, row[5])
        end
        local x, y = slot(#TUNE + 1)
        if ui.button(x, y, 200, 'defaults') then
            for _, row in ipairs(TUNE) do g.settings[row[1]] = row[4] end
        end
    end)
end

return s
