-- src/polyline.lua
local polyline = {}

local LINES_PARALLEL_EPS = 0.05

local sqrt, abs, random = math.sqrt, math.abs, love.math.random

-- math helpers (scalar-based; no tables)
local function vlen(x, y) return sqrt(x * x + y * y) end
local function normal_xy(vx, vy, scale) return -vy * scale, vx * scale end
local function cross(x1, y1, x2, y2) return x1 * y2 - y1 * x2 end

----------------------------------------------------------------------
-- Edge writers (no allocations; write to flat arrays ax/ay and nx/ny)
----------------------------------------------------------------------

-- JOIN: none (butt)
local function renderEdgeNone(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, hw)
    -- prev normal (from s)
    local inv_len_s        = 1 / len_s
    local nsx, nsy         = normal_xy(s_x, s_y, hw * inv_len_s)

    -- 1) contribute with previous normal
    local ai               = #ax + 1
    ax[ai], ay[ai]         = qx, qy
    ax[ai + 1], ay[ai + 1] = qx, qy

    local ni               = #nx + 1
    nx[ni], ny[ni]         = nsx, nsy
    nx[ni + 1], ny[ni + 1] = -nsx, -nsy

    -- 2) compute new segment and its normal
    local t_x, t_y         = rx - qx, ry - qy
    local len_t            = vlen(t_x, t_y)
    local inv_len_t        = 1 / len_t
    local ntx, nty         = normal_xy(t_x, t_y, hw * inv_len_t)

    -- 3) contribute with next normal (flipped then non-flipped)
    ai                     = #ax + 1
    ax[ai], ay[ai]         = qx, qy
    ax[ai + 1], ay[ai + 1] = qx, qy

    ni                     = #nx + 1
    nx[ni], ny[ni]         = -ntx, -nty
    nx[ni + 1], ny[ni + 1] = ntx, nty

    return t_x, t_y, len_t
end

-- JOIN: miter
local function renderEdgeMiter(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, hw)
    local inv_len_s        = 1 / len_s
    local nsx, nsy         = normal_xy(s_x, s_y, hw * inv_len_s)

    local t_x, t_y         = rx - qx, ry - qy
    local len_t            = vlen(t_x, t_y)
    local inv_len_t        = 1 / len_t
    local ntx, nty         = normal_xy(t_x, t_y, hw * inv_len_t)

    -- anchors at q (twice)
    local ai               = #ax + 1
    ax[ai], ay[ai]         = qx, qy
    ax[ai + 1], ay[ai + 1] = qx, qy

    -- parallel-ish & same direction?
    local det              = cross(s_x, s_y, t_x, t_y)
    local dot              = s_x * t_x + s_y * t_y
    if (abs(det) < LINES_PARALLEL_EPS * len_s * len_t) and (dot > 0) then
        local ni               = #nx + 1
        nx[ni], ny[ni]         = nsx, nsy
        nx[ni + 1], ny[ni + 1] = -nsx, -nsy
    else
        -- Cramer's rule for intersection of offset lines
        local dx, dy           = (ntx - nsx), (nty - nsy)
        local lambda           = cross(dx, dy, t_x, t_y) / det
        local mx, my           = nsx + s_x * lambda, nsy + s_y * lambda

        local ni               = #nx + 1
        nx[ni], ny[ni]         = mx, my
        nx[ni + 1], ny[ni + 1] = -mx, -my
    end

    return t_x, t_y, len_t
end

