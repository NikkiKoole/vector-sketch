-- main.lua
-- Humanoid made of a torso (2 bones) + 4 limbs (each 2 bones) using 2D Linear Blend Skinning (LBS)
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
    -- Build a ribbony strip along a straight segment p0->p1
    local pts, inflUV = {}, {}
    for i = 0, segs do
        local t = i / segs
        local cx, cy = mix2(p0x, p0y, p1x, p1y, t)
        local dx, dy = p1x - p0x, p1y - p0y
        local len = math.sqrt(dx * dx + dy * dy) + 1e-6
        local nx, ny = -dy / len, dx / len
        local jit = jitter * (hashf(i * 1.23) - 0.5)
        local w = width * (0.75 + 0.5 * math.sin(math.pi * t))
        local lx, ly = cx + (w * 0.5 + jit) * nx, cy + (w * 0.5 + jit) * ny
        local rx, ry = cx - (w * 0.5 + jit) * nx, cy - (w * 0.5 + jit) * ny
        table.insert(pts, { lx, ly }); table.insert(pts, { rx, ry })
        inflUV[#pts - 1] = t; inflUV[#pts] = t
    end
    return pts, inflUV
end

local function limbMeshAt(originX, originY, lengthA, lengthB, width, segs)
    -- Build a 2-bone limb in bind pose pointing along +x from origin
    local p0x, p0y = originX, originY
    local elbowX, elbowY = originX + lengthA, originY
    local tipX, tipY = elbowX + lengthB, originY
    local pts1, uv1 = makeRibbon(p0x, p0y, elbowX, elbowY, width, math.floor(segs * 0.5), 3.0)
    local pts2, uv2 = makeRibbon(elbowX, elbowY, tipX, tipY, width * 0.9, segs, 3.0)
    -- Stitch arrays
    for i = 1, #pts2 do
        table.insert(pts1, pts2[i]); table.insert(uv1, 0.5 + 0.5 * uv2[i])
    end
    return pts1, uv1, elbowX, elbowY, tipX, tipY
end

local function torsoMeshAt(x, y, h, wTop, wBot, segs)
    -- Vertical torso from hips (y) upwards (y+h)
    local pts = {}
    local uv = {}
    for i = 0, segs do
        local t = i / segs
        local cy = y + t * h
        local w = lerp(wBot, wTop, t) * (0.95 + 0.1 * math.sin(6.283 * t))
        local jit = (hashf(i * 2.7) - 0.5) * 2.0
        local lx, ly = x - w * 0.5 - jit, cy
        local rx, ry = x + w * 0.5 + jit, cy
        table.insert(pts, { lx, ly }); table.insert(pts, { rx, ry }); uv[#pts - 1] = t; uv[#pts] = t
    end
    return pts, uv
end

--############################ Scene Setup ##################################
local bones = {}
local meshes = {}
local groups = {} -- for drawing & updating per part

local t = 0

function love.load()
    love.window.setTitle("Humanoid Skinning — Torso + 4 Limbs (LÖVE)")
    love.graphics.setLineWidth(2)

    -- Root transform (world origin at hip)
    local root                     = Bone.new { name = "root", length = 0, localPos = { 0, 0 }, localRot = 0 }

    -- Torso: two bones stacked upward from hips
    local torsoLower               = Bone.new { name = "torsoLower", length = 70, parent = root, localPos = { 0, 0 }, localRot = 0 }
    local torsoUpper               = Bone.new { name = "torsoUpper", length = 70, parent = torsoLower, localPos = { 0, -torsoLower.length }, localRot = 0 }

    -- Shoulders attach near top of lower/upper boundary (shoulder line)
    local shoulderY                = -torsoLower.length - torsoUpper.length * 0.7
    local hipY                     = 0

    -- Arms (each 2 bones)
    local L                        = -1 -- left side uses negative x
    local R                        = 1  -- right side uses positive x
    local shoulderOffset           = 38
    local upperArmLen, foreArmLen  = 60, 56
    local upperLegLen, lowerLegLen = 70, 70

    local lShoulder                = Bone.new { name = "lUpperArm", length = upperArmLen, parent = torsoUpper, localPos = { -shoulderOffset, shoulderY - (-torsoLower.length - torsoUpper.length) }, localRot = 0 }
    local lForearm                 = Bone.new { name = "lForearm", length = foreArmLen, parent = lShoulder, localPos = { upperArmLen, 0 }, localRot = 0 }
    local rShoulder                = Bone.new { name = "rUpperArm", length = upperArmLen, parent = torsoUpper, localPos = { shoulderOffset, shoulderY - (-torsoLower.length - torsoUpper.length) }, localRot = 0 }
    local rForearm                 = Bone.new { name = "rForearm", length = foreArmLen, parent = rShoulder, localPos = { upperArmLen, 0 }, localRot = 0 }

    -- Legs
    local hipOffset                = 24
    local lThigh                   = Bone.new { name = "lThigh", length = upperLegLen, parent = torsoLower, localPos = { -hipOffset, 0 }, localRot = 0 }
    local lShin                    = Bone.new { name = "lShin", length = lowerLegLen, parent = lThigh, localPos = { 0, upperLegLen }, localRot = 0 }
    local rThigh                   = Bone.new { name = "rThigh", length = upperLegLen, parent = torsoLower, localPos = { hipOffset, 0 }, localRot = 0 }
    local rShin                    = Bone.new { name = "rShin", length = lowerLegLen, parent = rThigh, localPos = { 0, upperLegLen }, localRot = 0 }

    bones                          = { root, torsoLower, torsoUpper, lShoulder, lForearm, rShoulder, rForearm, lThigh,
        lShin, rThigh, rShin }

    -- Compute bind transforms
    for _, b in ipairs(bones) do b:updateLocal() end
    for _, b in ipairs(bones) do b:updateWorld() end
    for _, b in ipairs(bones) do
        b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end

    -- Build meshes in bind pose (world/model space) around the joints
    local cx, cy = 0, 0
    local torsoH = torsoLower.length + torsoUpper.length

    -- Torso mesh centered at x=0, from hip (cy) upwards
    local torsoPts, torsoUV = torsoMeshAt(cx, cy - torsoH, torsoH, 46, 34, 28)
    local torsoInfl = {}
    for i, p in ipairs(torsoPts) do
        local t = torsoUV[i]
        -- Blend between lower & upper torso bones along height
        local wUpper = t
        local wLower = 1 - t
        torsoInfl[i] = { { bone = torsoLower, w = wLower }, { bone = torsoUpper, w = wUpper } }
    end
    table.insert(meshes, Mesh.new(torsoPts, torsoInfl))
    table.insert(groups, { name = "torso", meshIndex = #meshes, bones = { torsoLower, torsoUpper } })

    -- Arms (left/right)
    local armWidth = 22
    local segs = 24
    -- left arm origin (shoulder socket in bind): relative to torsoUpper top
    local lShoulderWorldX, lShoulderWorldY = -shoulderOffset, shoulderY
    local lArmPts, lUV = limbMeshAt(lShoulderWorldX, lShoulderWorldY, upperArmLen, foreArmLen, armWidth, segs)
    local lInfl = {}
    for i, p in ipairs(lArmPts) do
        local t = lUV[i]
        local elbowT = upperArmLen / (upperArmLen + foreArmLen)
        local w2 = t; local w1 = 1 - t
        -- soften around elbow
        local k = 0.12; local dist = math.abs(t - elbowT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        lInfl[i] = { { bone = lShoulder, w = w1 }, { bone = lForearm, w = w2 } }
    end
    table.insert(meshes, Mesh.new(lArmPts, lInfl))
    table.insert(groups, { name = "lArm", meshIndex = #meshes, bones = { lShoulder, lForearm } })

    -- right arm
    local rShoulderWorldX, rShoulderWorldY = shoulderOffset, shoulderY
    local rArmPts, rUV = limbMeshAt(rShoulderWorldX, rShoulderWorldY, upperArmLen, foreArmLen, armWidth, segs)
    local rInfl = {}
    for i, p in ipairs(rArmPts) do
        local t = rUV[i]
        local elbowT = upperArmLen / (upperArmLen + foreArmLen)
        local w2 = t; local w1 = 1 - t
        local k = 0.12; local dist = math.abs(t - elbowT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        rInfl[i] = { { bone = rShoulder, w = w1 }, { bone = rForearm, w = w2 } }
    end
    table.insert(meshes, Mesh.new(rArmPts, rInfl))
    table.insert(groups, { name = "rArm", meshIndex = #meshes, bones = { rShoulder, rForearm } })

    -- Legs
    local legWidth = 24
    -- left leg origin at hip
    local lHipX, lHipY = -hipOffset, hipY
    local lLegPts, lLegUV = limbMeshAt(lHipX, lHipY, upperLegLen, lowerLegLen, legWidth, segs)
    local lLegInfl = {}
    for i, p in ipairs(lLegPts) do
        local t = lLegUV[i]
        local kneeT = upperLegLen / (upperLegLen + lowerLegLen)
        local w2 = t; local w1 = 1 - t
        local k = 0.12; local dist = math.abs(t - kneeT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        lLegInfl[i] = { { bone = lThigh, w = w1 }, { bone = lShin, w = w2 } }
    end
    table.insert(meshes, Mesh.new(lLegPts, lLegInfl))
    table.insert(groups, { name = "lLeg", meshIndex = #meshes, bones = { lThigh, lShin } })

    -- right leg
    local rHipX, rHipY = hipOffset, hipY
    local rLegPts, rLegUV = limbMeshAt(rHipX, rHipY, upperLegLen, lowerLegLen, legWidth, segs)
    local rLegInfl = {}
    for i, p in ipairs(rLegPts) do
        local t = rLegUV[i]
        local kneeT = upperLegLen / (upperLegLen + lowerLegLen)
        local w2 = t; local w1 = 1 - t
        local k = 0.12; local dist = math.abs(t - kneeT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        rLegInfl[i] = { { bone = rThigh, w = w1 }, { bone = rShin, w = w2 } }
    end
    table.insert(meshes, Mesh.new(rLegPts, rLegInfl))
    table.insert(groups, { name = "rLeg", meshIndex = #meshes, bones = { rThigh, rShin } })
end

--############################ Animation ####################################
local function updateBones(dt)
    t = t + dt
    local root, torsoLower, torsoUpper, lShoulder, lForearm, rShoulder, rForearm, lThigh, lShin, rThigh, rShin = unpack(
        bones)

    -- Torso sway + breathing scale hint (optional small rotation)
    torsoLower.localRot = 0.08 * math.sin(t * 0.9)
    torsoUpper.localRot = -0.10 * math.sin(t * 0.9 + 0.5)

    -- Arms swing
    lShoulder.localRot = 0.60 * math.sin(t * 1.6)
    lForearm.localRot = 0.95 * math.sin(t * 2.3)
    rShoulder.localRot = -0.60 * math.sin(t * 1.6)
    rForearm.localRot = -0.95 * math.sin(t * 2.3)

    -- Legs contra-phase (walk-like)
    lThigh.localRot = 0.45 * math.sin(t * 1.2)
    lShin.localRot = -0.75 * math.sin(t * 1.2 + 0.6)
    rThigh.localRot = -0.45 * math.sin(t * 1.2)
    rShin.localRot = 0.75 * math.sin(t * 1.2 + 0.6)

    for _, b in ipairs(bones) do b:updateLocal() end
    for _, b in ipairs(bones) do b:updateWorld() end
end

--############################ Rendering ####################################
local function drawPolyline(points)
    for i = 1, #points - 1 do
        love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
    end
end

function love.update(dt)
    updateBones(dt)
    for _, g in ipairs(groups) do
        local mesh = meshes[g.meshIndex]
        mesh:skin()
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(360, 420)

    -- Draw meshes (each as two polylines: left and right edge)
    love.graphics.setColor(1, 1, 1, 1)
    for _, g in ipairs(groups) do
        local m = meshes[g.meshIndex]
        local top, bot = {}, {}
        for i = 1, #m.v_final, 2 do table.insert(top, m.v_final[i]) end
        for i = 2, #m.v_final, 2 do table.insert(bot, m.v_final[i]) end
        drawPolyline(top); drawPolyline(bot)
    end

    -- Draw bones in green
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
    love.graphics.print(
        "Humanoid LBS: torso(2) + arms(2x2) + legs(2x2)\nNo input — sinusoid animation.\nTweak swing multipliers for different gaits.",
        14, 14)
end
