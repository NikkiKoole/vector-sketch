-- main.lua
-- Box2D → Bones → Organic Skinned Mesh + Mouse Interaction + Random Mesh Generator
-- Press [M] to regenerate a new random organic mesh variation.
-- LÖVE 11.x

--########################## 2D Affine (3x3) ################################
local M = {}
local function mat(a11, a12, a13, a21, a22, a23, a31, a32, a33)
    return { a11, a12, a13, a21, a22, a23, a31, a32, a33 }
end
function M.identity() return mat(1, 0, 0, 0, 1, 0, 0, 0, 1) end

function M.mul(A, B)
    local C = {}
    C[1]    = A[1] * B[1] + A[2] * B[4] + A[3] * B[7]
    C[2]    = A[1] * B[2] + A[2] * B[5] + A[3] * B[8]
    C[3]    = A[1] * B[3] + A[2] * B[6] + A[3] * B[9]
    C[4]    = A[4] * B[1] + A[5] * B[4] + A[6] * B[7]
    C[5]    = A[4] * B[2] + A[5] * B[5] + A[6] * B[8]
    C[6]    = A[4] * B[3] + A[5] * B[6] + A[6] * B[9]
    C[7]    = A[7] * B[1] + A[8] * B[4] + A[9] * B[7]
    C[8]    = A[7] * B[2] + A[8] * B[5] + A[9] * B[8]
    C[9]    = A[7] * B[3] + A[8] * B[6] + A[9] * B[9]
    return C
end

function M.transform(A, x, y)
    local nx = A[1] * x + A[2] * y + A[3]
    local ny = A[4] * x + A[5] * y + A[6]
    return nx, ny
end

function M.translation(tx, ty) return mat(1, 0, tx, 0, 1, ty, 0, 0, 1) end

function M.rotation(r)
    local c, s = math.cos(r), math.sin(r)
    return mat(c, -s, 0, s, c, 0, 0, 0, 1)
end

function M.scale(sx, sy) return mat(sx, 0, 0, 0, sy or sx, 0, 0, 0, 1) end

function M.TRS(tx, ty, rot, sx, sy)
    return M.mul(M.mul(M.translation(tx, ty), M.rotation(rot or 0)), M.scale(sx or 1, sy or sx or 1))
end

function M.inverse(A)
    local a, b, c, d, e, f = A[1], A[2], A[3], A[4], A[5], A[6]
    local det = a * e - b * d
    if math.abs(det) < 1e-9 then return M.identity() end
    local id = 1 / det
    local na, nb, nd, ne = e * id, -b * id, -d * id, a * id
    local nc = -(na * c + nb * f)
    local nf = -(nd * c + ne * f)
    return mat(na, nb, nc, nd, ne, nf, 0, 0, 1)
end

--############################## Bones ######################################
local Bone = {}
Bone.__index = Bone
function Bone.new(args)
    local b     = setmetatable({}, Bone)
    b.name      = args.name or "bone"
    b.length    = args.length or 100
    b.body      = args.body
    b.parent    = args.parent
    b.worldMat  = M.identity()
    b.bindWorld = nil
    b.bindInv   = nil
    return b
end

function Bone:updateFromPhysics()
    local x, y    = self.body:getPosition()
    local r       = self.body:getAngle()
    self.worldMat = M.TRS(x, y, r, 1, 1)
end

--############################## Mesh #######################################
local Mesh = {}
Mesh.__index = Mesh
function Mesh.new(points, influences)
    local m = setmetatable({}, Mesh)
    m.v_bind = points or {}
    m.v_final = {}
    m.influences = influences or {}
    return m
end

function Mesh:skin()
    for i, v in ipairs(self.v_bind) do
        local sx, sy = 0, 0
        for _, inf in ipairs(self.influences[i]) do
            local bone, w = inf.bone, inf.w
            local lx, ly = M.transform(bone.bindInv, v[1], v[2])
            local wx, wy = M.transform(bone.worldMat, lx, ly)
            sx, sy = sx + w * wx, sy + w * wy
        end
        self.v_final[i] = { sx, sy }
    end
