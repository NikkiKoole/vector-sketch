-- Haircuts that bounce and sag: the haircut strip (TRACE_VERTICES, ribbon.traceVerticesMesh) keeps
-- its inner edge on the head and lets its outer edge follow a spring: most in the middle, not
-- at all at the ends, so the hair stays attached at the sides and wobbles on top. The spring is pushed by the
-- head's acceleration (the hair lags when thrown, flattens on a landing, wobbles after) and by a
-- sag: gravity as the head feels it minus gravity when upright, so standing up the haircut is as
-- drawn and tilted or upside down it slides toward the floor. Body space, one spring per haircut.
-- Tuned in the settings panel's 'hair bounce' section (src/ui/world-settings.lua). Parked, off by
-- default: "this isnt it really" (2026-10-31), docs/HAIR-LOCKS.md.
local lib = {}

local state = require('src.state')

-- On state, not a module local, so a hot reload keeps the tuning.
state.hairBounce = state.hairBounce or {
    on = false,    -- parked (docs/HAIR-LOCKS.md): turn on in settings → hair bounce
    spring = 60,   -- stiffer: faster, smaller wobble
    damping = 6,   -- higher: settles sooner
    push = 1,      -- how much the head's acceleration moves the hair
    sag = 0.4,     -- how much tilting lets the hair slide toward the floor
    reach = 0.5,   -- farthest the outer edge goes, as a share of the strip's width
    focus = 4,     -- how much only the middle moves: 1 a gentle arch, higher a narrower part on top
}
local settings = state.hairBounce
settings.focus = settings.focus or 4 -- (a tuning table from before focus)

local MAX_ACCEL = 20000 -- px/s²: a hard landing's one-frame stop, clamped
local springs = setmetatable({}, { __mode = 'k' }) -- per haircut extra
local scratch = setmetatable({}, { __mode = 'k' }) -- per mesh: the vertex table written each frame

local function springOf(extra, body)
    local s = springs[extra]
    if not s then
        local vx, vy = body:getLinearVelocity()
        s = { x = 0, y = 0, vx = 0, vy = 0, lastVX = vx, lastVY = vy, appliedX = 0, appliedY = 0 }
        springs[extra] = s
    end
    return s
end

-- How much each vertex follows the spring: 0 on the inner edge, on the outer edge (the one of
-- each pair farther from the outline's centre: the mesh is around it) sin(pi * v) along the
-- strip to the power `focus`, 0 at the ends and 1 in the middle.
local function weights(rest)
    if rest.weights and rest.weightsFocus == settings.focus then return rest.weights end
    local w = {}
    for i = 1, #rest - 1, 2 do
        local a, b = rest[i], rest[i + 1]
        local along = math.sin(math.pi * a[4]) ^ settings.focus
        local aOut = a[1] * a[1] + a[2] * a[2] > b[1] * b[1] + b[2] * b[2]
        w[i], w[i + 1] = aOut and along or 0, aOut and 0 or along
    end
    rest.weights, rest.weightsFocus = w, settings.focus
    return w
end

-- Step the haircut's spring and bend `mesh` (made from `rest`, body space) by it.
function lib.apply(extra, body, mesh, rest, dt)
    if not (mesh and rest) then return end
    local s = springOf(extra, body)
    if not state.world.paused and settings.on then
        dt = math.min(dt, 1 / 30)
        if dt > 0 then
            local vx, vy = body:getLinearVelocity()
            local ax, ay = (vx - s.lastVX) / dt, (vy - s.lastVY) / dt
            s.lastVX, s.lastVY = vx, vy
            local am = math.sqrt(ax * ax + ay * ay)
            if am > MAX_ACCEL then ax, ay = ax / am * MAX_ACCEL, ay / am * MAX_ACCEL end
            -- into body space
            local angle = body:getAngle()
            local c, sn = math.cos(-angle), math.sin(-angle)
            local lax, lay = ax * c - ay * sn, ax * sn + ay * c
            local gx, gy = state.physicsWorld:getGravity()
            local g = math.sqrt(gx * gx + gy * gy)
            local lgx, lgy = gx * c - gy * sn, gx * sn + gy * c
            local fx = -settings.spring * s.x - settings.damping * s.vx - settings.push * lax
                + settings.sag * lgx
            local fy = -settings.spring * s.y - settings.damping * s.vy - settings.push * lay
                + settings.sag * (lgy - g)
            s.vx, s.vy = s.vx + fx * dt, s.vy + fy * dt
            s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
            local reach = settings.reach * (extra.width or 100)
            local d = math.sqrt(s.x * s.x + s.y * s.y)
            if d > reach then
                s.x, s.y = s.x / d * reach, s.y / d * reach
                s.vx, s.vy = s.vx * 0.5, s.vy * 0.5
            end
        end
    end
    local ox, oy = settings.on and s.x or 0, settings.on and s.y or 0
    if math.abs(ox - s.appliedX) + math.abs(oy - s.appliedY) < 0.25
        and rest.weightsFocus == settings.focus then return end
    s.appliedX, s.appliedY = ox, oy
    local weight = weights(rest)
    local verts = scratch[mesh]
    if not verts then
        verts = {}
        for i = 1, #rest do verts[i] = { 0, 0, rest[i][3], rest[i][4] } end
        scratch[mesh] = verts
    end
    for i = 1, #rest do
        local r, v = rest[i], verts[i]
        local k = weight[i]
        v[1], v[2] = r[1] + ox * k, r[2] + oy * k
    end
    mesh:setVertices(verts)
end

-- Where each haircut's outer edge is now (body space px), for a look from the bridge.
function lib.offsets()
    local out = {}
    for _, s in pairs(springs) do out[#out + 1] = string.format('%.1f,%.1f', s.x, s.y) end
    return out
end

local function field(key, kind, min, max)
    return { key = key, kind = kind, min = min, max = max,
        get = function(t) return t[key] end,
        set = function(t, v) t[key] = v end }
end

-- What the settings panel shows (src/ui/inspector.lua rows), on lib.settings.
lib.settings = settings
lib.rows = {
    field('on', 'bool'),
    field('spring', 'number', 5, 300),
    field('damping', 'number', 0, 40),
    field('push', 'number', 0, 3),
    field('sag', 'number', 0, 1.5),
    field('reach', 'number', 0, 1.5),
    field('focus', 'number', 1, 12),
}

return lib
