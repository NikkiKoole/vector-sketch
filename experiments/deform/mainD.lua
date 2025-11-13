-- main.lua
-- Simple T‑pose character: 1 torso + 2 arms (each 2 bones)
-- Starts in a static T‑pose. Press SPACE to toggle idle arm sway.

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
    b.length    = args.length or 60
    b.localRot  = args.localRot or 0
    b.localPos  = args.localPos or { 0, 0 }
    b.parent    = args.parent
    b.localMat  = M.TRS(b.localPos[1], b.localPos[2], b.localRot, 1, 1)
    b.worldMat  = M.identity()
    b.bindWorld = nil
    b.bindInv   = nil
    return b
end

function Bone:updateLocal() self.localMat = M.TRS(self.localPos[1], self.localPos[2], self.localRot, 1, 1) end

function Bone:updateWorld()
    if self.parent then
        self.worldMat = M.mul(self.parent.worldMat, self.localMat)
    else
        self.worldMat =
            self.localMat
    end
end

--############################## Mesh #######################################
local Mesh = {}
Mesh.__index = Mesh
function Mesh.new(points, influences)
    local m = setmetatable({}, Mesh)
    m.v_bind = points
    m.v_final = {}
    m.influences = influences
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

--########################## Geometry Helpers ###############################
local function lerp(a, b, t) return a + (b - a) * t end
local function mix2(ax, ay, bx, by, t) return lerp(ax, bx, t), lerp(ay, by, t) end
local function hashf(i)
    local x = math.sin(i * 127.1) * 43758.5453
    return x - math.floor(x)
end

