-- The meta scene's meta8 outlines, next to src/shape8-dict.lua.
-- docs/SCENES.md.
--
-- Run from experiments/playtime:
--   lua claudetools/shape8-from-meta.lua
--
-- Compares scripts/meta.playtime.json to the dict and to the shape catalogs.
-- A picture on the sheet that is not in the dict yet is printed as a line to
-- paste into src/shape8-dict.lua. This does not write the dict: four outlines
-- on the sheet were retuned in the dict, and the game uses the dict.

local json = require('vendor.dkjson')

local M = {}

-- editor-render.lua logs a meta8 outline with math.floor(v + 0.5).
function M.roundCoord(v)
    return math.floor(v + 0.5)
end

-- Outlines retuned in the dict after the sheet was saved. Within a pixel means
-- "still the same trace"; these are not. The game uses the dict.
M.vertexDrift = {
    ['hand3r.png'] = true,  -- up to 124px; retuned 2025-07 ("hands are good now")
    ['earx3r.png'] = true,  -- up to 222px
    ['feet3xr.png'] = true, -- up to 68px
    ['shapeA3.png'] = true, -- the centre line, up to 8px
}

-- Sheet size, then the dict size. earx2r's outline matches; only the width differs.
M.dimensionDrift = {
    ['earx2r.png'] = { sheet = { 352, 420 }, dict = { 354, 420 } },
    ['feet3xr.png'] = { sheet = { 213, 505 }, dict = { 231, 505 } },
}

local function moduleRoot()
    local src = debug.getinfo(1, 'S').source
    if src:sub(1, 1) == '@' then src = src:sub(2) end
    local dir = src:match('^(.-)/?claudetools/shape8%-from%-meta%.lua$')
    if not dir or dir == '' then return '.' end
    return dir
end

M.root = moduleRoot()
M.scenePath = M.root .. '/scripts/meta.playtime.json'

function M.loadScene(path)
    local f, openErr = io.open(path, 'r')
    if not f then return nil, 'cannot read ' .. tostring(path) .. ': ' .. tostring(openErr) end
    local text = f:read('*a')
    f:close()
    local scene, _, err = json.decode(text)
    if err or type(scene) ~= 'table' then
        return nil, 'cannot parse ' .. tostring(path) .. ': ' .. tostring(err)
    end
    return scene
end

