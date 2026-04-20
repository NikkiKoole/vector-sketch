-- main.lua — spine-mesh humanoid sandbox.
--
-- Workflow:
--   1. A polygon (procedural ribbon, cartoon arm, or loaded from a
--      playtime JSON file) appears unbound at its authored position.
--   2. Skeleton is visible in default T-pose — drag joints to place
--      them on the polygon's correct spots (shoulder, elbow, wrist
--      for a limb; head/pelvis/etc for a body).
--   3. Press [r] to bind: the current chain becomes the rest spine.
--   4. Drag any chain joint → polygon deforms around the live curve.
--
-- [t] toggles polygon kind. [space] resets skeleton + unbinds.
-- [ / ] adjust bendiness on the active bind.

local Skeleton = require('skeleton')
local Limb     = require('limb')
local SpineMesh = require('spine-mesh')

local SCREEN_CX, SCREEN_CY = 600, 400 -- where loaded polygon centers

local instance
local polygon     -- current polygon (unbound view)
local bind        -- SpineMesh bind; nil until the user presses [r]
local activeLimb  -- chain name that the bind is against

local dragging    -- joint name currently being dragged, or nil
local DOT_R = 8
local bendiness = 2
local polyKind = 'cartoon' -- 'ribbon' | 'cartoon' | 'loaded'
local LOADED_PATH = os.getenv('HOME') ..
    '/Library/Application Support/LOVE/playtime/shape.playtime.json'

-- For procedural polys we bind to a single chain. For loaded (whole-body)
-- we bind to ALL 5 chains — each vertex picks its closest at bind time.
local FULL_BODY_CHAINS = { 'bodyAxis', 'leftArm', 'rightArm', 'leftLeg', 'rightLeg' }

local function limbForKind(kind)
    if kind == 'loaded' then return 'multi' end
    return 'leftArm'
end

local function chainsForMulti()
    local out = {}
    for _, name in ipairs(FULL_BODY_CHAINS) do
        out[name] = Skeleton.chainPoints(instance, name)
    end
    return out
end

-- Build the current unbound polygon for the selected kind. For procedural
-- shapes (ribbon / cartoon) we base it on the limb's CURRENT chain so the
-- polygon appears overlaid on the skeleton. For loaded, center at screen.
local function buildPolygon()
    activeLimb = limbForKind(polyKind)
    if polyKind == 'loaded' then
        local poly, err = Limb.loadFromPlaytimeJSON(LOADED_PATH, SCREEN_CX, SCREEN_CY)
        if not poly then
            print('load failed:', err, '— falling back to cartoon')
            polyKind = 'cartoon'
            activeLimb = limbForKind(polyKind)
        else
            return poly
        end
    end
    local chain = Skeleton.chainPoints(instance, activeLimb)
    if polyKind == 'cartoon' then
        return Limb.cartoonArmAroundChain(chain)
    else
        return Limb.ribbonAroundChain(chain, 24)
    end
end

-- Snapshot the current chain(s) as rest pose and build the bind.
local function doBind()
    if activeLimb == 'multi' then
        bind = SpineMesh.bindMultiChain(polygon, chainsForMulti())
    else
        local chain = Skeleton.chainPoints(instance, activeLimb)
        bind = SpineMesh.bind(polygon, chain)
    end
end

local function resetAll()
    instance = Skeleton.newInstance()
    polygon = buildPolygon()
    bind = nil
end

function love.load()
    love.window.setTitle('spine-mesh humanoid sandbox')
    love.window.setMode(1200, 768, { resizable = true })
    resetAll()
end

local function hitJoint(x, y)
    for name, p in pairs(instance.pos) do
        local dx, dy = p.x - x, p.y - y
        if dx * dx + dy * dy <= (DOT_R * 2) ^ 2 then return name end
    end
    return nil
end

function love.mousepressed(x, y, button)
    if button == 1 then dragging = hitJoint(x, y) end
end

function love.mousereleased(x, y, button)
    if button == 1 then dragging = nil end
end

function love.mousemoved(x, y)
    if dragging then
        instance.pos[dragging].x = x
        instance.pos[dragging].y = y
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if key == 'r' then doBind() end
    if key == 'u' then bind = nil end -- unbind (show raw polygon again)
    if key == 'space' then resetAll() end
    if key == '[' then bendiness = math.max(0, bendiness - 1) end
    if key == ']' then bendiness = math.min(6, bendiness + 1) end
    if key == 't' then
        polyKind = (polyKind == 'ribbon') and 'cartoon'
            or (polyKind == 'cartoon') and 'loaded'
            or 'ribbon'
        polygon = buildPolygon()
        bind = nil -- polygon changed, require rebind
    end
end

local function drawSkeleton()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.5, 0.5, 0.55)
    for _, e in ipairs(Skeleton.edges()) do
        local a, b = instance.pos[e[1]], instance.pos[e[2]]
        love.graphics.line(a.x, a.y, b.x, b.y)
    end
    love.graphics.setColor(1, 0.55, 0.1)
    for _, p in pairs(instance.pos) do
        love.graphics.circle('fill', p.x, p.y, DOT_R)
    end
    love.graphics.setColor(0.1, 0.1, 0.12)
    for name, p in pairs(instance.pos) do
        love.graphics.print(name, p.x + DOT_R + 2, p.y - 6)
    end
    -- Highlight the active chain(s). For multi, all 5 limb chains glow.
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.2, 0.7, 1.0)
    local function highlight(chainName)
        local chain = Skeleton.limbs[chainName]
        if not chain then return end
        for i = 1, #chain - 1 do
            local a, b = instance.pos[chain[i]], instance.pos[chain[i + 1]]
            if a and b then love.graphics.line(a.x, a.y, b.x, b.y) end
        end
    end
    if activeLimb == 'multi' then
        for _, name in ipairs(FULL_BODY_CHAINS) do highlight(name) end
    else
        highlight(activeLimb)
    end
end

local function drawPolygon()
    if bind then
        local deformed
        if bind.multi then
            deformed = SpineMesh.evaluateMultiChain(bind, chainsForMulti(), bendiness)
        else
            local chain = Skeleton.chainPoints(instance, activeLimb)
            deformed = SpineMesh.evaluate(bind, chain, bendiness)
        end
        if deformed and #deformed >= 6 then
            love.graphics.setColor(0.55, 0.55, 0.55, 0.2)
            love.graphics.polygon('line', bind.polygon)
            love.graphics.setColor(0.85, 0.72, 0.55, 0.35)
            love.graphics.polygon('fill', deformed)
            love.graphics.setColor(0.55, 0.35, 0.15, 1)
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon('line', deformed)
        end
    else
        -- Unbound: just show the polygon as-is.
        love.graphics.setColor(0.85, 0.72, 0.55, 0.25)
        love.graphics.polygon('fill', polygon)
        love.graphics.setColor(0.55, 0.35, 0.15, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon('line', polygon)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.94, 0.94, 0.92)

    drawPolygon()
    drawSkeleton()

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print(
        'drag dots | [r] bind current pose as rest | [u] unbind | [space] reset | [ / ] bendiness | [t] poly | [esc] quit',
        10, 10)
    love.graphics.print('active chain: ' .. (activeLimb or '?') ..
        '  |  polygon: ' .. polyKind ..
        '  |  state: ' .. (bind and 'BOUND — dragging joints deforms' or 'UNBOUND — place joints, then press [r]'),
        10, 28)
    love.graphics.print('bendiness: ' .. bendiness, 10, 46)
end