local function makeRibbon(p0x, p0y, p1x, p1y, width, segs, jitter)
    local pts, tvals = {}, {}
    for i = 0, segs do
        local t = i / segs
        local cx, cy = mix2(p0x, p0y, p1x, p1y, t)
        local dx, dy = p1x - p0x, p1y - p0y
        local len = math.sqrt(dx * dx + dy * dy) + 1e-6
        local nx, ny = -dy / len, dx / len
        local jit = (jitter or 0) * (hashf(i * 1.23) - 0.5)
        local w = width
        local lx, ly = cx + (w * 0.5 + jit) * nx, cy + (w * 0.5 + jit) * ny
        local rx, ry = cx - (w * 0.5 + jit) * nx, cy - (w * 0.5 + jit) * ny
        table.insert(pts, { lx, ly }); table.insert(pts, { rx, ry }); tvals[#pts - 1] = t; tvals[#pts] = t
    end
    return pts, tvals
end

local function limbMeshAt(originX, originY, lengthA, lengthB, width, segs)
    -- Two straight segments along +x from origin (bind pose)
    local p0x, p0y = originX, originY
    local elbowX, elbowY = originX + lengthA, originY
    local tipX, tipY = elbowX + lengthB, originY
    local pts1, tv1 = makeRibbon(p0x, p0y, elbowX, elbowY, width, math.floor(segs * 0.5))
    local pts2, tv2 = makeRibbon(elbowX, elbowY, tipX, tipY, width * 0.92, segs)
    for i = 1, #pts2 do
        table.insert(pts1, pts2[i]); table.insert(tv1, 0.5 + 0.5 * tv2[i])
    end
    return pts1, tv1, elbowX, elbowY, tipX, tipY
end

local function torsoMeshAt(cx, hipY, height, wTop, wBot, segs)
    -- Vertical strip centered on cx, from hipY up
    local pts, tv = {}, {}
    for i = 0, segs do
        local t = i / segs
        local y = hipY - t * height
        local w = lerp(wBot, wTop, t)
        local lx, ly = cx - w * 0.5, y
        local rx, ry = cx + w * 0.5, y
        table.insert(pts, { lx, ly }); table.insert(pts, { rx, ry }); tv[#pts - 1] = t; tv[#pts] = t
    end
    return pts, tv
end

--############################ Scene Setup ##################################
local bones = {}
local meshes = {}
local groups = {}
local t = 0
local doIdle = false

function love.load()
    love.window.setTitle("Simple T‑Pose — Torso + 2 Arms (LÖVE)")
    love.graphics.setLineWidth(2)

    -- Root at hips
    local root                    = Bone.new { name = "root", length = 0, localPos = { 0, 0 }, localRot = 0 }
    local torso                   = Bone.new { name = "torso", length = 90, parent = root, localPos = { 0, 0 }, localRot = 0 }

    -- Shoulder line at top of torso in local coords (negative y is up here)
    local shoulderY               = -torso.length
    local shoulderOffset          = 42

    -- Arms (bind pointing outward horizontally)
    local upperArmLen, foreArmLen = 64, 60
    local lUpperArm               = Bone.new { name = "lUpperArm", length = upperArmLen, parent = torso, localPos = { -shoulderOffset, shoulderY }, localRot = math.pi } -- points left
    local lForearm                = Bone.new { name = "lForearm", length = foreArmLen, parent = lUpperArm, localPos = { upperArmLen, 0 }, localRot = 0 }
    local rUpperArm               = Bone.new { name = "rUpperArm", length = upperArmLen, parent = torso, localPos = { shoulderOffset, shoulderY }, localRot = 0 }        -- points right
    local rForearm                = Bone.new { name = "rForearm", length = foreArmLen, parent = rUpperArm, localPos = { upperArmLen, 0 }, localRot = 0 }

    bones                         = { root, torso, lUpperArm, lForearm, rUpperArm, rForearm }

    -- Bind transforms
    for _, b in ipairs(bones) do
        b:updateLocal(); b:updateWorld(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end

    -- Build meshes in bind
    local cx, hipY = 0, 0
    local torsoPts, torsoUV = torsoMeshAt(cx, hipY, torso.length, 46, 36, 20)
    local torsoInfl = {}
    for i, _ in ipairs(torsoPts) do torsoInfl[i] = { { bone = torso, w = 1.0 } } end
    table.insert(meshes, Mesh.new(torsoPts, torsoInfl))
    table.insert(groups, { name = "torso", meshIndex = #meshes, bones = { torso } })

    local armWidth, segs = 20, 22
    -- Left arm
    local lShoulderX, lShoulderY = -shoulderOffset, shoulderY
    local lPts, lUV = limbMeshAt(lShoulderX, lShoulderY, upperArmLen, foreArmLen, armWidth, segs)
    local lInfl = {}
    local elbowT = upperArmLen / (upperArmLen + foreArmLen)
    for i, _ in ipairs(lPts) do
        local tval = lUV[i]
        local w2 = tval; local w1 = 1 - tval
        local k = 0.12; local dist = math.abs(tval - elbowT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        lInfl[i] = { { bone = lUpperArm, w = w1 }, { bone = lForearm, w = w2 } }
    end
    table.insert(meshes, Mesh.new(lPts, lInfl))
    table.insert(groups, { name = "lArm", meshIndex = #meshes, bones = { lUpperArm, lForearm } })

    -- Right arm
    local rShoulderX, rShoulderY = shoulderOffset, shoulderY
    local rPts, rUV = limbMeshAt(rShoulderX, rShoulderY, upperArmLen, foreArmLen, armWidth, segs)
    local rInfl = {}
    for i, _ in ipairs(rPts) do
        local tval = rUV[i]
        local w2 = tval; local w1 = 1 - tval
        local k = 0.12; local dist = math.abs(tval - elbowT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        rInfl[i] = { { bone = rUpperArm, w = w1 }, { bone = rForearm, w = w2 } }
    end
    table.insert(meshes, Mesh.new(rPts, rInfl))
    table.insert(groups, { name = "rArm", meshIndex = #meshes, bones = { rUpperArm, rForearm } })
end

--############################ Animation ####################################
function love.keypressed(k)
    if k == "space" then doIdle = not doIdle end
end

function love.update(dt)
    t = t + dt
    if doIdle then
        -- idle arm sway around the T‑pose
        local _, torso, lUp, lFo, rUp, rFo = unpack(bones)
        lUp.localRot = math.pi + 0.25 * math.sin(t * 1.2)
        lFo.localRot = 0.60 * math.sin(t * 1.8)
        rUp.localRot = 0.00 - 0.25 * math.sin(t * 1.2)
        rFo.localRot = -0.60 * math.sin(t * 1.8)
    else
        -- exact T‑pose
        local _, torso, lUp, lFo, rUp, rFo = unpack(bones)
        lUp.localRot, lFo.localRot = math.pi, 0
        rUp.localRot, rFo.localRot = 0, 0
    end
    for _, b in ipairs(bones) do b:updateLocal() end
    for _, b in ipairs(bones) do b:updateWorld() end
    for _, g in ipairs(groups) do meshes[g.meshIndex]:skin() end
end

--############################ Rendering ####################################
local function drawPolyline(points)
    for i = 1, #points - 1 do
        love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(360, 380)

    -- Meshes
    love.graphics.setColor(1, 1, 1, 1)
    for _, g in ipairs(groups) do
        local m = meshes[g.meshIndex]
        local top, bot = {}, {}
        for i = 1, #m.v_final, 2 do table.insert(top, m.v_final[i]) end
        for i = 2, #m.v_final, 2 do table.insert(bot, m.v_final[i]) end
        drawPolyline(top); drawPolyline(bot)
    end

    -- Bones
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    local function boneLine(b)
        local sx, sy = M.transform(b.worldMat, 0, 0)
        local ex, ey = M.transform(b.worldMat, b.length, 0)
        love.graphics.line(sx, sy, ex, ey)
        love.graphics.circle("fill", sx, sy, 3)
        love.graphics.circle("fill", ex, ey, 3)
    end
    for i = 2, #bones do boneLine(bones[i]) end -- skip root
    love.graphics.pop()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Simple T‑Pose — Torso + 2 Arms\nSPACE: toggle idle sway\nBind pose is exact T‑pose.", 12, 12)
end
