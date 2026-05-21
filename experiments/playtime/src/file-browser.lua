local lib = {}
local ui = require('src.ui.all')

local PANEL_W   = 420
local PANEL_H   = 480
local PANEL_X   = 180
local PANEL_Y   = 80
local THUMB     = 44
local ROW_H     = 50
local ROW_GAP   = 4
local DIR_H     = 30

local state = {
    open        = false,
    basePath    = '',
    currentPath = '',
    filterRules = nil,
    files       = {},
    dirs        = {},
    callback    = nil,
    query       = '',
    imageCache  = {},
}

local function loadDir(path, filterRules)
    local files = {}
    local dirs  = {}
    local items = love.filesystem.getDirectoryItems(path)
    for _, item in ipairs(items) do
        local info = love.filesystem.getInfo(path .. '/' .. item)
        if info then
            if info.type == 'directory' then
                table.insert(dirs, { name = item, full = path .. '/' .. item })
            elseif info.type == 'file' then
                local ok = true
                if filterRules then
                    if filterRules.excludes and string.find(item, filterRules.excludes) then ok = false end
                    if filterRules.includes and not string.find(item, filterRules.includes) then ok = false end
                end
                if ok then
                    table.insert(files, { path = path, item = item, full = path .. '/' .. item })
                end
            end
        end
    end
    table.sort(dirs,  function(a, b) return a.name < b.name end)
    table.sort(files, function(a, b) return a.item < b.item end)
    return files, dirs
end

local function getImage(fullPath)
    if state.imageCache[fullPath] == nil then
        local ok, img = pcall(love.graphics.newImage, fullPath)
        state.imageCache[fullPath] = ok and img or false
    end
    return state.imageCache[fullPath]
end

local function navigate(path)
    state.currentPath = path
    state.query       = ''
    state.files, state.dirs = loadDir(path, state.filterRules)
end

function lib:open(path, filterRules, callback)
    state.open        = true
    state.basePath    = path
    state.filterRules = filterRules
    state.callback    = callback
    navigate(path)
end

function lib:close()
    state.open     = false
    state.callback = nil
end

function lib:isOpen()
    return state.open
end

function lib:draw()
    if not state.open then return end

    -- Filter files by search query (dirs always shown unfiltered)
    local filtered = {}
    local q = state.query:lower()
    for _, f in ipairs(state.files) do
        if q == '' or string.find(f.item:lower(), q, 1, true) then
            table.insert(filtered, f)
        end
    end

    local atRoot    = (state.currentPath == state.basePath)
    local showBack  = not atRoot
    local dirCount  = #state.dirs + (showBack and 1 or 0)
    local totalH    = dirCount * (DIR_H + ROW_GAP) + #filtered * (ROW_H + ROW_GAP)

    ui.panel(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, '• pick texture •', function()
        local x = PANEL_X + 10
        local y = PANEL_Y + 30

        -- Search input + close button
        local newQuery = ui.textinput('fb_search', x, y, PANEL_W - 55, 25, 'search...', state.query)
        if newQuery ~= nil then state.query = newQuery end

        if ui.button(PANEL_X + PANEL_W - 38, y, 28, 'x') then
            lib:close()
            return
        end
        y = y + 34

        -- Current path breadcrumb
        local relPath = state.currentPath:sub(#state.basePath + 1)
        if relPath == '' then relPath = '/' end
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print(relPath, x, y)
        y = y + 18

        -- Scrollable list
        local listH = PANEL_H - 90
        ui.scrollableList('fb_list', x, y, PANEL_W - 30, listH, function(lx, ly, lw, _lh, offset)
            local cy = ly + offset

            -- Back button
            if showBack then
                love.graphics.setColor(0.3, 0.5, 0.7, 0.9)
                love.graphics.rectangle('fill', lx, cy, lw, DIR_H, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print('  ← ..', lx + 6, cy + 7)
                if ui.button(lx, cy, lw, '', DIR_H, { 0, 0, 0, 0 }) then
                    local parent = state.currentPath:match('^(.+)/[^/]+$')
                    if parent and #parent >= #state.basePath then
                        navigate(parent)
                    end
                end
                cy = cy + DIR_H + ROW_GAP
            end

            -- Subdirectory buttons
            for _, d in ipairs(state.dirs) do
                love.graphics.setColor(0.25, 0.4, 0.6, 0.8)
                love.graphics.rectangle('fill', lx, cy, lw, DIR_H, 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print('  ' .. d.name .. '/', lx + 6, cy + 7)
                if ui.button(lx, cy, lw, '', DIR_H, { 0, 0, 0, 0 }) then
                    navigate(d.full)
                end
                cy = cy + DIR_H + ROW_GAP
            end

            -- File rows
            for _, f in ipairs(filtered) do
                local img = getImage(f.full)
                if img then
                    local iw, ih = img:getDimensions()
                    local scale  = math.min(THUMB / iw, THUMB / ih)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(img, lx + 3, cy + 3, 0, scale, scale)
                else
                    love.graphics.setColor(0.25, 0.25, 0.25)
                    love.graphics.rectangle('fill', lx + 3, cy + 3, THUMB, THUMB)
                end

                local bx = lx + THUMB + 8
                local bw = lw - THUMB - 10
                if ui.button(bx, cy, bw, f.item, ROW_H) then
                    if state.callback then state.callback(f.full) end
                    lib:close()
                end

                cy = cy + ROW_H + ROW_GAP
            end

            return totalH
        end)
    end)
end

return lib