-- One row per body that has a meta8 sensor or a part picture.
-- vertices are extra.vertices (point 1 first), rounded like the editor log.
function M.outlines(scene)
    local rows = {}
    for _, body in ipairs(scene.bodies or {}) do
        local url, meta
        for _, fix in ipairs(body.fixtures or {}) do
            local ud = fix.userData
            if type(ud) == 'table' then
                local extra = ud.extra or {}
                local bg = extra.main and extra.main.bgURL
                if ud.label == 'meta8' then meta = extra end
                if type(bg) == 'string' and bg ~= '' and ud.label ~= 'meta8' then
                    url = bg
                end
            end
        end
        if meta or url then
            local vertices
            if meta and type(meta.vertices) == 'table' then
                vertices = {}
                for i, v in ipairs(meta.vertices) do
                    vertices[i] = M.roundCoord(v)
                end
            end
            local dims
            if body.dims and body.dims.width and body.dims.height then
                dims = { body.dims.width, body.dims.height }
            end
            rows[#rows + 1] = { url = url, dimensions = dims, vertices = vertices }
        end
    end
    return rows
end

function M.maxDelta(a, b)
    if not a or not b or #a ~= #b or #a == 0 then return math.huge end
    local maxDelta = 0
    for i = 1, #a do
        local d = math.abs(a[i] - b[i])
        if d > maxDelta then maxDelta = d end
    end
    return maxDelta
end

function M.catalogUrls(catalogs)
    local set = {}
    for _, group in ipairs({ 'torsoHeadShapes', 'earShapes', 'feetShapes', 'handShapes' }) do
        for _, name in ipairs(catalogs[group] or {}) do
            set[name .. '.png'] = true
        end
    end
    return set
end

local function samePair(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2]
end

local function add(problems, msg)
    problems[#problems + 1] = msg
end

-- Empty when the sheet, the dict and the catalogs still correspond, including
-- the known drifts above (those must still be the recorded difference).
function M.problems(rows, dict, catalogs)
    local problems = {}
    local seen = {}
    for _, row in ipairs(rows) do
        local url = row.url
        if not url or url == '' then
            add(problems, 'a meta8 body has no picture url')
        elseif seen[url] then
            add(problems, url .. ' is on the sheet twice')
        else
            seen[url] = true
            local shape = dict[url]
            if not shape then
                add(problems, url .. ' is on the sheet but not in src/shape8-dict.lua')
            else
                if not row.vertices or #row.vertices ~= 16 or #shape.vertices ~= 16 then
                    add(problems, url .. ' outline is not 8 points')
                else
                    local delta = M.maxDelta(row.vertices, shape.vertices)
                    if M.vertexDrift[url] then
                        if delta <= 1 then
                            add(problems, url ..
                                ' outline matches the sheet now; remove it from vertexDrift in claudetools/shape8-from-meta.lua')
                        end
                    elseif delta > 1 then
                        add(problems, url .. ' outline differs from the sheet by ' .. delta ..
                            'px (the game uses the dict; see docs/SCENES.md)')
                    end
                end
                local expect = M.dimensionDrift[url]
                if expect then
                    if not samePair(row.dimensions, expect.sheet) then
                        add(problems, url .. ' sheet size is no longer ' ..
                            expect.sheet[1] .. 'x' .. expect.sheet[2])
                    end
                    if not samePair(shape.dimensions, expect.dict) then
                        add(problems, url .. ' dict size is no longer ' ..
                            expect.dict[1] .. 'x' .. expect.dict[2])
                    end
                elseif not samePair(row.dimensions, shape.dimensions) then
                    local sw = row.dimensions and (row.dimensions[1] .. 'x' .. row.dimensions[2]) or 'missing'
                    local dw = shape.dimensions and (shape.dimensions[1] .. 'x' .. shape.dimensions[2]) or 'missing'
                    add(problems, url .. ' size differs (sheet ' .. sw .. ', dict ' .. dw .. ')')
                end
                if url:match('^earx%d+r%.png$') then
                    if type(shape.root) ~= 'table' or #shape.root ~= 2 then
                        add(problems, url .. ' needs a root (where the drawing meets the head); the sheet has none')
                    end
                elseif shape.root then
                    add(problems, url .. ' has a root; only ears do')
                end
            end
        end
    end
    for url in pairs(dict) do
        if not seen[url] then
            add(problems, url .. ' is in the dict but not on the meta sheet')
        end
    end
    if catalogs then
        local listed = M.catalogUrls(catalogs)
        for url in pairs(dict) do
            if not listed[url] then
                add(problems, url ..
                    ' is not in src/shape-catalogs.lua (torsoHeadShapes, earShapes, feetShapes or handShapes)')
            end
        end
        for url in pairs(listed) do
            if not dict[url] then
                add(problems, url .. ' is in a shape catalog but not in the dict')
            end
        end
    end
    table.sort(problems)
    return problems
end

function M.entryText(row)
    local coords = {}
    for i, n in ipairs(row.vertices) do
        coords[i] = string.format('%d', n)
    end
    return string.format("    ['%s'] = { dimensions = { %d, %d },\n        vertices = { %s } },",
        row.url, row.dimensions[1], row.dimensions[2], table.concat(coords, ', '))
end

function M.main()
    local scene, err = M.loadScene(M.scenePath)
    if not scene then
        io.stderr:write(err .. '\n')
        os.exit(1)
    end
    local dict = require('src.shape8-dict')
    local catalogs = require('src.shape-catalogs')
    local rows = M.outlines(scene)
    for _, row in ipairs(rows) do
        if row.url and row.vertices and row.dimensions and not dict[row.url] then
            print(row.url .. ' — paste into src/shape8-dict.lua:')
            print(M.entryText(row))
            if row.url:match('^ear') then
                print('    -- ear: add root = { x, y } where the drawing meets the head, measured from the mask')
            end
            print('    -- and add the name (no .png) to src/shape-catalogs.lua')
        end
    end
    local problems = M.problems(rows, dict, catalogs)
    if #problems == 0 then
        print(#rows .. ' pictures. The sheet and src/shape8-dict.lua agree within a pixel,')
        print('except the known drifts (hand3r, earx3r, feet3xr, shapeA3, and the earx2r / feet3xr sizes).')
        print('The game uses the dict. docs/SCENES.md')
        return
    end
    print(#problems .. ' difference(s) between the meta sheet and src/shape8-dict.lua:')
    for _, problem in ipairs(problems) do
        print('  ' .. problem)
    end
    os.exit(1)
end

local script = arg and arg[0]
if script and script:match('shape8%-from%-meta%.lua$') then
    M.main()
end

return M
