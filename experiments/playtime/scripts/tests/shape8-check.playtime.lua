-- shape8-check: compare shape8 outlines in the game, two Mipos per case: the game now (left)
-- and another outline for the same picture (right). The red lines are the collision
-- outlines of the shape8 parts (the dict's 8 points).
-- keys: left/right: next case (and back to it after scrolling away)   r: build the Mipos again
--   p: pause the world
-- docs/SCENES.md (meta — the shape outlines). The right side lives only in this scene.

local s = {}

local SPACING = 2400 -- between cases
local HALF = 330     -- now / fix either side of the case's middle
local ZOOM = 0.85
local GROUND_Y = 900

-- Decided 2026-11-01: shapes9 and earx13r had two digits swapped in their size and
-- were squashed; the dict now has the png's size with the outline stretched along. The
-- right Mipo shows them as they were. hand3r, earx3r, feet3xr and shapeA3 kept the dict's
-- outline (the sheet has it now too). Add a case to compare another outline.
local CASES = {
    { url = 'mipo/body/body-13.png', parts = 'torso', title = 'shapes9: now 520x648, before 520x468 (squashed)',
      fixLabel = 'before',
      fix = { dimensions = { 520, 468 },
          vertices = { 0, -236, 233, -191, 198, 24, 174, 206, -18, 216, -226, 205, -233, 19, -234, -198 } } },
    { url = 'mipo/ear/ear-13.png', parts = 'ears', title = 'earx13r: now 225x366, before 225x336 (squashed)',
      fixLabel = 'before',
      fix = { dimensions = { 225, 336 }, root = { 31, 129 },
          vertices = { -33, -100, 12, -33, 29, 16, 43, 73, -9, 86, -54, 72, -57, 15, -62, -33 } } },
}

local PARTS = {
    torso = { 'torso1' }, -- the other bands take torso1's shape
    ears = { 'lear', 'rear' },
    hands = { 'lhand', 'rhand' },
    feet = { 'lfoot', 'rfoot' },
}

local function fixKey(case) return case.url .. '#fix' end

-- The fix as a dict entry that borrows the original's picture.
local function registerFixes()
    for _, case in ipairs(CASES) do
        local fix = case.fix
        shape8Dict[fixKey(case)] = { picture = case.url, dimensions = fix.dimensions, vertices = fix.vertices,
            root = fix.root or shape8Dict[case.url].root }
    end
end

local function unregisterFixes()
    for _, case in ipairs(CASES) do shape8Dict[fixKey(case)] = nil end
end

local function check() -- kept on state, so a script hot reload keeps the Mipos
    state.shape8Check = state.shape8Check or { mipos = {}, current = 1 }
    return state.shape8Check
end

local alive = mipoKit.isAlive -- src/mipo-kit.lua

local function setShape(inst, case, url)
    if case.parts == 'torso' then
        for i = 1, inst.dna.creation.torsoSegments or 1 do
            characterManager.updatePart('torso' .. i, { shape8URL = url }, inst)
        end
    else
        for _, partName in ipairs(PARTS[case.parts]) do
            characterManager.updatePart(partName, { shape8URL = url }, inst)
        end
    end
    characterManager.rebuildTextures(inst) -- updatePart drops the pictures
end

local function caseX(i) return (i - 1) * SPACING end

local function build()
    local c = check()
    for i, case in ipairs(CASES) do
        for side, url in pairs({ now = case.url, fix = fixKey(case) }) do
            local key = i .. side
            local x = caseX(i) + (side == 'now' and -HALF or HALF)
            if not alive(c.mipos[key]) then
                c.mipos[key] = characterManager.createCharacter('humanoid', x, GROUND_Y - 400, 0.3)
            end
            if c.mipos[key] then setShape(c.mipos[key], case, url) end
        end
    end
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    local w = SPACING * (#CASES + 1)
    c.ground = love.physics.newBody(world, w / 2 - SPACING, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(w, 100))
end

local function lookAt(i)
    local c = check()
    c.current = math.max(1, math.min(#CASES, i))
    cam:setScale(ZOOM)
    cam:setTranslation(caseX(c.current), GROUND_Y - 350)
    c.hold = true
end

function s.onStart()
    registerFixes()
    makeGround()
    build()
    lookAt(check().current)
end

function s.onUnload()
    unregisterFixes() -- spec/shape8-dict_spec wants the dict as written
    local c = state.shape8Check
    if c and c.ground and not c.ground:isDestroyed() then c.ground:destroy() end
    if c then c.ground = nil end
end

-- play mode moves the camera (follow, zoom limits): hold it on the case until you
-- touch, drag or zoom yourself
function s.update()
    local c = check()
    if not (c.hold and state.playMode) then return end
    if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or cam.scale ~= ZOOM then
        c.hold = false
    else
        lookAt(c.current)
    end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'right' then lookAt(c.current + 1) end
    if key == 'left' then lookAt(c.current - 1) end
    if key == 'r' then build() end
    if key == 'p' then worldState.paused = not worldState.paused end
end

-- every shape8 part (torso, ears, hands, feet): the collision outline over the picture
local function drawOutline(inst)
    for name, part in pairs(inst.parts) do
        local partData = inst.dna.parts[name]
        if partData and partData.shape8URL and part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                local shape = fixture:getShape()
                if not fixture:getUserData() and shape:getType() == 'polygon' then
                    love.graphics.polygon('line', part.body:getWorldPoints(shape:getPoints()))
                end
            end
        end
    end
end

function s.draw()
    local c = check()
    for i, case in ipairs(CASES) do
        local x = caseX(i)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(i .. '/' .. #CASES .. '  ' .. case.title, x - 600, GROUND_Y + 25, 800, 'center',
            0, 1.5, 1.5)
        love.graphics.printf('now (the game)', x - HALF - 225, GROUND_Y - 790, 300, 'center', 0, 1.5, 1.5)
        love.graphics.printf(case.fixLabel, x + HALF - 225, GROUND_Y - 790, 300, 'center', 0, 1.5, 1.5)
        love.graphics.setColor(1, 0, 0)
        love.graphics.setLineWidth(2)
        for _, side in ipairs({ 'now', 'fix' }) do
            local inst = c.mipos[i .. side]
            if alive(inst) then drawOutline(inst) end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

return s
