-- blob.lua — the SOFTBODY sfixture: a squishy blob around its body (docs/BLOBS.md).
--
-- The body is an ordinary thing: saved, selectable, clonable, can carry behaviors and
-- joints. The sfixture holds the settings and the look (OMP layers in extra.main, baked
-- by makeCombinedImages like a texfixture). Its outline is the picture's own: the
-- shape8 outline of extra.main.bgURL.
--
-- The rim is built at runtime from those settings and never saved: small circle bodies
-- along the outline, rigid links and bend springs between neighbours, shape matching
-- (every point pulled toward its spot in the rest shape fitted onto the rim) and gas
-- pressure. The body is tied to the rim's middle by a stiff damped pull (the opposite
-- pull spread over the rim) and is made heavier than the rim, so dragging it carries the
-- blob. It used to hang on distance-joint spokes: those only know lengths, so a hard drag
-- pulled the body out through the rim and left it there. Rim bodies have no
-- userData and aren't registered, so save, selection, scripts and signals skip them;
-- `lib.ownerOf` maps one back to its blob. The body's own collision shape collides
-- with nothing (it's the handle to carry the blob by).
--
-- Drawn as one mesh fixed at rest (middle, inner rings, rim) whose inside follows the
-- rim with mean value coordinates, from a smoothed copy of the rim: the physics rim
-- kinks under a squash and a kink folds the triangles next to it.
-- The spike with the measurements behind these choices: experiments/blob-spike.
local lib = {}

local state = require('src.state')
local subtypes = require('src.subtypes')
local registry = require('src.registry')
local units = require('src.physics-units')

-- What a new blob starts with (also the fallback for missing keys).
lib.defaults = {
    height = 300,       -- world units, the outline's height at rest
    rimPoints = 28,     -- rim bodies (not 'nodes': io.lua takes extra.nodes for a ribbon's joints)
    -- Hz below are as at 100 px per metre (src/physics-units.lua)
    stiffness = 4,      -- shape matching, Hz (capped by the step: stable up to ~1 / (2 pi dt))
    damping = 0.5,      -- shape matching, damping ratio
    pressure = 1,       -- 1: at 10% less area the rim pushes out with ~3x the blob's weight
    bend = 3,           -- bend springs, Hz (0 = off; 10+ made blobs cave in)
    friction = 0.7,
    restitution = 0.05,
    drawSmooth = 4,     -- smoothing passes over the rim, for drawing only
    zOffset = 0,
    zGroupOffset = 0,
}

local RINGS = 3 -- inner mesh rings between the middle and the rim
local HANDLE_HZ = 8 -- the body's pull toward the rim's middle
local HANDLE_MASS = 2 -- the body's mass, in rim masses
-- Rims live on `state` and outlive a hot reload of this file; one built by an older
-- version of it is rebuilt. Bump when the runtime's layout changes.
local BUILD = 2

-- runtime per SOFTBODY sfixture id; on state so a hot reload keeps the blobs
state.blobs = state.blobs or {}
-- rim body -> runtime
state.blobRims = state.blobRims or setmetatable({}, { __mode = 'k' })

local function setting(extra, key)
    local v = extra[key]
    if v == nil then return lib.defaults[key] end
    return v
end

-- A random OMP look on one of the head/body shapes.
local LOOK_SHAPES = { 'shapeA1', 'shapeA2', 'shapeA3', 'shapeA4',
    'shapes1', 'shapes2', 'shapes3', 'shapes4', 'shapes5' }
local LOOK_PATTERNS = { 'type0.png', 'type1.png', 'type2t.png', 'type3_.png', 'type6.png' }
function lib.randomLook()
    local function hex() return string.format('%02X%02X%02XFF', love.math.random(40, 240),
        love.math.random(40, 240), love.math.random(40, 240)) end
    local shape = LOOK_SHAPES[love.math.random(#LOOK_SHAPES)]
    return { bgURL = shape .. '.png', fgURL = shape .. '-mask.png',
        pURL = LOOK_PATTERNS[love.math.random(#LOOK_PATTERNS)],
        bgHex = '000000ff', fgHex = hex(), pHex = hex() }
end

function lib.newExtra()
    local extra = { OMP = true, dirty = true, main = lib.randomLook() }
    for k, v in pairs(lib.defaults) do extra[k] = v end
    return extra
end

---------------------------------------------------------------- outline -> rim

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- The picture's outline: shape8 points in texture space over `dimensions`. A picture
-- without one gets an oval over its image.
local function outlineOf(bgURL)
    local shape = bgURL and require('src.shape8-dict')[bgURL]
    if shape then return shape.vertices, shape.dimensions[1], shape.dimensions[2] end
    local w, h = 200, 200
    local info = bgURL and love.filesystem.getInfo('textures/' .. bgURL, 'file')
    if info then
        local ok, img = pcall(love.graphics.newImage, 'textures/' .. bgURL)
        if ok then w, h = img:getDimensions(); img:release() end
    end
    local verts = {}
    for i = 0, 7 do
        local a = -math.pi / 2 + i * math.pi / 4
        verts[#verts + 1] = math.cos(a) * w * 0.45
        verts[#verts + 1] = math.sin(a) * h * 0.45
    end
    return verts, w, h
end

-- closed Catmull-Rom through the outline, then n points evenly spaced along it
local function resampleOutline(flat, n)
    local pts = {}
    for i = 1, #flat, 2 do pts[#pts + 1] = { flat[i], flat[i + 1] } end
    local m, dense, STEPS = #pts, {}, 24
    for i = 1, m do
        local p0, p1 = pts[(i - 2) % m + 1], pts[i]
        local p2, p3 = pts[i % m + 1], pts[(i + 1) % m + 1]
        for s = 0, STEPS - 1 do
            local t = s / STEPS
            dense[#dense + 1] = { catmull(p0[1], p1[1], p2[1], p3[1], t), catmull(p0[2], p1[2], p2[2], p3[2], t) }
        end
    end
    local lengths, total = { 0 }, 0
    for i = 1, #dense do
        local a, b = dense[i], dense[i % #dense + 1]
        total = total + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        lengths[i + 1] = total
    end
    local out, j = {}, 1
    for k = 0, n - 1 do
        local target = total * k / n
        while lengths[j + 1] < target do j = j + 1 end
        local a, b = dense[j], dense[j % #dense + 1]
        local t = (target - lengths[j]) / math.max(lengths[j + 1] - lengths[j], 1e-6)
        out[#out + 1] = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
    end
    return out, total
end

-- a group index no fixture uses yet: a blob's own rim circles mustn't collide
local function freeGroupIndex()
    local lowest = 0
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, f in ipairs(body:getFixtures()) do lowest = math.min(lowest, f:getGroupIndex()) end
    end
    return lowest - 1
end

---------------------------------------------------------------- build / destroy

local function signature(extra)
    local bgURL = tostring((extra.main or {}).bgURL)
    return table.concat({ bgURL, setting(extra, 'height'), setting(extra, 'rimPoints') }, '|')
end

local function jointSignature(extra)
    return table.concat({ setting(extra, 'stiffness'), setting(extra, 'damping'), setting(extra, 'bend'),
        setting(extra, 'friction'), setting(extra, 'restitution') }, '|')
end

local function applyJointSettings(rt, extra)
    for _, j in ipairs(rt.bends) do
        if not j:isDestroyed() then j:setFrequency(units.rate(setting(extra, 'bend'))); j:setDampingRatio(0.7) end
    end
    for _, f in ipairs(rt.rimFixtures) do
        f:setFriction(setting(extra, 'friction'))
        f:setRestitution(setting(extra, 'restitution'))
    end
    rt.jointSignature = jointSignature(extra)
end

local function destroy(rt)
    for _, node in ipairs(rt.nodes) do
        state.blobRims[node] = nil
        if not node:isDestroyed() then node:destroy() end -- takes its joints with it
    end
    if rt.mesh then rt.mesh:release() end
    state.blobs[rt.id] = nil
end

local buildMesh -- below

local function build(fixture)
    local ud, body = fixture:getUserData(), fixture:getBody()
    local extra = ud.extra
    local world = state.physicsWorld
    local outline, dw, dh = outlineOf((extra.main or {}).bgURL)
    local nodes = math.max(8, math.floor(setting(extra, 'rimPoints')))
    local scale = setting(extra, 'height') / dh
    local points, perimeter = resampleOutline(outline, nodes)
    local cxs, cys = 0, 0
    for _, p in ipairs(points) do cxs, cys = cxs + p[1], cys + p[2] end
    cxs, cys = cxs / #points, cys / #points

    local r = perimeter * scale / nodes * 0.5 -- neighbours just touch
    local group = freeGroupIndex()
    local bx, by = body:getPosition()
    local angle = body:getAngle()
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local vx, vy = body:getLinearVelocity()

    local rt = { build = BUILD, id = ud.id, fixture = fixture, body = body, nodes = {}, rimFixtures = {}, uvs = {},
        rest = {}, links = {}, bends = {}, r = r, signature = signature(extra), rim = {}, rimVerts = {},
        centreUV = { cxs / dw + 0.5, cys / dh + 0.5 } }

    -- winding of the outline, for normals and pressure
    local signed = 0
    for i = 1, #points do
        local p, q = points[i], points[i % #points + 1]
        signed = signed + p[1] * q[2] - q[1] * p[2]
    end
    rt.winding = signed > 0 and 1 or -1

    local nodeShape = love.physics.newCircleShape(r)
    for i, p in ipairs(points) do
        local a, b = points[(i - 2) % #points + 1], points[i % #points + 1]
        local tx, ty = b[1] - a[1], b[2] - a[2]
        local len = math.max(math.sqrt(tx * tx + ty * ty), 1e-6)
        local nx, ny = ty / len * rt.winding, -tx / len * rt.winding
        -- inset by r, so the circles' outer edge lies on the outline
        local lx, ly = (p[1] - cxs) * scale - nx * r, (p[2] - cys) * scale - ny * r
        local wx, wy = bx + lx * cosA - ly * sinA, by + lx * sinA + ly * cosA
        local node = love.physics.newBody(world, wx, wy, 'dynamic')
        local f = love.physics.newFixture(node, nodeShape, 1)
        f:setGroupIndex(group)
        node:setFixedRotation(true)
        node:setLinearVelocity(vx, vy)
        rt.nodes[i] = node
        rt.rimFixtures[i] = f
        rt.uvs[i] = { p[1] / dw + 0.5, p[2] / dh + 0.5 }
        rt.rest[i] = { lx, ly } -- rest spot, body-local at angle 0 (re-centred below)
        state.blobRims[node] = rt
    end
    local n = #rt.nodes
    for i = 1, n do
        local a, b = rt.nodes[i], rt.nodes[i % n + 1]
        local ax, ay = a:getPosition()
        local cx, cy = b:getPosition()
        rt.links[i] = love.physics.newDistanceJoint(a, b, ax, ay, cx, cy, false) -- rigid
    end
    if setting(extra, 'bend') > 0 then
        for i = 1, n do
            local a, b = rt.nodes[i], rt.nodes[(i + 1) % n + 1]
            local ax, ay = a:getPosition()
            local cx, cy = b:getPosition()
            rt.bends[i] = love.physics.newDistanceJoint(a, b, ax, ay, cx, cy, false)
        end
    end
    applyJointSettings(rt, extra)

    -- rest shape around its own middle, for shape matching
    local mx, my = 0, 0
    for _, p in ipairs(rt.rest) do mx, my = mx + p[1] / n, my + p[2] / n end
    for _, p in ipairs(rt.rest) do p[1], p[2] = p[1] - mx, p[2] - my end
    -- a heavy handle: the pull that ties it to the rim then barely stretches while dragging
    local rimMass = 0
    for _, node in ipairs(rt.nodes) do rimMass = rimMass + node:getMass() end
    rt.handleMass = rimMass * HANDLE_MASS
    rt.theta = angle

    -- rest area (signed, same winding as the rim) and the pressure that goes with it
    local area = 0
    for i = 1, n do
        local ax, ay = rt.nodes[i]:getPosition()
        local cx, cy = rt.nodes[i % n + 1]:getPosition()
        area = area + ax * cy - cx * ay
    end
    rt.restArea = area / 2
    local mass = rt.handleMass + rimMass
    local gx, gy = world:getGravity()
    rt.pressureK = 30 * mass * math.sqrt(gx * gx + gy * gy) / (perimeter * scale)

    buildMesh(rt, extra)
    state.blobs[rt.id] = rt
    return rt
end

---------------------------------------------------------------- per step

-- Gas pressure (dreamengine jelly.c): push every rim edge outwards, harder the more the
-- area shrank. Signed area and winding normals, so an inside-out blob is pushed back out.
local function applyPressure(rt, extra)
    local pressure = setting(extra, 'pressure')
    if pressure <= 0 then return end
    local nodes, n = rt.nodes, #rt.nodes
    local xs, ys = rt._xs or {}, rt._ys or {}
    rt._xs, rt._ys = xs, ys
    local signed = 0
    for i = 1, n do xs[i], ys[i] = nodes[i]:getPosition() end
    for i = 1, n do
        local j = i % n + 1
        signed = signed + xs[i] * ys[j] - xs[j] * ys[i]
    end
    signed = signed / 2
    local k = rt.pressureK
    local p = pressure * k * (rt.restArea - signed) / rt.restArea
    p = math.max(-k, math.min(p, 5 * k))
    local w = rt.restArea > 0 and 1 or -1
    for i = 1, n do
        local j = i % n + 1
        local fx, fy = (ys[j] - ys[i]) * w * p * 0.5, -(xs[j] - xs[i]) * w * p * 0.5
        nodes[i]:applyForce(fx, fy)
        nodes[j]:applyForce(fx, fy)
    end
end

local function wrapAngle(a)
    return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Shape matching: fit the rest shape onto the rim (its middle, best rotation) and pull
-- every rim point toward its spot in it, damped against the rim's own motion. The rim
-- keeps its shape on its own and can't turn inside out. Then tie the body to the rim's
-- middle and turn it with the rim; the opposite pull goes to the rim, so a pointer
-- dragging the body carries the whole blob.
local function shapeMatch(rt, extra, dt)
    local nodes, n, rest = rt.nodes, #rt.nodes, rt.rest
    local cx, cy, vcx, vcy = 0, 0, 0, 0
    local xs, ys = rt._mx or {}, rt._my or {}
    rt._mx, rt._my = xs, ys
    for i = 1, n do
        xs[i], ys[i] = nodes[i]:getPosition()
        local vx, vy = nodes[i]:getLinearVelocity()
        cx, cy, vcx, vcy = cx + xs[i] / n, cy + ys[i] / n, vcx + vx / n, vcy + vy / n
    end
    local sxx, sxy = 0, 0
    for i = 1, n do
        local ax, ay = rest[i][1], rest[i][2]
        local bx, by = xs[i] - cx, ys[i] - cy
        sxx, sxy = sxx + ax * bx + ay * by, sxy + ax * by - ay * bx
    end
    local theta = math.atan2(sxy, sxx)
    local spin = wrapAngle(theta - (rt.theta or theta)) / dt
    rt.theta = theta
    local c, s = math.cos(theta), math.sin(theta)

    -- explicit springs: stable while omega * dt stays under ~1
    local maxOmega = 1 / dt
    local omega = math.min(2 * math.pi * units.rate(setting(extra, 'stiffness')), maxOmega)
    local zeta = setting(extra, 'damping')
    for i = 1, n do
        local ax, ay = rest[i][1], rest[i][2]
        local tx, ty = cx + ax * c - ay * s, cy + ax * s + ay * c
        local m = nodes[i]:getMass()
        local vx, vy = nodes[i]:getLinearVelocity()
        -- the rim's own velocity at this point: moving along and spinning
        local rvx, rvy = vcx - spin * (ty - cy), vcy + spin * (tx - cx)
        nodes[i]:applyForce(m * omega * omega * (tx - xs[i]) + 2 * m * omega * zeta * (rvx - vx),
            m * omega * omega * (ty - ys[i]) + 2 * m * omega * zeta * (rvy - vy))
    end

    -- the handle
    local body = rt.body
    if math.abs(body:getMass() - rt.handleMass) > rt.handleMass * 1e-3 then
        local lx, ly, mass, inertia = body:getMassData()
        body:setMassData(lx, ly, rt.handleMass, inertia * rt.handleMass / math.max(mass, 1e-9))
    end
    -- body and rim pull on each other: a spring between two masses, so it's tuned on the
    -- reduced mass (tuned on the body's mass alone it ran 1.7x too fast and the explicit
    -- damping overshot every step: velocities flipped sign each frame and grew)
    local hOmega = math.min(2 * math.pi * units.rate(HANDLE_HZ), 0.5 * maxOmega)
    local mb = body:getMass()
    local mr = rt.handleMass / HANDLE_MASS
    local mu = mb * mr / (mb + mr)
    local bx, by = body:getPosition()
    local bvx, bvy = body:getLinearVelocity()
    local fx = mu * hOmega * hOmega * (cx - bx) + 2 * mu * hOmega * (vcx - bvx)
    local fy = mu * hOmega * hOmega * (cy - by) + 2 * mu * hOmega * (vcy - bvy)
    body:applyForce(fx, fy)
    for i = 1, n do nodes[i]:applyForce(-fx / n, -fy / n) end
    local inertia = body:getInertia() -- the turn has no counter-torque on the rim: plain spring
    body:applyTorque(inertia * hOmega * hOmega * wrapAngle(theta - body:getAngle())
        + 2 * inertia * hOmega * (spin - body:getAngularVelocity()))
end

-- The editor moved or turned the body (drag, rotate, set position): take the rim along.
local function followTeleport(rt)
    local x, y = rt.body:getPosition()
    local a = rt.body:getAngle()
    if not rt.lastX or (x == rt.lastX and y == rt.lastY and a == rt.lastA) then return end
    local da = a - rt.lastA
    local c, s = math.cos(da), math.sin(da)
    for _, node in ipairs(rt.nodes) do
        local nx, ny = node:getPosition()
        local rx, ry = nx - rt.lastX, ny - rt.lastY
        node:setPosition(x + rx * c - ry * s, y + rx * s + ry * c)
        node:setLinearVelocity(rt.body:getLinearVelocity())
    end
end

local function rimIntact(rt)
    if rt.body:isDestroyed() then return false end
    for _, node in ipairs(rt.nodes) do
        if node:isDestroyed() then return false end
    end
    return true
end

-- Before the physics step (also while paused): build, rebuild and drop rims to match the
-- SOFTBODY sfixtures in the world, follow editor moves, push the pressure.
function lib.beforeStep(paused, dt)
    dt = dt or 1 / 60
    local world = state.physicsWorld
    if not world then return end
    local seen = {}
    -- the registered sfixtures, not every fixture of every body (BUG17)
    for _, fixture in pairs(registry.sfixtures) do
        local ud = not fixture:isDestroyed() and fixture:getUserData()
        local body = ud and fixture:getBody()
        if type(ud) == 'table' and subtypes.is(ud, subtypes.SOFTBODY) and ud.extra
            and body:getWorld() == world and not state.blobRims[body] then
            seen[ud.id] = true
            local rt = state.blobs[ud.id]
            if rt and (rt.build ~= BUILD or rt.body ~= body or not rimIntact(rt)
                    or rt.signature ~= signature(ud.extra)) then
                destroy(rt)
                rt = nil
            end
            if rt then
                rt.fixture = fixture -- moving/resizing the sfixture replaces the fixture
                followTeleport(rt)
                if rt.jointSignature ~= jointSignature(ud.extra) then applyJointSettings(rt, ud.extra) end
            else
                rt = build(fixture)
            end
            -- the body's own shape is only a handle: it collides with nothing
            for _, f in ipairs(body:getFixtures()) do
                if not f:getUserData() then f:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16) end
            end
            if not paused and dt > 0 then
                shapeMatch(rt, ud.extra, dt)
                applyPressure(rt, ud.extra)
            end
        end
    end
    for id, rt in pairs(state.blobs) do
        if not seen[id] then destroy(rt) end
    end
end

-- After the physics step: where the body is now, so an editor move shows up as a jump.
local function insideRim(rt, x, y)
    local inside, n = false, #rt.nodes
    local jx, jy = rt.nodes[n]:getPosition()
    for k = 1, n do
        local ix, iy = rt.nodes[k]:getPosition()
        if ((iy > y) ~= (jy > y)) and (x < (jx - ix) * (y - iy) / (jy - iy) + ix) then inside = not inside end
        jx, jy = ix, iy
    end
    return inside
end

-- The handle stays inside its rim. The pull that ties them is a spring, and a hard yank
-- (the pointer on the handle at full drag force) outran it: at the game's 100 px per metre
-- Box2D lets a body move 200 px a step, at the 30 the specs used to run at only 60, which
-- had hidden it. An escaped handle goes back just inside, on the line to the rim's middle,
-- moving with the rim; the pointer keeps pulling and the spring takes the rim along.
local function keepHandleInside(rt)
    local x, y = rt.body:getPosition()
    if insideRim(rt, x, y) then return end
    local n = #rt.nodes
    local cx, cy, vx, vy = 0, 0, 0, 0
    for _, node in ipairs(rt.nodes) do
        local nx, ny = node:getPosition()
        local nvx, nvy = node:getLinearVelocity()
        cx, cy, vx, vy = cx + nx / n, cy + ny / n, vx + nvx / n, vy + nvy / n
    end
    if not insideRim(rt, cx, cy) then return end -- a rim folded around its own middle: leave it
    -- the rim's edge on the line from the middle (t = 0) to the handle (t = 1)
    local lo, hi = 0, 1
    for _ = 1, 10 do
        local t = (lo + hi) / 2
        if insideRim(rt, cx + (x - cx) * t, cy + (y - cy) * t) then lo = t else hi = t end
    end
    local t = lo * 0.8
    rt.body:setPosition(cx + (x - cx) * t, cy + (y - cy) * t)
    rt.body:setLinearVelocity(vx, vy)
end

function lib.afterStep()
    for _, rt in pairs(state.blobs) do
        if rimIntact(rt) then keepHandleInside(rt) end
        if not rt.body:isDestroyed() then
            rt.lastX, rt.lastY = rt.body:getPosition()
            rt.lastA = rt.body:getAngle()
        end
    end
end

-- The blob whose rim (x, y) is inside: its body and the body's own (handle) fixture.
-- Only the rim circles and the small handle circle are fixtures, so a press in between
-- would otherwise grab nothing.
function lib.hitAt(x, y)
    for _, rt in pairs(state.blobs) do
        if rimIntact(rt) and insideRim(rt, x, y) then
            for _, f in ipairs(rt.body:getFixtures()) do
                if not f:getUserData() then return rt.body, f end
            end
        end
    end
end

-- The blob body a rim body belongs to (nil for anything else).
function lib.ownerOf(body)
    local rt = body and state.blobRims[body]
    return rt and rt.body or nil
end

-- A whole blob's mass (rim and body) for its body or one of its rim bodies; nil otherwise.
function lib.massOf(body)
    local owner = lib.ownerOf(body) or body
    for _, rt in pairs(state.blobs) do
        if rt.body == owner and rt.handleMass then
            return rt.handleMass * (1 + 1 / HANDLE_MASS)
        end
    end
    return nil
end

-- The SOFTBODY sfixture of a blob body (nil for anything else).
function lib.sfixtureOf(body)
    for _, rt in pairs(state.blobs) do
        if rt.body == body and not rt.fixture:isDestroyed() then return rt.fixture end
    end
end

---------------------------------------------------------------- drawing

-- The drawn rim: rim positions smoothed (drawing only), pushed out by r along the normal
-- (so the circles' outer edge is the picture's edge), plus Catmull-Rom midpoints.
local function computeRim(rt, extra)
    local nodes, n, w = rt.nodes, #rt.nodes, rt.winding
    local xs, ys = rt._dx or {}, rt._dy or {}
    local tx, ty = rt._tx or {}, rt._ty or {}
    rt._dx, rt._dy, rt._tx, rt._ty = xs, ys, tx, ty
    for i = 1, n do xs[i], ys[i] = nodes[i]:getPosition() end
    -- Taubin: a shrink pass then an inflate pass irons out kinks without shrinking
    for _ = 1, setting(extra, 'drawSmooth') do
        for _, f in ipairs({ 0.5, -0.53 }) do
            for i = 1, n do
                local a, b = (i - 2) % n + 1, i % n + 1
                tx[i] = xs[i] + f * ((xs[a] + xs[b]) / 2 - xs[i])
                ty[i] = ys[i] + f * ((ys[a] + ys[b]) / 2 - ys[i])
            end
            for i = 1, n do xs[i], ys[i] = tx[i], ty[i] end
        end
    end
    local rim = rt.rim
    for i = 1, n do
        local a, b = (i - 2) % n + 1, i % n + 1
        local ex, ey = xs[b] - xs[a], ys[b] - ys[a]
        local len = math.max(math.sqrt(ex * ex + ey * ey), 1e-6)
        local nx, ny = ey / len * w, -ex / len * w -- from the winding: never flips in a dent
        local rv = rim[i] or {}
        rv[1], rv[2] = xs[i] + nx * rt.r, ys[i] + ny * rt.r
        rv[3], rv[4] = rt.uvs[i][1], rt.uvs[i][2]
        rim[i] = rv
    end
    local out, k = rt.rimVerts, 1
    for i = 1, n do
        local p0, p1, p2, p3 = rim[(i - 2) % n + 1], rim[i], rim[i % n + 1], rim[(i + 1) % n + 1]
        local v = out[k] or {}
        v[1], v[2], v[3], v[4] = p1[1], p1[2], p1[3], p1[4]
        out[k] = v
        v = out[k + 1] or {}
        for c = 1, 4 do v[c] = catmull(p0[c], p1[c], p2[c], p3[c], 0.5) end
        out[k + 1] = v
        k = k + 2
    end
    return out
end

-- Mean value coordinates of (px, py) in a polygon: weights that rebuild the point from
-- the polygon's corners, smooth inside, also for dented shapes.
local function mvcWeights(px, py, poly)
    local m = #poly
    local dist, angle, weights, sum = {}, {}, {}, 0
    for i = 1, m do
        local dx, dy = poly[i][1] - px, poly[i][2] - py
        dist[i] = math.max(math.sqrt(dx * dx + dy * dy), 1e-6)
    end
    for i = 1, m do
        local j = i % m + 1
        local ax, ay = poly[i][1] - px, poly[i][2] - py
        local bx, by = poly[j][1] - px, poly[j][2] - py
        angle[i] = math.atan2(ax * by - ay * bx, ax * bx + ay * by)
    end
    for i = 1, m do
        weights[i] = (math.tan(angle[(i - 2) % m + 1] / 2) + math.tan(angle[i] / 2)) / dist[i]
        sum = sum + weights[i]
    end
    for i = 1, m do weights[i] = weights[i] / sum end
    return weights
end

-- Triangles fixed at rest: middle, RINGS inner rings, rim. Each frame the inner vertices
-- are rebuilt from the rim with the weights taken here (a fan from one middle point
-- folded as soon as a squash hid part of the rim from it).
buildMesh = function(rt, extra)
    local rest = computeRim(rt, extra)
    local m = #rest
    local cx, cy, cu, cv = 0, 0, 0, 0
    for _, r in ipairs(rest) do cx, cy, cu, cv = cx + r[1], cy + r[2], cu + r[3], cv + r[4] end
    cx, cy, cu, cv = cx / m, cy / m, cu / m, cv / m
    local restPoly = {}
    for i = 1, m do restPoly[i] = { rest[i][1], rest[i][2] } end

    local verts, inner, map = {}, {}, {}
    for i = 1, m do verts[i] = { rest[i][1], rest[i][2], rest[i][3], rest[i][4], 1, 1, 1, 1 } end
    local function addInner(t, r)
        local x, y = cx + (r[1] - cx) * t, cy + (r[2] - cy) * t
        verts[#verts + 1] = { x, y, cu + (r[3] - cu) * t, cv + (r[4] - cv) * t, 1, 1, 1, 1 }
        inner[#inner + 1] = { index = #verts, weights = mvcWeights(x, y, restPoly) }
        return #verts
    end
    local function tri(a, b, c) map[#map + 1], map[#map + 2], map[#map + 3] = a, b, c end
    local centre = addInner(0, rest[1])
    local rings = {}
    for k = 1, RINGS do
        rings[k] = {}
        for i = 1, m do rings[k][i] = addInner(k / (RINGS + 1), rest[i]) end
    end
    rings[RINGS + 1] = {}
    for i = 1, m do rings[RINGS + 1][i] = i end
    for i = 1, m do tri(centre, rings[1][i], rings[1][i % m + 1]) end
    for k = 1, RINGS do
        local a, b = rings[k], rings[k + 1]
        for i = 1, m do
            local j = i % m + 1
            tri(a[i], b[i], b[j])
            tri(a[i], b[j], a[j])
        end
    end
    rt.verts, rt.inner = verts, inner
    rt.mesh = love.graphics.newMesh(verts, 'triangles', 'stream')
    rt.mesh:setVertexMap(map)
end

local function updateMesh(rt, extra)
    local rimVerts = computeRim(rt, extra)
    local verts, m = rt.verts, #rimVerts
    for i = 1, m do verts[i][1], verts[i][2] = rimVerts[i][1], rimVerts[i][2] end
    for _, inner in ipairs(rt.inner) do
        local x, y, ws = 0, 0, inner.weights
        for i = 1, m do x, y = x + ws[i] * rimVerts[i][1], y + ws[i] * rimVerts[i][2] end
        verts[inner.index][1], verts[inner.index][2] = x, y
    end
    rt.mesh:setVertices(verts)
end

function lib.draw(fixture)
    local ud = fixture:getUserData()
    local rt = ud and state.blobs[ud.id]
    if not rt or not rimIntact(rt) then return end
    updateMesh(rt, ud.extra)
    local img = ud.extra.ompImage
    if img then
        rt.mesh:setTexture(img)
        love.graphics.setColor(1, 1, 1, 1)
    else
        rt.mesh:setTexture()
        love.graphics.setColor(0.8, 0.6, 0.7, 1)
    end
    love.graphics.draw(rt.mesh)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib
