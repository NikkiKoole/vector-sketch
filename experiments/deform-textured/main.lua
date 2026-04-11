-- main.lua
-- Textured skeletal mesh deformation driven by Box2D physics.
-- A grid mesh is laid over an image, bone weights computed per vertex,
-- and the mesh deforms as physics bodies move.
-- Bodies ARE bones — each rectangle's long axis defines the bone segment.
--
-- Controls:
--   LMB drag       — grab and move body parts (physics)
--   Scroll on bone — adjust influence radius (nearest of 3 points: A, mid, B)
--   D              — toggle debug overlay (bones, weights, grid)
--   S              — toggle skinning method (DQS / LBS)
--   A              — toggle adaptive grid
--   G              — cycle grid resolution (coarse / medium / fine)
--   F              — toggle gravity
--   R              — reset skeleton to bind pose
--   Cmd+S          — save project
--   Drag-drop      — load PNG image or .lua project
--
-- Edit mode (E):
--   Drag bodies    — reposition
--   Drag joints    — move revolute anchor points
--   Drag endpoints — reshape bone segments
--   W + scroll     — adjust body width
--   H + scroll     — adjust body height
--   T + scroll     — adjust body rotation
--   E              — bake & exit (new positions become bind pose)
--
-- Weight paint mode (W):
--   Click bone     — select active bone
--   LMB drag       — paint weight for active bone
--   RMB drag       — erase weight
--   Scroll         — adjust brush size
--
-- LÖVE 11.x

---------------------------------------------------------------------------
-- 2D Affine matrix (3x3, stored flat)
---------------------------------------------------------------------------
local M = {}
local function mat(a11,a12,a13, a21,a22,a23, a31,a32,a33)
    return {a11,a12,a13, a21,a22,a23, a31,a32,a33}
end
function M.identity() return mat(1,0,0, 0,1,0, 0,0,1) end

function M.mul(A,B)
    return mat(
        A[1]*B[1]+A[2]*B[4]+A[3]*B[7], A[1]*B[2]+A[2]*B[5]+A[3]*B[8], A[1]*B[3]+A[2]*B[6]+A[3]*B[9],
        A[4]*B[1]+A[5]*B[4]+A[6]*B[7], A[4]*B[2]+A[5]*B[5]+A[6]*B[8], A[4]*B[3]+A[5]*B[6]+A[6]*B[9],
        A[7]*B[1]+A[8]*B[4]+A[9]*B[7], A[7]*B[2]+A[8]*B[5]+A[9]*B[8], A[7]*B[3]+A[8]*B[6]+A[9]*B[9])
end

function M.transform(A, x, y)
    return A[1]*x + A[2]*y + A[3], A[4]*x + A[5]*y + A[6]
end

function M.translation(tx,ty) return mat(1,0,tx, 0,1,ty, 0,0,1) end

function M.rotation(r)
    local c,s = math.cos(r), math.sin(r)
    return mat(c,-s,0, s,c,0, 0,0,1)
end

function M.scale(sx,sy) return mat(sx,0,0, 0,sy or sx,0, 0,0,1) end

function M.TRS(tx,ty,rot,sx,sy)
    return M.mul(M.mul(M.translation(tx,ty), M.rotation(rot or 0)), M.scale(sx or 1, sy or sx or 1))
end

function M.inverse(A)
    local a,b,c,d,e,f = A[1],A[2],A[3],A[4],A[5],A[6]
    local det = a*e - b*d
    if math.abs(det) < 1e-9 then return M.identity() end
    local id = 1/det
    local na,nb,nd,ne = e*id, -b*id, -d*id, a*id
    return mat(na,nb, -(na*c+nb*f), nd,ne, -(nd*c+ne*f), 0,0,1)
end

---------------------------------------------------------------------------
-- Bone
---------------------------------------------------------------------------
local Bone = {}
Bone.__index = Bone

function Bone.new(args)
    local b      = setmetatable({}, Bone)
    b.name       = args.name or "bone"
    b.body       = args.body
    b.parent     = args.parent
    b.worldMat   = M.identity()
    b.bindWorld  = nil
    b.bindInv    = nil
    -- segment endpoints in local body space (for weight computation)
    b.localA     = args.localA or {0, 0}   -- joint/top end
    b.localB     = args.localB or {0, 0}   -- tip/bottom end
    b.color      = args.color or {1, 0, 0}
    b.radiusA    = args.radiusA or args.radius or 80  -- influence at endpoint A
    b.radiusM    = args.radiusM or args.radius or 80  -- influence at midpoint
    b.radiusB    = args.radiusB or args.radius or 80  -- influence at endpoint B
    return b
end

function Bone:updateFromPhysics()
    local x, y = self.body:getPosition()
    local r    = self.body:getAngle()
    self.worldMat = M.TRS(x, y, r, 1, 1)
end

function Bone:getWorldEndpoints()
    local ax, ay = M.transform(self.worldMat, self.localA[1], self.localA[2])
    local bx, by = M.transform(self.worldMat, self.localB[1], self.localB[2])
    return ax, ay, bx, by
end

function Bone:getWorldMidpoint()
    local ax, ay, bx, by = self:getWorldEndpoints()
    return (ax+bx)*0.5, (ay+by)*0.5
end


---------------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------------
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

local function smoothstep(edge0, edge1, x)
    local t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

-- Distance from point (px,py) to line segment (ax,ay)-(bx,by)
-- Returns distance and t (0=at A, 1=at B)
local function distToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx*dx + dy*dy
    if len2 < 1e-9 then
        local ex, ey = px - ax, py - ay
        return math.sqrt(ex*ex + ey*ey), 0
    end
    local t = clamp(((px-ax)*dx + (py-ay)*dy) / len2, 0, 1)
    local cx, cy = ax + t*dx, ay + t*dy
    local ex, ey = px - cx, py - cy
    return math.sqrt(ex*ex + ey*ey), t
end

