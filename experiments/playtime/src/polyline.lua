-- src/polyline.lua
-- A thick line as a triangle strip with mitered corners (the hair ribbons in
-- box2d-draw-textured.lua). It had none/bevel joins, anti-alias overdraw and a
-- random-width mode too; nothing used them.
local polyline = {}

local LINES_PARALLEL_EPS = 0.05

local sqrt, abs = math.sqrt, math.abs

local function vlen(x, y) return sqrt(x * x + y * y) end
local function normal_xy(vx, vy, scale) return -vy * scale, vx * scale end
local function cross(x1, y1, x2, y2) return x1 * y2 - y1 * x2 end

-- One corner: the two outline points at q, where the offset edges of q->r and the
-- previous segment meet (or straight across when they run on).
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

-- The strip around coords (flat x, y, ...) half_width to each side, as
-- { {x, y}, ... } for a 'strip' mesh. A line that ends where it starts closes.
function polyline.miter(coords, half_width)
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
        s_x, s_y, len_s = renderEdgeMiter(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, half_width)
    end

    -- tail / closure
    qx, qy = rx, ry
    if is_looping then
        rx, ry = coords[3], coords[4]
    else
        rx, ry = rx + s_x, ry + s_y
    end
    renderEdgeMiter(ax, ay, nx, ny, s_x, s_y, len_s, qx, qy, rx, ry, half_width)

    local vertices = {}
    for i = 1, #nx do
        vertices[i] = { ax[i] + nx[i], ay[i] + ny[i] }
    end
    return vertices
end

return polyline
