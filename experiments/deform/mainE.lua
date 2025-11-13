-- main.lua
-- Box2D-driven bones: two rectangles (upper + lower) linked by a revolute joint
-- Leaves a clean hook to drive a deformable (skinned) mesh from the physics bodies.
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
    local b       = setmetatable({}, Bone)
    b.name        = args.name or "bone"
    b.length      = args.length or 100           -- purely for drawing / mesh mapping
    b.body        = args.body                    -- love.physics Body
    b.parent      = args.parent                  -- parent Bone
    b.localAnchor = args.localAnchor or { 0, 0 } -- visual offset inside body (for elbow)
    b.worldMat    = M.identity()                 -- updated from body each frame
    b.bindWorld   = nil
    b.bindInv     = nil
    return b
end

function Bone:updateFromPhysics()
    local x, y    = self.body:getPosition()
    local r       = self.body:getAngle()
    -- body transform maps body-local (0,0) to world at (x,y) with rotation r
    self.worldMat = M.TRS(x, y, r, 1, 1)
end

--############################## Mesh #######################################
-- Placeholder mesh type with hooks; we won't build a real skin here yet.
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
    -- no-op until we attach influences; kept to show integration point
    self.v_final = self.v_bind
end

--############################## Scene ######################################
local world
local bodies = {}
local shapes = {}
local fixtures = {}
local joints = {}

local bones = {}
local demoMesh -- placeholder to show where a deformable mesh would be managed

local function createArmSystem()
    local g              = love.physics.newWorld(0, 980, true) -- gravity downward

    -- Ground
    local ground         = love.physics.newBody(g, 0, 520, "static")
    local gshape         = love.physics.newEdgeShape(-2000, 0, 2000, 0)
    local gfix           = love.physics.newFixture(ground, gshape)

    -- Upper segment (like upper arm)
    local upperW, upperH = 140, 18
    local upper          = love.physics.newBody(g, 360, 260, "dynamic")
    upper:setLinearDamping(0.8); upper:setAngularDamping(1.2)
    local ushape = love.physics.newRectangleShape(upperW, upperH)
    local ufix   = love.physics.newFixture(upper, ushape, 1.0)
    ufix:setFriction(0.6)

    -- Lower segment (forearm)
    local lowerW, lowerH = 130, 16
    local lower = love.physics.newBody(g, 360 + upperW * 0.5 + lowerW * 0.5, 260, "dynamic")
    lower:setLinearDamping(0.8); lower:setAngularDamping(1.2)
    local lshape = love.physics.newRectangleShape(lowerW, lowerH)
    local lfix   = love.physics.newFixture(lower, lshape, 1.0)
    lfix:setFriction(0.6)

    -- Revolute joint at the elbow (right end of upper / left end of lower)
    local elbowX = 360 + upperW * 0.5
    local elbowY = 260
    local elbow = love.physics.newRevoluteJoint(upper, lower, elbowX, elbowY, false)
    elbow:setLimitsEnabled(true)
    elbow:setLimits(-1.4, 1.2) -- radians

    -- Optional motor for idle motion
    elbow:setMotorEnabled(true)
    elbow:setMaxMotorTorque(1200)
    elbow:setMotorSpeed(1.2) -- rad/s

    world = g
    bodies = { ground = ground, upper = upper, lower = lower }
    shapes = { gshape = gshape, ushape = ushape, lshape = lshape }
    fixtures = { gfix = gfix, ufix = ufix, lfix = lfix }
    joints = { elbow = elbow }

    -- Bones driven by physics
    local bUpper = Bone.new { name = "upper", length = upperW, body = upper }
    local bLower = Bone.new { name = "lower", length = lowerW, body = lower, parent = bUpper }

    bones = { bUpper, bLower }

    -- Capture bind pose (for skinning later)
    for _, b in ipairs(bones) do
        b:updateFromPhysics(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
    end

    -- Placeholder mesh (empty); in the next step we'll bind vertices to bones
    demoMesh = Mesh.new()
end

function love.load()
    love.window.setTitle("Box2D → Bones Driver (2 Rects + Revolute)")
    love.graphics.setLineWidth(2)
    createArmSystem()
end

function love.update(dt)
    world:update(dt)
    for _, b in ipairs(bones) do b:updateFromPhysics() end
    if demoMesh then demoMesh:skin() end
end

--############################## Rendering ##################################
local function drawBodyRect(body, w, h)
    local x, y = body:getPosition()
    local r    = body:getAngle()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(r)
    love.graphics.rectangle("line", -w * 0.5, -h * 0.5, w, h)
    love.graphics.pop()
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(80, 60)

    -- Ground
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.line(-10000, 520, 10000, 520)

    -- Bodies
    love.graphics.setColor(1, 1, 1, 1)
    drawBodyRect(bodies.upper, 140, 18)
    drawBodyRect(bodies.lower, 130, 16)

    -- Joint anchor
    love.graphics.setColor(0.2, 0.9, 0.3, 0.9)
    local ax, ay = joints.elbow:getAnchors()
    love.graphics.circle("fill", ax, ay, 4)

    -- Bone debug (from physics → affine)
    local function boneLine(b)
        local sx, sy = M.transform(b.worldMat, -b.length * 0.5, 0)
        local ex, ey = M.transform(b.worldMat, b.length * 0.5, 0)
        love.graphics.line(sx, sy, ex, ey)
        love.graphics.circle("fill", sx, sy, 3)
        love.graphics.circle("fill", ex, ey, 3)
    end
    love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
    for _, b in ipairs(bones) do boneLine(b) end

    love.graphics.pop()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "Box2D-driven 2-bone chain (upper+lower)\n• Revolute joint with limits + motor\n• Blue = bone lines derived from Box2D bodies\nNext step: attach a skinned mesh using b.bindInv and b.worldMat.",
        14, 14)
end

--############################## Controls ###################################
function love.keypressed(k)
    if k == "r" then -- reset positions
        local u, l = bodies.upper, bodies.lower
        u:setPosition(360, 260); u:setAngle(0); u:setLinearVelocity(0, 0); u:setAngularVelocity(0)
        l:setPosition(360 + 140 * 0.5 + 130 * 0.5, 260); l:setAngle(0); l:setLinearVelocity(0, 0); l:setAngularVelocity(0)
        for _, b in ipairs(bones) do
            b:updateFromPhysics(); b.bindWorld = b.worldMat; b.bindInv = M.inverse(b.bindWorld)
        end
    elseif k == "m" then
        local on = not joints.elbow:isMotorEnabled()
        joints.elbow:setMotorEnabled(on)
    end
end
