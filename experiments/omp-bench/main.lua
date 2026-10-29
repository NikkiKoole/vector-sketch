-- OMP bench: what Playtime's baked part textures (outline + mask + pattern, "OMP")
-- cost in texture memory, bake time and frame time, per option.
--
-- It uses Playtime's own bake code (src/ is a symlink to ../playtime/src) and the
-- real Mipo parts from scripts/dollhouse.playtime.json, so the baseline is honest.
--
--   love .          interactive: 1-4 picks an option, z toggles game/close zoom
--   love . --auto   runs every option, writes results/ and quits
--
-- Options (EXPERIMENTS-HARVEST follow-up, 2026-10-29):
--   baseline    what Playtime does today: bake at full source size, old images left to the GC
--   shrink-1.5  bake at 1/1.5 of the source size (box2d-draw-textured's shrinkFactor)
--   shrink-2    bake at half size
--   release     baseline, but :release() the old image when a part is re-baked

-- an unattended run must not sit on LÖVE's error screen
for _, a in ipairs(arg or {}) do
    if a == '--auto' then
        love.errorhandler = function(msg)
            print(debug.traceback('Error: ' .. tostring(msg), 3))
        end
    end
end

local textured = require('src.physics.box2d-draw-textured')
local json = require('vendor.dkjson')

local SCENE = 'scripts/dollhouse.playtime.json'
local CAMERA_SCALE = 0.35 -- the dollhouse's saved camera zoom
local CLOSE_SCALE = 1.0 -- a close look, for judging sharpness
local MIPO_COUNTS = { 5, 10, 30, 60 }
local FRAME_TEST_MIPOS = 30
local FRAME_TEST_FRAMES = 600
local RANDOMIZES = 25
local GC_EVERY = 32 -- main.lua: one full collect after this many new textures

local RUN_SUFFIX = '' -- results-<N>.md for a --mipos=N run, so the default results stay
-- --mipos=N: measure memory up to N Mipos and draw N in the frame test
for _, a in ipairs(arg or {}) do
    local n = tonumber(a:match('^%-%-mipos=(%d+)$'))
    if n then
        MIPO_COUNTS = { 5, math.floor(n / 4), math.floor(n / 2), n }
        FRAME_TEST_MIPOS = n
        RUN_SUFFIX = '-' .. n
    end
end

local OPTIONS = {
    { name = 'baseline',   shrink = 1,   release = false },
    { name = 'shrink-1.5', shrink = 1.5, release = false },
    { name = 'shrink-2',   shrink = 2,   release = false },
    { name = 'release',    shrink = 1,   release = true },
}

local MB = 1024 * 1024

-- Source images, loaded once and shared, with the same rules as getLoveImage
-- in box2d-draw-textured (a missing file or a folder gives nil).
local sourceCache = {}
local function getSource(path)
    if sourceCache[path] == nil then
        local info = love.filesystem.getInfo(path)
        sourceCache[path] = (info and info.type == 'file') and love.graphics.newImage(path) or false
    end
    return sourceCache[path] or nil
end

local tex1, lineFallback, maskFallback
local mipos = {}        -- { {extra, ...}, ... } grouped by zGroupOffset, from the scene
local results = {}      -- one row per option
local runner            -- the --auto coroutine
local view = { baked = {}, scale = CAMERA_SCALE, layout = 'scatter' }
local hud = ''
local lastFrameTime = 0

local function texMB()
    return love.graphics.getStats().texturememory / MB
end

local function sorted(list)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    table.sort(copy)
    return copy
end

local function percentile(list, p)
    local copy = sorted(list)
    return copy[math.max(1, math.min(#copy, math.ceil(#copy * p)))]
end

local function median(list)
    return percentile(list, 0.5)
end

local function bboxSize(vertices)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #vertices, 2 do
        minX = math.min(minX, vertices[i]); maxX = math.max(maxX, vertices[i])
        minY = math.min(minY, vertices[i + 1]); maxY = math.max(maxY, vertices[i + 1])
    end
    return maxX - minX, maxY - minY
end

local function loadMipos()
    local contents = love.filesystem.read(SCENE) -- read's second return (size) would be decode's start position
    local data = json.decode(contents, 1, nil)
    local groups, order = {}, {}
    for _, body in ipairs(data.bodies) do
        for _, fixture in ipairs(body.fixtures or {}) do
            local extra = fixture.userData and fixture.userData.extra
            -- parts without vertices are connected-texture ribbons (limbs, hair, neck skin):
            -- baked the same way, drawn along a curve in Playtime
            if extra and extra.OMP and extra.main and extra.main.bgURL and extra.main.bgURL ~= '' then
                local key = extra.zGroupOffset or 0
                if not groups[key] then
                    groups[key] = {}
                    order[#order + 1] = key
                end
                table.insert(groups[key], extra)
            end
        end
    end
    table.sort(order)
    local result = {}
    for _, key in ipairs(order) do
        if #groups[key] >= 5 then table.insert(result, groups[key]) end -- props aren't Mipos
    end
    return result
end

-- A copy of a part's main layer with other colours: an extra Mipo for the counts.
local rng = love.math.newRandomGenerator(42)
local function randomHex()
    return string.format('%02X%02X%02XFF', rng:random(0, 255), rng:random(0, 255), rng:random(0, 255))
end

local function recoloured(main)
    local copy = {}
    for k, v in pairs(main) do copy[k] = v end
    copy.fgHex, copy.pHex = randomHex(), randomHex()
    copy.cached = nil
    return copy
end

-- Same steps as makePatch in box2d-draw-textured.
local function bakePatch(p)
    if not (p and p.bgURL) then return nil end
    local outline = getSource('textures/' .. p.bgURL)
    if not outline then return nil end
    local olr, olg, olb, ola = textured.hexToColor(p.bgHex)
    local mr, mg, mb, ma = textured.hexToColor(p.fgHex)
    local pr, pg, pb, pa = textured.hexToColor(p.pHex)
    local imgData = textured.makeTexturedCanvas(
        outline, getSource('textures/' .. (p.fgURL or '')),
        { mr, mg, mb }, ma * 5,
        getSource('textures/pat/' .. (p.pURL or '')) or tex1, { pr, pg, pb }, pa * 5,
        p.pr or 0, p.psx or 1, p.psy or 1, p.ptx or 0, p.pty or 0,
        { olr, olg, olb }, ola * 5, p.fx or 1, p.fy or 1)
    return {
        img = love.graphics.newImage(imgData), imgData = imgData,
        tint = p.tint or 'ffffff', tx = p.tx, ty = p.ty, sx = p.sx, sy = p.sy, r = p.r,
    }
end

-- Same steps as makeCombinedImages in box2d-draw-textured, for one part.
local function bakePart(extra, main)
    if not main.cached then textured.makeCached(main) end
    local c = main.cached
    local patches = {}
    for i, name in ipairs({ 'patch1', 'patch2', 'patch3' }) do
        patches[i] = bakePatch(extra[name]) or false
    end
    local hasFg = main.fgURL and main.fgURL ~= ''
    local imgData = textured.makeTexturedCanvas(
        getSource('textures/' .. main.bgURL) or lineFallback,
        hasFg and (getSource('textures/' .. main.fgURL) or maskFallback) or nil,
        c.fgRGB, c.fgA * 5,
        getSource('textures/pat/' .. (main.pURL or '')) or tex1, c.pRGB, c.pA * 5,
        main.pr or 0, main.psx or 1, main.psy or 1, main.ptx or 0, main.pty or 0,
        c.bgRGB, c.bgA * 5, main.fx or 1, main.fy or 1, patches)
    -- a ribbon's on-screen size depends on its joints; draw it at its source size (1 px = 1 unit)
    local w, h
    if extra.vertices then
        w, h = bboxSize(extra.vertices)
    else
        local source = getSource('textures/' .. main.bgURL) or lineFallback
        w, h = source:getDimensions()
    end
    return { img = love.graphics.newImage(imgData), imgData = imgData, patches = patches, w = w, h = h }
end

local function releaseBaked(baked)
    baked.img:release()
    baked.imgData:release()
    for _, patch in ipairs(baked.patches) do
        if patch then
            patch.img:release()
            patch.imgData:release()
        end
    end
end

local function bakeMipo(parts, fresh)
    local list = {}
    for _, extra in ipairs(parts) do
        local main = fresh and recoloured(extra.main) or extra.main
        table.insert(list, bakePart(extra, main))
    end
    return list
end

local function preloadSources()
    for _, parts in ipairs(mipos) do
        for _, extra in ipairs(parts) do
            local m = extra.main
            getSource('textures/' .. m.bgURL)
            if m.fgURL and m.fgURL ~= '' then getSource('textures/' .. m.fgURL) end
            getSource('textures/pat/' .. (m.pURL or ''))
        end
    end
end

-- Texture pixels per screen pixel at a zoom, at full size: how much headroom shrinking has.
local function oversampling(scale)
    local values = {}
    for _, parts in ipairs(mipos) do
        for _, extra in ipairs(parts) do
            local img = getSource('textures/' .. extra.main.bgURL)
            if img and extra.vertices then -- ribbons have no fixed size
                local w = bboxSize(extra.vertices)
                if w > 0 then table.insert(values, img:getWidth() / (w * scale)) end
            end
        end
    end
    return median(values), percentile(values, 0.1), percentile(values, 0.9)
end

---------------------------------------------------------------- drawing

local function drawPart(baked, x, y, scale)
    local iw, ih = baked.img:getDimensions()
    love.graphics.draw(baked.img, x, y, 0, baked.w * scale / iw, baked.h * scale / ih)
end

local function drawScatter(list, scale)
    local w, h = love.graphics.getDimensions()
    local placeRng = love.math.newRandomGenerator(7) -- the same layout every frame and every option
    love.graphics.setColor(1, 1, 1)
    for _, baked in ipairs(list) do
        drawPart(baked, placeRng:random(-50, w - 50), placeRng:random(-50, h - 50), scale)
    end
end

-- One Mipo's parts side by side, for looking at and for the screenshot diff.
local function drawGrid(list, scale)
    local w = love.graphics.getWidth()
    local x, y, rowH = 10, 30, 0
    love.graphics.setColor(1, 1, 1)
    for _, baked in ipairs(list) do
        local pw, ph = baked.w * scale, baked.h * scale
        if x + pw > w - 10 then
            x, y, rowH = 10, y + rowH + 10, 0
        end
        drawPart(baked, x, y, scale)
        x = x + pw + 10
        rowH = math.max(rowH, ph)
    end
end

local function renderLooks(list, scale)
    local canvas = love.graphics.newCanvas(love.graphics.getDimensions())
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.85, 0.8, 0.75, 1)
    drawGrid(list, scale)
    love.graphics.setCanvas()
    local data = canvas:newImageData()
    canvas:release()
    return data
end

-- Mean difference per channel (0-255) and the share of pixels that differ visibly.
local function compareLooks(a, b)
    local w, h = a:getDimensions()
    local sum, visible = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            local d = (math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)) / 3
            sum = sum + d
            if d > 8 / 255 then visible = visible + 1 end
        end
    end
    return sum / (w * h) * 255, visible / (w * h) * 100
end

---------------------------------------------------------------- the --auto run

local function writeFile(name, contents)
    local file = assert(io.open(love.filesystem.getSource() .. '/results/' .. name, 'wb'))
    file:write(contents)
    file:close()
end

local function settle()
    collectgarbage('collect')
    collectgarbage('collect')
    coroutine.yield()
end

local baselineLooks = {}

local function runOption(opt)
    local row = { name = opt.name }
    textured.setShrinkFactor(opt.shrink)
    settle()
    local startMB = texMB()

    -- 1. memory and bake time for growing numbers of Mipos
    local all, bakeTimes = {}, {}
    local mipoCount = 0
    for _, target in ipairs(MIPO_COUNTS) do
        while mipoCount < target do
            mipoCount = mipoCount + 1
            local parts = mipos[(mipoCount - 1) % #mipos + 1]
            local t0 = love.timer.getTime()
            local list = bakeMipo(parts, mipoCount > #mipos)
            table.insert(bakeTimes, (love.timer.getTime() - t0) * 1000)
            for _, baked in ipairs(list) do table.insert(all, baked) end
            hud = opt.name .. ': baking Mipo ' .. mipoCount
            coroutine.yield()
        end
        settle()
        row['mb' .. target] = texMB() - startMB
    end
    local first, last = MIPO_COUNTS[1], MIPO_COUNTS[#MIPO_COUNTS]
    row.mbPerMipo = (row['mb' .. last] - row['mb' .. first]) / (last - first)
    row.bakeMsPerMipo = median(bakeTimes)

    -- 2. frame time with FRAME_TEST_MIPOS on screen at the dollhouse zoom
    local onScreen = {}
    local partsPerMipo = #all / mipoCount
    for i = 1, math.floor(FRAME_TEST_MIPOS * partsPerMipo) do onScreen[i] = all[i] end
    view.baked, view.scale, view.layout = onScreen, CAMERA_SCALE, 'scatter'
    local frames = {}
    hud = opt.name .. ': frame test'
    coroutine.yield()
    coroutine.yield() -- skip the first frames after a layout change
    for _ = 1, FRAME_TEST_FRAMES do
        coroutine.yield()
        table.insert(frames, lastFrameTime * 1000)
    end
    row.frameMedian = median(frames)
    row.frameP95 = percentile(frames, 0.95)
    row.drawcalls = view.drawcalls

    -- 3. looks: Mipo 1 at the dollhouse zoom and close up, against the baseline
    local firstMipo = {}
    for i = 1, #mipos[1] do firstMipo[i] = all[i] end
    for _, zoom in ipairs({ { 'game', CAMERA_SCALE }, { 'close', CLOSE_SCALE } }) do
        local data = renderLooks(firstMipo, zoom[2])
        writeFile('looks-' .. opt.name .. '-' .. zoom[1] .. '.png', data:encode('png'):getString())
        if opt.name == 'baseline' then
            baselineLooks[zoom[1]] = data
        else
            row['diff_' .. zoom[1]], row['changed_' .. zoom[1]] = compareLooks(baselineLooks[zoom[1]], data)
            data:release()
        end
    end

    -- clear everything before the randomize test
    view.baked = {}
    for _, baked in ipairs(all) do releaseBaked(baked) end
    all = nil
    settle()

    -- 4. randomize one Mipo RANDOMIZES times, the way the Mipo editor re-bakes
    local current = {}
    for i, parts in ipairs(mipos) do current[i] = bakeMipo(parts, false) end
    settle()
    local beforeMB = texMB()
    local peakMB, created = beforeMB, 0
    for r = 1, RANDOMIZES do
        for i, extra in ipairs(mipos[1]) do
            local old = current[1][i]
            current[1][i] = bakePart(extra, recoloured(extra.main))
            if opt.release then
                releaseBaked(old)
            else
                created = created + 1
                if created >= GC_EVERY then
                    created = 0
                    collectgarbage('collect')
                end
            end
            peakMB = math.max(peakMB, texMB())
        end
        hud = opt.name .. ': randomize ' .. r
        coroutine.yield()
        peakMB = math.max(peakMB, texMB())
    end
    row.randomizePeakExtraMB = peakMB - beforeMB
    row.randomizeEndExtraMB = texMB() - beforeMB -- what's still held, before any extra collect
    for _, list in ipairs(current) do
        for _, baked in ipairs(list) do releaseBaked(baked) end
    end
    settle()
    return row
end

local function fmt(v, digits)
    return string.format('%.' .. (digits or 1) .. 'f', v)
end

local function writeResults(sourcesMB, mipoCount, partCount)
    local columns = { { 'option', 'name' } }
    for _, count in ipairs(MIPO_COUNTS) do
        table.insert(columns, { 'MB@' .. count, 'mb' .. count })
    end
    for _, col in ipairs({
        { 'MB per Mipo', 'mbPerMipo', 2 },
        { 'bake ms/Mipo', 'bakeMsPerMipo' },
        { 'frame ms median', 'frameMedian', 2 }, { 'frame ms p95', 'frameP95', 2 },
        { 'draw calls', 'drawcalls', 0 },
        { 'diff game', 'diff_game', 2 }, { '% px changed game', 'changed_game' },
        { 'diff close', 'diff_close', 2 }, { '% px changed close', 'changed_close' },
        { 'randomize peak +MB', 'randomizePeakExtraMB' },
        { 'randomize end +MB', 'randomizeEndExtraMB' },
    }) do
        table.insert(columns, col)
    end
    local csv, md = {}, {}
    local header, sep = {}, {}
    for _, col in ipairs(columns) do
        table.insert(header, col[1])
        table.insert(sep, '---')
    end
    table.insert(csv, table.concat(header, ','))
    table.insert(md, '| ' .. table.concat(header, ' | ') .. ' |')
    table.insert(md, '|' .. table.concat(sep, '|') .. '|')
    for _, row in ipairs(results) do
        local cells = {}
        for _, col in ipairs(columns) do
            local v = row[col[2]]
            table.insert(cells, type(v) == 'number' and fmt(v, col[3]) or tostring(v or ''))
        end
        table.insert(csv, table.concat(cells, ','))
        table.insert(md, '| ' .. table.concat(cells, ' | ') .. ' |')
    end
    local o50, o10, o90 = oversampling(CAMERA_SCALE)
    local c50 = oversampling(CLOSE_SCALE)
    local name, version, vendor, device = love.graphics.getRendererInfo()
    local intro = {
        '# OMP bench results',
        '',
        string.format('Run: %s on %s %s (%s, %s).', os.date('%Y-%m-%d %H:%M'), name, version, vendor, device),
        string.format('Scene: %s, %d Mipos, %d OMP parts. Extra Mipos are recoloured copies. '
            .. 'Ribbon parts (connected-texture) are drawn as quads at their source size.',
            SCENE, mipoCount, partCount),
        string.format('Source images (outline/mask/pattern, shared, not in the MB columns): %.1f MB.', sourcesMB),
        string.format('Oversampling at full size (texture px per screen px): median %.1f (p10 %.1f, p90 %.1f) '
            .. 'at the dollhouse zoom %.2f; median %.1f at zoom %.1f.', o50, o10, o90, CAMERA_SCALE, c50, CLOSE_SCALE),
        '',
        string.format('Frame test: %d Mipos scattered at the dollhouse zoom, vsync off, %d frames.',
            FRAME_TEST_MIPOS, FRAME_TEST_FRAMES),
        'diff = mean difference per channel (0-255) against baseline; % px changed = pixels off by more than 8/255.',
        string.format('Randomize: Mipo 1 re-baked %d times next to the others; +MB over the start.', RANDOMIZES),
        '',
    }
    writeFile('results' .. RUN_SUFFIX .. '.csv', table.concat(csv, '\n') .. '\n')
    writeFile('results' .. RUN_SUFFIX .. '.md', table.concat(intro, '\n') .. '\n' .. table.concat(md, '\n') .. '\n')
    print(table.concat(intro, '\n') .. '\n' .. table.concat(md, '\n'))
end

local function autoRun()
    preloadSources()
    settle()
    local sourcesMB = texMB()
    local partCount = 0
    for _, parts in ipairs(mipos) do partCount = partCount + #parts end
    for _, opt in ipairs(OPTIONS) do
        table.insert(results, runOption(opt))
    end
    writeResults(sourcesMB, #mipos, partCount)
    love.event.quit()
end

-- --patch-check: does a part with patches look the same baked at shrink 1 and 2?
-- (makeTexturedCanvas multiplies patch offset and scale by shrinkFactor; the patch
-- image itself is baked at 1/shrinkFactor, so that multiply should cancel it out)
local function patchCheck()
    local part
    for _, extra in ipairs(mipos[1]) do
        if extra.vertices then
            local w, h = bboxSize(extra.vertices)
            if not part or w * h > part.size then part = { extra = extra, size = w * h } end
        end
    end
    -- the default skin patches from character-manager.lua (two eye spots, a wide snout)
    local function patch(url, fields)
        local p = { bgURL = url .. '.png', fgURL = url .. '-mask.png', pURL = 'type2t.png',
            bgHex = '020202ff', fgHex = 'ff0000ff', pHex = 'ffff00ff' }
        for k, v in pairs(fields) do p[k] = v end
        return p
    end
    local extra = {}
    for k, v in pairs(part.extra) do extra[k] = v end
    extra.patch1 = patch('patch2', { tx = -0.33, ty = 0 })
    extra.patch2 = patch('patch1', { tx = 0.33, ty = 0 })
    extra.patch3 = patch('patch1', { tx = 0, ty = 0.83, sx = 2 })

    local looks = {}
    for _, shrink in ipairs({ 1, 2 }) do
        textured.setShrinkFactor(shrink)
        local baked = bakePart(extra, extra.main)
        baked.w, baked.h = baked.w * 2, baked.h * 2 -- big enough to see the patches
        looks[shrink] = renderLooks({ baked }, CLOSE_SCALE)
        writeFile('patch-check-shrink-' .. shrink .. '.png', looks[shrink]:encode('png'):getString())
        releaseBaked(baked)
    end
    local diff, changed = compareLooks(looks[1], looks[2])
    local report = string.format('patch check (%s): diff %.2f/255, %.1f%% px changed between shrink 1 and 2',
        part.extra.main.bgURL, diff, changed)
    print(report)
    writeFile('patch-check.txt', report .. '\n')
    love.event.quit()
end

---------------------------------------------------------------- interactive

local interactive = { list = {} }

local function bakeInteractive(index)
    for _, baked in ipairs(interactive.list) do releaseBaked(baked) end
    collectgarbage('collect')
    textured.setShrinkFactor(OPTIONS[index].shrink)
    interactive.list = bakeMipo(mipos[1], false)
    view.baked, view.layout = interactive.list, 'grid'
    hud = OPTIONS[index].name .. ' (1-4 option, z zoom, esc quit)'
end

---------------------------------------------------------------- LÖVE

function love.load(args)
    tex1 = getSource('textures/pat/type0.png')
    tex1:setWrap('mirroredrepeat', 'mirroredrepeat')
    lineFallback = getSource('textures/shapes6.png')
    maskFallback = getSource('textures/shapes6-mask.png')
    mipos = loadMipos()

    local auto, checkPatches = false, false
    for _, a in ipairs(args) do
        if a == '--auto' then auto = true end
        if a == '--patch-check' then checkPatches = true end
    end
    if checkPatches then
        patchCheck()
    elseif auto then
        runner = coroutine.create(autoRun)
    else
        bakeInteractive(1)
    end
end

function love.update(dt)
    lastFrameTime = dt
    if runner and coroutine.status(runner) ~= 'dead' then
        local ok, err = coroutine.resume(runner)
        if not ok then error(debug.traceback(runner, err)) end
    end
end

function love.draw()
    love.graphics.clear(0.85, 0.8, 0.75, 1)
    if view.layout == 'grid' then
        drawGrid(view.baked, view.scale)
    else
        drawScatter(view.baked, view.scale)
    end
    view.drawcalls = love.graphics.getStats().drawcalls
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(string.format('%s   tex %.1f MB   %d fps', hud, texMB(), love.timer.getFPS()), 10, 10)
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if runner then return end
    local index = tonumber(key)
    if index and OPTIONS[index] then bakeInteractive(index) end
    if key == 'z' then
        view.scale = view.scale == CAMERA_SCALE and CLOSE_SCALE or CAMERA_SCALE
    end
end