-- JOIN: bevel
local function renderEdgeBevel(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, hw)
    local inv_len_s = 1 / len_s
    local nsx, nsy = normal_xy(s_x, s_y, hw * inv_len_s)

    local t_x, t_y = rx - qx, ry - qy
    local len_t = vlen(t_x, t_y)
    local inv_len_t = 1 / len_t
    local ntx, nty = normal_xy(t_x, t_y, hw * inv_len_t)

    local det = cross(s_x, s_y, t_x, t_y)
    local dot = s_x * t_x + s_y * t_y

    -- parallel-ish & same direction → flat join using current normal
    if (abs(det) < LINES_PARALLEL_EPS * len_s * len_t) and (dot > 0) then
        local ai               = #ax + 1
        ax[ai], ay[ai]         = qx, qy
        ax[ai + 1], ay[ai + 1] = qx, qy

        local ni               = #nx + 1
        nx[ni], ny[ni]         = ntx, nty
        nx[ni + 1], ny[ni + 1] = -ntx, -nty

        return t_x, t_y, len_t
    end

    -- miter direction at q
    local dx, dy           = (ntx - nsx), (nty - nsy)
    local lambda           = cross(dx, dy, t_x, t_y) / det
    local mx, my           = nsx + s_x * lambda, nsy + s_y * lambda

    -- anchors: q four times
    local ai               = #ax + 1
    ax[ai], ay[ai]         = qx, qy
    ax[ai + 1], ay[ai + 1] = qx, qy
    ax[ai + 2], ay[ai + 2] = qx, qy
    ax[ai + 3], ay[ai + 3] = qx, qy

    local ni               = #nx + 1
    if det > 0 then
        -- left turn
        nx[ni], ny[ni]         = mx, my
        nx[ni + 1], ny[ni + 1] = -nsx, -nsy
        nx[ni + 2], ny[ni + 2] = mx, my
        nx[ni + 3], ny[ni + 3] = -ntx, -nty
    else
        -- right turn
        nx[ni], ny[ni]         = nsx, nsy
        nx[ni + 1], ny[ni + 1] = -mx, -my
        nx[ni + 2], ny[ni + 2] = ntx, nty
        nx[ni + 3], ny[ni + 3] = -mx, -my
    end

    return t_x, t_y, len_t
end

----------------------------------------------------------------------
-- Overdraw (AA) writers (use flat normals but preserve your API)
----------------------------------------------------------------------

local function renderOverdraw(vertices, offset, vertex_count, overdraw_vertex_count, nx, ny, pixel_size, is_looping)
    -- first side (forward)
    for i = 1, vertex_count, 2 do
        vertices[i + offset] = { vertices[i][1], vertices[i][2] }
        local nlen = vlen(nx[i], ny[i])
        vertices[i + offset + 1] = {
            vertices[i][1] + nx[i] * (pixel_size / nlen),
            vertices[i][2] + ny[i] * (pixel_size / nlen),
        }
    end

    -- second side (reverse)
    for i = 1, vertex_count, 2 do
        local k = vertex_count - i + 1
        vertices[offset + vertex_count + i] = { vertices[k][1], vertices[k][2] }
        local nlen = vlen(nx[k], ny[k])
        vertices[offset + vertex_count + i + 1] = {
            vertices[k][1] + nx[k] * (pixel_size / nlen),
            vertices[k][2] + ny[k] * (pixel_size / nlen),
        }
    end

    if not is_looping then
        -- cap spacing tweaks (preserves your original behavior)
        local spacerx                                    = vertices[offset + 1][1] - vertices[offset + 3][1]
        local spacery                                    = vertices[offset + 1][2] - vertices[offset + 3][2]
        local spacer_length                              = vlen(spacerx, spacery)
        spacerx, spacery                                 = spacerx * (pixel_size / spacer_length),
            spacery * (pixel_size / spacer_length)
        vertices[offset + 2][1], vertices[offset + 2][2] =
            vertices[offset + 2][1] + spacerx, vertices[offset + 2][2] + spacery
        vertices[offset + overdraw_vertex_count - 2][1]  =
            vertices[offset + overdraw_vertex_count - 2][1] + spacerx
        vertices[offset + overdraw_vertex_count - 2][2]  =
            vertices[offset + overdraw_vertex_count - 2][2] + spacery

        spacerx                                          = vertices[offset + vertex_count - 0][1] -
            vertices[offset + vertex_count - 2][1]
        spacery                                          = vertices[offset + vertex_count - 0][2] -
            vertices[offset + vertex_count - 2][2]
        spacer_length                                    = vlen(spacerx, spacery)
        spacerx, spacery                                 = spacerx * (pixel_size / spacer_length),
            spacery * (pixel_size / spacer_length)
        vertices[offset + vertex_count][1]               = vertices[offset + vertex_count][1] + spacerx
        vertices[offset + vertex_count][2]               = vertices[offset + vertex_count][2] + spacery
        vertices[offset + vertex_count + 2][1]           = vertices[offset + vertex_count + 2][1] + spacerx
        vertices[offset + vertex_count + 2][2]           = vertices[offset + vertex_count + 2][2] + spacery

        vertices[offset + overdraw_vertex_count - 1]     = vertices[offset + 1]
        vertices[offset + overdraw_vertex_count - 0]     = vertices[offset + 2]
    end
