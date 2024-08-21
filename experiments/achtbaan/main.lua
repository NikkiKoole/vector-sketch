function love.load()
    coaster_track_points = {} -- Table to store the points
    mousepressed = false
    min_distance = 10         -- Minimum distance between points
end

function love.update(dt)
end

function love.draw()
    -- Draw the line connecting the points
    if #coaster_track_points > 1 then
        for i = 1, #coaster_track_points - 1 do
            local p1 = coaster_track_points[i]
            local p2 = coaster_track_points[i + 1]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Only track left mouse button press
        coaster_track_points = {}
        print('hello!')
        mousepressed = true
        -- Start a new line by adding the first point
        table.insert(coaster_track_points, { x = x, y = y })
    end
end

function love.mousemoved(x, y, dx, dy)
    if mousepressed then
        local last_point = coaster_track_points[#coaster_track_points]
        -- Calculate the distance between the last point and the current mouse position
        local distance = math.sqrt((x - last_point.x) ^ 2 + (y - last_point.y) ^ 2)

        -- Only add the new point if it's far enough from the last point
        if distance >= min_distance then
            table.insert(coaster_track_points, { x = x, y = y })
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        mousepressed = false
        print('released', #coaster_track_points)
    end
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end
