-- feet-check: every foot picture on a Mipo of its own (the same Mipo otherwise), to see how
-- each one stands. A foot hangs from its picture's ankle (src/shape8-dict.lua, the anchors
-- on the meta sheet). Red: the feet's collision outline. Under each: how far each foot is
-- off level, and STOP when it's pressed against the ankle's stop. spec/feet-stand checks
-- the same (three drops, each foot at rest on its sole). Load the scene again for fresh Mipos
-- after changing how feet are built.
-- keys: d: drop them all again   p: pause the world

local s = {}

local PER_ROW = 4
local SPACING = 650
local ROW_GAP = 1300
local GROUND_Y = 900 -- of the first row
local ZOOM = 0.45

local function check() -- on state: a script hot reload keeps the Mipos
    state.feetCheck = state.feetCheck or { mipos = {}, grounds = {} }
    return state.feetCheck
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function slot(i)
    local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    return col * SPACING, GROUND_Y + row * ROW_GAP
end

local function rows() return math.ceil(#shapeCatalogs.handShapes / PER_ROW) end

local function makeGrounds()
    local c = check()
    for r = 1, rows() do
        local g = c.grounds[r]
        if not (g and not g:isDestroyed()) then
            local w = SPACING * (PER_ROW + 1)
            g = love.physics.newBody(world, (PER_ROW - 1) * SPACING / 2, GROUND_Y + (r - 1) * ROW_GAP + 50, 'static')
            love.physics.newFixture(g, love.physics.newRectangleShape(w, 100)):setFriction(0.9)
            c.grounds[r] = g
        end
    end
end

local function build()
    local c = check()
    for i, name in ipairs(shapeCatalogs.handShapes) do
        if not alive(c.mipos[i]) then
            local x, groundY = slot(i)
            local inst = characterManager.createCharacter('humanoid', x, groundY - 400, 0.3)
            if inst then
                characterManager.updatePart('lfoot', { shape8URL = name .. '.png' }, inst)
                characterManager.updatePart('rfoot', { shape8URL = name .. '.png' }, inst)
                characterManager.rebuildTextures(inst)
            end
            c.mipos[i] = inst
        end
    end
end

local function lookAtAll()
    cam:setScale(ZOOM)
    cam:setTranslation((PER_ROW - 1) * SPACING / 2, GROUND_Y + (rows() - 1) * ROW_GAP / 2 - 250)
    check().hold = true
end

function s.onStart()
    makeGrounds()
    build()
    lookAtAll()
end

-- the follow camera moves the view: hold it on all the Mipos until you touch, drag or zoom
function s.update()
    local c = check()
    if not c.hold then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAtAll()
    end
end

-- lift each Mipo and let go, as spec/feet-stand does
local function dropAll()
    for _, inst in pairs(check().mipos) do
        if alive(inst) then
            for _, part in pairs(inst.parts) do
                local body = part.body
                body:setPosition(body:getX(), body:getY() - 400)
                body:setLinearVelocity(0, 0)
                body:setAngularVelocity(0)
            end
        end
    end
end

function s.onUnload()
    local c = state.feetCheck
    if not c then return end
    for r, g in pairs(c.grounds) do
        if not g:isDestroyed() then g:destroy() end
        c.grounds[r] = nil
    end
end

function s.onKeyPress(key)
    if key == 'p' then worldState.paused = not worldState.paused end
    if key == 'd' then dropAll() end
end

-- the ankle: the revolute joint between a foot and its shin
local function ankle(inst, foot, shin)
    local fb, sb = inst.parts[foot] and inst.parts[foot].body, inst.parts[shin] and inst.parts[shin].body
    if not (fb and sb) or fb:isDestroyed() or sb:isDestroyed() then return end
    for _, joint in ipairs(fb:getJoints()) do
        local a, b = joint:getBodies()
        if joint:getType() == 'revolute' and (a == sb or b == sb) then return joint end
    end
end

-- built a quarter turn from its shin: flat is ±90 degrees
local REST = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }

local function footText(inst, foot, shin)
    local joint = ankle(inst, foot, shin)
    if not joint then return '?' end
    local d = inst.parts[foot].body:getAngle() - REST[foot]
    local off = math.deg(math.abs(math.atan2(math.sin(d), math.cos(d))))
    local angle, low, up = joint:getJointAngle(), joint:getLimits()
    local stop = (angle <= low + 0.02 or angle >= up - 0.02) and ' STOP' or ''
    return string.format('%.0f deg%s', off, stop)
end

function s.draw()
    local c = check()
    for i, name in ipairs(shapeCatalogs.handShapes) do
        local inst = c.mipos[i]
        local x, groundY = slot(i)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(name, x - 300, groundY + 110, 300, 'center', 0, 2, 2)
        if alive(inst) then
            love.graphics.printf(footText(inst, 'lfoot', 'llleg') .. '   ' .. footText(inst, 'rfoot', 'rlleg'),
                x - 300, groundY + 160, 300, 'center', 0, 2, 2)
            love.graphics.setColor(1, 0, 0)
            love.graphics.setLineWidth(2)
            for _, foot in ipairs({ 'lfoot', 'rfoot' }) do
                local body = inst.parts[foot] and inst.parts[foot].body
                if body and not body:isDestroyed() then
                    for _, fixture in ipairs(body:getFixtures()) do
                        local shape = fixture:getShape()
                        if not fixture:getUserData() and shape:getType() == 'polygon' then
                            love.graphics.polygon('line', body:getWorldPoints(shape:getPoints()))
                        end
                    end
                end
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

return s
