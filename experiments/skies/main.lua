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


-- Define color stops for the midday sky
local middayColorStops = {
    { color = hex2rgb('#000000'), position = -11.0 }, -- Black (Space beyond below)
    { color = hex2rgb('#012459'), position = 0.0 },  -- Deep Navy Blue (Horizon)
    { color = hex2rgb('#01396C'), position = 0.1 },  -- Dark Blue
    { color = hex2rgb('#01557F'), position = 0.25 }, -- Blue
    { color = hex2rgb('#017393'), position = 0.4 },  -- Teal Blue
    { color = hex2rgb('#0190A7'), position = 0.55 }, -- Light Teal
    { color = hex2rgb('#01A0BB'), position = 0.7 },  -- Sky Blue
    { color = hex2rgb('#03B0CF'), position = 0.8 },  -- Lighter Sky Blue
    { color = hex2rgb('#05C0E3'), position = 0.9 },  -- Very Light Blue
    { color = hex2rgb('#07D0F7'), position = 0.95 }, -- Almost White Blue
    { color = hex2rgb('#000000'), position = 12.0 },  -- Black (Space beyond above)
}

-- Define color stops for the dawn gradient
local dawnColorStops = {
    { color = hex2rgb('#000000'), position = 12.0 },  -- Black (Space beyond above)
    { color = hex2rgb('#0000CD'), position = 0.95 },  -- Medium Blue
    { color = hex2rgb('#1E90FF'), position = 0.9 },   -- Dodger Blue
    { color = hex2rgb('#00BFFF'), position = 0.8 },   -- Deep Sky Blue
    { color = hex2rgb('#87CEFA'), position = 0.7 },   -- Light Sky Blue
    { color = hex2rgb('#FFB6C1'), position = 0.55 },  -- Light Pink
    { color = hex2rgb('#FF69B4'), position = 0.4 },   -- Hot Pink
    { color = hex2rgb('#FF7F50'), position = 0.25 },  -- Coral (Warm Orange)
    { color = hex2rgb('#FFA07A'), position = 0.1 },   -- Light Salmon (Soft Orange)
    { color = hex2rgb('#FFD1DC'), position = 0.0 },   -- Light Pink (Horizon)
    { color = hex2rgb('#000000'), position = -11.0 }, -- Black (Space beyond below)
}

-- Define color stops for the dusk gradient
local duskColorStops = {
    { color = hex2rgb('#000000'), position = 12.0 },  -- Black (Space beyond above)
    { color = hex2rgb('#000080'), position = 0.95 },  -- Navy
    { color = hex2rgb('#4B0082'), position = 0.9 },   -- Indigo
    { color = hex2rgb('#8A2BE2'), position = 0.8 },   -- Blue Violet
    { color = hex2rgb('#9370DB'), position = 0.7 },   -- Medium Purple
    { color = hex2rgb('#C71585'), position = 0.55 },  -- Medium Violet Red
    { color = hex2rgb('#FF1493'), position = 0.4 },   -- Deep Pink
    { color = hex2rgb('#FF8C00'), position = 0.25 },  -- Dark Orange
    { color = hex2rgb('#FF6347'), position = 0.1 },   -- Tomato (Vibrant Orange)
    { color = hex2rgb('#FF4500'), position = 0.0 },   -- Orange Red (Horizon)
    { color = hex2rgb('#000000'), position = -11.0 }, -- Black (Space beyond below)
}


colorStops = middayColorStops



local sky
local extraSky -- New SkyGradient instance for the extra layer
local camera = {
    y = 0.5,        -- Initial camera y position (can be outside [0, 1])
    height = 1,     -- Height of the camera view in gradient's coordinate system
    zoom = 1      -- Initial zoom level
}

function love.load()
    -- Create the main SkyGradient instance
    sky = SkyGradient:new(colorStops)

    -- Define color stops for the extra simpler layer
    -- This example uses a subtle white gradient for a fog or haze effect
    local extraColorStops = {
        { color = {1, 1, 1, 0}, position = 0.0 },    -- Transparent at the bottom
          { color = {1, 0, 0, 1}, position = 0.25 },  -- Semi-transparent in the middle
        { color = {1, 0, 0, 1}, position = 0.5 },  -- Semi-transparent in the middle
          { color = {1, 0, 0, 1}, position = 0.75 },  -- Semi-transparent in the middle
        { color = {1, 1, 1, 0}, position = 1.0 },    -- Transparent at the top
    }

    -- Define color stops for the extra simpler layer (Sepia Overlay)
       -- Using a uniform color with transparency for simplicity
       local extraColorStops = {
           { color = {0.439, 0.259, 0.078, 0}, position = 0.0 },    -- Transparent at the bottom
           { color = {0.439, 0.259, 0.078, 0.3}, position = 0.5 },  -- Semi-transparent sepia in the middle
           { color = {0.439, 0.259, 0.078, 0}, position = 1.0 },    -- Transparent at the top
       }


    -- Create the extra SkyGradient instance
    extraSky = SkyGradient:new(extraColorStops)

    -- Initial mesh updates for both layers
    sky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)
    extraSky:updateMesh(camera.y, camera.height, love.graphics.getHeight(), camera.zoom)
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

    -- **Start of Extra Layer Drawing**
    -- Set the desired opacity for the extra layer (e.g., 0.3 for 30% opacity)
   -- love.graphics.setColor(1, 1, 1, 1)

    -- Draw the extra simpler gradient layer on top
   -- extraSky:draw(0, 0, love.graphics.getWidth(), love.graphics.getHeight())

--   love.graphics.setColor(1, 0.8, 0.8, 0.3)
   -- love.graphics.setColor(0.439, 0.259, 0.078, 0.03) -- Sepia RGB (112, 66, 20) normalized
  --      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        -- Reset color to white with full opacity
    --    love.graphics.setColor(1, 1, 1, 1)
    -- Reset color to white with full opacity for other drawings
    love.graphics.setColor(1, 1, 1, 1)
    -- **End of Extra Layer Drawing**

    -- Your game rendering goes here
    love.graphics.print("Use Up/Down arrows to move the camera", 10, 10)
    love.graphics.print("Use Left/Right arrows to zoom", 10, 30)
end