end

-- specialized AA for join_type == 'none'
local function renderOverdrawNone(vertices, offset, vertex_count, overdraw_vertex_count, pixel_size, is_looping)
    for i = 1, vertex_count - 1, 4 do
        local sx = vertices[i][1] - vertices[i + 3][1]
        local sy = vertices[i][2] - vertices[i + 3][2]
        local tx = vertices[i][1] - vertices[i + 1][1]
        local ty = vertices[i][2] - vertices[i + 1][2]
        local sl = vlen(sx, sy)
        local tl = vlen(tx, ty)
        sx, sy = sx * (pixel_size / sl), sy * (pixel_size / sl)
        tx, ty = tx * (pixel_size / tl), ty * (pixel_size / tl)

        local k = 4 * (i - 1) + 1 + offset
        vertices[k + 00] = { vertices[i + 0][1], vertices[i + 0][2] }
        vertices[k + 01] = { vertices[i + 0][1] + sx + tx, vertices[i + 0][2] + sy + ty }
        vertices[k + 02] = { vertices[i + 1][1] + sx - tx, vertices[i + 1][2] + sy - ty }
        vertices[k + 03] = { vertices[i + 1][1], vertices[i + 1][2] }

        vertices[k + 04] = { vertices[i + 1][1], vertices[i + 1][2] }
        vertices[k + 05] = { vertices[i + 1][1] + sx - tx, vertices[i + 1][2] + sy - ty }
        vertices[k + 06] = { vertices[i + 2][1] - sx - tx, vertices[i + 2][2] - sy - ty }
        vertices[k + 07] = { vertices[i + 2][1], vertices[i + 2][2] }

        vertices[k + 08] = { vertices[i + 2][1], vertices[i + 2][2] }
        vertices[k + 09] = { vertices[i + 2][1] - sx - tx, vertices[i + 2][2] - sy - ty }
        vertices[k + 10] = { vertices[i + 3][1] - sx + tx, vertices[i + 3][2] - sy + ty }
        vertices[k + 11] = { vertices[i + 3][1], vertices[i + 3][2] }

        vertices[k + 12] = { vertices[i + 3][1], vertices[i + 3][2] }
        vertices[k + 13] = { vertices[i + 3][1] - sx + tx, vertices[i + 3][2] - sy + ty }
        vertices[k + 14] = { vertices[i + 0][1] + sx + tx, vertices[i + 0][2] + sy + ty }
        vertices[k + 15] = { vertices[i + 0][1], vertices[i + 0][2] }
    end
end

----------------------------------------------------------------------
-- Public: polyline.render
----------------------------------------------------------------------

local JOIN = {
    none  = renderEdgeNone,
    miter = renderEdgeMiter,
    bevel = renderEdgeBevel,
}


