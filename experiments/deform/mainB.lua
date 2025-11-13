-- main.lua
-- 2D Linear Blend Skinning (LBS) demo in LÖVE with an "organic" mesh
-- Mesh is generated along a curved centerline with varying width and mild noise

--########### Math helpers (2D affine, 3x3) #################################
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

--########### Skeleton ######################################################
local Bone = {}
Bone.__index = Bone

function Bone.new(args)
    local b     = setmetatable({}, Bone)
    b.name      = args.name or "bone"
    b.length    = args.length or 100
    b.localRot  = args.localRot or 0
    b.localPos  = args.localPos or { 0, 0 }
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
    if self.parent then self.worldMat = M.mul(self.parent.worldMat, self.localMat) else self.worldMat = self.localMat end
end

--########### Mesh / Skin ###################################################
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

--########### Organic geometry helpers #####################################
local function lerp(a, b, t) return a + (b - a) * t end
local function mix2(ax, ay, bx, by, t) return lerp(ax, bx, t), lerp(ay, by, t) end

-- Cubic Bezier curve
local function bezier(p0, p1, p2, p3, t)
    local ax, ay = mix2(p0[1], p0[2], p1[1], p1[2], t)
    local bx, by = mix2(p1[1], p1[2], p2[1], p2[2], t)
    local cx, cy = mix2(p2[1], p2[2], p3[1], p3[2], t)
    local dx, dy = mix2(ax, ay, bx, by, t)
    local ex, ey = mix2(bx, by, cx, cy, t)
    local qx, qy = mix2(dx, dy, ex, ey, t)
    return qx, qy, dx, dy, ex, ey -- also return de Casteljau points to get tangent
end

local function tangent(p0, p1, p2, p3, t)
    -- derivative of cubic bezier
    local ax = -p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]
    local ay = -p0[2] + 3 * p1[2] - 3 * p2[2] + p3[2]
    local bx = 3 * p0[1] - 6 * p1[1] + 3 * p2[1]
    local by = 3 * p0[2] - 6 * p1[2] + 3 * p2[2]
    local cx = -3 * p0[1] + 3 * p1[1]
    local cy = -3 * p0[2] + 3 * p1[2]
    local tx = (ax * t + bx) * t + cx
    local ty = (ay * t + by) * t + cy
    return tx, ty
end

-- tiny hash noise (deterministic jitter)
local function hashf(i)
    local x = math.sin(i * 127.1) * 43758.5453
    return x - math.floor(x)
end

--########### Demo scene ####################################################
local bones = {}
local mesh
local L, elbowT

function love.load()
    love.window.setTitle("2D LBS — Organic Mesh (LÖVE)")
    love.graphics.setLineWidth(2)

    -- Skeleton: two bones (upperArm -> foreArm)
    local upper = Bone.new { name = "upper", length = 150, localPos = { 0, 0 }, localRot = 0 }
    local fore  = Bone.new { name = "fore", length = 140, localPos = { upper.length, 0 }, localRot = 0, parent = upper }
    bones       = { upper, fore }

    -- Compute bind/world transforms
    for _, b in ipairs(bones) do
        b:updateLocal(); b:updateWorld()
    end
    for _, b in ipairs(bones) do
        b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end

    -- Organic centerline via a smooth S-curve cubic Bezier
    L = upper.length + fore.length
    elbowT = upper.length / L

    local p0 = { 0, -20 }
    local p1 = { L * 0.35, 50 }
    local p2 = { L * 0.65, -60 }
    local p3 = { L, 10 }

    -- Generate a ribbony strip along the curve
    local segs = 4
    local baseWidth = 34 * 2
    local pts = {}
    local infl = {}

    for i = 0, segs do
        local t = i / segs
        local cx, cy = bezier(p0, p1, p2, p3, t)
        local tx, ty = tangent(p0, p1, p2, p3, t)
        local len = math.sqrt(tx * tx + ty * ty) + 1e-6
        local nx, ny = -ty / len, tx / len -- left-hand normal

        -- width varies along the limb (bulge mid, taper ends) + mild sine
        local width = baseWidth * (0.6 + 0.8 * math.sin(math.pi * t)) + 6 * math.sin(6.283 * t)

        -- tiny jitter for organic outline
        local jitterL = (hashf(i * 1.37) - 0.5) * 3.0
        local jitterR = (hashf(i * 3.11) - 0.5) * 3.0

        local lx, ly = cx + (width * 0.5 + jitterL) * nx, cy + (width * 0.5 + jitterL) * ny
        local rx, ry = cx - (width * 0.5 + jitterR) * nx, cy - (width * 0.5 + jitterR) * ny

        table.insert(pts, { lx, ly }) -- top/left edge
        table.insert(pts, { rx, ry }) -- bottom/right edge

        -- Influence blending based on progress along total length
        local xAlong = t -- 0..1 along the centerline
        local wFore  = xAlong
        local wUpper = 1 - xAlong

        -- elbow softness window
        local k      = 0.12
        local dist   = math.abs(xAlong - elbowT)
        if dist < k then
            local s = 1 - (dist / k)
            wUpper  = wUpper + 0.25 * s
            wFore   = wFore + 0.25 * s
        end
        local sum      = wUpper + wFore; wUpper, wFore = wUpper / sum, wFore / sum

        infl[#pts - 1] = { { bone = upper, w = wUpper }, { bone = fore, w = wFore } }
        infl[#pts]     = { { bone = upper, w = wUpper }, { bone = fore, w = wFore } }
    end

    mesh = Mesh.new(pts, infl)
end

local t = 0
function love.update(dt)
    t = t + dt
    local upper, fore = bones[1], bones[2]
    upper.localRot = 0.35 * math.sin(t * 0.7) * 4
    fore.localRot = 1.05 * math.sin(t * 1.5) * 4

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
    love.graphics.translate(140, 280)

    -- Draw deformed mesh outline
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
        "Organic 2D LBS — two bones, curved mesh\nNo input. Try tweaking: baseWidth, jitter, control points p0..p3, and elbow softness k.",
        12, 12)
end
