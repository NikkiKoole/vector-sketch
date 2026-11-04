-- raspberry: Mipos blowing raspberries, tongue out between pressed lips (docs/RASPBERRY.md).
-- The tongue is drawn in code and the pbbbbt is made in code: placeholders for a drawing and a
-- recording. Timing lives in src/mipo-raspberry.lua (outTime, wait, inTime, shakeRate, soundLength).
-- keys: space: all of them, one after another   1-3: one   r: new Mipos   (tap a Mipo: it blows)

local s = {}

local COUNT = 3
local SPACING = 520
local GROUND_Y = 900
local ZOOM = 0.8

local function check() -- on state: a script hot reload keeps the Mipos
    state.raspberrySpike = state.raspberrySpike or { mipos = {}, queue = {} }
    return state.raspberrySpike
end

local function alive(inst)
    if not inst or not inst.parts then return false end
    for _, part in pairs(inst.parts) do
        if part.body and not part.body:isDestroyed() then return true end
    end
    return false
end

local function makeMipos()
    local c = check()
    for _, inst in ipairs(c.mipos) do
        if alive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
    for i = 1, COUNT do
        local x = (i - (COUNT + 1) / 2) * SPACING
        local inst = characterManager.createCharacter('humanoid', x, GROUND_Y - 500, 0.3)
        if inst then characterManager.randomizeMipoConstrained(inst) end -- today's Bathhouse Mipos
        c.mipos[i] = inst
    end
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(SPACING * (COUNT + 2), 100)):setFriction(0.9)
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation(0, GROUND_Y - 420)
    check().hold = true
end

local function blow(i)
    local inst = check().mipos[i]
    if alive(inst) then mipoRaspberry.blow(inst) end
end

function s.onStart()
    worldState.paused = false
    makeGround()
    local c = check()
    local any = false
    for _, inst in ipairs(c.mipos) do any = any or alive(inst) end
    if not any then makeMipos() end
    lookAtAll()
end

function s.onUnload()
    local c = state.raspberrySpike
    if c and c.ground and not c.ground:isDestroyed() then c.ground:destroy() end
    if c then c.ground = nil end
end

function s.update()
    local c = check()
    local now = love.timer.getTime()
    for i = #c.queue, 1, -1 do -- space: one after another
        if now >= c.queue[i].at then
            blow(c.queue[i].index)
            table.remove(c.queue, i)
        end
    end
    -- the follow camera moves the view: hold it on the Mipos until you touch, drag or zoom
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

-- tap a Mipo (play mode): it blows one
function s.onPressed(things)
    for _, thing in ipairs(things or {}) do
        local inst = thing and thing.mipoId and mipoRegistry.getById(thing.mipoId)
        if inst then mipoRaspberry.blow(inst); return end
    end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'space' then
        local now = love.timer.getTime()
        for i = 1, #c.mipos do c.queue[#c.queue + 1] = { index = i, at = now + (i - 1) * 0.6 } end
    elseif key == 'r' then
        makeMipos()
    elseif tonumber(key) and c.mipos[tonumber(key)] then
        blow(tonumber(key))
    end
end

function s.drawUI()
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print('raspberry spike   space: all   1-3: one   r: new Mipos   tap a Mipo', 20,
        love.graphics.getHeight() - 30)
end

return s
