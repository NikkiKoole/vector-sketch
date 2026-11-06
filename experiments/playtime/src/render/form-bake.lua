-- form-bake.lua — a picture's roundness, baked from its mask, for the plasticine shader's light
-- (src/render/shaders.lua, extra.plasticineFormBaked). How far in from the outline a point is gives
-- a height, and the height a normal: the light then wraps round the whole shape, where the shader's
-- own guess (its alpha four texels around) only rounds the outer edge and leaves the middle flat.
-- After the glass bead spike's bake (scripts/spikes/glass.playtime.lua, 2026-11-04): a small grid
-- (MAP texels on the longer side), the mask averaged per cell (grainy brushes), small holes filled,
-- a chamfer distance, a round rise, smoothed twice.
-- rise: the part of the deepest distance in from the edge over which the shape rises to full height
-- (1: one dome over the whole shape; 0.2: a pebble, round at the edge, flat on top).
-- The map: r the height, g b the normal's x y (0.5 is flat), a inside. Cached per mask and rise: a
-- few small images per picture used, so it levels off like the other picture caches.
local lib = {}

lib.MAP = 96

local cache = {}

local function grid(data, step, gw, gh)
    local iw, ih = data:getDimensions()
    local inside, dist = {}, {}
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local sum, n = 0, 0
            for sy = math.floor(gy * step), math.min(ih - 1, math.floor((gy + 1) * step) - 1), 2 do
                for sx = math.floor(gx * step), math.min(iw - 1, math.floor((gx + 1) * step) - 1), 2 do
                    local r, _, _, a = data:getPixel(sx, sy)
                    sum = sum + r * a; n = n + 1 -- a mask: white inside, black outside
                end
            end
            local k = gy * gw + gx
            inside[k] = n > 0 and sum / n > 0.3
            dist[k] = inside[k] and 1e9 or 0
        end
    end
    return inside, dist
end

