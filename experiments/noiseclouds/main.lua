local cloudCanvas
local cloudOpacity = 0.85      -- Cloud opacity
local noiseScale = 0.08     -- Controls "size" of cloud features
local canvasSize = 32      -- Small canvas size for efficiency
local cloudSpeed = 1        -- Speed for cloud movement

-- Camera setup
local camera = {
    y = 0.5,      -- Initial camera y position
     x = 0.5,
    height = 1,   -- Camera view height
    zoom = 1      -- Initial zoom level
}

function love.load()
    -- Create a canvas with alpha support
    cloudCanvas = love.graphics.newCanvas(canvasSize, canvasSize, {format = "rgba8"})
    generateClouds()
end

function generateClouds()
    -- Generate clouds using noise and draw on a transparent canvas
    love.graphics.setCanvas(cloudCanvas)
    love.graphics.clear(0, 0, 0, 0) -- Clear with full transparency

    for x = 1, canvasSize do
        for y = 1, canvasSize do
            -- Adjust noise based on camera position and zoom
            local n = love.math.noise(
                (x + camera.x * 100) * noiseScale / camera.zoom,
                (y + camera.y * 100) * noiseScale / camera.zoom,
                love.timer.getTime() * cloudSpeed
            )

            -- Map noise to cloud opacity
            local alpha = n * cloudOpacity
            love.graphics.setColor(1, 1, 1, alpha) -- White clouds
            love.graphics.points(x, y)
        end
    end



    love.graphics.setCanvas()
end

function love.update(dt)
    -- Update cloud noise over time for animation
    generateClouds()

    -- Camera controls
    if love.keyboard.isDown("up") then
        camera.y = camera.y + 0.5 * dt / camera.zoom
    elseif love.keyboard.isDown("down") then
        camera.y = camera.y - 0.5 * dt / camera.zoom
    end
    if love.keyboard.isDown("left") then
        camera.x = camera.x - 0.5 * dt / camera.zoom
    elseif love.keyboard.isDown("right") then
        camera.x = camera.x + 0.5 * dt / camera.zoom
    end

    -- Zoom controls
    if love.keyboard.isDown("z") then
        camera.zoom = camera.zoom + dt
    elseif love.keyboard.isDown("x") then
        camera.zoom = camera.zoom - dt
    end

    -- Clamp camera values
    camera.zoom = math.max(0.1, camera.zoom)
    camera.y = math.max(-12, math.min(12, camera.y))
end

function love.draw()
    -- Draw the flat sky color
    love.graphics.clear(0.5, 0.5, 1)
 love.graphics.clear(0,0,0)
    -- Scale cloud canvas to fit the window and apply zoom effect
    local scaleX = (love.graphics.getWidth() / canvasSize) --* camera.zoom
    local scaleY = (love.graphics.getHeight() / canvasSize) --* camera.zoom

    -- Apply camera position by translating clouds
    love.graphics.push()
    --love.graphics.translate(0, -camera.y * 50 * camera.zoom) -- Adjust vertical offset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cloudCanvas, 0, 0, 0, scaleX, scaleY)
    love.graphics.pop()

    -- UI instructions
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("Use Up/Down arrows to move the camera", 10, 10)
    love.graphics.print("Use z/x arrows to zoom", 10, 30)
end
