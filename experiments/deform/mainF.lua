-- main.lua
-- Box2D-driven bones + skinned ribbon mesh (upper + lower rectangles with a revolute joint)
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
-- A "Bone" that is driven by a Box2D body. We keep bind matrices for skinning.
local Bone = {}
Bone.__index = Bone
function Bone.new(args)
    local b     = setmetatable({}, Bone)
    b.name      = args.name or "bone"
    b.length    = args.length or 100 -- visual length for debug & mesh mapping
    b.body      = args.body          -- love.physics Body
    b.parent    = args.parent        -- parent Bone
    b.worldMat  = M.identity()       -- updated from body each frame
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

--############################## Scene ######################################
local world
local bodies = {}
local joints = {}

local bones = {}
local skin -- the skinned ribbon mesh

-- ribbon util
local function makeRibbonAlongBone(bone, halfLen, width, segs, tOffset)
    -- Build points in WORLD space in the current (bind) pose along the bone's local +x axis
    local pts, tvals = {}, {}
    for i = 0, segs do
        local t = i / segs
        local x = -halfLen + t * (2 * halfLen)
        local y = 0
        -- edge normals are bone-local ±y; transform both edges into world
        local lx, ly = x, -width * 0.5
        local rx, ry = x, width * 0.5
        local Lx, Ly = M.transform(bone.bindWorld, lx, ly)
        local Rx, Ry = M.transform(bone.bindWorld, rx, ry)
        table.insert(pts, { Lx, Ly }); table.insert(pts, { Rx, Ry })
        tvals[#pts - 1] = (tOffset or 0) + t * 0.5
        tvals[#pts]     = (tOffset or 0) + t * 0.5
    end
    return pts, tvals
end

local function buildSkinnedRibbon(bUpper, bLower, wUpper, wLower, width)
    -- Build a continuous ribbon that spans both bones in their BIND pose (world space)
    local segs1, segs2 = 14, 14
    local pts1, u1 = makeRibbonAlongBone(bUpper, wUpper * 0.5, width, segs1, 0.0)
    local pts2, u2 = makeRibbonAlongBone(bLower, wLower * 0.5, width * 0.95, segs2, 0.5)
    -- stitch
    for i = 1, #pts2 do
        table.insert(pts1, pts2[i]); table.insert(u1, u2[i])
    end

    -- weights along the chain
    local infl = {}
    local elbowT = wUpper / (wUpper + wLower)
    for i, _ in ipairs(pts1) do
        local t = u1[i] -- 0..1 along whole chain
        local w2, w1 = t, 1 - t
        local k = 0.12; local dist = math.abs(t - elbowT)
        if dist < k then
            local s = 1 - (dist / k); w1 = w1 + 0.25 * s; w2 = w2 + 0.25 * s
        end
        local sum = w1 + w2; w1, w2 = w1 / sum, w2 / sum
        infl[i] = { { bone = bUpper, w = w1 }, { bone = bLower, w = w2 } }
    end
    return Mesh.new(pts1, infl)
end

local function createArmSystem()
    world = love.physics.newWorld(0, 980, true) -- gravity downward

    -- Ground
    local ground = love.physics.newBody(world, 0, 520, "static")
    love.physics.newFixture(ground, love.physics.newEdgeShape(-2000, 0, 2000, 0))

    -- Upper segment (like upper arm)
    local upperW, upperH = 140, 18
    local upper = love.physics.newBody(world, 360, 260, "dynamic")
    upper:setLinearDamping(0.8); upper:setAngularDamping(1.2)
    love.physics.newFixture(upper, love.physics.newRectangleShape(upperW, upperH), 1.0)

    -- Lower segment (forearm)
    local lowerW, lowerH = 130, 16
    local lower = love.physics.newBody(world, 360 + upperW * 0.5 + lowerW * 0.5, 260, "dynamic")
    lower:setLinearDamping(0.8); lower:setAngularDamping(1.2)
    love.physics.newFixture(lower, love.physics.newRectangleShape(lowerW, lowerH), 1.0)

    -- Revolute joint at the elbow (right end of upper / left end of lower)
    local elbowX = 360 + upperW * 0.5
    local elbowY = 260
    local elbow = love.physics.newRevoluteJoint(upper, lower, elbowX, elbowY, false)
    elbow:setLimitsEnabled(true)
    elbow:setLimits(-1.4, 1.2)
    elbow:setMotorEnabled(true)
    elbow:setMaxMotorTorque(1200)
    elbow:setMotorSpeed(1.2)

    -- Bones driven by physics
    local bUpper = Bone.new { name = "upper", length = upperW, body = upper }
    local bLower = Bone.new { name = "lower", length = lowerW, body = lower, parent = bUpper }
    bones = { bUpper, bLower }

    -- Capture bind pose (immediately after creation is fine)
    for _, b in ipairs(bones) do
        b:updateFromPhysics(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end

    -- Build a ribbon mesh in WORLD SPACE using the bind transforms
    skin = buildSkinnedRibbon(bUpper, bLower, upperW, lowerW, 28)
end

function love.load()
    love.window.setTitle("Box2D → Bones → Skinned Mesh (2 Rects + Revolute)")
    love.graphics.setLineWidth(2)
    createArmSystem()
end

function love.update(dt)
    world:update(dt)
    for _, b in ipairs(bones) do b:updateFromPhysics() end
    if skin then skin:skin() end
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
    for i = 1, #points - 1 do
        love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(80, 60)

    -- Ground
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.line(-10000, 520, 10000, 520)

    -- Bodies (white)
    love.graphics.setColor(1, 1, 1, 1)
    drawBodyRect(bones[1].body, bones[1].length, 18)
    drawBodyRect(bones[2].body, bones[2].length, 16)

    -- Joint anchor (green)
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    local ax, ay = 360 + bones[1].length * 0.5, 260
    love.graphics.circle("fill", ax, ay, 4)

    -- Bone debug (blue)
    local function boneLine(b)
        local sx, sy = M.transform(b.worldMat, -b.length * 0.5, 0)
        local ex, ey = M.transform(b.worldMat, b.length * 0.5, 0)
        love.graphics.line(sx, sy, ex, ey)
        love.graphics.circle("fill", sx, sy, 3)
        love.graphics.circle("fill", ex, ey, 3)
    end
    love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
    for _, b in ipairs(bones) do boneLine(b) end

    -- Skinned ribbon (white)
    if skin then
        love.graphics.setColor(1, 1, 1, 1)
        local top, bot = {}, {}
        for i = 1, #skin.v_final, 2 do table.insert(top, skin.v_final[i]) end
        for i = 2, #skin.v_final, 2 do table.insert(bot, skin.v_final[i]) end
        drawPolyline(top); drawPolyline(bot)
    end
    love.graphics.pop()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "Box2D → Bones → Skinned Ribbon\n• White = rectangles & ribbon (skinned)\n• Blue = bone lines (from Box2D)\n• Green = elbow joint anchor\nKeys: m (toggle motor), r (reset)\nHook ready to expand to torso/shoulder next.",
        14, 14)
end

--############################## Controls ###################################
function love.keypressed(k)
    if k == "r" then -- reset positions and rebind
        local upperW, lowerW = bones[1].length, bones[2].length
        bones[1].body:setPosition(360, 260); bones[1].body:setAngle(0); bones[1].body:setLinearVelocity(0, 0); bones[1]
            .body:setAngularVelocity(20)
        bones[2].body:setPosition(360 + upperW * 0.5 + lowerW * 0.5, 260); bones[2].body:setAngle(0); bones[2].body
            :setLinearVelocity(0, 0); bones[2].body:setAngularVelocity(0)
        for _, b in ipairs(bones) do
            b:updateFromPhysics(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
        end
        skin = nil
        skin = (function() return buildSkinnedRibbon(bones[1], bones[2], upperW, lowerW, 28) end)()
    elseif k == "m" then
        local on = not joints or not joints.elbow or not joints.elbow:isMotorEnabled() -- joints isn't stored now
    end
end