-- small holes (a grainy brush) filled; big ones stay holes (a ring)
local function fillSmallHoles(inside, dist, gw, gh)
    local seen = {}
    for start = 0, gw * gh - 1 do
        if not inside[start] and not seen[start] then
            local stack, comp, open = { start }, {}, false
            seen[start] = true
            while #stack > 0 do
                local k = table.remove(stack)
                comp[#comp + 1] = k
                local gx, gy = k % gw, math.floor(k / gw)
                if gx == 0 or gy == 0 or gx == gw - 1 or gy == gh - 1 then open = true end
                for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local nx, ny = gx + d[1], gy + d[2]
                    local nk = ny * gw + nx
                    if nx >= 0 and ny >= 0 and nx < gw and ny < gh and not inside[nk] and not seen[nk] then
                        seen[nk] = true
                        stack[#stack + 1] = nk
                    end
                end
            end
            if not open and #comp < gw * gh * 0.03 then
                for _, k in ipairs(comp) do inside[k] = true; dist[k] = 1e9 end
            end
        end
    end
end

-- how far in from the edge (a chamfer distance, two passes); returns the deepest
local function chamfer(inside, dist, gw, gh)
    local function at(gx, gy)
        if gx < 0 or gy < 0 or gx >= gw or gy >= gh then return 0 end
        return dist[gy * gw + gx]
    end
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local k = gy * gw + gx
            if inside[k] then
                dist[k] = math.min(dist[k], at(gx - 1, gy) + 1, at(gx, gy - 1) + 1,
                    at(gx - 1, gy - 1) + 1.414, at(gx + 1, gy - 1) + 1.414)
            end
        end
    end
    local dmax = 1
    for gy = gh - 1, 0, -1 do
        for gx = gw - 1, 0, -1 do
            local k = gy * gw + gx
            if inside[k] then
                dist[k] = math.min(dist[k], at(gx + 1, gy) + 1, at(gx, gy + 1) + 1,
                    at(gx + 1, gy + 1) + 1.414, at(gx - 1, gy + 1) + 1.414)
                if dist[k] > dmax then dmax = dist[k] end
            end
        end
    end
    return dmax
end

-- The map as ImageData from a mask's ImageData (white inside, black or see-through outside).
function lib.bakeData(data, rise)
    local iw, ih = data:getDimensions()
    rise = rise or 1
    -- a low rise (a pebble) turns from edge to flat top in a few cells: its rim followed the grid's
    -- steps (Nikki 2026-11-06, brass and gold showed them). A finer grid there, and the distance
    -- smoothed before it becomes a height. A dome (rise 1) is baked as before.
    local low = rise < 1
    local cells = low and math.floor(lib.MAP * math.min(2, 1 / math.sqrt(rise))) or lib.MAP
    local step = math.max(iw, ih) / cells
    local gw, gh = math.max(1, math.ceil(iw / step)), math.max(1, math.ceil(ih / step))
    local inside, dist = grid(data, step, gw, gh)
    fillSmallHoles(inside, dist, gw, gh)
    local dmax = chamfer(inside, dist, gw, gh)
    if low then
        for _ = 1, 4 do
            local smooth = {}
            for gy = 0, gh - 1 do
                for gx = 0, gw - 1 do
                    local k = gy * gw + gx
                    if inside[k] then
                        local sum = 0
                        for oy = -1, 1 do
                            for ox = -1, 1 do
                                local nx, ny = gx + ox, gy + oy
                                if nx >= 0 and ny >= 0 and nx < gw and ny < gh then
                                    sum = sum + dist[ny * gw + nx]
                                end
                            end
                        end
                        smooth[k] = sum / 9
                    else
                        smooth[k] = 0
                    end
                end
            end
            dist = smooth
        end
    end
    local riseTexels = math.max(1, rise * dmax)
    local height = {}
    for k = 0, gw * gh - 1 do
        local t = math.min(1, dist[k] / riseTexels)
        height[k] = inside[k] and math.sqrt(1 - (1 - t) * (1 - t)) or 0
    end
    local function h(gx, gy)
        gx = math.max(0, math.min(gw - 1, gx)); gy = math.max(0, math.min(gh - 1, gy))
        return height[gy * gw + gx]
    end
    for _ = 1, 2 do
        local smooth = {}
        for gy = 0, gh - 1 do
            for gx = 0, gw - 1 do
                local sum = 0
                for oy = -1, 1 do for ox = -1, 1 do sum = sum + h(gx + ox, gy + oy) end end
                smooth[gy * gw + gx] = sum / 9
            end
        end
        height = smooth
    end
    local map = love.image.newImageData(gw, gh)
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local dx = (h(gx + 1, gy) - h(gx - 1, gy)) * 0.5 * riseTexels
            local dy = (h(gx, gy + 1) - h(gx, gy - 1)) * 0.5 * riseTexels
            local len = math.sqrt(dx * dx + dy * dy + 1)
            map:setPixel(gx, gy, h(gx, gy), 0.5 - dx / len * 0.5, 0.5 - dy / len * 0.5,
                inside[gy * gw + gx] and 1 or 0)
        end
    end
    return map
end

-- The form map for a texfixture's look (from its mask; the outline picture is only lines), or nil.
function lib.map(extra, rise)
    local main = extra.main
    local url = main and main.fgURL
    if not url or url == '' then return nil end
    rise = rise or 1
    local key = url .. '|' .. string.format('%.2f', rise)
    if cache[key] == nil then
        local path = 'textures/' .. url
        if love.filesystem.getInfo(path, 'file') then
            -- mipmapped: drawn smaller than the map (a zoomed-out view), it skipped cells and its
            -- steps showed on shiny parts (Nikki 2026-11-06)
            local image = love.graphics.newImage(lib.bakeData(love.image.newImageData(path), rise), { mipmaps = true })
            image:setFilter('linear', 'linear')
            image:setMipmapFilter('linear')
            cache[key] = image
        else
            cache[key] = false
        end
    end
    return cache[key] or nil
end

return lib
