-- main.lua — spine-mesh humanoid sandbox.
--
-- Run: cd experiments/spine-humanoid-sandbox && love .
--
-- Phase A: draggable skeleton, no meshes.
-- Phase B: one limb bound at startup, deforms as you drag its chain joints.
-- Phase C (future): all four limbs + torso.
-- Phase D (future): texturing.
--
-- Current state: Phase B — leftArm's limb ribbon is bound and redrawn
-- each frame as you drag its three chain joints (leftShoulder,
-- leftElbow, leftWrist).

local Skeleton = require('skeleton')
local Limb     = require('limb')
local SpineMesh = require('spine-mesh')

local instance
local leftArmBind
local dragging -- joint name currently being dragged, or nil
local DOT_R = 8
local bendiness = 2 -- 0 = rubbery, 4 = crisp corners
local polyKind = 'cartoon' -- 'ribbon' | 'cartoon' | 'loaded'
local LOADED_PATH = os.getenv('HOME') .. '/Library/Application Support/LOVE/playtime/shape.playtime.json'

-- Rebuild the bind for a limb from the instance's CURRENT chain. Call
-- this when starting fresh, or after an explicit "rebind at this pose"
-- operation. During normal drag we do NOT rebind; we re-evaluate the
-- existing bind against the moved chain.
local function rebindLimb(limbName)
    local chain = Skeleton.chainPoints(instance, limbName)
    local poly, err
    if polyKind == 'loaded' then
        poly, err = Limb.loadFromPlaytimeJSON(LOADED_PATH, chain)
        if not poly then
            print('load failed:', err, '— falling back to cartoon')
            poly = Limb.cartoonArmAroundChain(chain)
        end
    elseif polyKind == 'cartoon' then
        poly = Limb.cartoonArmAroundChain(chain)
    else
        poly = Limb.ribbonAroundChain(chain, 24)
    end
    return SpineMesh.bind(poly, chain)
end

function love.load()
    love.window.setTitle('spine-mesh humanoid sandbox')
    love.window.setMode(1200, 768, { resizable = true })
    instance = Skeleton.newInstance()
    leftArmBind = rebindLimb('leftArm')
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
    if key == 'r' then
        -- rebind current pose (freeze this as the new rest)
        leftArmBind = rebindLimb('leftArm')
    end
    if key == 'space' then
        -- reset to default pose
        instance = Skeleton.newInstance()
        leftArmBind = rebindLimb('leftArm')
    end
    if key == '[' then bendiness = math.max(0, bendiness - 1) end
    if key == ']' then bendiness = math.min(6, bendiness + 1) end
    if key == 't' then
        polyKind = (polyKind == 'ribbon') and 'cartoon'
            or (polyKind == 'cartoon') and 'loaded'
            or 'ribbon'
        leftArmBind = rebindLimb('leftArm')
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
    for name, p in pairs(instance.pos) do
        love.graphics.circle('fill', p.x, p.y, DOT_R)
    end
    love.graphics.setColor(0.1, 0.1, 0.12)
    for name, p in pairs(instance.pos) do
        love.graphics.print(name, p.x + DOT_R + 2, p.y - 6)
    end
end

local function drawLimb(bind, limbName, fill, outline)
    local chain = Skeleton.chainPoints(instance, limbName)
    local deformed = SpineMesh.evaluate(bind, chain, bendiness)
    if not deformed or #deformed < 6 then return end

    -- Rest polygon, faint grey — so you can see rest vs deformed.
    love.graphics.setColor(0.55, 0.55, 0.55, 0.25)
    love.graphics.polygon('line', bind.polygon)

    -- Deformed polygon.
    love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 0.35)
    love.graphics.polygon('fill', deformed)
    love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon('line', deformed)
end

function love.draw()
    love.graphics.setBackgroundColor(0.94, 0.94, 0.92)

    -- Limb fill first so skeleton dots land on top.
    drawLimb(leftArmBind, 'leftArm',
        { 0.85, 0.72, 0.55 },
        { 0.55, 0.35, 0.15 })

    drawSkeleton()

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print('drag dots | [r] rebind | [space] reset | [ / ] bendiness | [t] toggle poly | [esc] quit', 10, 10)
    love.graphics.print('bound limb: leftArm (shoulder → elbow → wrist)', 10, 28)
    love.graphics.print('bendiness: ' .. bendiness .. '  |  polygon: ' .. polyKind, 10, 46)
end
