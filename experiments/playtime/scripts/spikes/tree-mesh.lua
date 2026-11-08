-- tree-mesh: a grown tree's branches (tree-grow.lua) as meshes for the bark shader (bark-look.lua) and
-- Nikki's crayon outlines (drawn-stroke.lua), not a scene. Loaded with
-- love.filesystem.load('scripts/spikes/tree-mesh.lua')() -> { parts, MESH_FORMAT }.
-- parts(branches, seed) -> one part per depth, deepest first (twigs behind their branches, branches behind
-- the trunk): { mesh, strokes (outline meshes), isStem (the trunk: the eyes go on it) }. seed turns each
-- branch's bark round a little differently. From the bark spike (docs/BARK.md).
local lib = {}

local STROKE = love.filesystem.load('scripts/spikes/drawn-stroke.lua')()

local MESH_FORMAT = {
    { 'VertexPosition', 'float', 2 },
    { 'Across', 'float', 2 },
    { 'Frame', 'float', 4 },
}

-- a branch's strip as triangles into verts (two vertices per point, its way up and its length so far), its
-- edges as lines for the outline (no line across its end: a trunk's limbs grow out of it there)
local function addStrip(pts, seed, verts, lines, trim)
    local left, right = {}, {}
    local prevL, prevR
    for i, p in ipairs(pts) do
        local a, b = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
        local ux, uy = b.x - a.x, b.y - a.y
        local len = math.sqrt(ux * ux + uy * uy)
        ux, uy = ux / len, uy / len
        local rx, ry = -uy, ux -- the strip's right (as the shader's)
        local hl, hr = (p.wl or p.w) / 2, (p.wr or p.w) / 2
        local half = (hl + hr) / 2
        local L = { p.x - rx * hl, p.y - ry * hl, -1, half, ux, uy, p.along, seed }
        local R = { p.x + rx * hr, p.y + ry * hr, 1, half, ux, uy, p.along, seed }
        if prevL then
            verts[#verts + 1] = prevL; verts[#verts + 1] = prevR; verts[#verts + 1] = L
            verts[#verts + 1] = prevR; verts[#verts + 1] = R; verts[#verts + 1] = L
        end
        prevL, prevR = L, R
        left[#left + 1] = { L[1], L[2] }
        right[#right + 1] = { R[1], R[2] }
    end
    -- the crayon line as thick as suits the branch (a twig's thinner, the thinnest none)
    local w = math.min(13, pts[1].w * 0.1)
    for _ = 1, math.min(trim or 0, #left - 2) do
        left[#left] = nil
        right[#right] = nil
    end
    if w >= 2.5 then
        lines[#lines + 1] = { pts = left, width = w }
        lines[#lines + 1] = { pts = right, width = w }
    end
end

function lib.parts(branches, seed)
    local byDepth, maxDepth = {}, 0
    for b, br in ipairs(branches) do
        local d = br.depth
        maxDepth = math.max(maxDepth, d)
        byDepth[d] = byDepth[d] or { verts = {}, lines = {} }
        addStrip(br.pts, seed + b * 0.173, byDepth[d].verts, byDepth[d].lines, br.outlineTrim)
    end
    local parts = {}
    for d = maxDepth, 0, -1 do
        local g = byDepth[d]
        if g and #g.verts >= 3 then
            parts[#parts + 1] = {
                mesh = love.graphics.newMesh(MESH_FORMAT, g.verts, 'triangles', 'static'),
                strokes = STROKE.meshes(g.lines, 0.6, 0, true), isStem = d == 0 }
        end
    end
    return parts
end

lib.MESH_FORMAT = MESH_FORMAT

return lib
