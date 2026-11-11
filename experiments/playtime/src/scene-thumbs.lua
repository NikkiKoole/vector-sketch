-- scene-thumbs.lua — a small picture of every scene for the scenes tab (src/ui/scenes-tab.lua).
--
--   love . --thumbs                 every scene (an off-screen window without the bridge, beside the game)
--   love . --thumbs dollhouse bark  just these
--   ./playtime.sh thumbs [names]    the same, no audio
--
-- Each scene loads in play mode, runs SETTLE seconds (scripts make their Mipos, things fall
-- and land), the camera goes where FRAMES says (else the scene's own saved camera), and the
-- window, without any UI, is shrunk to WIDTH and written to scripts/thumbs/<name>.png. The
-- tab reads them from there (lib.image); a scene without one shows its name in an empty box.
local lib = {}

local state = require('src.state')
local camera = require('src.camera')

lib.DIR = 'scripts/thumbs'
local WIDTH = 320
local SETTLE = 1.5 -- seconds of play before the picture

-- The view per scene when its own saved camera doesn't show it well: { x, y, w, h }, the
-- centre and the size in world units (camera.centerCameraOnPosition fits it to the window),
-- 'fit': everything solid in the world, or 'crowd': the moving things without stragglers.
-- Picked by looking at each picture (2026-11-08).
lib.FRAMES = {
    ['bakery'] = 'fit',
    ['catapult'] = 'crowd',
    ['elasto'] = 'crowd',
    ['miposhader'] = 'fit',
    ['overworld'] = 'fit',
    ['planets'] = 'fit',
    ['platforms'] = { 250, 300, 1800, 1400 },
    ['resources'] = 'fit',
    ['snap'] = 'crowd',
    ['snap2'] = 'crowd',
    ['treehouse'] = 'fit',
    ['water'] = { -100, 800, 3600, 2200 }, -- the pool and its floor (bodies flung far off)
    ['workmoreclean'] = 'fit',
    ['mudready'] = 'crowd',
    ['meta'] = 'fit',
    ['sm-demo'] = 'fit',
    ['voicebox'] = 'crowd', -- its one big Mipo
}

-- ── the tab's side ──────────────────────────────────────────────────────────────────────────

local images = {} -- id -> Image, or false when there's none
function lib.image(id)
    local img = images[id]
    if img == nil then
        local path = lib.DIR .. '/' .. id .. '.png'
        img = false
        if love.filesystem.getInfo(path, 'file') then
            local ok, loaded = pcall(love.graphics.newImage, path, { mipmaps = true })
            if ok then
                loaded:setFilter('linear', 'linear')
                loaded:setMipmapFilter('linear')
                img = loaded
            end
        end
        images[id] = img
    end
    return img or nil
end

function lib.forget() images = {} end -- read the files again (new pictures made)

-- ── making them ─────────────────────────────────────────────────────────────────────────────

-- The run: { queue = {entries}, i, phase, t } on state, so a hot reload doesn't lose it.
local function run() return state.sceneThumbs end
function lib.capturing() return run() ~= nil end

-- `--thumbs [names]` on the command line: true when this run makes pictures.
function lib.fromArgs(args)
    local on, names = false, {}
    for i = 1, #args do
        if args[i] == '--thumbs' then
            on = true
        elseif on and not args[i]:match('^%-%-') then
            names[#names + 1] = args[i]
        elseif on then
            break
        end
    end
    if not on then return false end
    local catalog = require('src.scene-catalog')
    local want = {}
    for _, n in ipairs(names) do want[n] = true end
    local queue = {}
    for _, entry in ipairs(catalog.list()) do
        if not entry.scriptOnly and (#names == 0 or want[entry.id]) then queue[#queue + 1] = entry end
    end
    state.sceneThumbs = { queue = queue, i = 0, phase = 'next', t = 0, made = 0, failed = {} }
    require('src.music').enabled = false
    return true
end

local function projectPath(file)
    return love.filesystem.getSource() .. '/' .. lib.DIR .. '/' .. file
end

-- the whole window's picture, shrunk to WIDTH, written beside the scenes
local function save(id, imageData)
    local big = love.graphics.newImage(imageData, { mipmaps = true })
    big:setFilter('linear', 'linear')
    big:setMipmapFilter('linear')
    local scale = WIDTH / big:getWidth()
    local h = math.floor(big:getHeight() * scale + 0.5)
    local canvas = love.graphics.newCanvas(WIDTH, h)
    love.graphics.push('all')
    love.graphics.reset()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(big, 0, 0, 0, scale, scale)
    love.graphics.setCanvas()
    love.graphics.pop()
    local png = canvas:newImageData():encode('png')
    os.execute('mkdir -p "' .. love.filesystem.getSource() .. '/' .. lib.DIR .. '"')
    local file = io.open(projectPath(id .. '.png'), 'wb')
    if file then
        file:write(png:getString())
        file:close()
        return true
    end
    return false
end

-- the box round every solid fixture in the world (sensors left out: sfixtures, triggers)
local function worldBounds()
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:isSensor() then
                local ax, ay, bx, by = fixture:getBoundingBox(1)
                x1, y1, x2, y2 = math.min(x1, ax), math.min(y1, ay), math.max(x2, bx), math.max(y2, by)
            end
        end
    end
    if x1 > x2 then return nil end
    return x1, y1, x2, y2
end

-- the moving things (dynamic bodies), stragglers far from the rest left out (a ball shot off, a
-- part fallen away): the box round the ones whose centre is within the middle 80% spread out 1.5x
local function crowdBounds()
    local boxes, xs, ys = {}, {}, {}
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        if body:getType() == 'dynamic' then
            for _, fixture in ipairs(body:getFixtures()) do
                if not fixture:isSensor() then
                    local ax, ay, bx, by = fixture:getBoundingBox(1)
                    boxes[#boxes + 1] = { ax, ay, bx, by }
                    xs[#xs + 1], ys[#ys + 1] = (ax + bx) / 2, (ay + by) / 2
                end
            end
        end
    end
    if #boxes == 0 then return nil end
    table.sort(xs)
    table.sort(ys)
    local function range(v)
        local lo, hi = v[math.max(1, math.floor(#v * 0.1))], v[math.ceil(#v * 0.9)]
        local mid, half = (lo + hi) / 2, math.max(200, (hi - lo) * 0.75)
        return mid - half, mid + half
    end
    local cx1, cx2 = range(xs)
    local cy1, cy2 = range(ys)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, b in ipairs(boxes) do
        local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
        if cx >= cx1 and cx <= cx2 and cy >= cy1 and cy <= cy2 then
            x1, y1, x2, y2 = math.min(x1, b[1]), math.min(y1, b[2]), math.max(x2, b[3]), math.max(y2, b[4])
        end
    end
    return x1, y1, x2, y2
end

local function frame(id)
    local f = lib.FRAMES[id]
    if f == 'crowd' then
        local x1, y1, x2, y2 = crowdBounds()
        if x1 then
            local w, h = math.max(500, (x2 - x1) * 1.4), math.max(400, (y2 - y1) * 1.4)
            camera.centerCameraOnPosition((x1 + x2) / 2, (y1 + y2) / 2 + h * 0.1, w, h) -- a bit of floor
        end
    elseif f == 'fit' then
        local x1, y1, x2, y2 = worldBounds()
        if x1 then
            local pad = 1.1
            camera.centerCameraOnPosition((x1 + x2) / 2, (y1 + y2) / 2, (x2 - x1) * pad, (y2 - y1) * pad)
        end
    elseif f then
        camera.centerCameraOnPosition(f[1], f[2], f[3], f[4])
    end
end

-- once a frame (love.update) while a run is on
function lib.update(dt)
    local r = run()
    if not r then return end
    r.t = r.t + dt
    if r.phase == 'next' then
        r.i = r.i + 1
        local entry = r.queue[r.i]
        if not entry then
            print(string.format('[thumbs] %d made, %d failed%s', r.made, #r.failed,
                #r.failed > 0 and (': ' .. table.concat(r.failed, ', ')) or ''))
            state.sceneThumbs = nil
            io.stdout:flush()
            os.exit(0) -- not love.event.quit: a scene's script can turn that down, and the run hung
            return
        end
        local playMode = require('src.play-mode')
        if playMode.isOn() then playMode.exit() end
        local ok, err = pcall(require('src.scene-loader').loadScriptAndScene, entry.id)
        if not ok then
            print('[thumbs] ' .. entry.id .. ' did not load: ' .. tostring(err))
            r.failed[#r.failed + 1] = entry.id
            return
        end
        playMode.enter()
        r.phase, r.t = 'settle', 0
    elseif r.phase == 'settle' and r.t >= SETTLE then
        local entry = r.queue[r.i]
        local playMode = require('src.play-mode')
        playMode.exit() -- no follow camera, the world stops where it is
        state.world.paused = true
        frame(entry.id)
        r.phase, r.t = 'shoot', 0
    elseif r.phase == 'shoot' and r.t > 0.1 then -- a frame or two drawn at the new camera first
        local entry = r.queue[r.i]
        r.phase = 'wait'
        love.graphics.captureScreenshot(function(imageData)
            if save(entry.id, imageData) then
                r.made = r.made + 1
                print(string.format('[thumbs] %d/%d %s', r.i, #r.queue, entry.id))
            else
                r.failed[#r.failed + 1] = entry.id
            end
            r.phase = 'next'
        end)
    end
end

return lib