---------------------------------------------------------------------------
-- Lua table serializer
---------------------------------------------------------------------------
local function serialize(val, indent, level)
    level = level or 0
    indent = indent or "  "
    local t = type(val)
    if val == nil then return "nil"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = {}
        local ind = string.rep(indent, level + 1)
        local indClose = string.rep(indent, level)
        -- Array part
        for i = 1, #val do
            parts[#parts + 1] = ind .. serialize(val[i], indent, level + 1)
        end
        -- Hash part
        for k, v in pairs(val) do
            if type(k) ~= "number" or k < 1 or k > #val then
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = "[" .. serialize(k, indent, level + 1) .. "]"
                end
                parts[#parts + 1] = ind .. key .. " = " .. serialize(v, indent, level + 1)
            end
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indClose .. "}"
    end
    return "nil"
end

---------------------------------------------------------------------------
-- Save / Load project
---------------------------------------------------------------------------
local SAVE_FILE = "project.lua"

local function saveProject()
    -- Gather current body positions (in image-local coords)
    local bodiesData = {}
    for key, body in pairs(allBodies) do
        local bx, by = body:getPosition()
        bodiesData[key] = {
            x = bx - DRAW_OFFSET_X,
            y = by - DRAW_OFFSET_Y,
            angle = body:getAngle(),
        }
    end

    -- Gather bone data (localA, localB, radius, name, key)
    local bonesData = {}
    for i, bone in ipairs(bones) do
        -- Find which SKEL key this bone belongs to
        local boneKey = nil
        for key, body in pairs(allBodies) do
            if body == bone.body then boneKey = key; break end
        end
        bonesData[i] = {
            key = boneKey,
            name = bone.name,
            localA = {bone.localA[1], bone.localA[2]},
            localB = {bone.localB[1], bone.localB[2]},
            radiusA = bone.radiusA,
            radiusM = bone.radiusM,
            radiusB = bone.radiusB,
            color = {bone.color[1], bone.color[2], bone.color[3]},
        }
    end

    -- Gather weight data
    local weightsData = nil
    if boneWeights then
        weightsData = {}
        for vi = 1, #boneWeights do
            local infl = boneWeights[vi]
            local entry = {}
            for k = 1, #infl do
                entry[k] = {infl[k][1], infl[k][2]}
            end
            weightsData[vi] = entry
        end
    end

    -- Save joint anchors in image-local coords
    local jointsData = {}
    for key, anchor in pairs(jointAnchors) do
        jointsData[key] = {x = anchor.x - DRAW_OFFSET_X, y = anchor.y - DRAW_OFFSET_Y}
    end

    local project = {
        imageFile = IMAGE_FILE,
        gridLevelIdx = gridLevelIdx,
        useAdaptiveGrid = useAdaptiveGrid,
        useDQS = useDQS,
        bodies = bodiesData,
        bones = bonesData,
        joints = jointsData,
        weights = weightsData,
    }

    local data = "return " .. serialize(project)
    love.filesystem.write(SAVE_FILE, data)
    print("Saved to " .. love.filesystem.getSaveDirectory() .. "/" .. SAVE_FILE)
end

local function loadProject(path)
    local chunk, err
    if path then
        -- Load from absolute path
        local f = io.open(path, "r")
        if not f then print("Cannot open " .. path); return false end
        local data = f:read("*a")
        f:close()
        chunk, err = loadstring(data)
    else
        -- Load from save directory
        if not love.filesystem.getInfo(SAVE_FILE) then return false end
        local data = love.filesystem.read(SAVE_FILE)
        chunk, err = loadstring(data)
    end

    if not chunk then print("Failed to parse project: " .. (err or "")); return false end
    local ok, project = pcall(chunk)
    if not ok or not project then print("Failed to load project"); return false end

    -- Restore settings
    if project.gridLevelIdx then gridLevelIdx = project.gridLevelIdx end
    if project.useAdaptiveGrid ~= nil then useAdaptiveGrid = project.useAdaptiveGrid end
    if project.useDQS ~= nil then useDQS = project.useDQS end

    -- Restore joint anchor positions
    if project.joints then
        for key, jd in pairs(project.joints) do
            jointAnchors[key] = {x = DRAW_OFFSET_X + jd.x, y = DRAW_OFFSET_Y + jd.y}
        end
    end

    -- Restore body positions
    if project.bodies then
        for key, bd in pairs(project.bodies) do
            local body = allBodies[key]
            if body then
                body:setPosition(DRAW_OFFSET_X + bd.x, DRAW_OFFSET_Y + bd.y)
                if bd.angle then body:setAngle(bd.angle) end
                body:setLinearVelocity(0, 0)
                body:setAngularVelocity(0)
            end
        end
    end

    -- Restore bone properties
    if project.bones then
        for i, bd in ipairs(project.bones) do
            if bones[i] then
                bones[i].localA = {bd.localA[1], bd.localA[2]}
                bones[i].localB = {bd.localB[1], bd.localB[2]}
                bones[i].radiusA = bd.radiusA or bd.radius or bones[i].radiusA
                bones[i].radiusM = bd.radiusM or bd.radius or bones[i].radiusM
                bones[i].radiusB = bd.radiusB or bd.radius or bones[i].radiusB
                if bd.color then
                    bones[i].color = {bd.color[1], bd.color[2], bd.color[3]}
                end
            end
        end
    end

    -- Rebake bind pose
    for _, b in ipairs(bones) do
        b:updateFromPhysics()
        b.bindWorld = b.worldMat
        b.bindInv = M.inverse(b.bindWorld)
    end

    -- Rebuild grid
    rebuildGrid()

    -- Restore painted weights (overwrite auto-computed weights)
    if project.weights then
        for vi = 1, math.min(#project.weights, #boneWeights) do
            local saved = project.weights[vi]
            local infl = {}
            for k = 1, #saved do
                infl[k] = {saved[k][1], saved[k][2]}
            end
            boneWeights[vi] = infl
        end
    end

    print("Loaded project")
    return true
end

-- Load a new image (from file drop or path)
local function loadNewImage(filepath)
    -- Copy file to save directory so LÖVE can access it
    local f = io.open(filepath, "rb")
    if not f then print("Cannot open " .. filepath); return end
    local data = f:read("*a")
    f:close()

    local filename = filepath:match("([^/\\]+)$")
    love.filesystem.write(filename, data)

    -- Load as LÖVE image
    local fileData = love.filesystem.newFileData(data, filename)
    cachedImageData = love.image.newImageData(fileData)
    image = love.graphics.newImage(cachedImageData)
    image:setFilter("linear", "linear")
    IMAGE_FILE = filename

    local imgW, imgH = image:getDimensions()
    DRAW_OFFSET_X = (1200 - imgW) * 0.5
    DRAW_OFFSET_Y = (768 - imgH) * 0.5

    -- Recreate skeleton at new positions
    if mouseJoint then mouseJoint:destroy(); mouseJoint = nil end
    -- Destroy old world
    if world then world:destroy() end
    allBodies = {}
    allJoints = {}
    bones = {}
    createSkeleton()
    rebuildGrid()

    love.window.setTitle("Textured Skeletal Deformation — " .. filename)
end

---------------------------------------------------------------------------
-- Grid mesh generation
---------------------------------------------------------------------------

-- Build adaptive grid line positions along one axis.
-- n = number of grid cells, size = image dimension (pixels),
-- hotspots = list of positions (in pixels) where density should increase.
-- Returns array of (n+1) positions in [0, size].
local HOTSPOT_RADIUS = 80   -- how far a hotspot's influence reaches (pixels)
local HOTSPOT_STRENGTH = 3  -- how much denser near hotspots (multiplier)

local function adaptivePositions(n, size, hotspots)
    if not hotspots or #hotspots == 0 then
        -- Uniform fallback
        local pos = {}
        for i = 0, n do pos[i + 1] = i / n * size end
        return pos
    end

    -- Sample density function at many points
    local samples = 512
    local density = {}
    for i = 0, samples do
        local p = i / samples * size
        local d = 1.0  -- base density
        for _, hs in ipairs(hotspots) do
            local dist = math.abs(p - hs)
            if dist < HOTSPOT_RADIUS then
                local t = 1 - dist / HOTSPOT_RADIUS
                d = d + HOTSPOT_STRENGTH * t * t  -- quadratic falloff
            end
        end
        density[i + 1] = d
    end

    -- Accumulate density to build CDF
    local cdf = {0}
    for i = 1, samples do
        cdf[i + 1] = cdf[i] + (density[i] + density[i + 1]) * 0.5
    end
    local total = cdf[samples + 1]

    -- Invert CDF: for each grid line, find the position where cumulative density matches
    local pos = {}
    for gi = 0, n do
        local target = gi / n * total
        -- Binary search in cdf
        local lo, hi = 1, samples + 1
        while lo < hi - 1 do
            local mid = math.floor((lo + hi) / 2)
            if cdf[mid] < target then lo = mid else hi = mid end
        end
        -- Interpolate within the interval
        local frac = 0
        if cdf[hi] > cdf[lo] then
            frac = (target - cdf[lo]) / (cdf[hi] - cdf[lo])
        end
        local samplePos = ((lo - 1) + frac) / samples * size
        pos[gi + 1] = samplePos
    end
    -- Clamp endpoints
    pos[1] = 0
    pos[n + 1] = size
    return pos
end

local useAdaptiveGrid = true

-- Sample image alpha at a pixel position. Returns 0-1.
-- imageData is cached per createGridMesh call.
local cachedImageData = nil

local function sampleAlpha(imgData, px, py, imgW, imgH)
    local ix = clamp(math.floor(px), 0, imgW - 1)
    local iy = clamp(math.floor(py), 0, imgH - 1)
    local _, _, _, a = imgData:getPixel(ix, iy)
    return a
end

-- Check if a grid cell has any non-transparent content
local function cellHasContent(imgData, x0, y0, x1, y1, imgW, imgH)
    local cx, cy = (x0+x1)*0.5, (y0+y1)*0.5
    local threshold = 0.01
    if sampleAlpha(imgData, x0, y0, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, x1, y0, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, x0, y1, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, x1, y1, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, cx, cy, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, cx, y0, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, cx, y1, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, x0, cy, imgW, imgH) > threshold then return true end
    if sampleAlpha(imgData, x1, cy, imgW, imgH) > threshold then return true end
    return false
end

local function createGridMesh(image, gridW, gridH, jointDefs)
    local imgW, imgH = image:getDimensions()

    -- cachedImageData is set in love.load / loadNewImage

    -- Collect joint hotspot positions for adaptive grid
    local xSpots, ySpots = {}, {}
    if useAdaptiveGrid and jointDefs then
        for _, def in pairs(jointDefs) do
            xSpots[#xSpots + 1] = def[3]
            ySpots[#ySpots + 1] = def[4]
        end
    end

    -- Compute grid line positions (adaptive or uniform)
    local xPositions = adaptivePositions(gridW, imgW, xSpots)
    local yPositions = adaptivePositions(gridH, imgH, ySpots)

    local vertices = {}
    -- (gridW+1) x (gridH+1) vertices
    for gy = 0, gridH do
        for gx = 0, gridW do
            local x = xPositions[gx + 1]
            local y = yPositions[gy + 1]
            local u = x / imgW
            local v = y / imgH
            vertices[#vertices + 1] = {x, y, u, v, 255, 255, 255, 255}
        end
    end

    -- Triangle indices — skip fully empty cells
    local indices = {}
    local cols = gridW + 1
    for gy = 0, gridH - 1 do
        for gx = 0, gridW - 1 do
            local x0 = xPositions[gx + 1]
            local x1 = xPositions[gx + 2]
            local y0 = yPositions[gy + 1]
            local y1 = yPositions[gy + 2]

            if not cachedImageData or cellHasContent(cachedImageData, x0, y0, x1, y1, imgW, imgH) then
                local tl = gy * cols + gx + 1
                local tr = tl + 1
                local bl = tl + cols
                local br = bl + 1
                indices[#indices + 1] = tl
                indices[#indices + 1] = bl
                indices[#indices + 1] = tr
                indices[#indices + 1] = tr
                indices[#indices + 1] = bl
                indices[#indices + 1] = br
            end
        end
    end

    local mesh = love.graphics.newMesh(
        {
            {"VertexPosition", "float", 2},
            {"VertexTexCoord", "float", 2},
            {"VertexColor",    "byte",  4},
        },
        vertices,
        "triangles",
        "stream"
    )
    mesh:setVertexMap(indices)
    mesh:setTexture(image)

    return mesh, vertices, indices
end

---------------------------------------------------------------------------
-- Bone weight computation
---------------------------------------------------------------------------
local MAX_INFLUENCES = 4
local WEIGHT_FALLOFF = 80  -- pixels: distance at which influence fades to zero

-- Check if a line from (x0,y0) to (x1,y1) crosses a transparent region.
-- Samples alpha along the line; returns true if path is mostly opaque.
local function hasOpaquePath(imgData, x0, y0, x1, y1, imgW, imgH, offX, offY)
    if not imgData then return true end
    local steps = 8
    local threshold = 0.05
    local opaqueCount = 0
    for i = 0, steps do
        local t = i / steps
        local px = x0 + (x1 - x0) * t - offX
        local py = y0 + (y1 - y0) * t - offY
        if px >= 0 and px < imgW and py >= 0 and py < imgH then
            if sampleAlpha(imgData, px, py, imgW, imgH) > threshold then
                opaqueCount = opaqueCount + 1
            end
        end
    end
    -- Consider path opaque if at least 60% of samples are opaque
    return opaqueCount / (steps + 1) > 0.6
end

local function computeBoneWeights(vertices, bones)
    local weights = {} -- weights[vertexIndex] = {{boneIndex, weight}, ...}
    local imgW, imgH
    if cachedImageData then
        imgW = cachedImageData:getWidth()
        imgH = cachedImageData:getHeight()
    end

    for vi = 1, #vertices do
        local vx, vy = vertices[vi][1], vertices[vi][2]
        local raw = {}

        for bi = 1, #bones do
            local bone = bones[bi]
            -- bone segment endpoints in world/bind space
            local ax, ay = M.transform(bone.bindWorld, bone.localA[1], bone.localA[2])
            local bx, by = M.transform(bone.bindWorld, bone.localB[1], bone.localB[2])
            local dist, t = distToSegment(vx, vy, ax, ay, bx, by)
            -- Interpolate radius through A (t=0), M (t=0.5), B (t=1)
            local boneRadius
            if t < 0.5 then
                local s = t * 2  -- 0..1 within A..M
                boneRadius = bone.radiusA * (1 - s) + bone.radiusM * s
            else
                local s = (t - 0.5) * 2  -- 0..1 within M..B
                boneRadius = bone.radiusM * (1 - s) + bone.radiusB * s
            end
            local w = 1 - smoothstep(0, boneRadius, dist)
            if w > 0.001 then
                -- Alpha-aware: reduce weight if path to bone crosses transparent area
                if cachedImageData and DRAW_OFFSET_X then
                    local boneCenter_x = (ax + bx) * 0.5
                    local boneCenter_y = (ay + by) * 0.5
                    if not hasOpaquePath(cachedImageData, vx, vy, boneCenter_x, boneCenter_y, imgW, imgH, DRAW_OFFSET_X, DRAW_OFFSET_Y) then
                        w = w * 0.05  -- heavily penalize bones behind transparent gaps
                    end
                end
                if w > 0.001 then
                    raw[#raw + 1] = {bi, w, dist}
                end
            end
        end

        -- sort by weight descending, keep top N
        table.sort(raw, function(a, b) return a[2] > b[2] end)
        local kept = {}
        local sum = 0
        for i = 1, math.min(MAX_INFLUENCES, #raw) do
            kept[i] = {raw[i][1], raw[i][2]}
            sum = sum + raw[i][2]
        end

        -- normalize
        if sum > 0 then
            for i = 1, #kept do kept[i][2] = kept[i][2] / sum end
        elseif #bones > 0 then
            -- fallback: assign to nearest bone with full weight
            local bestBi, bestDist = 1, math.huge
            for bi = 1, #bones do
                local bone = bones[bi]
                local ax, ay = M.transform(bone.bindWorld, bone.localA[1], bone.localA[2])
                local bx, by = M.transform(bone.bindWorld, bone.localB[1], bone.localB[2])
                local dist = distToSegment(vx, vy, ax, ay, bx, by)
                if dist < bestDist then bestDist = dist; bestBi = bi end
            end
            kept = {{bestBi, 1.0}}
        end

        weights[vi] = kept
    end

    return weights
end

---------------------------------------------------------------------------
-- CPU skinning: deform vertex positions based on current bone transforms
---------------------------------------------------------------------------

-- Linear Blend Skinning (original — causes candy wrapper)
local function skinVerticesLBS(bindVerts, weights, bones, deformedVerts)
    for vi = 1, #bindVerts do
        local bx, by = bindVerts[vi][1], bindVerts[vi][2]
        local sx, sy = 0, 0
        local infl = weights[vi]
        for k = 1, #infl do
            local boneIdx, w = infl[k][1], infl[k][2]
            local bone = bones[boneIdx]
            local lx, ly = M.transform(bone.bindInv, bx, by)
            local wx, wy = M.transform(bone.worldMat, lx, ly)
            sx = sx + w * wx
            sy = sy + w * wy
        end
        deformedVerts[vi][1] = sx
        deformedVerts[vi][2] = sy
    end
end

-- Dual Quaternion Skinning (2D version — preserves volume)
--
-- Instead of blending transformed positions (LBS), we:
-- 1. Blend the rotations properly (circular mean via cos/sin)
-- 2. Compute rotation-compensated translations
-- 3. Apply the blended transform
--
-- This prevents the mesh from collapsing at joints.
local function skinVerticesDQS(bindVerts, weights, bones, deformedVerts)
    local atan2, cos, sin, sqrt = math.atan2, math.cos, math.sin, math.sqrt

    for vi = 1, #bindVerts do
        local bx, by = bindVerts[vi][1], bindVerts[vi][2]
        local infl = weights[vi]

        -- Step 1: compute per-bone skinning transforms, extract angle + translation
        -- Skinning matrix S_i = worldMat_i * bindInv_i
        -- Decompose: angle = atan2(S[4], S[1]), tx = S[3], ty = S[6]

        local cosSum, sinSum = 0, 0  -- for blending rotation

        -- Pre-compute skinning data per influence
        local nInfl = #infl
        -- Use local arrays to avoid table creation per vertex
        local angles, txs, tys, ws = {}, {}, {}, {}

        for k = 1, nInfl do
            local boneIdx, w = infl[k][1], infl[k][2]
            local bone = bones[boneIdx]
            local S = M.mul(bone.worldMat, bone.bindInv)
            local theta = atan2(S[4], S[1])
            angles[k] = theta
            txs[k] = S[3]
            tys[k] = S[6]
            ws[k] = w
            cosSum = cosSum + w * cos(theta)
            sinSum = sinSum + w * sin(theta)
        end

        -- Step 2: blended rotation angle
        local len = sqrt(cosSum * cosSum + sinSum * sinSum)
        local blendAngle
        if len > 1e-9 then
            blendAngle = atan2(sinSum / len, cosSum / len)
        else
            blendAngle = 0
        end

        -- Step 3: apply blended rotation to bind-pose vertex
        local cosB, sinB = cos(blendAngle), sin(blendAngle)
        local rbx = cosB * bx - sinB * by  -- R_blend * bindPos
        local rby = sinB * bx + cosB * by

        -- Step 4: compute blended translation
        -- For each bone: t_effective = (S_i * bindPos) - (R_blend * bindPos)
        -- This isolates translation in a rotation-independent way
        local txBlend, tyBlend = 0, 0
        for k = 1, nInfl do
            local c, s = cos(angles[k]), sin(angles[k])
            -- S_i * bindPos = R(θ_i) * bindPos + (tx_i, ty_i)
            local spx = c * bx - s * by + txs[k]
            local spy = s * bx + c * by + tys[k]
            -- effective translation = (S_i * bindPos) - (R_blend * bindPos)
            txBlend = txBlend + ws[k] * (spx - rbx)
            tyBlend = tyBlend + ws[k] * (spy - rby)
        end

        -- Step 5: final position = R_blend * bindPos + blended translation
        deformedVerts[vi][1] = rbx + txBlend
        deformedVerts[vi][2] = rby + tyBlend
    end
end

-- Active skinning method (toggle with S key)
local useDQS = true
local function skinVertices(bindVerts, weights, bones, deformedVerts)
    if useDQS then
        skinVerticesDQS(bindVerts, weights, bones, deformedVerts)
    else
        skinVerticesLBS(bindVerts, weights, bones, deformedVerts)
    end
end

---------------------------------------------------------------------------
-- Scene: Box2D skeleton for Snoopy
---------------------------------------------------------------------------
-- Image is 386x488. We'll position it centered on screen.
-- Bone positions are in image-local coordinates (0,0 = top-left of image).

local IMAGE_FILE = "oldman.png"
local DRAW_OFFSET_X, DRAW_OFFSET_Y = 0, 0  -- computed in love.load

local world, image
local allBodies = {}
local allJoints = {}
local bones = {}
local mouseJoint, mouseBody
local mouseX, mouseY = 0, 0

local gridMesh, bindVerts, gridIndices
local deformedVerts
local boneWeights

-- Multi-layer support: each layer = {image, imageData, gridMesh, bindVerts, gridIndices, deformedVerts, boneWeights, file}
-- Layers are drawn back-to-front. Layer 1 = backmost.
-- When layers is non-nil, the per-layer data overrides the globals above for rendering.
local layers = nil  -- nil = single image mode (backwards compatible), table = multi-layer mode

local debugMode = true
local boneDisplayMode = 1  -- 0=off, 1=bones, 2=weights
local hoveredBone = nil    -- bone nearest to mouse cursor (for scroll-to-resize)

-- Edit mode: reposition bodies and bone endpoints, then rebake
local editMode = false
local editDrag = nil  -- {type="body"|"endpointA"|"endpointB"|"joint", ...}

-- Runtime joint anchor positions (world coords, editable in edit mode)
local jointAnchors = {}  -- jointAnchors[key] = {x, y}

-- Weight paint mode
local weightPaintMode = false
local activeBoneIdx = nil    -- index into bones[] for painting
local brushRadius = 30
local brushStrength = 0.15   -- how much weight to add/remove per frame of painting
local painting = false       -- currently painting (LMB held)
local erasing = false        -- currently erasing (RMB held)

local gridLevels = {
    {name = "coarse", w = 8,  h = 10},
    {name = "medium", w = 16, h = 20},
    {name = "fine",   w = 32, h = 40},
}
local gridLevelIdx = 2

-- T-pose character skeleton (positions in image pixel coords)
-- Image is 700x679. Character has arms stretched horizontally, legs apart.
--   Head center:     ~350, 65
--   Neck:            ~350, 125
--   Torso center:    ~350, 250
--   Hip:             ~350, 370
--   Left arm:  shoulder ~255, 175  elbow ~130, 180  hand ~20, 175
--   Right arm: shoulder ~445, 175  elbow ~570, 180  hand ~680, 175
--   Left leg:  hip ~300, 385  knee ~285, 500  foot ~275, 620
--   Right leg: hip ~400, 385  knee ~415, 500  foot ~425, 620

-- Each body IS a bone. Color is for debug vis.
-- The bone segment runs along the body's long axis automatically.
local BODY_COLORS = {
    head  = {1, 0.3, 0.3},
    torso = {0.3, 1, 0.3},
    lUArm = {1, 1, 0.3},
    lLArm = {1, 0.8, 0.3},
    rUArm = {0.3, 1, 1},
    rLArm = {0.3, 0.8, 1},
    lULeg = {1, 0.3, 1},
    lLLeg = {0.8, 0.3, 1},
    rULeg = {0.5, 0.5, 1},
    rLLeg = {0.3, 0.5, 1},
}

local SKEL = {
    head  = {x = 350, y = 65,  w = 100, h = 140, bodyType = "dynamic"},
    torso = {x = 350, y = 255, w = 140, h = 170, bodyType = "static"},
    lUArm = {x = 200, y = 178, w = 120, h = 28,  bodyType = "dynamic"},
    lLArm = {x = 70,  y = 175, w = 120, h = 25,  bodyType = "dynamic"},
    rUArm = {x = 500, y = 178, w = 120, h = 28,  bodyType = "dynamic"},
    rLArm = {x = 630, y = 175, w = 120, h = 25,  bodyType = "dynamic"},
    lULeg = {x = 295, y = 460, w = 55,  h = 130, bodyType = "dynamic"},
    lLLeg = {x = 280, y = 580, w = 50,  h = 120, bodyType = "dynamic"},
    rULeg = {x = 405, y = 460, w = 55,  h = 130, bodyType = "dynamic"},
    rLLeg = {x = 420, y = 580, w = 50,  h = 120, bodyType = "dynamic"},
}

-- Ordered list of body keys (for deterministic bone indexing)
local SKEL_ORDER = {"torso", "head", "lUArm", "lLArm", "rUArm", "rLArm", "lULeg", "lLLeg", "rULeg", "rLLeg"}

-- Joint definitions: {bodyA_key, bodyB_key, anchorX, anchorY, lowerLimit, upperLimit}
local JOINT_DEFS = {
    neck      = {"torso", "head",  350, 125,  -0.5, 0.5},
    lShoulder = {"torso", "lUArm", 265, 178,  -1.5, 1.5},
    lElbow    = {"lUArm", "lLArm", 130, 178,  -2.0, 0.5},
    rShoulder = {"torso", "rUArm", 435, 178,  -1.5, 1.5},
    rElbow    = {"rUArm", "rLArm", 570, 178,  -0.5, 2.0},
    lHip      = {"torso", "lULeg", 305, 385,  -1.0, 1.0},
    lKnee     = {"lULeg", "lLLeg", 288, 520,  -0.3, 1.5},
    rHip      = {"torso", "rULeg", 395, 385,  -1.0, 1.0},
    rKnee     = {"rULeg", "rLLeg", 412, 520,  -0.3, 1.5},
}

local useGravity = false

-- Auto-generate bone from body dimensions: bone runs along the long axis
local function boneFromBody(key, def)
    local hw, hh = def.w * 0.5, def.h * 0.5
    local localA, localB
    if def.w >= def.h then
        -- Horizontal body: bone runs left-right
        localA = {-hw, 0}
        localB = {hw, 0}
    else
        -- Vertical body: bone runs top-bottom
        localA = {0, -hh}
        localB = {0, hh}
    end
    local radius = math.max(def.w, def.h) * 0.45
    return {
        key = key,
        localA = localA,
        localB = localB,
        color = BODY_COLORS[key] or {1, 1, 1},
        radiusA = radius,
        radiusM = radius,
        radiusB = radius,
    }
end


local function createSkeleton()
    local gy = useGravity and 600 or 0
    world = love.physics.newWorld(0, gy, true)

    -- Ground for gravity mode
    if useGravity then
        local ground = love.physics.newBody(world, 600, 750, "static")
        love.physics.newFixture(ground, love.physics.newEdgeShape(-800, 0, 800, 0))
    end

    -- Create bodies
    for _, key in ipairs(SKEL_ORDER) do
        local def = SKEL[key]
        local b = love.physics.newBody(world, DRAW_OFFSET_X + def.x, DRAW_OFFSET_Y + def.y, def.bodyType)
        b:setLinearDamping(2.0)
        b:setAngularDamping(3.0)
        if def.angle then b:setAngle(def.angle) end
        local shape = love.physics.newRectangleShape(def.w, def.h)
        local fix = love.physics.newFixture(b, shape, 1.0)
        -- Negative group: all skeleton bodies ignore each other
        fix:setGroupIndex(-1)
        allBodies[key] = b
    end

    -- Create joints and store editable anchor positions
    for key, def in pairs(JOINT_DEFS) do
        local bodyA = allBodies[def[1]]
        local bodyB = allBodies[def[2]]
        -- Use stored anchor if we have one (from previous edit), otherwise from definition
        local ax = jointAnchors[key] and jointAnchors[key].x or (DRAW_OFFSET_X + def[3])
        local ay = jointAnchors[key] and jointAnchors[key].y or (DRAW_OFFSET_Y + def[4])
        jointAnchors[key] = {x = ax, y = ay}
        local j = love.physics.newRevoluteJoint(bodyA, bodyB, ax, ay, false)
        j:setLimitsEnabled(true)
        j:setLimits(def[5], def[6])
        allJoints[key] = j
    end

    -- Auto-generate bones from bodies (each body IS a bone)
    bones = {}
    for _, key in ipairs(SKEL_ORDER) do
        local def = SKEL[key]
        local boneDef = boneFromBody(key, def)
        local bone = Bone.new{
            name   = key,
            body   = allBodies[key],
            localA = boneDef.localA,
            localB = boneDef.localB,
            color  = boneDef.color,
            radiusA = boneDef.radiusA,
            radiusM = boneDef.radiusM,
            radiusB = boneDef.radiusB,
        }
        bones[#bones + 1] = bone
    end

    -- Capture bind pose
    for _, b in ipairs(bones) do
        b:updateFromPhysics()
        b.bindWorld = b.worldMat
        b.bindInv   = M.inverse(b.bindWorld)
    end
end

-- Build grid mesh + weights for a single image (used by both single and multi-layer modes)
local function buildLayerGrid(layerImage, layerImageData)
    local gl = gridLevels[gridLevelIdx]
    -- Temporarily swap cachedImageData so createGridMesh's alpha check uses the right image
    local origImageData = cachedImageData
    cachedImageData = layerImageData
    local lMesh, lBindVerts, lGridIndices = createGridMesh(layerImage, gl.w, gl.h, JOINT_DEFS)
    cachedImageData = origImageData

    -- Offset bind vertices to world space
    local worldBindVerts = {}
    for i = 1, #lBindVerts do
        worldBindVerts[i] = {
            lBindVerts[i][1] + DRAW_OFFSET_X,
            lBindVerts[i][2] + DRAW_OFFSET_Y,
            lBindVerts[i][3],
            lBindVerts[i][4],
        }
    end

    local lWeights = computeBoneWeights(worldBindVerts, bones)

    local lDeformed = {}
    for i = 1, #worldBindVerts do
        lDeformed[i] = {worldBindVerts[i][1], worldBindVerts[i][2]}
    end

    lBindVerts._world = worldBindVerts

    return {
        image = layerImage,
        imageData = layerImageData,
        gridMesh = lMesh,
        bindVerts = lBindVerts,
        gridIndices = lGridIndices,
        deformedVerts = lDeformed,
        boneWeights = lWeights,
    }
end

local function rebuildGrid()
    local gl = gridLevels[gridLevelIdx]
    gridMesh, bindVerts, gridIndices = createGridMesh(image, gl.w, gl.h, JOINT_DEFS)

    -- Offset bind vertices to world space for weight computation
    -- (the image is drawn at DRAW_OFFSET_X/Y, so grid verts need that offset)
    local worldBindVerts = {}
    for i = 1, #bindVerts do
        worldBindVerts[i] = {
            bindVerts[i][1] + DRAW_OFFSET_X,
            bindVerts[i][2] + DRAW_OFFSET_Y,
            bindVerts[i][3],
            bindVerts[i][4],
        }
    end

    boneWeights = computeBoneWeights(worldBindVerts, bones)

    -- Init deformed verts (copy of world-space bind verts)
    deformedVerts = {}
    for i = 1, #worldBindVerts do
        deformedVerts[i] = {worldBindVerts[i][1], worldBindVerts[i][2]}
    end

    -- Store world-space bind positions for skinning
    bindVerts._world = worldBindVerts

    -- Rebuild all layers too
    if layers then
        for li = 1, #layers do
            local L = layers[li]
            local rebuilt = buildLayerGrid(L.image, L.imageData)
            layers[li] = rebuilt
        end
    end
end

---------------------------------------------------------------------------
-- Weight painting
---------------------------------------------------------------------------
-- Find the nearest bone index to a world-space point, excluding a specific bone
local function findNearestBoneIdx(vx, vy, excludeIdx)
    local bestIdx, bestDist = nil, math.huge
    for bi, bone in ipairs(bones) do
        if bi ~= excludeIdx then
            local ax, ay = M.transform(bone.bindWorld, bone.localA[1], bone.localA[2])
            local bx, by = M.transform(bone.bindWorld, bone.localB[1], bone.localB[2])
            local d = distToSegment(vx, vy, ax, ay, bx, by)
            if d < bestDist then bestDist = d; bestIdx = bi end
        end
    end
    return bestIdx
end

-- Paint or erase weight for activeBoneIdx at mouse position
local function paintWeights(mx, my, add)
    if not activeBoneIdx or not boneWeights or not bindVerts._world then return end

    local r2 = brushRadius * brushRadius

    for vi = 1, #bindVerts._world do
        local vx, vy = bindVerts._world[vi][1], bindVerts._world[vi][2]
        local dx, dy = vx - mx, vy - my
        local d2 = dx*dx + dy*dy
        if d2 < r2 then
            -- Falloff: stronger at center, weaker at edge
            local falloff = 1 - math.sqrt(d2) / brushRadius
            local delta = brushStrength * falloff

            local infl = boneWeights[vi]

            if add then
                -- PAINTING: increase active bone, decrease others proportionally
                local activeK = nil
                for k = 1, #infl do
                    if infl[k][1] == activeBoneIdx then activeK = k; break end
                end
                if not activeK then
                    infl[#infl + 1] = {activeBoneIdx, 0}
                    activeK = #infl
                end

                local oldW = infl[activeK][2]
                local newW = clamp(oldW + delta, 0, 1)
                local added = newW - oldW
                infl[activeK][2] = newW

                -- Subtract added amount from other bones proportionally
                local otherSum = 0
                for k = 1, #infl do
                    if k ~= activeK then otherSum = otherSum + infl[k][2] end
                end
                if otherSum > 0 then
                    for k = 1, #infl do
                        if k ~= activeK then
                            infl[k][2] = infl[k][2] - added * (infl[k][2] / otherSum)
                            if infl[k][2] < 0 then infl[k][2] = 0 end
                        end
                    end
                end
            else
                -- ERASING: decrease active bone, give weight to nearest other bone
                local activeK = nil
                for k = 1, #infl do
                    if infl[k][1] == activeBoneIdx then activeK = k; break end
                end
                if not activeK then goto continue end

                local oldW = infl[activeK][2]
                local newW = clamp(oldW - delta, 0, 1)
                local removed = oldW - newW
                infl[activeK][2] = newW

                if removed > 0 then
                    -- Find another bone to receive the weight
                    local otherK = nil
                    for k = 1, #infl do
                        if k ~= activeK and infl[k][2] > 0 then
                            otherK = k; break
                        end
                    end
                    if not otherK then
                        -- No other bone on this vertex — find nearest and add it
                        local nearIdx = findNearestBoneIdx(vx, vy, activeBoneIdx)
                        if nearIdx then
                            infl[#infl + 1] = {nearIdx, 0}
                            otherK = #infl
                        end
                    end
                    if otherK then
                        infl[otherK][2] = infl[otherK][2] + removed
                    end
                end
            end

            -- Remove near-zero entries
            local j = 1
            while j <= #infl do
                if infl[j][2] < 0.005 then
                    table.remove(infl, j)
                else
                    j = j + 1
                end
            end

            -- Safety: must have at least one entry
            if #infl == 0 then
                local nearIdx = findNearestBoneIdx(vx, vy, -1)
                infl[1] = {nearIdx or 1, 1.0}
            end

            ::continue::
        end
    end
end

-- Get the weight of a specific bone on a vertex (for visualization)
local function getBoneWeight(vi, boneIdx)
    if not boneWeights or not boneWeights[vi] then return 0 end
    for _, entry in ipairs(boneWeights[vi]) do
        if entry[1] == boneIdx then return entry[2] end
    end
    return 0
end

---------------------------------------------------------------------------
-- Mouse interaction
---------------------------------------------------------------------------
-- Find the nearest joint anchor to (x,y)
local function findNearestJointAnchor(x, y, maxDist)
    maxDist = maxDist or 12
    local bestKey, bestDist = nil, maxDist
    for key, anchor in pairs(jointAnchors) do
        local d = math.sqrt((x - anchor.x)^2 + (y - anchor.y)^2)
        if d < bestDist then
            bestDist = d
            bestKey = key
        end
    end
    return bestKey
end

-- Find a bone endpoint near (x,y). Returns bone, "A" or "B", distance
local function findNearestEndpoint(x, y, maxDist)
    maxDist = maxDist or 15
    local bestBone, bestEnd, bestDist = nil, nil, maxDist
    for _, bone in ipairs(bones) do
        local ax, ay, bx, by = bone:getWorldEndpoints()
        local dA = math.sqrt((x-ax)^2 + (y-ay)^2)
        local dB = math.sqrt((x-bx)^2 + (y-by)^2)
        if dA < bestDist then bestDist = dA; bestBone = bone; bestEnd = "A" end
        if dB < bestDist then bestDist = dB; bestBone = bone; bestEnd = "B" end
    end
    return bestBone, bestEnd, bestDist
end

-- Find which body key is at point
local function findBodyKeyAtPoint(x, y)
    for key, def in pairs(SKEL) do
        local body = allBodies[key]
        local bx, by = body:getPosition()
        -- Simple distance check to body center
        local d = math.sqrt((x-bx)^2 + (y-by)^2)
        if d < math.max(def.w, def.h) * 0.6 then
            return key
        end
    end
    return nil
end

-- Rebake: recapture bind pose from current body positions and recompute weights
local function rebake()
    for _, b in ipairs(bones) do
        b:updateFromPhysics()
        b.bindWorld = b.worldMat
        b.bindInv = M.inverse(b.bindWorld)
    end
    rebuildGrid()
end

-- Enter edit mode: snap bodies to bind pose and make kinematic
local function enterEditMode()
    editMode = true
    if mouseJoint then mouseJoint:destroy(); mouseJoint = nil end

    -- Snap all bodies back to their bind pose so they align with the undeformed image
    for _, bone in ipairs(bones) do
        local bx = bone.bindWorld[3]  -- tx from bind matrix
        local by = bone.bindWorld[6]  -- ty from bind matrix
        local angle = math.atan2(bone.bindWorld[4], bone.bindWorld[1])  -- rotation from bind matrix
        bone.body:setPosition(bx, by)
        bone.body:setAngle(angle)
    end

    -- Make everything kinematic for free dragging
    for key, body in pairs(allBodies) do
        body:setType("kinematic")
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

-- Exit edit mode: recreate joints at new positions, rebake bind pose
local function exitEditMode()
    editMode = false
    editDrag = nil

    -- Destroy old joints
    for key, j in pairs(allJoints) do
        j:destroy()
    end
    allJoints = {}

    -- Recreate joints using stored (possibly edited) anchor positions
    for key, def in pairs(JOINT_DEFS) do
        local bodyA = allBodies[def[1]]
        local bodyB = allBodies[def[2]]
        local anchor = jointAnchors[key]
        local j = love.physics.newRevoluteJoint(bodyA, bodyB, anchor.x, anchor.y, false)
        j:setLimitsEnabled(true)
        j:setLimits(def[5], def[6])
        allJoints[key] = j
    end

    -- Restore body types
    for key, def in pairs(SKEL) do
        allBodies[key]:setType(def.bodyType)
        allBodies[key]:setLinearVelocity(0, 0)
        allBodies[key]:setAngularVelocity(0)
    end

    -- Rebake bind pose and weights
    rebake()
end

local function findNearestBone(x, y, maxDist)
    maxDist = maxDist or 60
    local best, bestDist = nil, maxDist
    for _, bone in ipairs(bones) do
        local ax, ay, bx, by = bone:getWorldEndpoints()
        local d = distToSegment(x, y, ax, ay, bx, by)
        if d < bestDist then
            bestDist = d
            best = bone
        end
    end
    return best
end

local function bodyAtPoint(x, y)
    local found = nil
    world:queryBoundingBox(x - 2, y - 2, x + 2, y + 2, function(fixture)
        local b = fixture:getBody()
        if b:getType() == "dynamic" then
            found = b
            return false
        end
        return true
    end)
    return found
end

---------------------------------------------------------------------------
-- LÖVE callbacks
---------------------------------------------------------------------------
-- Helper to load an image file and return {image, imageData}
local function loadImagePair(filename)
    local iData = love.image.newImageData(filename)
    local img = love.graphics.newImage(iData)
    img:setFilter("linear", "linear")
    return img, iData
end

function love.load()
    love.window.setTitle("Textured Skeletal Deformation")
    love.graphics.setBackgroundColor(0.15, 0.15, 0.18)

    cachedImageData = love.image.newImageData(IMAGE_FILE)
    image = love.graphics.newImage(cachedImageData)
    image:setFilter("linear", "linear")
    local imgW, imgH = image:getDimensions()

    -- Center the image on screen
    DRAW_OFFSET_X = (1200 - imgW) * 0.5
    DRAW_OFFSET_Y = (768 - imgH) * 0.5

    createSkeleton()
    rebuildGrid()

    -- Set up multi-layer mode if layer images exist
    -- Draw order: torso (back) → legs (middle) → arms (front)
    local layerFiles = {"oldman-torso.png", "oldman-legs.png", "oldman-arms.png"}
    local allExist = true
    for _, f in ipairs(layerFiles) do
        if not love.filesystem.getInfo(f) then allExist = false; break end
    end
    if allExist then
        layers = {}
        for _, f in ipairs(layerFiles) do
            local img, data = loadImagePair(f)
            layers[#layers + 1] = buildLayerGrid(img, data)
        end
        love.window.setTitle("Textured Skeletal Deformation — MULTI-LAYER (" .. #layers .. " layers)")
    end

    -- Auto-load saved project
    loadProject()
end

function love.update(dt)
    if weightPaintMode then
        -- Paint while mouse is held
        if painting then paintWeights(mouseX, mouseY, true) end
        if erasing then paintWeights(mouseX, mouseY, false) end
        for _, b in ipairs(bones) do b:updateFromPhysics() end
        return
    end

    if editMode then
        -- In edit mode: handle body/endpoint dragging
        if editDrag then
            if editDrag.type == "body" then
                local body = allBodies[editDrag.key]
                body:setPosition(mouseX - editDrag.ox, mouseY - editDrag.oy)
            elseif editDrag.type == "endpointA" or editDrag.type == "endpointB" then
                -- Convert mouse world pos to body-local coords
                local bone = editDrag.bone
                local body = bone.body
                local lx, ly = body:getLocalPoint(mouseX, mouseY)
                if editDrag.type == "endpointA" then
                    bone.localA = {lx, ly}
                else
                    bone.localB = {lx, ly}
                end
            elseif editDrag.type == "joint" then
                jointAnchors[editDrag.key] = {x = mouseX, y = mouseY}
            end
        end
        -- Still update bone transforms for display
        for _, b in ipairs(bones) do b:updateFromPhysics() end
        return
    end

    if mouseJoint then
        mouseJoint:setTarget(mouseX, mouseY)
    end

    world:update(dt)

    -- Update bone transforms from physics
    for _, b in ipairs(bones) do
        b:updateFromPhysics()
    end

    -- Skin the mesh (CPU)
    if bindVerts._world and boneWeights then
        skinVertices(bindVerts._world, boneWeights, bones, deformedVerts)

        -- Push deformed positions into the LÖVE mesh
        for vi = 1, #deformedVerts do
            gridMesh:setVertex(vi,
                deformedVerts[vi][1] - DRAW_OFFSET_X,  -- back to image-local for drawing
                deformedVerts[vi][2] - DRAW_OFFSET_Y,
                bindVerts[vi][3],  -- u
                bindVerts[vi][4],  -- v
                255, 255, 255, 255
            )
        end
    end

    -- Skin all layers
    if layers then
        for _, L in ipairs(layers) do
            if L.bindVerts._world and L.boneWeights then
                skinVertices(L.bindVerts._world, L.boneWeights, bones, L.deformedVerts)
                for vi = 1, #L.deformedVerts do
                    L.gridMesh:setVertex(vi,
                        L.deformedVerts[vi][1] - DRAW_OFFSET_X,
                        L.deformedVerts[vi][2] - DRAW_OFFSET_Y,
                        L.bindVerts[vi][3],
                        L.bindVerts[vi][4],
                        255, 255, 255, 255
                    )
                end
            end
        end
    end
end

function love.draw()
    -- Draw the deformed textured mesh (dimmed in edit/paint mode)
    if editMode or weightPaintMode then
        love.graphics.setColor(1, 1, 1, 0.3)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Multi-layer: draw back-to-front
    if layers then
        for _, L in ipairs(layers) do
            love.graphics.draw(L.gridMesh, DRAW_OFFSET_X, DRAW_OFFSET_Y)
        end
    else
        love.graphics.draw(gridMesh, DRAW_OFFSET_X, DRAW_OFFSET_Y)
    end

    -- Weight paint heatmap overlay
    if weightPaintMode and activeBoneIdx and bindVerts._world then
        local gl = gridLevels[gridLevelIdx]
        local cols = gl.w + 1

        -- Draw filled triangles with weight-based colors
        for vi = 1, #bindVerts._world do
            local w = getBoneWeight(vi, activeBoneIdx)
            -- Heatmap: blue (0) -> green (0.5) -> red (1)
            local r, g, b
            if w < 0.5 then
                local t = w * 2
                r, g, b = 0, t, 1 - t
            else
                local t = (w - 0.5) * 2
                r, g, b = t, 1 - t, 0
            end
            love.graphics.setColor(r, g, b, 0.6)
            local vx, vy = bindVerts._world[vi][1], bindVerts._world[vi][2]
            love.graphics.circle("fill", vx, vy, 4)
        end

        -- Brush cursor
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", mouseX, mouseY, brushRadius)
        love.graphics.setLineWidth(1)

        -- Bone list with active highlight
        local listY = 140
        for bi, bone in ipairs(bones) do
            local isActive = (bi == activeBoneIdx)
            if isActive then
                love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 1)
                love.graphics.print("> " .. bone.name, 14, listY)
            else
                love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 0.5)
                love.graphics.print("  " .. bone.name, 14, listY)
            end
            listY = listY + 16
        end

        -- Draw all bones so you can click them
        love.graphics.setLineWidth(3)
        for bi, bone in ipairs(bones) do
            local ax, ay, bx, by = bone:getWorldEndpoints()
            local isActive = (bi == activeBoneIdx)
            love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], isActive and 1 or 0.4)
            love.graphics.line(ax, ay, bx, by)
            love.graphics.circle("fill", ax, ay, isActive and 6 or 3)
            love.graphics.circle("fill", bx, by, isActive and 6 or 3)
        end
        love.graphics.setLineWidth(1)

        -- Paint mode banner
        love.graphics.setColor(0.3, 0.8, 1, 1)
        local boneName = activeBoneIdx and bones[activeBoneIdx].name or "none"
        love.graphics.print("WEIGHT PAINT — click bone to select, LMB paint, RMB erase, scroll = brush size | bone: " .. boneName .. " | brush: " .. brushRadius, 14, 748)
    end

    -- Edit mode: draw all bone endpoints as draggable handles
    if editMode then
        for _, bone in ipairs(bones) do
            local ax, ay, bx, by = bone:getWorldEndpoints()
            -- Bone line
            love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 1)
            love.graphics.setLineWidth(3)
            love.graphics.line(ax, ay, bx, by)
            -- Endpoint handles (larger, hollow = draggable)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", ax, ay, 8)
            love.graphics.circle("line", bx, by, 8)
            love.graphics.circle("fill", ax, ay, 4)
            love.graphics.circle("fill", bx, by, 4)
            -- Radius circle (faint)
            love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 0.1)
            local emx, emy = bone:getWorldMidpoint()
                love.graphics.circle("line", ax, ay, bone.radiusA)
                love.graphics.circle("line", emx, emy, bone.radiusM)
                love.graphics.circle("line", bx, by, bone.radiusB)
            -- Label
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(bone.name, (ax+bx)*0.5 + 10, (ay+by)*0.5 - 8)
        end

        -- Body centers (draggable)
        for key, body in pairs(allBodies) do
            local bx, by = body:getPosition()
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle("fill", bx, by, 6)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.circle("line", bx, by, 10)
        end

        -- Joint anchors (draggable, prominent)
        for key, anchor in pairs(jointAnchors) do
            love.graphics.setColor(0.2, 1, 0.3, 0.9)
            love.graphics.circle("fill", anchor.x, anchor.y, 7)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", anchor.x, anchor.y, 7)
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.print(key, anchor.x + 10, anchor.y - 8)
        end

        -- Edit mode banner
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.print("EDIT MODE — drag bodies/joints/endpoints | W+scroll=width H+scroll=height T+scroll=rotate | E=bake", 14, 748)
        love.graphics.setLineWidth(1)
    end

    -- Debug overlay
    if debugMode then
        -- Grid wireframe (draw triangle edges from index buffer)
        if boneDisplayMode >= 1 then
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.setLineWidth(1)
            -- Draw each triangle's edges
            for i = 1, #gridIndices - 2, 3 do
                local a = gridIndices[i]
                local b = gridIndices[i + 1]
                local c = gridIndices[i + 2]
                if deformedVerts[a] and deformedVerts[b] and deformedVerts[c] then
                    love.graphics.line(deformedVerts[a][1], deformedVerts[a][2], deformedVerts[b][1], deformedVerts[b][2])
                    love.graphics.line(deformedVerts[b][1], deformedVerts[b][2], deformedVerts[c][1], deformedVerts[c][2])
                    love.graphics.line(deformedVerts[c][1], deformedVerts[c][2], deformedVerts[a][1], deformedVerts[a][2])
                end
            end
        end

        -- Bone segments + radius visualization
        if boneDisplayMode >= 1 then
            love.graphics.setLineWidth(3)
            for _, bone in ipairs(bones) do
                local ax, ay, bx, by = bone:getWorldEndpoints()
                local isHovered = (bone == hoveredBone)
                local alpha = isHovered and 1.0 or 0.8
                love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], alpha)
                love.graphics.line(ax, ay, bx, by)
                love.graphics.circle("fill", ax, ay, isHovered and 6 or 4)
                love.graphics.circle("fill", bx, by, isHovered and 6 or 4)

                -- Show radius profile around hovered bone (A, M, B)
                if isHovered then
                    local mx, my = bone:getWorldMidpoint()
                    love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 0.15)
                    love.graphics.circle("fill", ax, ay, bone.radiusA)
                    love.graphics.circle("fill", mx, my, bone.radiusM)
                    love.graphics.circle("fill", bx, by, bone.radiusB)
                    -- Connect with tapered shape: A→M and M→B
                    local dx, dy = bx - ax, by - ay
                    local len = math.sqrt(dx*dx + dy*dy)
                    if len > 0.1 then
                        local ux, uy = dx/len, dy/len
                        local nxA, nyA = -uy * bone.radiusA, ux * bone.radiusA
                        local nxM, nyM = -uy * bone.radiusM, ux * bone.radiusM
                        local nxB, nyB = -uy * bone.radiusB, ux * bone.radiusB
                        -- A to M
                        love.graphics.polygon("fill",
                            ax + nxA, ay + nyA, mx + nxM, my + nyM,
                            mx - nxM, my - nyM, ax - nxA, ay - nyA)
                        -- M to B
                        love.graphics.polygon("fill",
                            mx + nxM, my + nyM, bx + nxB, by + nyB,
                            bx - nxB, by - nyB, mx - nxM, my - nyM)
                    end
                    -- Midpoint marker
                    love.graphics.setColor(bone.color[1], bone.color[2], bone.color[3], 0.6)
                    love.graphics.circle("fill", mx, my, 4)
                    -- Labels
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print(math.floor(bone.radiusA), ax + 8, ay - 16)
                    love.graphics.print(math.floor(bone.radiusM), mx + 8, my - 16)
                    love.graphics.print(math.floor(bone.radiusB), bx + 8, by - 16)
                    love.graphics.print(bone.name, mx + 10, my + 8)
                end
            end
            love.graphics.setLineWidth(1)
        end

        -- Weight visualization: color each vertex by its dominant bone
        if boneDisplayMode >= 2 then
            for vi = 1, #deformedVerts do
                local infl = boneWeights[vi]
                if infl and #infl > 0 then
                    -- blend colors by weight
                    local r, g, b = 0, 0, 0
                    for k = 1, #infl do
                        local bone = bones[infl[k][1]]
                        local w = infl[k][2]
                        r = r + bone.color[1] * w
                        g = g + bone.color[2] * w
                        b = b + bone.color[3] * w
                    end
                    love.graphics.setColor(r, g, b, 0.7)
                    love.graphics.circle("fill", deformedVerts[vi][1], deformedVerts[vi][2], 3)
                end
            end
        end

        -- Bodies = bones (filled + outline, colored)
        for _, key in ipairs(SKEL_ORDER) do
            local def = SKEL[key]
            local body = allBodies[key]
            if body then
                local x, y = body:getPosition()
                local r = body:getAngle()
                local col = BODY_COLORS[key] or {1, 1, 1}
                love.graphics.push()
                love.graphics.translate(x, y)
                love.graphics.rotate(r)
                -- Filled (semi-transparent)
                love.graphics.setColor(col[1], col[2], col[3], 0.15)
                love.graphics.rectangle("fill", -def.w*0.5, -def.h*0.5, def.w, def.h)
                -- Outline
                love.graphics.setColor(col[1], col[2], col[3], 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", -def.w*0.5, -def.h*0.5, def.w, def.h)
                -- Center dot
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.circle("fill", 0, 0, 3)
                love.graphics.pop()
            end
        end

        -- Joint anchors (bigger, brighter)
        love.graphics.setColor(0.2, 0.9, 0.3, 0.8)
        for _, j in pairs(allJoints) do
            local x, y = j:getAnchors()
            love.graphics.circle("fill", x, y, 5)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle("line", x, y, 5)
            love.graphics.setColor(0.2, 0.9, 0.3, 0.8)
        end
    end

    -- Mouse joint target
    if mouseJoint then
        love.graphics.setColor(1, 1, 0, 0.9)
        love.graphics.circle("line", mouseX, mouseY, 8)
    end

    -- HUD
    love.graphics.setColor(1, 1, 1, 1)
    local gl = gridLevels[gridLevelIdx]
    local skinMode = useDQS and "DQS" or "LBS"
    local gridType = useAdaptiveGrid and "adaptive" or "uniform"
    love.graphics.print(table.concat({
        "Textured Skeletal Deformation",
        "LMB drag = move body parts | Scroll over bone = adjust radius",
        "E = edit bones | W = weight paint | S = skinning (" .. skinMode .. ")",
        "A = grid type (" .. gridType .. ") | G = grid size (" .. gl.name .. ") | Cmd+S = save | R = reset",
        "Vertices: " .. #bindVerts .. " | Bones: " .. #bones,
    }, "\n"), 14, 14)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function love.mousepressed(x, y, button)
    mouseX, mouseY = x, y

    if weightPaintMode then
        if button == 1 then
            -- Try to select a bone first (click near a bone segment)
            local nearBone = findNearestBone(x, y, 20)
            if nearBone then
                for bi, bone in ipairs(bones) do
                    if bone == nearBone then activeBoneIdx = bi; break end
                end
            else
                -- Start painting
                painting = true
            end
        elseif button == 2 then
            erasing = true
        end
        return
    end

    if button == 1 then
        if editMode then
            -- Priority: joint anchors first, then bone endpoints, then bodies
            local jointKey = findNearestJointAnchor(x, y, 12)
            if jointKey then
                editDrag = {type = "joint", key = jointKey}
            else
                local bone, endpoint, dist = findNearestEndpoint(x, y, 15)
                if bone then
                    editDrag = {type = "endpoint" .. endpoint, bone = bone}
                else
                    local key = findBodyKeyAtPoint(x, y)
                    if key then
                        local bx, by = allBodies[key]:getPosition()
                        editDrag = {type = "body", key = key, ox = x - bx, oy = y - by}
                    end
                end
            end
            return
        end

        -- Normal mode: physics drag
        local b = bodyAtPoint(x, y)
        if b then
            mouseBody = b
            local mj = love.physics.newMouseJoint(b, x, y)
            mj:setDampingRatio(0.7)
            mj:setFrequency(5.0)
            mj:setMaxForce(8000 * b:getMass())
            mouseJoint = mj
        end
    end
end

function love.mousemoved(x, y)
    mouseX, mouseY = x, y
    if debugMode and not mouseJoint and not editDrag then
        hoveredBone = findNearestBone(x, y)
    end
end

-- Resize a body's fixture (destroy old, create new with updated SKEL dimensions)
local function resizeBody(key, newW, newH)
    local def = SKEL[key]
    local body = allBodies[key]
    if not body or not def then return end
    def.w = math.max(10, newW)
    def.h = math.max(10, newH)
    -- Destroy old fixtures
    for _, f in ipairs(body:getFixtures()) do
        f:destroy()
    end
    -- Create new fixture with updated size
    local shape = love.physics.newRectangleShape(def.w, def.h)
    love.physics.newFixture(body, shape, 1.0)
    -- Update the bone's localA/localB to match new dimensions
    for _, bone in ipairs(bones) do
        if bone.body == body then
            local boneDef = boneFromBody(key, def)
            bone.localA = boneDef.localA
            bone.localB = boneDef.localB
        end
    end
end

function love.wheelmoved(wx, wy)
    if weightPaintMode then
        -- Scroll adjusts brush size in paint mode
        brushRadius = clamp(brushRadius + wy * 5, 5, 200)
        return
    end

    -- Edit mode: W+scroll=width, H+scroll=height, T+scroll=rotation
    if editMode then
        local key = findBodyKeyAtPoint(mouseX, mouseY)
        if key then
            local def = SKEL[key]
            local body = allBodies[key]
            local step = 5
            if love.keyboard.isDown("w") then
                resizeBody(key, def.w + wy * step, def.h)
                return
            elseif love.keyboard.isDown("h") then
                resizeBody(key, def.w, def.h + wy * step)
                return
            elseif love.keyboard.isDown("t") then
                body:setAngle(body:getAngle() + wy * 0.05)
                return
            end
        end
    end

    if debugMode and hoveredBone then
        local step = 5
        -- Find which of the 3 control points (A, M, B) is closest to mouse
        local ax, ay, bx, by = hoveredBone:getWorldEndpoints()
        local mx, my = hoveredBone:getWorldMidpoint()
        local dA = math.sqrt((mouseX-ax)^2 + (mouseY-ay)^2)
        local dM = math.sqrt((mouseX-mx)^2 + (mouseY-my)^2)
        local dB = math.sqrt((mouseX-bx)^2 + (mouseY-by)^2)
        if dA <= dM and dA <= dB then
            hoveredBone.radiusA = math.max(5, hoveredBone.radiusA + wy * step)
        elseif dM <= dA and dM <= dB then
            hoveredBone.radiusM = math.max(5, hoveredBone.radiusM + wy * step)
        else
            hoveredBone.radiusB = math.max(5, hoveredBone.radiusB + wy * step)
        end
        -- Recompute weights with new radii
        if not editMode then
            rebuildGrid()
        end
    end
end

function love.mousereleased(x, y, button)
    if weightPaintMode then
        if button == 1 then painting = false end
        if button == 2 then erasing = false end
        return
    end
    if button == 1 then
        if editMode then
            editDrag = nil
            return
        end
        if mouseJoint then
            mouseJoint:destroy()
            mouseJoint = nil
            mouseBody = nil
        end
    end
end

function love.keypressed(k)
    if k == "s" and (love.keyboard.isDown("lgui") or love.keyboard.isDown("lctrl")) then
        saveProject()
        return
    end
    if k == "e" then
        if weightPaintMode then return end  -- exit paint mode first
        if editMode then
            exitEditMode()
        else
            enterEditMode()
        end
        return
    elseif k == "w" then
        if editMode then return end  -- exit edit mode first
        weightPaintMode = not weightPaintMode
        painting = false
        erasing = false
        if not weightPaintMode then
            -- Exiting paint mode: select first bone by default for next time
        else
            -- Entering paint mode: select first bone if none active
            if not activeBoneIdx then activeBoneIdx = 1 end
        end
        return
    elseif k == "d" then
        debugMode = not debugMode
    elseif k == "b" then
        boneDisplayMode = (boneDisplayMode + 1) % 3
    elseif k == "s" then
        useDQS = not useDQS
    elseif k == "a" then
        useAdaptiveGrid = not useAdaptiveGrid
        rebuildGrid()
    elseif k == "g" then
        gridLevelIdx = gridLevelIdx % #gridLevels + 1
        rebuildGrid()
    elseif k == "f" then
        -- Toggle gravity and wake all bodies
        useGravity = not useGravity
        if world then
            world:setGravity(0, useGravity and 600 or 0)
            for _, body in pairs(allBodies) do
                body:setAwake(true)
            end
        end
    elseif k == "r" then
        -- Reset: destroy everything and recreate
        if mouseJoint then mouseJoint:destroy(); mouseJoint = nil end
        allBodies = {}
        allJoints = {}
        bones = {}
        createSkeleton()
        rebuildGrid()
    elseif k == "escape" then
        love.event.quit()
    end
end

function love.filedropped(file)
    local path = file:getFilename()
    local ext = path:lower():match("%.(%w+)$")
    if ext == "png" or ext == "jpg" or ext == "jpeg" then
        loadNewImage(path)
    elseif ext == "lua" then
        loadProject(path)
    end
end
