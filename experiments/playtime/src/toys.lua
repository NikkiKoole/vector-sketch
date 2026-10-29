-- toys.lua — the built-in toys: src/props.lua recipes by name, shown on the
-- library's 'toys' shelf (src/ui/library-tab.lua). Unlike prefabs they are code,
-- not files, so they're always there and can't be deleted. Buttons, plates,
-- sockets and gates start on 'signal1'.
local lib = {}

local props = require('src.props')
local objectManager = require('src.object-manager')

-- { name, make(wx, wy) -> list of things (may contain nils) }
lib.LIST = {
    { 'ball', function(wx, wy) return { props.makeBall(wx, wy, 80, { squishy = true }) } end },
    { 'blob', function(wx, wy) return { props.makeBlob(wx, wy) } end },
    { 'cup', function(wx, wy) return { props.makeCup(wx, wy, 1) } end },
    { 'bath', function(wx, wy) return { props.makeBath(wx, wy, 1) } end },
    { 'skateboard', function(wx, wy)
        local deck, wheels = props.makeSkateboard(wx, wy, 1)
        return { deck, wheels and wheels[1], wheels and wheels[2] }
    end },
    { 'slide', function(wx, wy)
        local slide = props.makeSlide(wx, wy, 1)
        return { slide.ladder, slide.deck }
    end },
    { 'button', function(wx, wy)
        local button, post = props.makeButton(wx, wy, 450, 'signal1', 1)
        return { button, post }
    end },
    { 'plate', function(wx, wy) return { props.makePlate(wx, wy, 'signal1', 'hold', 1) } end },
    { 'snap block', function(wx, wy) return { props.makeSnapBlock(wx, wy, 1) } end },
    { 'socket', function(wx, wy) return { props.makeSocket(wx, wy, 'signal1', 'key', 'hold', 1) } end },
    { 'key', function(wx, wy) return { props.makeKey(wx, wy, 1) } end },
    { 'wheel', function(wx, wy) return { props.makeWheel(wx, wy, 1) } end },
    { 'plank', function(wx, wy) return { props.makePlank(wx, wy, 1) } end },
    { 'climbing wall', function(wx, wy)
        local board, holds = props.makeClimbingWall(wx, wy, 1)
        local things = { board }
        for _, hold in ipairs(holds or {}) do things[#things + 1] = hold end
        return things
    end },
    { 'gate', function(wx, wy)
        local base = objectManager.addThing('rectangle', { x = wx, y = wy, width = 300, height = 30,
            bodyType = 'static', label = 'gate-base' })
        return { base, base and props.makeGate(base.body, wx, wy - 15, 'signal1', 1) }
    end },
}

-- Build a toy at a world position; returns its things (no nils), first one to drag by.
function lib.make(name, wx, wy)
    for _, toy in ipairs(lib.LIST) do
        if toy[1] == name then
            local things = {}
            for _, thing in pairs(toy[2](wx, wy)) do
                if thing then things[#things + 1] = thing end
            end
            return things
        end
    end
    return {}
end

return lib
