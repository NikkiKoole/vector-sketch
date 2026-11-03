-- scan2tex: drawings on paper (a phone photo or a scan) into Playtime textures (docs/ASSETS-AND-BUILDS.md AB1).
-- Run from a terminal (it needs the python3 that has Pillow and numpy): love tools/scan2tex
-- The image work is claudetools/scan2tex.py; this window shows it and saves what you pick.
--   drop a photo or scan (HEIC, JPG, PNG) on the window: it's cut into its parts
--   click a part (or tab / shift-tab), then:
--     enter: type what part it is (foot, ear, body, ... or world/leaf), enter again when done: it's saved
--       as textures/mipo/<part>/<part>-<nn>.png (world/<what>/<what>-<nn>.png), the next free number
--       (docs/ASSETS-AND-BUILDS.md AB6; saved again, the same file)   f fill: auto / close / open / mask
--     r turn 90°   x skip it (not saved)   delete: forget its name
--   LOOKS LIKE: each part is compared with every texture in the game and the sheet's other parts; the
--   close ones show next to it and on the sheet (≈), and saving one of those asks first
--   the sheet's settings, sliders: size, mask inset, how far into the line, open below (applied when you let go)
--   ctrl-s save the named parts into textures/ (one saved before: ctrl-s again to overwrite it)
-- love tools/scan2tex --no-save [<file>]: try it out, saving only says what it would write (and opens <file>)
-- What you set per sheet is remembered (the save folder's sheets.json), so a sheet can be opened again.

local ROOT = love.filesystem.getSource():gsub('/tools/scan2tex/?$', '')
package.path = ROOT .. '/vendor/?.lua;' .. package.path
local json = require('dkjson')

local PYTHON = os.getenv('PYTHON') or 'python3'
local SCRIPT = ROOT .. '/claudetools/scan2tex.py'
local WORK = love.filesystem.getSaveDirectory() .. '/work'
local FILLS = { 'auto', 'close', 'open', 'mask' }
local LINE, BODY, BACK = { 0.24, 0.12, 0.16 }, { 0.91, 0.59, 0.43 }, { 0.78, 0.86, 0.78 }

local SETTINGS = { -- the sheet's: key, label, value, step, min, max, the script's env name
    { key = 'scale', label = 'size', value = 0.5, step = 0.05, min = 0.1, max = 1.5, env = 'SCALE' },
    { key = 'inset', label = 'mask inset px (at least)', value = 2, step = 1, min = 0, max = 12, env = 'INSET' },
    { key = 'into', label = 'mask into the line', value = 0.6, step = 0.1, min = 0, max = 1.5, env = 'INTO' },
    { key = 'open', label = 'open below (enclosed)', value = 0.07, step = 0.01, min = 0, max = 0.5, env = 'OPEN_BELOW' },
}

local sheet = nil       -- { src, base, img, w, h, parts = { {id, box, w, h, mask, inside, line, maskImg} } }
local picks = {}        -- per part id: { name, fill, rot, skip } (saved per sheet)
local selected = nil    -- index into sheet.parts
local busy, message = false, 'drop a photo or a scan of drawings on this window'
local busySince = 0    -- when the running script started (the window shows how long it's been)
local again = false     -- a change came in while the script ran: run once more after it
local dragging = nil    -- the slider being dragged
local before = nil      -- what the last run gave, to say what a change did
local confirmAt = nil   -- ctrl-s twice to overwrite, or to save look-alikes
local editing = false   -- typing the selected part's name
local thumbs = {}       -- texture name -> image (the look-alikes, loaded from textures/ when shown)
local maskShader
local noSave = false -- --no-save: try it out without writing into textures/
local save -- defined under saving (the test mode calls it from love.update, above it)

-- per-sheet memory ----------------------------------------------------------------------------------
local function loadMemory()
    local text = love.filesystem.read('sheets.json')
    return text and json.decode(text) or {}
end
local testing = nil -- --test / --test-save (below): runs that leave the memory alone
local function remember()
    if not sheet or testing then return end
    local all = loadMemory()
    local s = { picks = picks, settings = {} }
    for _, set in ipairs(SETTINGS) do s.settings[set.key] = set.value end
    all[sheet.src] = s
    love.filesystem.write('sheets.json', json.encode(all, { indent = true }))
end

-- running the script (in a thread, so the window keeps drawing) --------------------------------------
local THREAD = [[
local cmd = ...
local status = os.execute(cmd)
love.thread.getChannel('scan2tex'):push(status == 0 or status == true)
]]
local function shellQuote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function run()
    if not sheet then return end
    if busy then again = true return end
    busy, message = true, 'working on ' .. sheet.base .. ' ...'
    busySince = love.timer.getTime()
    local fill = {}
    for id, p in pairs(picks) do if p.fill and p.fill ~= 'auto' then fill[#fill + 1] = id .. ':' .. p.fill end end
    local env = { 'FILL=' .. shellQuote(table.concat(fill, ',')) }
    for _, set in ipairs(SETTINGS) do env[#env + 1] = set.env .. '=' .. set.value end
    os.execute('rm -rf ' .. shellQuote(WORK) .. ' && mkdir -p ' .. shellQuote(WORK))
    env[#env + 1] = 'CACHE=' .. shellQuote(love.filesystem.getSaveDirectory() .. '/cache')
    local cmd = ('cd %s && %s %s -I %s %s %s %s > %s 2>&1'):format(shellQuote(ROOT), table.concat(env, ' '),
        PYTHON, shellQuote(SCRIPT), shellQuote(sheet.src), shellQuote(WORK), shellQuote(sheet.base),
        shellQuote(WORK .. '.log'))
    love.thread.newThread(THREAD):start(cmd)
end

-- a texture from the game's textures/ (outside this tool's folder, so read as bytes)
local function loadTexture(name)
    local f = io.open(ROOT .. '/textures/' .. name .. '.png', 'rb')
    if not f then return nil end
    local bytes = f:read('*a')
    f:close()
    local ok, img = pcall(love.graphics.newImage, love.filesystem.newFileData(bytes, name .. '.png'))
    return ok and img or nil
end

local function image(path)
    local ok, img = pcall(love.graphics.newImage, path)
    return ok and img or nil
end

local function loaded()
    local text = love.filesystem.read('work/_parts.json')
    if not text then
        local log = love.filesystem.read('work.log') or ''
        message = 'the script failed (is ' .. PYTHON .. ' the one with Pillow and numpy? run from a terminal):\n'
            .. log:sub(-400)
        return
    end
    local d = json.decode(text)
    sheet.img = image('work/_sheet.png')
    sheet.w, sheet.h = d.sheet[1], d.sheet[2]
    sheet.parts = d.parts
    for _, p in ipairs(sheet.parts) do
        p.line = image('work/' .. p.id .. '.png')
        p.maskImg = p.mask and image('work/' .. p.id .. '-mask.png') or nil
        picks[p.id] = picks[p.id] or { fill = 'auto', rot = 0 }
    end
    if selected and selected > #sheet.parts then selected = nil end
    local masks = 0
    for _, p in ipairs(sheet.parts) do if p.mask then masks = masks + 1 end end
    local sel = selected and sheet.parts[selected]
    if before then -- what the change did
        local said = {}
        if before.masks ~= masks then said[#said + 1] = ('parts with a mask: %d -> %d'):format(before.masks, masks) end
        if before.count ~= #sheet.parts then said[#said + 1] = ('parts: %d -> %d'):format(before.count, #sheet.parts) end
        if sel and before.sel and before.sel.id == sel.id and (before.sel.w ~= sel.w or before.sel.h ~= sel.h) then
            said[#said + 1] = ('%s: %dx%d -> %dx%d px'):format(sel.id, before.sel.w, before.sel.h, sel.w, sel.h)
        end
        message = #said > 0 and ('changed: ' .. table.concat(said, ';  ')) or 'done: the change made no difference you can count (look at the masks)'
    else
        message = ('%d parts. Click one, enter to name it, ctrl-s saves the named ones into textures/'):format(#sheet.parts)
    end
    before = { masks = masks, count = #sheet.parts, sel = sel and { id = sel.id, w = sel.w, h = sel.h } }
end

function love.filedropped(file)
    local src = file:getFilename()
    local base = src:match('([^/]+)$'):gsub('%.[^.]+$', ''):gsub('[^%w_-]', ''):lower()
    sheet, selected, picks, before = { src = src, base = base, parts = {} }, nil, {}, nil
    local memory = loadMemory()[src]
    if memory then
        picks = memory.picks or {}
        for _, set in ipairs(SETTINGS) do set.value = memory.settings and memory.settings[set.key] or set.value end
    end
    run()
end

-- love tools/scan2tex --test <file>: load it, select the first look-alike, screenshot (the save folder's
-- test.png) and quit; for checking the window without clicking (`testing`, declared above remember)

function love.update()
    local done = love.thread.getChannel('scan2tex'):pop()
    if done ~= nil then
        busy = false
        loaded()
        if again then again = false; run() end
        if testing and sheet then
            for i, p in ipairs(sheet.parts) do if p.similar and #p.similar > 0 then selected = i break end end
            testing.shotIn = 3
            if testing.save then -- --test-save: part 1 as zz-scan2tex-test, turned once, saved (twice: it asks)
                picks[sheet.parts[1].id].name, picks[sheet.parts[1].id].rot = 'zz-scan2tex-test', 1
                save(); save()
            end
        end
    end
    if testing and testing.shotIn then
        testing.shotIn = testing.shotIn - 1
        if testing.shotIn == 0 then
            love.graphics.captureScreenshot(function(data)
                data:encode('png', 'test.png')
                print('test screenshot: ' .. love.filesystem.getSaveDirectory() .. '/test.png; ' .. message)
                love.event.quit()
            end)
        end
    end
end

-- saving ---------------------------------------------------------------------------------------------
local function exists(path)
    local f = io.open(path, 'rb')
    if f then f:close() end
    return f ~= nil
end

-- the part's file turned by rot quarter turns, as PNG bytes: the pixels copied as they are (drawing it into
-- a canvas multiplied the colour by the alpha and lost the white under the transparency: halos)
local function turned(file, rot)
    local src = love.image.newImageData(file)
    if rot % 4 == 0 then return src:encode('png'):getString() end
    local w, h = src:getDimensions()
    local dw, dh = (rot % 2 == 0) and w or h, (rot % 2 == 0) and h or w
    local dst = love.image.newImageData(dw, dh)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local dx, dy
            if rot % 4 == 1 then dx, dy = h - 1 - y, x        -- a quarter turn clockwise
            elseif rot % 4 == 2 then dx, dy = w - 1 - x, h - 1 - y
            else dx, dy = y, w - 1 - x end
            dst:setPixel(dx, dy, src:getPixel(x, y))
        end
    end
    return dst:encode('png'):getString()
end

local function write(path, bytes)
    local f = assert(io.open(path, 'wb'))
    f:write(bytes)
    f:close()
end

-- the highest number in textures/<folder>/<kind>-<nn>.png (0 when there's none)
local function highest(folder, kind)
    local top = 0
    local list = io.popen(('ls %s 2>/dev/null'):format(shellQuote(ROOT .. '/textures/' .. folder)))
    for file in list:lines() do
        local n = tonumber(file:match('^' .. kind:gsub('%-', '%%-') .. '%-(%d+)%.png$'))
        if n and n > top then top = n end
    end
    list:close()
    return top
end

-- where a named part is saved: 'foot' -> mipo/foot/foot-08 (the next free), 'world/leaf' -> world/leaf/leaf-01;
-- one saved before keeps its file. next: per folder, the numbers handed out in this save
local function target(pick, next)
    if pick.saved and pick.saved.name == pick.name then return pick.saved.file end
    local area, kind = pick.name:match('^(world)/([%w_-]+)$')
    if not area then area, kind = 'mipo', pick.name:gsub('/', '') end
    local folder = area .. '/' .. kind
    next[folder] = (next[folder] or highest(folder, kind)) + 1
    return ('%s/%s-%02d'):format(folder, kind, next[folder])
end

function save()
    if not sheet or busy then return end
    local todo, clash, alike, next = {}, {}, {}, {}
    for _, p in ipairs(sheet.parts) do
        local pick = picks[p.id]
        if pick.name and pick.name ~= '' and not pick.skip then
            local file = target(pick, next)
            local path = ROOT .. '/textures/' .. file .. '.png'
            todo[#todo + 1] = { p = p, pick = pick, path = path, file = file }
            if exists(path) then clash[#clash + 1] = file end
            if p.similar and #p.similar > 0 then
                alike[#alike + 1] = ('%s ≈ %s %d%%'):format(pick.name, p.similar[1].name, math.floor(p.similar[1].score * 100 + 0.5))
            end
        end
    end
    if #todo == 0 then message = 'nothing to save: give a part a name first' return end
    local now = love.timer.getTime()
    if (#clash > 0 or #alike > 0) and not (confirmAt and now - confirmAt < 6) then
        confirmAt = now
        local lines = {}
        if #clash > 0 then lines[#lines + 1] = 'already in textures/ (overwrite?): ' .. table.concat(clash, ', ') end
        if #alike > 0 then lines[#lines + 1] = 'look a lot like what is there: ' .. table.concat(alike, ', ') end
        message = table.concat(lines, '\n') .. '\nctrl-s again to save anyway, or x the ones you don\'t want'
        return
    end
    confirmAt = nil
    if noSave then
        local names = {}
        for _, t in ipairs(todo) do names[#names + 1] = t.file .. (t.p.maskImg and ' (+ mask)' or '') end
        message = 'saving is off (--no-save). It would write into textures/: ' .. table.concat(names, ', ')
        remember()
        return
    end
    local saved, stale = {}, {}
    for _, t in ipairs(todo) do
        os.execute(('mkdir -p %s'):format(shellQuote(t.path:match('^(.*)/'))))
        write(t.path, turned('work/' .. t.p.id .. '.png', t.pick.rot or 0))
        local maskPath = t.path:gsub('%.png$', '-mask.png')
        if t.p.maskImg then
            write(maskPath, turned('work/' .. t.p.id .. '-mask.png', t.pick.rot or 0))
        elseif exists(maskPath) then
            stale[#stale + 1] = t.file .. '-mask.png'
        end
        t.pick.saved = { name = t.pick.name, file = t.file }
        saved[#saved + 1] = t.file
    end
    message = 'saved into textures/: ' .. table.concat(saved, ', ')
    if #stale > 0 then message = message .. '\n(no mask now, an old one is still there: ' .. table.concat(stale, ', ') .. ')' end
    remember()
end

-- drawing --------------------------------------------------------------------------------------------
local layout = {}

local function button(x, y, w, h, label, fn)
    layout.buttons[#layout.buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn }
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle('fill', x, y, w, h, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + h / 2 - 7, w, 'center')
end

-- a part baked roughly as the game does: the mask filled with the body colour, the line on top
local function drawPart(p, x, y, maxW, maxH, rot)
    if not p.line then return end
    local w, h = p.line:getDimensions()
    local rw, rh = (rot % 2 == 0) and w or h, (rot % 2 == 0) and h or w
    local k = math.min(maxW / rw, maxH / rh, 1.5) -- true size (up to 1.5x), so a size change shows
    local cx, cy = x + maxW / 2, y + maxH / 2
    if p.maskImg then
        love.graphics.setShader(maskShader)
        love.graphics.setColor(BODY)
        love.graphics.draw(p.maskImg, cx, cy, rot * math.pi / 2, k, k, w / 2, h / 2)
        love.graphics.setShader()
    end
    love.graphics.setColor(LINE)
    love.graphics.draw(p.line, cx, cy, rot * math.pi / 2, k, k, w / 2, h / 2)
end

function love.draw()
    layout.buttons, layout.sliders = {}, {}
    local W, H = love.graphics.getDimensions()
    love.graphics.clear(0.13, 0.13, 0.15)
    local left = math.floor(W * 0.47)
    -- the sheet, its parts boxed
    if sheet and sheet.img then
        local k = math.min((left - 20) / sheet.w, (H - 120) / sheet.h)
        layout.sheet = { x = 10, y = 10, k = k }
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sheet.img, 10, 10, 0, k, k)
        for i, p in ipairs(sheet.parts) do
            local b, pick = p.box, picks[p.id]
            local named = pick.name and pick.name ~= ''
            if pick.skip then love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
            elseif i == selected then love.graphics.setColor(1, 0.5, 0.1)
            elseif named then love.graphics.setColor(0.2, 0.7, 0.3)
            else love.graphics.setColor(0.3, 0.5, 0.9) end
            love.graphics.setLineWidth(i == selected and 3 or 1.5)
            love.graphics.rectangle('line', 10 + b[1] * k, 10 + b[2] * k, (b[3] - b[1]) * k, (b[4] - b[2]) * k)
            if named or pick.skip then
                love.graphics.print(pick.skip and 'skip' or pick.name, 10 + b[1] * k, 10 + b[4] * k + 2)
            end
            if p.similar and #p.similar > 0 and not pick.skip then
                love.graphics.setColor(1, 0.85, 0.4)
                love.graphics.print('≈', 10 + b[3] * k - 10, 10 + b[2] * k - 2, 0, 1.5, 1.5)
            end
        end
    end
    -- the selected part
    local px = left + 10
    local likeX = W - 250 -- the look-alikes' column, on the dark side of the window
    love.graphics.setColor(BACK)
    love.graphics.rectangle('fill', px, 10, likeX - px - 10, 380, 6)
    if sheet and selected and sheet.parts[selected] then
        local p, pick = sheet.parts[selected], picks[sheet.parts[selected].id]
        drawPart(p, px + 10, 20, likeX - px - 30, 360, pick.rot or 0)
        if busy then
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.rectangle('fill', px, 10, likeX - px - 10, 380, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(('working... %d s%s'):format(love.timer.getTime() - busySince,
                again and '  (and once more after: you changed something)' or ''), px, 190, likeX - px - 10, 'center')
        end
        love.graphics.setColor(1, 1, 1)
        local y = 400
        love.graphics.print(('%s   %d x %d px   enclosed %d%%   %s'):format(p.id, p.w, p.h, math.floor(p.inside * 100),
            p.mask and 'mask' or 'no mask'), px, y)
        local caret = editing and (love.timer.getTime() % 1 < 0.5) and '|' or ''
        love.graphics.print('name: ' .. (pick.name or (editing and '' or '(enter to name it)')) .. caret, px, y + 24, 0,
            1.4, 1.4)
        button(px, y + 60, 150, 26, 'fill: ' .. (pick.fill or 'auto') .. '  (f)', function() love.keypressed('f') end)
        button(px + 160, y + 60, 120, 26, 'turn 90°  (r)', function() love.keypressed('r') end)
        button(px + 290, y + 60, 120, 26, (pick.skip and 'skipped' or 'skip') .. '  (x)', function() love.keypressed('x') end)
        -- what it looks like, already in the game (or on this sheet)
        if p.similar and #p.similar > 0 then
            love.graphics.setColor(1, 0.85, 0.4)
            love.graphics.print('looks like (already in the game):', likeX, 14)
            for i, f in ipairs(p.similar) do
                local ty = 20 + (i - 1) * 90 + 18
                local thumb = thumbs[f.name]
                if thumb == nil and not f.name:find('^%(this sheet%)') then
                    thumb = loadTexture(f.name) or false
                    thumbs[f.name] = thumb
                end
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.rectangle('fill', likeX, ty, 80, 80, 4)
                if thumb then
                    local tw, th = thumb:getDimensions()
                    local k = math.min(76 / tw, 76 / th)
                    love.graphics.setColor(LINE)
                    love.graphics.draw(thumb, likeX + 40, ty + 40, 0, k, k, tw / 2, th / 2)
                end
                love.graphics.setColor(1, 0.85, 0.4)
                love.graphics.print(('%s\n%d%% alike'):format(f.name, math.floor(f.score * 100 + 0.5)), likeX + 90, ty + 22)
            end
        end
    end
    -- the sheet's settings: sliders (drag; applied when you let go)
    local y = 520
    for _, set in ipairs(SETTINGS) do
        local tx, tw = px + 230, 260
        layout.sliders[#layout.sliders + 1] = { set = set, x = tx, y = y, w = tw, h = 24 }
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(('%s: %s'):format(set.label, tostring(set.value)), px, y + 5)
        love.graphics.setColor(0.3, 0.3, 0.36)
        love.graphics.rectangle('fill', tx, y + 10, tw, 4, 2)
        local t = (set.value - set.min) / (set.max - set.min)
        love.graphics.setColor(dragging and dragging.slider.set == set and { 1, 0.6, 0.2 } or { 0.85, 0.85, 0.9 })
        love.graphics.circle('fill', tx + t * tw, y + 12, 8)
        y = y + 30
    end
    button(px, y + 10, 220, 30, 'save named parts  (ctrl-s)', save)
    -- the message
    love.graphics.setColor(busy and { 1, 0.8, 0.3 } or { 0.85, 0.85, 0.85 })
    love.graphics.printf(message, 10, H - 100, W - 20)
    if noSave then
        love.graphics.setColor(1, 0.4, 0.3)
        love.graphics.print('saving is off (--no-save)', W - 200, H - 24)
    end
end

-- input ----------------------------------------------------------------------------------------------
local function slide(x)
    local sl = dragging and dragging.slider
    if not sl then return end
    local set = sl.set
    local t = math.max(0, math.min(1, (x - sl.x) / sl.w))
    local v = set.min + t * (set.max - set.min)
    v = math.floor(v / set.step + 0.5) * set.step
    set.value = math.floor(v * 100 + 0.5) / 100
end

function love.mousemoved(x) if dragging then slide(x) end end

function love.mousereleased()
    if not dragging then return end
    local changed = dragging.from ~= dragging.slider.set.value
    dragging = nil
    if changed then run(); remember() end
end

function love.mousepressed(x, y, b)
    if b ~= 1 then return end
    for _, sl in ipairs(layout.sliders or {}) do
        if x >= sl.x - 10 and x <= sl.x + sl.w + 10 and y >= sl.y - 4 and y <= sl.y + sl.h + 4 then
            dragging = { slider = sl, from = sl.set.value }
            slide(x)
            return
        end
    end
    for _, btn in ipairs(layout.buttons or {}) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then btn.fn() return end
    end
    local s = layout.sheet
    if sheet and s then
        local sx, sy = (x - s.x) / s.k, (y - s.y) / s.k
        for i, p in ipairs(sheet.parts) do
            local bx = p.box
            if sx >= bx[1] and sx <= bx[3] and sy >= bx[2] and sy <= bx[4] then selected, editing = i, false return end
        end
    end
end

function love.textinput(t)
    if not (editing and sheet and selected) then return end
    local pick = picks[sheet.parts[selected].id]
    pick.name = (pick.name or '') .. t:lower():gsub('[^%w_/-]', '')
end

function love.keypressed(key)
    local ctrl = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    if ctrl and key == 's' then save() return end
    if editing then
        local pick = sheet and selected and picks[sheet.parts[selected].id]
        if key == 'return' or key == 'kpenter' or key == 'escape' then editing = false; remember()
        elseif key == 'backspace' and pick then pick.name = (pick.name or ''):sub(1, -2) end
        return
    end
    if key == 'escape' then selected = nil return end
    if not (sheet and #sheet.parts > 0) then return end
    if key == 'tab' then
        local n = #sheet.parts
        selected = ((selected or 0) + (love.keyboard.isDown('lshift', 'rshift') and -2 or 0)) % n + 1
        return
    end
    if not selected then return end
    local pick = picks[sheet.parts[selected].id]
    if key == 'return' or key == 'kpenter' then editing = true return end
    if key == 'delete' or key == 'backspace' then pick.name = nil remember() return end
    if key == 'f' then
        local i = 1
        for k, f in ipairs(FILLS) do if f == pick.fill then i = k end end
        pick.fill = FILLS[i % #FILLS + 1]
        remember(); run()
    elseif key == 'r' then
        pick.rot = ((pick.rot or 0) + 1) % 4; remember()
    elseif key == 'x' then
        pick.skip = not pick.skip; remember()
    end
end

function love.load()
    love.keyboard.setKeyRepeat(true)
    maskShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) { return vec4(color.rgb, color.a * Texel(tex, uv).r); }
    ]])
    love.filesystem.createDirectory('work')
    for i, a in ipairs(arg or {}) do
        if a == '--no-save' then
            noSave = true
            local file = arg[i + 1]
            if file and not file:match('^%-%-') then love.filedropped({ getFilename = function() return file end }) end
        end
        if (a == '--test' or a == '--test-save') and arg[i + 1] then
            testing = { save = a == '--test-save' }
            love.filedropped({ getFilename = function() return arg[i + 1] end })
        end
    end
end
