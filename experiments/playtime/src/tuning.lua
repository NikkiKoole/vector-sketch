-- tuning.lua — the numbers a spike was tuned with, kept around and findable once it's in the engine
-- (Nikki 2026-11-12: "keep the sliders and settings around and findable").
-- A module declares `lib.tuning`, a list of groups:
--   { label = 'reactions', target = function() return lib.REACT end, rows = tuning.numbers({ ... }) }
-- (rows as src/ui/inspector.lua draws them; target a function, so a hot swap's new table is the one shown).
-- The settings panel's 'tuning' section (src/ui/world-settings.lua) lists every loaded src module that has
-- one, by name, a fold per group. Live only, not saved: 'print values' writes the module's numbers to the
-- console (GET /console on the bridge) as lines to copy into the code.
local lib = {}

-- 'bend.1' -> { 'bend', 1 }
local function pathOf(field)
    local parts = {}
    for p in field:gmatch('[^.]+') do parts[#parts + 1] = tonumber(p) or p end
    return parts
end
local function getPath(t, parts)
    for i = 1, #parts do
        if type(t) ~= 'table' then return nil end
        t = t[parts[i]]
    end
    return t
end
local function setPath(t, parts, v)
    for i = 1, #parts - 1 do t = t[parts[i]] end
    t[parts[#parts]] = v
end

-- number rows over a table's fields: spec = { { 'field' or 'a.b.1', min, max[, step] }, ... }
function lib.numbers(spec)
    local rows = {}
    for _, r in ipairs(spec) do
        local parts = pathOf(r[1])
        rows[#rows + 1] = { key = r[1], kind = 'number', min = r[2], max = r[3], step = r[4],
            get = function(s) return getPath(s, parts) end,
            set = function(s, v) setPath(s, parts, v) end }
    end
    return rows
end

-- every loaded src module with tuning: { { name = 'mipo-emotion', groups = {...} }, ... }, by name
function lib.entries()
    local list = {}
    for moduleName, m in pairs(package.loaded) do
        if type(m) == 'table' and type(moduleName) == 'string' and moduleName:sub(1, 4) == 'src.'
            and type(m.tuning) == 'table' then
            list[#list + 1] = { name = moduleName:sub(5), groups = m.tuning }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function shown(v)
    if type(v) == 'number' then return string.format('%.4g', v) end
    return tostring(v)
end

-- the module's numbers now, to the console
function lib.print(entry)
    for _, group in ipairs(entry.groups) do
        local target = group.target()
        local parts = {}
        for _, row in ipairs(group.rows) do
            if row.get then parts[#parts + 1] = row.key .. ' = ' .. shown(row.get(target)) end
        end
        print(string.format('[tuning] %s %s: %s', entry.name, group.label, table.concat(parts, ', ')))
    end
end

return lib
