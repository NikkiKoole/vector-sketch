-- main.lua
-- 2D Linear Blend Skinning (LBS) demo in LÖVE
-- Shows how multiple bone/joint weights deform a vertex mesh

--########### Math helpers (2D affine, 3x3) #################################
local M = {}

local function mat(a11, a12, a13, a21, a22, a23, a31, a32, a33)
    return { a11, a12, a13, a21, a22, a23, a31, a32, a33 }
end

function M.identity()
    return mat(1, 0, 0, 0, 1, 0, 0, 0, 1)
end

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
    -- assumes vec is [x, y, 1]
    local nx = A[1] * x + A[2] * y + A[3]
    local ny = A[4] * x + A[5] * y + A[6]
    return nx, ny
end

function M.translation(tx, ty)
    return mat(1, 0, tx, 0, 1, ty, 0, 0, 1)
end

function M.rotation(r)
    local c, s = math.cos(r), math.sin(r)
    return mat(c, -s, 0, s, c, 0, 0, 0, 1)
end

function M.scale(sx, sy)
    return mat(sx, 0, 0, 0, sy or sx, 0, 0, 0, 1)
end

function M.TRS(tx, ty, rot, sx, sy)
    return M.mul(M.mul(M.translation(tx, ty), M.rotation(rot or 0)), M.scale(sx or 1, sy or sx or 1))
end

function M.inverse(A)
    -- Inverse of 2D affine (bottom row 0,0,1)
    local a, b, c, d, e, f, _, _, _ = A[1], A[2], A[3], A[4], A[5], A[6], A[7], A[8], A[9]
    local det = a * e - b * d
    if math.abs(det) < 1e-9 then return M.identity() end
    local id = 1 / det
    local na = e * id
    local nb = -b * id
    local nd = -d * id
    local ne = a * id
    local nc = -(na * c + nb * f)
    local nf = -(nd * c + ne * f)
    return mat(na, nb, nc, nd, ne, nf, 0, 0, 1)
end

--########### Skeleton ######################################################
local Bone = {}
Bone.__index = Bone

function Bone.new(args)
    local b     = setmetatable({}, Bone)
    b.name      = args.name or "bone"
    b.length    = args.length or 100
    b.localRot  = args.localRot or 0
    b.localPos  = args.localPos or { 0, 0 } -- relative to parent
    b.parent    = args.parent
    b.localMat  = M.TRS(b.localPos[1], b.localPos[2], b.localRot, 1, 1)
    b.worldMat  = M.identity()
    b.bindWorld = nil
    b.bindInv   = nil
    return b
end

function Bone:updateLocal()
    self.localMat = M.TRS(self.localPos[1], self.localPos[2], self.localRot, 1, 1)
end

function Bone:updateWorld()
    if self.parent then
        self.worldMat = M.mul(self.parent.worldMat, self.localMat)
    else
        self.worldMat = self.localMat
    end
end

--########### Mesh / Skin ###################################################
local Mesh = {}
Mesh.__index = Mesh

function Mesh.new(points, influences)
    -- points: { {x,y}, ... } in bind pose (model space)
    -- influences: per-vertex list: { { {bone=bone0, w=0.6}, {bone=bone1, w=0.4} }, ... }
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
            -- Transform bind vertex by bone: world * bindInv * v
            local lx, ly = M.transform(bone.bindInv, v[1], v[2])
            local wx, wy = M.transform(bone.worldMat, lx, ly)
            sx, sy = sx + w * wx, sy + w * wy
        end
        self.v_final[i] = { sx, sy }
    end
end

--########### Demo scene ####################################################
local bones = {}
local mesh
local elbowX

