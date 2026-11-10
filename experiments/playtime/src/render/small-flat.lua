-- small-flat.lua — a lit face or foot drawn small on screen is drawn flat (LIGHT-AND-SHADOW LS30): zoomed
-- out to a room of 20 Mipos an eye is a few pixels and its light doesn't show, but its shader still costs
-- (eyes 1.4, feet 1.0, mouth 0.8, nose 0.3 ms with 20 Mipos on an iPhone SE 2). The eyes, nose, lips,
-- teeth and the feet's leg clip ask tooSmall with their own size in world units.
-- state.litMinPx: the smallest size (screen px) still lit; 0 lights everything (as before).
local lib = {}
local state = require('src.state')
local cam = require('src.camera').getInstance()

lib.MIN_PX = 20

function lib.tooSmall(size)
    local minPx = state.litMinPx or lib.MIN_PX
    if minPx <= 0 or not size then return false end
    return size * cam:getScale() < minPx
end

return lib