function polyline.render(join_type, coords, half_width, pixel_size, draw_overdraw, rndMultiplier)
    local renderEdge = JOIN[join_type]
    assert(renderEdge, tostring(join_type) .. " is not a valid line join type.")

    -- safety: only single half_width supported
    assert(type(half_width) ~= "table", "half_width must be a single value (no array support).")

    -- flat arrays for anchors & normals (GC-light)
    local ax, ay = {}, {}
    local nx, ny = {}, {}

    -- initial segment
    local is_looping = (coords[1] == coords[#coords - 1]) and (coords[2] == coords[#coords])
    local s_x, s_y
    if is_looping then
        s_x, s_y = coords[1] - coords[#coords - 3], coords[2] - coords[#coords - 2]
    else
        s_x, s_y = coords[3] - coords[1], coords[4] - coords[2]
    end
    local len_s = vlen(s_x, s_y)

    -- sweep edges
    local qx, qy = coords[1], coords[2]
    local rx, ry = qx, qy
    for i = 1, #coords - 2, 2 do
        qx, qy = rx, ry
        rx, ry = coords[i + 2], coords[i + 3]
        s_x, s_y, len_s = renderEdge(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, half_width)
    end

    -- tail / closure
    qx, qy = rx, ry
    if is_looping then
        rx, ry = coords[3], coords[4]
    else
        rx, ry = rx + s_x, ry + s_y
    end
    s_x, s_y, len_s = renderEdge(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, half_width)

    -- emit vertices
    local vertices = {}
    local indices = nil
    local draw_mode = 'strip'
    local vertex_count = #nx

    local extra_vertices = 0
    local overdraw_vertex_count = 0
    if draw_overdraw then
        if join_type == 'none' then
            overdraw_vertex_count = 4 * (vertex_count - 4 - 1)
        else
            overdraw_vertex_count = 2 * vertex_count
            if not is_looping then overdraw_vertex_count = overdraw_vertex_count + 2 end
            extra_vertices = 2
        end
    end

    if join_type == 'none' then
        -- same as your original: drop the first two and last two
        local trimmed = vertex_count - 4
        for i = 3, vertex_count - 2 do
            local vi = #vertices + 1
            vertices[vi] = {
                ax[i] + nx[i],
                ay[i] + ny[i],
                0, 0, 255, 255, 255, 255 -- keep your 8-component vertex
            }
        end
        draw_mode = 'triangles'
        vertex_count = trimmed
    else
        -- strip layout; support optional random extrusion multiplier
        local use_rng = (rndMultiplier ~= nil)
        local firstR = nil
        for i = 1, vertex_count do
            local r = 1
            if use_rng then
                if i == 1 then
                    r = 5 * rndMultiplier + (random() * rndMultiplier)
                    firstR = r
                elseif i == vertex_count then
                    r = firstR or (5 * rndMultiplier + (random() * rndMultiplier))
                else
                    r = 5 * rndMultiplier + (random() * rndMultiplier)
                end
            end
            vertices[#vertices + 1] = { ax[i] + nx[i] * r, ay[i] + ny[i] * r }
        end
    end

    -- Overdraw (AA)
    if draw_overdraw then
        if join_type == 'none' then
            renderOverdrawNone(vertices, vertex_count + extra_vertices, vertex_count, overdraw_vertex_count, pixel_size,
                is_looping)
            for i = vertex_count + 1 + extra_vertices, #vertices do
                -- keep your original alpha pattern for 'none'
                if ((i % 4) < 2) then
                    vertices[i][8] = 255
                else
                    vertices[i][8] = 0
                end
            end
        else
            renderOverdraw(vertices, vertex_count + extra_vertices, vertex_count, overdraw_vertex_count, nx, ny,
                pixel_size, is_looping)
            for i = vertex_count + 1 + extra_vertices, #vertices do
                vertices[i][8] = 255 * (i % 2) -- alpha
            end
        end
    end

    -- extra verts for non-none AA path (preserves your seam behavior)
    if extra_vertices > 0 then
        vertices[vertex_count + 1] = { vertices[vertex_count][1], vertices[vertex_count][2] }
        vertices[vertex_count + 2] = { vertices[vertex_count + 3][1], vertices[vertex_count + 3][2] }
    end

    -- indices for triangles mode
    if draw_mode == 'triangles' then
        indices = {}
        local num_quads = (vertex_count + extra_vertices + overdraw_vertex_count) / 4
        for i = 0, num_quads - 1 do
            local b = i * 4
            -- First triangle
            indices[#indices + 1] = b + 0 + 1
            indices[#indices + 1] = b + 1 + 1
            indices[#indices + 1] = b + 2 + 1
            -- Second triangle
            indices[#indices + 1] = b + 0 + 1
            indices[#indices + 1] = b + 2 + 1
            indices[#indices + 1] = b + 3 + 1
        end
    end

    return vertices, indices, draw_mode
end

return polyline
