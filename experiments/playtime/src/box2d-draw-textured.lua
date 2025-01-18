local lib = {}

local mathutils = require 'src.math-utils'

local img = love.graphics.newImage('textures/shapeA4.png')
local imgw, imgh = img:getDimensions()



function lib.drawTexturedWorld(world)
    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local ud = body:getUserData()
        if (ud and ud.thing) then
            local vertices = ud.thing.vertices
            local cx, cy, ww, hh = mathutils.getCenterOfPoints(vertices)
            --print(cx, cy, ww, hh)
            --print(cx, cy)h
            local sx = ww / imgw
            local sy = hh / imgh
            love.graphics.draw(img, body:getX(), body:getY(), body:getAngle(), sx * 1.1, sy * 1.1, imgw / 2, imgh / 2)
        end
    end
end

return lib
