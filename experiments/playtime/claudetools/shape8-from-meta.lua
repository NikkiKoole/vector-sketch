-- The meta scene's meta8 outlines, next to src/shape8-dict.lua.
-- docs/SCENES.md.
--
-- Run from experiments/playtime:
--   lua claudetools/shape8-from-meta.lua
--
-- Compares scripts/tests/meta.playtime.json to the dict and to the shape catalogs.
-- The two agree exactly (synced 2026-11-01). A picture on the sheet that is not
-- in the dict yet is printed as a line to paste into src/shape8-dict.lua (the
-- editor's 'copy dict entry' on a meta8 sensor gives the same line).

local json = require('vendor.dkjson')

local M = {}

-- editor-render.lua logs a meta8 outline with math.floor(v + 0.5).
function M.roundCoord(v)
    return math.floor(v + 0.5)
end

local function moduleRoot()
    local src = debug.getinfo(1, 'S').source
    if src:sub(1, 1) == '@' then src = src:sub(2) end
    local dir = src:match('^(.-)/?claudetools/shape8%-from%-meta%.lua$')
    if not dir or dir == '' then return '.' end
    return dir
end

M.root = moduleRoot()
M.scenePath = M.root .. '/scripts/tests/meta.playtime.json'

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
        local url, meta, ankle
        for _, fix in ipairs(body.fixtures or {}) do
            local ud = fix.userData
            if type(ud) == 'table' then
                local extra = ud.extra or {}
                local bg = extra.main and extra.main.bgURL
                if ud.label == 'meta8' then meta = extra end
                if ud.label == 'ankle' and type(fix.points) == 'table' and #fix.points > 0 then
                    -- an anchor: a small square around the point
                    local x, y = 0, 0
                    for i = 1, #fix.points, 2 do x, y = x + fix.points[i], y + fix.points[i + 1] end
                    local n = #fix.points / 2
                    ankle = { M.roundCoord(x / n), M.roundCoord(y / n) }
                end
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
            rows[#rows + 1] = { url = url, dimensions = dims, vertices = vertices, ankle = ankle }
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

-- Width and height of a png, from its header; nil when there's no such file.
function M.pngSize(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local header = f:read(24)
    f:close()
    if not header or #header < 24 then return nil end
    local function u32(i)
        local b1, b2, b3, b4 = header:byte(i, i + 3)
        return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    end
    return u32(17), u32(21)
end

local function samePair(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2]
end

local function add(problems, msg)
    problems[#problems + 1] = msg
end

-- Empty when the sheet, the dict and the catalogs still correspond.
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
                    if delta > 0 then
                        add(problems, url .. ' outline differs from the sheet by ' .. delta ..
                            'px (paste the sheet\'s, or put the dict\'s back on the sheet; docs/SCENES.md)')
                    end
                end
                if not samePair(row.dimensions, shape.dimensions) then
                    local sw = row.dimensions and (row.dimensions[1] .. 'x' .. row.dimensions[2]) or 'missing'
                    local dw = shape.dimensions and (shape.dimensions[1] .. 'x' .. shape.dimensions[2]) or 'missing'
                    add(problems, url .. ' size differs (sheet ' .. sw .. ', dict ' .. dw .. ')')
                end
                -- the pngs were scaled down, so only the shape has to match (body-14 and ear-13
                -- had two digits swapped and were squashed)
                local pw, ph = M.pngSize(M.root .. '/textures/' .. url)
                local dims = shape.dimensions
                if pw and dims and math.abs((dims[1] / dims[2]) / (pw / ph) - 1) > 0.02 then
                    add(problems, url .. ' is ' .. dims[1] .. 'x' .. dims[2] .. ' in the dict, but the png is ' ..
                        pw .. 'x' .. ph .. ': another shape, so the picture is squashed')
                end
                if url:match('^mipo/ear/ear%-%d+%.png$') then
                    if type(shape.root) ~= 'table' or #shape.root ~= 2 then
                        add(problems, url .. ' needs a root (where the drawing meets the head); the sheet has none')
                    end
                elseif shape.root then
                    add(problems, url .. ' has a root; only ears do')
                end
            end
        end
    end
    -- feet hang from their ankle (src/character-topology.lua): every picture a foot can wear
    -- has one, on the sheet (an anchor labelled ankle) and in the dict, the same point
    local feet = catalogs and M.catalogUrls({ handShapes = catalogs.handShapes }) or {}
    for _, row in ipairs(rows) do
        local shape = row.url and dict[row.url]
        if shape then
            if feet[row.url] and not (row.ankle and shape.ankle) then
                add(problems, row.url .. ' is worn as a foot but has no ankle ' ..
                    (row.ankle and 'in the dict' or 'on the sheet (an anchor labelled ankle)'))
            elseif row.ankle and not shape.ankle then
                add(problems, row.url .. ' has an ankle on the sheet but not in the dict')
            elseif shape.ankle and not row.ankle then
                add(problems, row.url .. ' has an ankle in the dict but not on the sheet')
            elseif row.ankle and not samePair(row.ankle, shape.ankle) then
                add(problems, row.url .. ' ankle: sheet ' .. row.ankle[1] .. ',' .. row.ankle[2] ..
                    ', dict ' .. shape.ankle[1] .. ',' .. shape.ankle[2])
            end
        end
    end
    for url, shape in pairs(dict) do
        if not seen[url] and not shape.measured then -- measured: from the picture, not traced on the sheet yet
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
    local ankle = row.ankle and string.format(' ankle = { %d, %d },', row.ankle[1], row.ankle[2]) or ''
    return string.format("    ['%s'] = { dimensions = { %d, %d },%s\n        vertices = { %s } },",
        row.url, row.dimensions[1], row.dimensions[2], ankle, table.concat(coords, ', '))
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
        print(#rows .. ' pictures. The sheet and src/shape8-dict.lua agree. docs/SCENES.md')
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
