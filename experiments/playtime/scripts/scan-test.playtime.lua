-- scan-test: a spike for docs/ASSETS-AND-BUILDS.md AB1: parts cut from old scans by claudetools/scan2tex.py
-- (textures/scantest/), baked the way the game bakes a Mipo part (outline + mask + pattern), above the
-- game's own GIMP-made textures baked the same way.
-- keys: 1 baked (colour, pattern, line)   2 outline only   3 mask only   s small (as on the phone)
--   c the next body colour   b the next background   r bake again
--   patterns (textures/pat/, as the Mipo look panel uses them): p next pattern (or off)   o its colour
--   [ ] smaller / bigger   t turn it   m mixed: a random pattern and colour per part (a random Mipo's look)
-- The scan parts are made, not committed: for n in 12 14; do python3 -I claudetools/scan2tex.py \
--   "../../scans/Scan $n.png" textures/scantest scan$n; done   (INSET=n sets how far inside the line the
--   mask stops); then r here.

local s = {}

local bake = ompBake

local GAME = { 'shapes1', 'shapes2', 'shapes6', 'shapes9', 'feet2r', 'feet6r', 'feet7r', 'earx3r', 'earx10r',
               'nose3', 'eye3', 'pupil3' }
local BODIES = { { 0.91, 0.59, 0.43 }, { 0.55, 0.75, 0.42 }, { 0.98, 0.85, 0.35 }, { 0.42, 0.58, 0.85 },
                 { 0.95, 0.95, 0.93 } }
local BACKS = { { 0.78, 0.86, 0.78 }, { 0.16, 0.16, 0.2 }, { 1, 1, 1 } }
local LINE = { 0.24, 0.12, 0.16 }
local PAT_COLORS = { { 0.25, 0.12, 0.16, 0.55 }, { 1, 1, 1, 0.7 }, { 0.98, 0.85, 0.35, 0.9 }, { 0.42, 0.58, 0.85, 0.8 },
                     { 0.8, 0.25, 0.3, 0.8 } }
local PAT_SCALES = { 0.25, 0.5, 1, 2, 4 }
local GAP, ROW_W = 24, 3000

local function lab() -- on state, so a script hot reload keeps the settings
    state.scanTest = state.scanTest or { view = 1, small = false, body = 1, back = 1 }
    local l = state.scanTest
    l.pat, l.patColor, l.patScale, l.patRot = l.pat or 1, l.patColor or 1, l.patScale or 3, l.patRot or 0
    return l
end

local function image(path)
    if not love.filesystem.getInfo(path, 'file') then return nil end
    local ok, img = pcall(love.graphics.newImage, path, { mipmaps = true })
    if not ok then return nil end
    img:setFilter('linear', 'linear')
    img:setMipmapFilter('linear')
    return img
end

-- the patterns: textures/pat/*.png, repeated mirrored as the game does (omp-bake)
local function patterns()
    local l = lab()
    if not l.patterns then
        l.patterns = {}
        for _, file in ipairs(love.filesystem.getDirectoryItems('textures/pat')) do
            if file:match('%.png$') then
                local img = image('textures/pat/' .. file)
                if img then
                    img:setWrap('mirroredrepeat', 'mirroredrepeat')
                    l.patterns[#l.patterns + 1] = { name = file, img = img }
                end
            end
        end
        table.sort(l.patterns, function(a, b) return a.name < b.name end)
    end
    return l.patterns
end

-- name -> { line, mask, baked }
local function part(name)
    return { name = name, line = image('textures/' .. name .. '.png'),
             mask = image('textures/' .. name .. '-mask.png') }
end

-- l.pat: 1 = off, 2.. = patterns()[l.pat - 1], 'mixed' = a random one per part (seeded per part)
local function bakeAll()
    local l = lab()
    local pats = patterns()
    for _, row in ipairs(l.rows) do
        for i, p in ipairs(row.parts) do
            if p.line then
                local pat, col, body = nil, PAT_COLORS[l.patColor], BODIES[l.body]
                if l.pat == 'mixed' then
                    local rnd = love.math.newRandomGenerator(i * 7919 + #row.title)
                    pat = pats[rnd:random(#pats)].img
                    col = PAT_COLORS[rnd:random(#PAT_COLORS)]
                    body = BODIES[rnd:random(#BODIES)]
                elseif l.pat > 1 then
                    pat = pats[l.pat - 1].img
                end
                local k = PAT_SCALES[l.patScale]
                local data = bake.makeTexturedCanvas(p.line, p.mask, body, 1, pat,
                    { col[1], col[2], col[3] }, pat and col[4] or 0, l.patRot, k, k, 0, 0, LINE, 1, 1, 1, nil)
                if p.baked then p.baked:release() end
                p.baked = love.graphics.newImage(data, { mipmaps = true })
                p.baked:setMipmapFilter('linear')
            end
        end
    end
end

local function build()
    local l = lab()
    local scans = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems('textures/scantest')) do
        local base = file:match('^(.-)%.png$')
        if base and not base:find('%-mask$') then scans[#scans + 1] = 'scantest/' .. base end
    end
    table.sort(scans)
    local game = {}
    for _, name in ipairs(GAME) do game[#game + 1] = name end
    l.rows = { { title = 'from the scans (claudetools/scan2tex.py, no GIMP)', parts = {} },
               { title = "the game's textures now (GIMP)", parts = {} } }
    for _, name in ipairs(scans) do table.insert(l.rows[1].parts, part(name)) end
    for _, name in ipairs(game) do table.insert(l.rows[2].parts, part(name)) end
    bakeAll()
end

function s.onStart() -- the camera is the scene file's (scan-test.playtime.json): the whole board
    worldState.paused = true
    build()
end

function s.onKeyPress(key)
    local l = lab()
    if key == '1' or key == '2' or key == '3' then l.view = tonumber(key) end
    if key == 's' then l.small = not l.small end
    if key == 'c' then l.body = l.body % #BODIES + 1; bakeAll() end
    if key == 'b' then l.back = l.back % #BACKS + 1 end
    local pats = #patterns()
    if key == 'p' then l.pat = l.pat == 'mixed' and 1 or l.pat % (pats + 1) + 1; bakeAll() end
    if key == 'm' then l.pat = l.pat == 'mixed' and 1 or 'mixed'; bakeAll() end
    if key == 'o' then l.patColor = l.patColor % #PAT_COLORS + 1; bakeAll() end
    if key == '[' then l.patScale = math.max(1, l.patScale - 1); bakeAll() end
    if key == ']' then l.patScale = math.min(#PAT_SCALES, l.patScale + 1); bakeAll() end
    if key == 't' then l.patRot = (l.patRot + math.pi / 4) % (math.pi * 2); bakeAll() end
    if key == 'r' then build() end
end

-- the parts laid out in rows, wrapping at ROW_W; drawn in the world, so the editor camera pans and zooms
function s.draw()
    local l = lab()
    if not l.rows then return end
    local back = BACKS[l.back]
    love.graphics.setColor(back[1], back[2], back[3])
    love.graphics.rectangle('fill', -200, -400, ROW_W + 400, 6000)
    local scale = l.small and 0.25 or 1
    local y = 0
    for _, row in ipairs(l.rows) do
        love.graphics.setColor(back[1] < 0.5 and 1 or 0, back[1] < 0.5 and 1 or 0, back[1] < 0.5 and 1 or 0)
        love.graphics.print(row.title, 0, y - 90, 0, 4, 4)
        local x, rowH = 0, 0
        for _, p in ipairs(row.parts) do
            local img = (l.view == 1 and p.baked) or (l.view == 2 and p.line) or (l.view == 3 and p.mask) or p.line
            if img then
                local w, h = img:getDimensions()
                local k = scale * (img == p.baked and 2 or 1) -- the bake is half size (omp-bake's shrinkFactor)
                if x + w * k > ROW_W then x, y, rowH = 0, y + rowH + GAP, 0 end
                local tint = l.view == 2 and LINE or { 1, 1, 1 }
                love.graphics.setColor(tint[1], tint[2], tint[3])
                love.graphics.draw(img, x, y, 0, k, k)
                x = x + w * k + GAP
                rowH = math.max(rowH, h * k)
            end
        end
        y = y + rowH + 260
    end
end

function s.drawUI()
    local l = lab()
    local views = { 'baked', 'outline', 'mask' }
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 10, 700, 900, 54)
    love.graphics.setColor(1, 1, 1)
    local pats = patterns()
    local pat = l.pat == 'mixed' and 'mixed (m)' or l.pat == 1 and 'off' or pats[l.pat - 1].name
    love.graphics.print(('view: %s%s   pattern: %s  x%s   1/2/3 s c b r · p o [ ] t m (see the script)')
        :format(views[l.view], l.small and ' (small)' or '', pat, PAT_SCALES[l.patScale]), 20, 718)
end

function s.onUnload()
    local l = state.scanTest
    if not l or not l.rows then return end
    for _, row in ipairs(l.rows) do
        for _, p in ipairs(row.parts) do
            for _, k in ipairs({ 'line', 'mask', 'baked' }) do if p[k] then p[k]:release() end end
        end
    end
    l.rows = nil
end

return s