function love.load()
    love.window.setTitle("2D Multi-Bone Skinning (LBS) — Love2D")
    love.graphics.setLineWidth(2)

    -- Skeleton: two bones (upperArm -> foreArm)
    local upper = Bone.new { name = "upper", length = 150, localPos = { 0, 0 }, localRot = 0 }
    local fore  = Bone.new { name = "fore", length = 140, localPos = { upper.length, 0 }, localRot = 0, parent = upper }
    bones       = { upper, fore }

    -- Compute initial world (bind) transforms
    for _, b in ipairs(bones) do b:updateLocal() end
    for _, b in ipairs(bones) do b:updateWorld() end
    for _, b in ipairs(bones) do
        b.bindWorld = b.worldMat
        b.bindInv = M.inverse(b.bindWorld)
    end

    -- Create a simple rectangular strip mesh along the x-axis (arm), width = 30
    local width = 30
    local segs = 24
    local L = upper.length + fore.length
    elbowX = upper.length

    local pts = {}
    for i = 0, segs do
        local t = i / segs
        local x = t * L
        local y = 0
        table.insert(pts, { x, y - width * 0.5 })
        table.insert(pts, { x, y + width * 0.5 })
    end

    -- Build influences per vertex: blend from upper->fore across length
    local infl = {}
    for i, p in ipairs(pts) do
        local t = math.min(1, math.max(0, p[1] / L))
        local wFore = t -- more influence as x increases
        local wUpper = 1 - t

        -- Slightly bias around elbow to reduce candy-wrapper effect
        -- Smoothstep around elbow: remap t near elbow region
        local k = 0.15 -- elbow softness region as % of total length
        local elbowT = elbowX / L
        local dist = math.abs(t - elbowT)
        if dist < k then
            local s = 1 - (dist / k) -- 1 at elbow, 0 at edge
            -- boost both weights near elbow so they sum to 1 after renorm
            wUpper  = wUpper + 0.25 * s
            wFore   = wFore + 0.25 * s
        end

        -- normalize
        local sum = wUpper + wFore
        wUpper, wFore = wUpper / sum, wFore / sum

        infl[i] = { { bone = upper, w = wUpper }, { bone = fore, w = wFore } }
    end

    mesh = Mesh.new(pts, infl)
end

local t = 0
function love.update(dt)
    t                 = t + dt

    -- Animate bones: shoulder swings slowly, elbow bends faster
    local upper, fore = bones[1], bones[2]
    upper.localRot    = 0.35 * math.sin(t * 0.8)
    fore.localRot     = 1.10 * math.sin(t * 1.6)

    for _, b in ipairs(bones) do b:updateLocal() end
    for _, b in ipairs(bones) do b:updateWorld() end

    mesh:skin()
end

local function drawPolyline(points)
    for i = 1, #points - 1 do
        love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(200, 280)

    -- Draw bind pose mesh (light)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.35)
    local bindTop, bindBot = {}, {}
    for i = 1, #mesh.v_bind, 2 do table.insert(bindTop, mesh.v_bind[i]) end
    for i = 2, #mesh.v_bind, 2 do table.insert(bindBot, mesh.v_bind[i]) end
    drawPolyline(bindTop); drawPolyline(bindBot)

    -- Draw deformed mesh (bold)
    love.graphics.setColor(1, 1, 1, 1)
    local top, bot = {}, {}
    for i = 1, #mesh.v_final, 2 do table.insert(top, mesh.v_final[i]) end
    for i = 2, #mesh.v_final, 2 do table.insert(bot, mesh.v_final[i]) end
    drawPolyline(top); drawPolyline(bot)

    -- Draw bones
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    local upper, fore = bones[1], bones[2]
    local sx, sy = M.transform(upper.worldMat, 0, 0)
    local ex, ey = M.transform(upper.worldMat, upper.length, 0)
    love.graphics.line(sx, sy, ex, ey)
    local fx, fy = M.transform(fore.worldMat, fore.length, 0)
    love.graphics.line(ex, ey, fx, fy)
    love.graphics.circle("fill", sx, sy, 4)
    love.graphics.circle("fill", ex, ey, 4)
    love.graphics.circle("fill", fx, fy, 4)
    love.graphics.pop()
    -- UI text
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "2D Linear Blend Skinning (LBS) — multiple weights per vertex\nKeys: none — just watch it bend.\nTip: tweak weight falloff near elbow in code (k).",
        12, 12)
end
