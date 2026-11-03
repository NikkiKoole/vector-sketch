-- fabuland: a spike for chunky building parts that click together (src/fabuland.lua, parked:
-- docs/FABULAND.md). A wide floor and a little house; the panel (play mode, tab) makes any part
-- above the middle of the screen. Drag parts together: they weld square on the 250 grid.
-- keys: h: hide/show the panel

local s = {}
local showPanel = true

local function hasParts()
    for _, body in ipairs(world:getBodies()) do
        if fabuland.partOf(body) then return true end
    end
    return false
end

-- a floor to build on, right of the scene's own, and a house of four blocks with a roof
local function buildKit()
    local ground = objectManager.addThing('rectangle', { x = 6600, y = 40, width = 7000, height = 80,
        bodyType = 'static', label = 'fab-ground' })
    if ground then
        for _, fixture in ipairs(ground.body:getFixtures()) do fixture:setFriction(0.9) end
    end
    fabuland.make('window block', 3500, -500, 'yellow')
    fabuland.make('door block', 4250, -500, 'red')
    fabuland.make('wheel window block', 5000, -500, 'blue')
    fabuland.make('arch window block', 5750, -500, 'red')
    fabuland.make('roof left', 3500, -1250, 'green')
    fabuland.make('roof right', 4250, -1250, 'green')
    -- weld the house now (snaps otherwise only happen while you drag)
    local was = state.snap.onlyConnectWhenInteracted
    state.snap.onlyConnectWhenInteracted = false
    snap.update(1 / 60)
    state.snap.onlyConnectWhenInteracted = was
    fabuland.make('stairs', 7200, -500, 'red')
    fabuland.make('railing', 8200, -125, 'red')
    fabuland.make('plank', 9200, -62, 'brown')
end

function s.onStart()
    worldState.paused = false
    state.fabuland = { on = true }
    if not hasParts() then buildKit() end
end

function s.onUnload()
    state.fabuland = nil
end

function s.onKeyPress(key)
    if key == 'h' then showPanel = not showPanel end
end

function s.drawUI()
    if not (state.playMode and showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 8, 300
    local h = BH * #fabuland.PARTS + pad * (#fabuland.PARTS + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• fabuland ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, part in ipairs(fabuland.PARTS) do
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            if ui.button(x, y, w - 20, part.name) then
                local sw, shh = love.graphics.getDimensions()
                local wx, wy = cam:getWorldCoordinates(sw / 2, shh / 3)
                fabuland.make(part.name, wx, wy)
            end
        end
    end)
end

return s