end

--############################## Utils ######################################
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function smoothstep(a, b, x)
    local t = clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end
local function hashf(i)
    local x = math.sin(i * 127.1) * 43758.5453
    return x - math.floor(x)
end
local function randomf(a, b) return a + (b - a) * math.random() end

local function buildSegmentPoints(bone, startOffset, segLen, baseWidth, segs, tStart, chaos)
    local pts, tvals = {}, {}
    for i = 0, segs do
        local t = i / segs
        local x = startOffset + t * segLen
        local width = baseWidth * (0.7 + 0.6 * math.sin(math.pi * (tStart + t))) * randomf(0.85, 1.15)
        local jitL = (hashf((i + 1) * 2.7) - 0.5) * chaos
        local jitR = (hashf((i + 1) * 4.1) - 0.5) * chaos
        local lx, ly = x, -(width * 0.5 + jitL)
        local rx, ry = x, (width * 0.5 + jitR)
        local Lx, Ly = M.transform(bone.bindWorld, lx, ly)
        local Rx, Ry = M.transform(bone.bindWorld, rx, ry)
        table.insert(pts, { Lx, Ly }); table.insert(pts, { Rx, Ry })
        tvals[#pts - 1] = tStart + t * segLen
        tvals[#pts]     = tStart + t * segLen
    end
    return pts, tvals
end

local function buildOrganicArmRibbon(bTorso, bUpper, bLower, lens, width)
    local chaos = randomf(2.0, 6.0)
    local Ltorso, Lupper, Llower = lens.torso, lens.upper, lens.lower
    local segsT, segsU, segsL = 8, 14, 14
    local torsoProxy = bUpper
    local startU = -bUpper.length * 0.5
    local startT = startU - Ltorso
    local startL = -bLower.length * 0.5
    local ptsT, tT = buildSegmentPoints(torsoProxy, startT, Ltorso, width * 1.05, segsT, 0, chaos)
    local ptsU, tU = buildSegmentPoints(bUpper, startU, Lupper, width * 1.00, segsU, Ltorso, chaos)
    local ptsL, tL = buildSegmentPoints(bLower, startL, Llower, width * 0.95, segsL, Ltorso + Lupper, chaos)
    local pts, tvals = {}, {}
    for i = 1, #ptsT do
        pts[#pts + 1] = ptsT[i]; tvals[#tvals + 1] = tT[i]
    end
    for i = 1, #ptsU do
        pts[#pts + 1] = ptsU[i]; tvals[#tvals + 1] = tU[i]
    end
    for i = 1, #ptsL do
        pts[#pts + 1] = ptsL[i]; tvals[#tvals + 1] = tL[i]
    end
    local Ltot = Ltorso + Lupper + Llower
    for i = 1, #tvals do tvals[i] = tvals[i] / Ltot end
    local infl      = {}
    local tShoulder = Ltorso / Ltot
    local tElbow    = (Ltorso + Lupper) / Ltot
    local k         = 0.10
    for i = 1, #pts do
        local t = tvals[i]
        local wT = 1 - smoothstep(tShoulder - k, tShoulder + k, t)
        local wU = smoothstep(tShoulder - k, tShoulder + k, t) * (1 - smoothstep(tElbow - k, tElbow + k, t))
        local wL = smoothstep(tElbow - k, tElbow + k, t)
        local sum = wT + wU + wL; if sum < 1e-6 then
            wT, wU, wL = 1, 0, 0; sum = 1
        end
        wT, wU, wL = wT / sum, wU / sum, wL / sum
        infl[i] = { { bone = bTorso, w = wT }, { bone = bUpper, w = wU }, { bone = bLower, w = wL } }
    end
    return Mesh.new(pts, infl)
end

--############################## Scene ######################################
local world, bodies, joints, bones, skin, mouseJoint
local mouseX, mouseY = 0, 0
local DIM = { torsoW = 80, torsoH = 110, upperW = 120, upperH = 18, lowerW = 110, lowerH = 16 }

local function createSystem()
    world = love.physics.newWorld(0, 980, true)
    local ground = love.physics.newBody(world, 0, 520, "static")
    love.physics.newFixture(ground, love.physics.newEdgeShape(-2000, 0, 2000, 0))
    local torso = love.physics.newBody(world, 360, 280, "static")
    love.physics.newFixture(torso, love.physics.newRectangleShape(DIM.torsoW, DIM.torsoH))
    local shoulderAnchorX = 360 + DIM.torsoW * 0.5
    local shoulderAnchorY = 280 - DIM.torsoH * 0.35
    local upper = love.physics.newBody(world, shoulderAnchorX + DIM.upperW * 0.5, shoulderAnchorY, "dynamic")
    upper:setLinearDamping(0.8); upper:setAngularDamping(1.1)
    love.physics.newFixture(upper, love.physics.newRectangleShape(DIM.upperW, DIM.upperH), 1.0)
    local elbowAnchorX = shoulderAnchorX + DIM.upperW
    local elbowAnchorY = shoulderAnchorY
    local lower = love.physics.newBody(world, elbowAnchorX + DIM.lowerW * 0.5, elbowAnchorY, "dynamic")
    lower:setLinearDamping(0.8); lower:setAngularDamping(1.1)
    love.physics.newFixture(lower, love.physics.newRectangleShape(DIM.lowerW, DIM.lowerH), 1.0)
    local shoulder = love.physics.newRevoluteJoint(torso, upper, shoulderAnchorX, shoulderAnchorY, false)
    --shoulder:setLimitsEnabled(true); shoulder:setLimits(-1.0, 1.0)
    --shoulder:setMotorEnabled(true); shoulder:setMaxMotorTorque(1600); shoulder:setMotorSpeed(0.6)
    local elbow    = love.physics.newRevoluteJoint(upper, lower, elbowAnchorX, elbowAnchorY, false)
    --elbow:setLimitsEnabled(true); elbow:setLimits(-1.4, 1.2)
    --elbow:setMotorEnabled(true); elbow:setMaxMotorTorque(1400); elbow:setMotorSpeed(1.2)
    bodies         = { ground = ground, torso = torso, upper = upper, lower = lower }
    joints         = { shoulder = shoulder, elbow = elbow }
    local bTorso   = Bone.new { name = "torso", length = DIM.torsoW, body = torso }
    local bUpper   = Bone.new { name = "upper", length = DIM.upperW, body = upper, parent = bTorso }
    local bLower   = Bone.new { name = "lower", length = DIM.lowerW, body = lower, parent = bUpper }
    bones          = { bTorso, bUpper, bLower }
    for _, b in ipairs(bones) do
        b:updateFromPhysics(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end
    local lens = { torso = 36, upper = DIM.upperW, lower = DIM.lowerW }
    skin = buildOrganicArmRibbon(bTorso, bUpper, bLower, lens, 28)
end

-- rebuild just the mesh with new randomness
local function regenerateMesh()
    if not bones then return end
    local bTorso, bUpper, bLower = bones[1], bones[2], bones[3]
    local lens = { torso = 36, upper = DIM.upperW, lower = DIM.lowerW }
    -- bump RNG so subsequent runs differ even within same second
    math.randomseed(os.time() + math.floor((love.timer.getTime() or 0) * 1000))
    skin = buildOrganicArmRibbon(bTorso, bUpper, bLower, lens, 10 + 100 * love.math.random())
end

function love.load()
    love.window.setTitle("Box2D → Bones → Organic Skinned Arm + Mouse Drag + Random Mesh")
    love.graphics.setLineWidth(2)
    math.randomseed(os.time())
    createSystem()
end

function love.update(dt)
    world:update(dt)
    if mouseJoint then mouseJoint:setTarget(mouseX, mouseY) end
    for _, b in ipairs(bones) do b:updateFromPhysics() end
    if skin then skin:skin() end
end

--############################## Mouse Picking ##############################
local function bodyAtPoint(x, y)
    local found = nil
    local function cb(fixture)
        if fixture:testPoint(x, y) then
            local b = fixture:getBody()
            if b:getType() == "dynamic" then
                found = b; return false
            end
        end
        return true
    end
    world:queryBoundingBox(x - 1, y - 1, x + 1, y + 1, cb)
    return found
end

function love.mousepressed(x, y, button)
    if button == 1 then
        mouseX, mouseY = x - 80, y - 60
        local b = bodyAtPoint(mouseX, mouseY)
        if b then
            local mj = love.physics.newMouseJoint(b, mouseX, mouseY)
            mj:setDampingRatio(0.7)
            mj:setFrequency(5.0)
            mj:setMaxForce(5000 * b:getMass())
            mouseJoint = mj
        end
    end
end

function love.mousemoved(x, y)
    mouseX, mouseY = x - 80, y - 60
end

function love.mousereleased(_, _, button)
    if button == 1 and mouseJoint then
        mouseJoint:destroy(); mouseJoint = nil
    end
end

--############################## Rendering ##################################
local function drawBodyRect(body, w, h)
    local x, y = body:getPosition()
    local r    = body:getAngle()
    love.graphics.push(); love.graphics.translate(x, y); love.graphics.rotate(r)
    love.graphics.rectangle("line", -w * 0.5, -h * 0.5, w, h)
    love.graphics.pop()
end

local function drawPolyline(points)
    for i = 1, #points - 1 do love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]) end
end

function love.draw()
    love.graphics.push(); love.graphics.translate(80, 60)
    -- ground
    love.graphics.setColor(1, 1, 1, 0.25); love.graphics.line(-10000, 520, 10000, 520)
    -- bodies
    love.graphics.setColor(1, 1, 1, 1)
    drawBodyRect(bodies.torso, DIM.torsoW, DIM.torsoH)
    drawBodyRect(bodies.upper, DIM.upperW, DIM.upperH)
    drawBodyRect(bodies.lower, DIM.lowerW, DIM.lowerH)
    -- joints
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    local sx, sy = joints.shoulder:getAnchors(); local ex, ey = joints.elbow:getAnchors()
    love.graphics.circle("fill", sx, sy, 4); love.graphics.circle("fill", ex, ey, 4)
    -- bones
    love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
    for _, b in ipairs(bones) do
        local sx, sy = M.transform(b.worldMat, -b.length * 0.5, 0)
        local ex, ey = M.transform(b.worldMat, b.length * 0.5, 0)
        love.graphics.line(sx, sy, ex, ey)
        love.graphics.circle("fill", sx, sy, 3); love.graphics.circle("fill", ex, ey, 3)
    end
    -- mesh
    if skin then
        love.graphics.setColor(1, 1, 1, 1)
        local top, bot = {}, {}
        for i = 1, #skin.v_final, 2 do top[#top + 1] = skin.v_final[i] end
        for i = 2, #skin.v_final, 2 do bot[#bot + 1] = skin.v_final[i] end
        drawPolyline(top); drawPolyline(bot)
    end
    -- mouse joint target
    if mouseJoint then
        love.graphics.setColor(1, 1, 0, 0.9); love.graphics.circle("line", mouseX, mouseY, 6)
    end
    love.graphics.pop()
    love.graphics.origin(); love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "Torso + Shoulder + Elbow (Box2D-driven)\n• Drag with LMB to apply forces (MouseJoint)\n• Green = joint anchors, Blue = bone lines, White = organic ribbon\nKeys: R reset & rebind | T toggle motors | M new random mesh",
        14, 14)
end

--############################## Controls ###################################
function love.keypressed(k)
    if k == "r" then
        if mouseJoint then
            mouseJoint:destroy(); mouseJoint = nil
        end
        createSystem()
    elseif k == "t" then
        local on = not joints.shoulder:isMotorEnabled()
        joints.shoulder:setMotorEnabled(on)
        joints.elbow:setMotorEnabled(on)
    elseif k == "m" then
        regenerateMesh()
    end
end
