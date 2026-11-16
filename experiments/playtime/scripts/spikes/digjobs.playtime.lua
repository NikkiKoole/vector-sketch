-- digjobs: paint tiles in the earth, the Mipos walk over and dig them out (the ant-farm feel)
-- Nikki 2026-11-16: burrow felt boring ("i ment the burrow itself"); "could we sort of have a little job, so i
-- draw a tile (that is reachable to be dig, a mipo needs to be close to there, maybe he can walk and do it?)".
-- The finger doesn't dig here: it marks tiles (a chalk outline round the plan). A free Mipo picks the nearest
-- marked tile it can get at, walks there (mipoWalk.drive), and digs it bite by bite with its arms going, the bite
-- nearest to it first. Honest reach: only what it can touch from where it stands (beside it, above its head,
-- under its feet), with no earth in between. Dig under its own feet and it drops in and goes on: a shaft.
-- A tile it can't get to stays marked; one it walked toward without getting there it leaves for a while.
-- Made of: the earth   scripts/spikes/burrow.playtime.lua (its own state 'digjobsEarth'; its cave, its rocks,
--                      its two Mipos: one on the grass, one in the cave; m adds one at the mouse, r resets)
-- play mode (tab): drag on the earth to mark tiles; start a drag on a marked tile to unmark.
-- keys: c clear the marks   h the panel   (the burrow's own: m Mipo  r reset  t o b i looks)
local s = {}

local TILE_MIN, TILE_MAX = 200, 600
local TY0, TX0 = 2250, 1500 -- the tile grid lines up with the burrow cave's flat floor
local BITES = 4             -- a tile is dug in BITES x BITES round bites
local CHECK_EVERY = 0.3     -- seconds between looking for work
local STUCK_CHECK = 1.5     -- seconds between "did it get closer?"
local GIVE_UP_FOR = 10      -- seconds a tile it couldn't reach is left by that Mipo
local CRUMB_COLORS = { { 0.36, 0.25, 0.16 }, { 0.3, 0.2, 0.13 }, { 0.62, 0.44, 0.28 }, { 0.5, 0.38, 0.3 } }

local function st()
    state.digjobs = state.digjobs or { marks = {}, tile = 420, biteTime = 0.18, reach = 1.25, speed = 1.4,
        showPanel = true, crumbs = {} }
    return state.digjobs
end

---------------------------------------------------------------- the earth

local panelRect
local function overPanel()
    local r = panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

-- the scene names the burrow uses (loaded with love.filesystem.load it runs in the plain globals)
local function earthEnv()
    return { state = state, world = world, cam = cam, camera = camera, ui = ui, objectManager = objectManager,
        fixtures = fixtures, shape8Dict = shape8Dict, characterManager = characterManager, worldState = worldState,
        mouseWorldPos = mouseWorldPos, getInteractedWithPointer = getInteractedWithPointer, love = love,
        math = math, table = table, string = string, pairs = pairs, ipairs = ipairs, unpack = unpack,
        print = print, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall }
end

local earth
local function loadEarth()
    return love.filesystem.load('scripts/spikes/burrow.playtime.lua')({
        env = earthEnv(), stateKey = 'digjobsEarth',
        canDig = function() return false end, -- the finger marks, the Mipos dig
        sharedFrame = true,
    })
end

local function workers()
    local b = state.digjobsEarth
    local list = {}
    for _, inst in ipairs(b and b.mipos or {}) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    return list
end

---------------------------------------------------------------- tiles

local function tileOf(x, y)
    local T = st().tile
    return math.floor((x - TX0) / T), math.floor((y - TY0) / T)
end
local function keyOf(i, j) return i .. ',' .. j end
local function tileRect(i, j)
    local T = st().tile
    return TX0 + i * T, TY0 + j * T, T
end
local function tileCentre(i, j)
    local x, y, T = tileRect(i, j)
    return x + T / 2, y + T / 2
end

-- the bite centres of a tile (a BITES x BITES grid) and their radius: together they cover the square
local function bitesOf(i, j)
    local x, y, T = tileRect(i, j)
    local step = T / BITES
    local list = {}
    for a = 0, BITES - 1 do
        for b = 0, BITES - 1 do list[#list + 1] = { x + (a + 0.5) * step, y + (b + 0.5) * step } end
    end
    return list, step * 0.75
end

-- how much earth is left in a tile: the bite centres still in earth
local function earthLeft(i, j)
    local n = 0
    for _, p in ipairs((bitesOf(i, j))) do
        if earth.earthAt(p[1], p[2]) > 0.5 then n = n + 1 end
    end
    return n
end

-- a tile with air beside it (or already partly dug) can be worked on
local function isOpen(i, j)
    if earthLeft(i, j) < BITES * BITES then return true end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local x, y = tileCentre(i + d[1], j + d[2])
        if earth.earthAt(x, y) < 0.5 then return true end
    end
    return false
end

local function torsoOf(inst) return inst.parts.torso1.body:getPosition() end

-- can it touch the tile from here: close enough, and no earth between it and the tile's edge
local function canReach(inst, i, j)
    local tx, ty = torsoOf(inst)
    local cx, cy = tileCentre(i, j)
    local c = st()
    local dx, dy = cx - tx, cy - ty
    local d = math.sqrt(dx * dx + dy * dy)
    if d > c.tile * c.reach then return false end
    local steps = math.ceil(d / 30)
    for k = 1, steps do
        local x, y = tx + dx * k / steps, ty + dy * k / steps
        local ti, tj = tileOf(x, y)
        if ti == i and tj == j then return true end -- into the tile itself: reached
        if earth.earthAt(x, y) > 0.5 then return false end
    end
    return true
end

local function held(inst)
    local bodies = getInteractedWithPointer()
    if #bodies == 0 then return false end
    for _, part in pairs(inst.parts) do
        for _, body in ipairs(bodies) do
            if part.body == body then return true end
        end
    end
    return false
end

---------------------------------------------------------------- the work

local function claimedBy(key)
    for _, inst in ipairs(workers()) do
        if inst._dig and inst._dig.key == key then return inst end
    end
end

local function stopWork(inst)
    if inst._dig then
        mipoWalk.drive(inst, nil)
        mipoActions.stopPointing(inst)
        mipoActions.stopLooking(inst)
    end
    inst._dig = nil
end

local function giveUp(inst, now)
    inst._digGaveUp = inst._digGaveUp or {}
    inst._digGaveUp[inst._dig.key] = now + GIVE_UP_FOR
    stopWork(inst)
end

-- the nearest open marked tile nobody has, that it hasn't just given up on, not too far above its head
-- (it can't climb: a tile out of reach above stays marked)
local function pickTile(inst, now)
    local c = st()
    local tx, ty = torsoOf(inst)
    local best, bestScore
    for key, m in pairs(c.marks) do
        local gaveUp = inst._digGaveUp and inst._digGaveUp[key]
        if not (gaveUp and gaveUp > now) and not claimedBy(key) then
            local cx, cy = tileCentre(m[1], m[2])
            if cy > ty - c.tile * c.reach and isOpen(m[1], m[2]) then
                local score = math.abs(cx - tx) + 2 * math.abs(cy - ty)
                if not bestScore or score < bestScore then best, bestScore = m, score end
            end
        end
    end
    return best
end

local function crumbs(x, y, n)
    local list = st().crumbs
    for _ = 1, n do
        local a = -math.pi / 2 + (love.math.random() - 0.5) * 2.6
        local v = 200 + love.math.random() * 400
        list[#list + 1] = { x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v,
            r = 6 + love.math.random() * 10, life = 0.5 + love.math.random() * 0.5,
            color = CRUMB_COLORS[love.math.random(1, #CRUMB_COLORS)] }
    end
end

-- one bite: the bite centre still in earth nearest to it
local function bite(inst, job)
    local list, r = bitesOf(job.i, job.j)
    local tx, ty = torsoOf(inst)
    local best, bestD
    for _, p in ipairs(list) do
        if earth.earthAt(p[1], p[2]) > 0.5 then
            local d = (p[1] - tx) ^ 2 + (p[2] - ty) ^ 2
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    if not best then return false end
    earth.dig(best[1], best[2], best[1], best[2], false, r)
    crumbs(best[1], best[2], 4)
    job.at = best
    return true
end

local function workTick(inst, dt, now)
    local c = st()
    local job = inst._dig
    if held(inst) then
        if job then stopWork(inst) end
        return
    end
    if not job then
        inst._digLook = (inst._digLook or 0) - dt
        if inst._digLook > 0 then return end
        inst._digLook = CHECK_EVERY
        local m = pickTile(inst, now)
        if not m then return end
        local tx = torsoOf(inst)
        job = { i = m[1], j = m[2], key = keyOf(m[1], m[2]), phase = 'walk', checkAt = now + STUCK_CHECK, lastX = tx }
        inst._dig = job
    end
    if not c.marks[job.key] then return stopWork(inst) end -- unmarked meanwhile
    if earthLeft(job.i, job.j) == 0 then
        c.marks[job.key] = nil
        return stopWork(inst)
    end
    if job.phase == 'walk' then
        if canReach(inst, job.i, job.j) then
            mipoWalk.drive(inst, nil)
            job.phase, job.biteIn = 'dig', 0.3
            mipoActions.pointAt(inst, function()
                local p = job.at or { tileCentre(job.i, job.j) }
                local t = love.timer.getTime() * 11
                return p[1] + math.sin(t) * 60, p[2] + math.cos(t * 0.7) * 60
            end)
            mipoActions.lookAt(inst, function()
                local p = job.at or { tileCentre(job.i, job.j) }
                return p[1], p[2]
            end)
            return
        end
        local tx = torsoOf(inst)
        local cx = tileCentre(job.i, job.j)
        local dir = cx > tx and 1 or -1
        if math.abs(cx - tx) < c.tile * 0.2 then
            -- right above or under it and still not reaching: there's no way from here
            return giveUp(inst, now)
        end
        mipoWalk.drive(inst, dir * c.speed, 'walk')
        if mipoWalk.blocked(inst) then return giveUp(inst, now) end
        if now > job.checkAt then
            if math.abs(tx - job.lastX) < c.tile * 0.15 then return giveUp(inst, now) end
            job.lastX, job.checkAt = tx, now + STUCK_CHECK
        end
    else -- dig
        if not canReach(inst, job.i, job.j) then -- fell, slid, was bumped: walk again
            mipoActions.stopPointing(inst)
            mipoActions.stopLooking(inst)
            job.phase, job.checkAt, job.lastX = 'walk', now + STUCK_CHECK, (torsoOf(inst))
            return
        end
        job.biteIn = job.biteIn - dt
        if job.biteIn <= 0 then
            job.biteIn = c.biteTime
            if not bite(inst, job) then
                c.marks[job.key] = nil
                stopWork(inst)
            end
        end
    end
end

---------------------------------------------------------------- the finger: marking

local function markAt(x, y, on)
    local c = st()
    local i, j = tileOf(x, y)
    local key = keyOf(i, j)
    if on then
        if not c.marks[key] and earthLeft(i, j) > 0 then c.marks[key] = { i, j } end
    elseif c.marks[key] then
        c.marks[key] = nil
        local inst = claimedBy(key)
        if inst then stopWork(inst) end
    end
end

local function fingerTick()
    local c = st()
    local down = state.playMode and love.mouse.isDown(1)
    if down and not c.stroke and #getInteractedWithPointer() == 0 and not overPanel() then
        local mx, my = mouseWorldPos()
        local i, j = tileOf(mx, my)
        c.stroke = { on = not c.marks[keyOf(i, j)], x = mx, y = my } -- started on a mark: this stroke unmarks
    elseif not down then
        c.stroke = nil
    end
    if c.stroke then
        local mx, my = mouseWorldPos()
        local dx, dy = mx - c.stroke.x, my - c.stroke.y
        local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / (c.tile * 0.3)))
        for k = 0, steps do markAt(c.stroke.x + dx * k / steps, c.stroke.y + dy * k / steps, c.stroke.on) end
        c.stroke.x, c.stroke.y = mx, my
    end
end

---------------------------------------------------------------- hooks

local function clearMarks()
    for _, inst in ipairs(workers()) do stopWork(inst) end
    st().marks = {}
end

function s.onStart()
    worldState.paused = false
    local c = st()
    earth = loadEarth()
    if not c.panelFolded then -- the burrow's big panel folded at first
        state.scriptPanels = state.scriptPanels or {}
        state.scriptPanels['•• burrow ••'] = true
        c.panelFolded = true
    end
    earth.onStart()
    for _, inst in ipairs(workers()) do inst._dig = nil end
end

function s.onUnload()
    for _, inst in ipairs(workers()) do stopWork(inst) end
    if earth then earth.onUnload() end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    if key == 'c' then
        clearMarks()
    elseif key == 'h' then
        st().showPanel = not st().showPanel
    elseif key == 'r' then
        clearMarks()
        earth.onKeyPress(key)
    elseif earth then
        earth.onKeyPress(key)
    end
end

function s.update(dt)
    if not earth then return end
    local c = st()
    fingerTick()
    earth.update(dt) -- rebuilds what was dug
    local now = love.timer.getTime()
    for _, inst in ipairs(workers()) do workTick(inst, dt, now) end
    for i = #c.crumbs, 1, -1 do
        local p = c.crumbs[i]
        p.vy = p.vy + 1800 * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(c.crumbs, i) end
    end
end

-- a dashed line, for the chalk outline of the plan
local function dashed(x1, y1, x2, y2, dash)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local n = math.max(1, math.floor(len / dash))
    for k = 0, n - 1, 2 do
        local a, b = k / n, math.min(1, (k + 1) / n)
        love.graphics.line(x1 + dx * a, y1 + dy * a, x1 + dx * b, y1 + dy * b)
    end
end

-- the marks under the Mipos: a faint chalk wash per tile, a dashed line round the plan's outside
local function drawMarks()
    local c = st()
    local T = c.tile
    for key, m in pairs(c.marks) do
        local x, y = tileRect(m[1], m[2])
        love.graphics.setColor(1, 0.97, 0.85, claimedBy(key) and 0.22 or 0.12)
        love.graphics.rectangle('fill', x, y, T, T)
    end
    love.graphics.setColor(1, 0.97, 0.85, 0.75)
    love.graphics.setLineWidth(math.max(6, T * 0.025))
    local dash = T / 7
    for _, m in pairs(c.marks) do
        local i, j = m[1], m[2]
        local x, y = tileRect(i, j)
        if not c.marks[keyOf(i, j - 1)] then dashed(x, y, x + T, y, dash) end
        if not c.marks[keyOf(i, j + 1)] then dashed(x, y + T, x + T, y + T, dash) end
        if not c.marks[keyOf(i - 1, j)] then dashed(x, y, x, y + T, dash) end
        if not c.marks[keyOf(i + 1, j)] then dashed(x + T, y, x + T, y + T, dash) end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawBelow()
    if not earth then return end
    earth.drawBelow()
    drawMarks()
end

function s.draw()
    if not earth then return end
    earth.draw()
    local c = st()
    for _, p in ipairs(c.crumbs) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], math.min(1, p.life * 3))
        love.graphics.circle('fill', p.x, p.y, p.r)
    end
    -- the tile under the finger
    if state.playMode and not overPanel() then
        local mx, my = mouseWorldPos()
        local x, y, T = tileRect(tileOf(mx, my))
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle('line', x, y, T, T)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------- the panel

local PANEL = { w = 300, row = 32, pad = 6 }

function s.drawUI()
    if state.playMode then ui.startFrame() end -- once a frame, for both panels
    if earth then earth.drawUI() end
    local c = st()
    panelRect = nil
    if not (c.showPanel and state.playMode) then return end
    local sw = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * 7 + 34
    local x0, y0 = sw - w - 12, 12
    panelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• dig jobs ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local x, y = row()
        if ui.button(x, y, w - PANEL.pad * 2, 'clear the marks') then clearMarks() end
        for _, r in ipairs({ { 'tile', TILE_MIN, TILE_MAX, 1 }, { 'biteTime', 0.03, 0.6 }, { 'reach', 1, 2 },
            { 'speed', 0.5, 3 } }) do
            x, y = row()
            local v = ui.sliderWithInput('digjobs' .. r[1], x, y, 150, r[2], r[3], c[r[1]], nil, r[4])
            if v and v ~= c[r[1]] then
                if r[1] == 'tile' then clearMarks() end -- the old marks don't fit the new grid
                c[r[1]] = v + 0
            end
            ui.label(x + 248, y + 4, r[1])
        end
        x, y = row()
        local n = 0
        for _ in pairs(c.marks) do n = n + 1 end
        ui.label(x, y + 4, n .. ' tiles marked, ' .. #workers() .. ' Mipos')
        x, y = row()
        ui.label(x, y + 4, 'c clear  m Mipo  r reset  h panel')
    end)
end

return s
