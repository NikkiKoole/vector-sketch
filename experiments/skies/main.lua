-- main.lua
local SkyGradient = require("SkyGradient")

-- Utility function to convert hex to RGB
local function hex2rgb(hex)
    hex = hex:gsub("#","")
    return {
        tonumber(hex:sub(1,2), 16) / 255,
        tonumber(hex:sub(3,4), 16) / 255,
        tonumber(hex:sub(5,6), 16) / 255,
        1 -- Default alpha
    }
end


-- exract more from here:
-- https://www.figma.com/design/vJb1HDi7nUfai3qxQgyfwW/Sky-Gradient-Library-(Community)?node-id=6-2&t=SFXug5XiyNyEJCkv-0
local others1 = {
    {color=hex2rgb('020111'), position=0.0},
    {color=hex2rgb('191621'), position=1},
}
local others2 = {
    {color=hex2rgb('020111'), position=0.0},
    {color=hex2rgb('20202C'), position=1},
}
local others3 = {
    {color=hex2rgb('020111'), position=0.0},
    {color=hex2rgb('3A3A52'), position=1},
}
local others4 = {
    {color=hex2rgb('20202C'), position=0.0},
    {color=hex2rgb('515175'), position=1},
}
local others5 = {
    {color=hex2rgb('40405C'), position=0},
    {color=hex2rgb('6F71AA'), position=0.8},
    {color=hex2rgb('8A76AB'), position=1},
}
local others6 = {
    {color=hex2rgb('4A4969'), position=0},
    {color=hex2rgb('7072AB'), position=0.5},
    {color=hex2rgb('CD82A0'), position=1},
}
local others7 = {
    {color=hex2rgb('757ABF'), position=0},
    {color=hex2rgb('8583BE'), position=0.6},
    {color=hex2rgb('EAB0D1'), position=1},
}
local others8 = {
    {color=hex2rgb('82ADDB'), position=0.0},
    {color=hex2rgb('EBB2B1'), position=1},
}
local others9 = {
    {color=hex2rgb('94C5F8'), position=0},
    {color=hex2rgb('A6E6FF'), position=0.7},
    {color=hex2rgb('B1B5EA'), position=1},
}
local others10 = {
    {color=hex2rgb('B7EAFF'), position=0.0},
    {color=hex2rgb('94DFFF'), position=1},
}
local others11 = {
    {color=hex2rgb('9BE2FE'), position=0.0},
    {color=hex2rgb('67D1FB'), position=1},
}
local others12 = {
    {color=hex2rgb('90DFFE'), position=0.0},
    {color=hex2rgb('38A3D1'), position=1},
}
local others13 = {
    {color=hex2rgb('57C1EB'), position=0.0},
    {color=hex2rgb('246FA8'), position=1},
}
local others14 = {
    {color=hex2rgb('2D91C2'), position=0.0},
    {color=hex2rgb('1E528E'), position=1},
}
local others15 = {
    {color=hex2rgb('2473AB'), position=0.0},
    {color=hex2rgb('1E528E'), position=0.7},
    {color=hex2rgb('5B7983'), position=1},
}
local others16 = {
    {color=hex2rgb('1E528E'), position=0.0},
    {color=hex2rgb('265889'), position=0.5},
    {color=hex2rgb('9DA671'), position=1},
}
local others17 = {
    {color=hex2rgb('1E528E'), position=0.0},
    {color=hex2rgb('728A7C'), position=0.5},
    {color=hex2rgb('E9CE5D'), position=1},
}
local others18 = {
    {color=hex2rgb('154277'), position=0},
    {color=hex2rgb('576E71'), position=0.3},
    {color=hex2rgb('E1C45E'), position=0.7},
    {color=hex2rgb('B26339'), position=1},
}
local others19 = {
    {color=hex2rgb('163C52'), position=0},
    {color=hex2rgb('4F4F47'), position=0.3},
    {color=hex2rgb('C5752D'), position=0.6},
    {color=hex2rgb('B7490F'), position=0.8},
    {color=hex2rgb('2F1107'), position=1},
}
local others20 = {
    {color=hex2rgb('071B26'), position=0},
    {color=hex2rgb('071B26'), position=0.3},
    {color=hex2rgb('8A3B12'), position=0.8},
    {color=hex2rgb('240E03'), position=1},
}
local others21 = {
    {color=hex2rgb('010A10'), position=0},
    {color=hex2rgb('59230B'), position=0.3},
    {color=hex2rgb('2F1107'), position=1},
}
local others22 = {
    {color=hex2rgb('090401'), position=0},
    {color=hex2rgb('4B1D06'), position=1},
}
local others23 = {
    {color=hex2rgb('00000C'), position=0},
    {color=hex2rgb('150800'), position=1},
}
colorstopindex = 5
gradients = {
    others1,others2,others3,others4,others5,others6,
    others7,others8,others9,others10,others11,others12,
    others13,others14,others15,others16,others17,others18,
    others19,others20,others21,others22,others23
}
colorStops = gradients[colorstopindex]

local sky

local camera = {
    y = 0.5,        -- Initial camera y position (can be outside [0, 1])
    height = 1,     -- Height of the camera view in gradient's coordinate system
    zoom = 1      -- Initial zoom level
}

function love.load()
    -- Create the main SkyGradient instance
    sky = SkyGradient:new(colorStops)
    -- Initial mesh updates for both layers
    sky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)

end
function love.keypressed(k)
    if k == 'space' then
        colorstopindex = colorstopindex + 1
        if colorstopindex > #gradients then
            colorstopindex = 1
        end
        colorStops = gradients[colorstopindex]

        sky = SkyGradient:new(colorStops)
        sky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)
    end
end
function love.update(dt)
    -- Update camera position based on input or game logic
    -- Move camera upward with "up" arrow and downward with "down" arrow
    if love.keyboard.isDown("up") then
        camera.y = camera.y + 0.5 * dt/camera.zoom
    elseif love.keyboard.isDown("down") then
        camera.y = camera.y - 0.5 * dt/camera.zoom
    end

    -- Zoom in with "left" arrow and zoom out with "right" arrow
    if love.keyboard.isDown("left") then
        camera.zoom = camera.zoom + dt
    elseif love.keyboard.isDown("right") then
        camera.zoom = camera.zoom - dt
    end

    -- Clamp camera.zoom to prevent it from being zero or negative
    camera.zoom = math.max(0.1, camera.zoom)


    camera.y = math.max(-12, math.min(12, camera.y))

    -- Update the mesh with the new camera position for both layers
    sky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)
   -- extraSky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)
end

function love.draw()
    -- Draw the main sky gradient covering the entire window
    love.graphics.setColor(1, 1, 1, 1)
    sky:draw(0, 0, love.graphics.getWidth(), love.graphics.getHeight())


    love.graphics.setColor(1, 1, 1, 1)
    -- **End of Extra Layer Drawing**

    -- Your game rendering goes here
    love.graphics.print("Use Up/Down arrows to move the camera", 10, 10)
    love.graphics.print("Use Left/Right arrows to zoom", 10, 30)
    love.graphics.print("Use Space to time", 10, 50)
end
