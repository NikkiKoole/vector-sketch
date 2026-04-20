-- limb.lua — generate a simple ribbon-like limb polygon around a chain.
--
-- Sandbox Phase B: before the user can trace a limb by hand, hardcode a
-- uniform-width polygon around each limb's rest chain. This gives us
-- something bindable right now. Later, replace with traced polygons.

local M = {}

-- Build a ribbon polygon of constant halfWidth around a chain. Returns
-- flat array {x1,y1,...} with 2N points: N top (left-forward), N bottom
-- (right-backward). Matches playtime's polylineRibbon layout so (t, s)
-- signs land where expected.
function M.ribbonAroundChain(chain, halfWidth)
    local n = #chain / 2
    assert(n >= 2, 'need >=2 chain points')

    local function segNormal(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local L = math.sqrt(dx * dx + dy * dy)
        if L < 1e-9 then return 0, 0 end
        return -dy / L, dx / L -- left-normal
    end

    local left, right = {}, {}
    for i = 1, n do
        local x, y = chain[(i - 1) * 2 + 1], chain[(i - 1) * 2 + 2]
        local nx, ny
        if i == 1 then
            nx, ny = segNormal(x, y, chain[i * 2 + 1], chain[i * 2 + 2])
        elseif i == n then
            nx, ny = segNormal(chain[(i - 2) * 2 + 1], chain[(i - 2) * 2 + 2], x, y)
        else
            local nx1, ny1 = segNormal(chain[(i - 2) * 2 + 1], chain[(i - 2) * 2 + 2], x, y)
            local nx2, ny2 = segNormal(x, y, chain[i * 2 + 1], chain[i * 2 + 2])
            nx, ny = nx1 + nx2, ny1 + ny2
            local L = math.sqrt(nx * nx + ny * ny)
            if L > 1e-9 then nx, ny = nx / L, ny / L end
        end
        left[#left + 1] = x + nx * halfWidth
        left[#left + 1] = y + ny * halfWidth
        right[#right + 1] = x - nx * halfWidth
        right[#right + 1] = y - ny * halfWidth
    end

    local poly = {}
    for i = 1, #left, 2 do
        poly[#poly + 1] = left[i]
        poly[#poly + 1] = left[i + 1]
    end
    for i = #right - 1, 1, -2 do
        poly[#poly + 1] = right[i]
        poly[#poly + 1] = right[i + 1]
    end
    return poly
end

return M
