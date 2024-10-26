function love.load()
    coaster_track_points = {}                     -- Table to store the points
    support_beam_positions = {}                   -- Table to store support beam positions
    mousepressed = false
    min_distance = 30                             -- Minimum distance between points
    support_spacing = 100                         -- Distance between support beams along the track
    min_horizontal_spacing = 50                   -- Minimum horizontal spacing between beams
    ground_level = love.graphics.getHeight() - 50 -- Define where the ground is

    -- Physical constants
    gravity = 9.81              -- Gravitational acceleration (pixels/s^2)
    mass = 1                    -- Mass of the cart (arbitrary units)
    friction_coefficient = 0.05 -- Coefficient of friction (adjust as needed)
    max_speed = 500             -- Maximum speed of the cart (pixels/s)
    min_speed = 0               -- Minimum speed (to prevent negative speeds)

    -- Cart variables
    cart = {
        positionOnTrack = 0,  -- Distance along the track
        velocity = 0,         -- Velocity of the cart (pixels/s)
        acceleration = 0,     -- Acceleration of the cart (pixels/s^2)
        x = 0,                -- Current x-coordinate
        y = 0,                -- Current y-coordinate
        direction = 0,        -- Direction angle in radians
        offsetDirection = 1,  -- 1 for above the track, -1 for below
        lastFlipIndex = nil,  -- To prevent multiple flips at the same flip point
        lastAccelIndex = nil, -- To prevent multiple accelerations at the same point
        lastBrakeIndex = nil, -- To prevent multiple brakes at the same point
    }
    totalTrackLength = 0
    segment_lengths = {}
    cartInitialized = false

    -- Acceleration and Deceleration values
    acceleration_value = 200 -- Increase in speed (pixels/s)
    deceleration_value = 200 -- Decrease in speed (pixels/s)
end

function love.update(dt)
    if cartInitialized then
        updateCartPosition(dt)
    end
end

function love.draw()
    -- Draw the line connecting the points (the track)
    if #coaster_track_points > 1 then
        for i = 1, #coaster_track_points do
            local p1 = coaster_track_points[i]
            local p2 = coaster_track_points[i % #coaster_track_points + 1]
            love.graphics.setColor(1, 1, 1) -- White color for the track
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)

            -- Draw the points with different colors based on their properties
            if p1.flip then
                love.graphics.setColor(0, 0, 1) -- Blue for flip points
            elseif p1.accelerate then
                love.graphics.setColor(0, 1, 0) -- Green for acceleration points
            elseif p1.decelerate then
                love.graphics.setColor(1, 0, 0) -- Red for deceleration points
            else
                love.graphics.setColor(1, 1, 1) -- White for normal points
            end
            love.graphics.circle('fill', p1.x, p1.y, 5)
        end
    elseif #coaster_track_points == 1 then
        -- If there's only one point, draw it
        local p1 = coaster_track_points[1]
        love.graphics.circle('fill', p1.x, p1.y, 3)
    end

    -- Draw support beams
    if #support_beam_positions > 0 then
        love.graphics.setColor(0.5, 0.5, 0.5) -- Gray color for beams
        for _, beam in ipairs(support_beam_positions) do
            -- Draw the beam (line from track to ground)
            love.graphics.line(beam.x, beam.y, beam.x, ground_level)
            -- Draw red circle at the connection point
            love.graphics.setColor(1, 0, 0)       -- Red color for connection
            love.graphics.circle('fill', beam.x, beam.y, 5)
            love.graphics.setColor(0.5, 0.5, 0.5) -- Reset color for beams
        end
    end

    -- Draw the cart
    if cartInitialized then
        love.graphics.setColor(1, 0, 0) -- Red color for the cart
        love.graphics.push()
        love.graphics.translate(cart.x, cart.y)
        love.graphics.rotate(cart.direction)
        -- Draw the cart as a rectangle
        love.graphics.rectangle('fill', -10, -5, 20, 10)
        love.graphics.pop()

        -- Display cart speed and acceleration
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Speed: %.2f px/s", cart.velocity), 10, 10)
        love.graphics.print(string.format("Acceleration: %.2f px/s²", cart.acceleration), 10, 30)
    end

    -- Draw ground
    love.graphics.setColor(0, 1, 0) -- Green color for ground
    love.graphics.line(0, ground_level, love.graphics.getWidth(), ground_level)

    love.graphics.setColor(1, 1, 1) -- Reset color to white
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Only track left mouse button press
        coaster_track_points = {}
        support_beam_positions = {}
        cartInitialized = false
        print('hello!')
        mousepressed = true
        -- Start a new line by adding the first point
        table.insert(coaster_track_points, { x = x, y = y, flip = false, accelerate = false, decelerate = false })
    end
end

function love.mousemoved(x, y, dx, dy)
    if mousepressed then
        local last_point = coaster_track_points[#coaster_track_points]
        -- Calculate the distance between the last point and the current mouse position
        local distance = math.sqrt((x - last_point.x) ^ 2 + (y - last_point.y) ^ 2)

        if distance >= min_distance then
            -- Calculate the number of segments needed
            local num_segments = math.floor(distance / min_distance)
            local segment_length = distance / num_segments
            -- Get the direction vector components
            local dir_x = (x - last_point.x) / distance
            local dir_y = (y - last_point.y) / distance

            -- Insert intermediate points
            for i = 1, num_segments do
                local nx = last_point.x + dir_x * segment_length * i
                local ny = last_point.y + dir_y * segment_length * i
                table.insert(coaster_track_points,
                    { x = nx, y = ny, flip = false, accelerate = false, decelerate = false })
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        mousepressed = false
        print('released', #coaster_track_points)

        -- After completing the track, calculate support beam positions and track lengths
        calculateSupportBeams()
        calculateTrackLengths()

        -- Initialize the cart
        initializeCart()
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'f' then
        -- Toggle flip at the closest point to the mouse cursor
        local x, y = love.mouse.getPosition()
        local closest_point = findClosestPoint(x, y)
        if closest_point then
            closest_point.flip = not closest_point.flip
            print('Flip point at index', closest_point.index, 'flip set to', closest_point.flip)
        end
    elseif key == 'a' then
        -- Toggle acceleration at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point = findClosestPoint(x, y)
        if closest_point then
            closest_point.accelerate = not closest_point.accelerate
            closest_point.decelerate = false -- Ensure decelerate is false
            print('Acceleration point at index', closest_point.index, 'accelerate set to', closest_point.accelerate)
        end
    elseif key == 'd' then
        -- Toggle deceleration at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point = findClosestPoint(x, y)
        if closest_point then
            closest_point.decelerate = not closest_point.decelerate
            closest_point.accelerate = false -- Ensure accelerate is false
            print('Deceleration point at index', closest_point.index, 'decelerate set to', closest_point.decelerate)
        end
    end
end

function findClosestPoint(x, y)
    local min_dist_sq = math.huge
    local closest_point = nil
    for i, point in ipairs(coaster_track_points) do
        local dx = point.x - x
        local dy = point.y - y
        local dist_sq = dx * dx + dy * dy
        if dist_sq < min_dist_sq then
            min_dist_sq = dist_sq
            closest_point = point
            closest_point.index = i
        end
    end
    -- Set a threshold distance
    if min_dist_sq < 100 ^ 2 then
        return closest_point
    else
        return nil
    end
end

-- Function to calculate support beam positions along the track
function calculateSupportBeams()
    support_beam_positions = {}
    local initial_beam_positions = {}

    -- Total length of the track
    local total_length = 0

    for i = 1, #coaster_track_points do
        local p1 = coaster_track_points[i]
        local p2 = coaster_track_points[i % #coaster_track_points + 1] -- Wrap around
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local segment_length = math.sqrt(dx * dx + dy * dy)
        segment_lengths[i] = segment_length
        total_length = total_length + segment_length
    end

    -- Place initial support beams at regular intervals along the total length
    local num_beams = math.floor(total_length / support_spacing)
    for i = 1, num_beams do
        local target_distance = i * support_spacing
        local accumulated_distance = 0

        -- Find which segment the support beam falls on
        for j = 1, #coaster_track_points do
            local segment_length = segment_lengths[j]
            if accumulated_distance + segment_length >= target_distance then
                local remaining_distance = target_distance - accumulated_distance
                local t = remaining_distance / segment_length

                -- Interpolate position along the segment
                local p1 = coaster_track_points[j]
                local p2 = coaster_track_points[j % #coaster_track_points + 1]
                local beam_x = p1.x + (p2.x - p1.x) * t
                local beam_y = p1.y + (p2.y - p1.y) * t

                table.insert(initial_beam_positions, { x = beam_x, y = beam_y })
                break
            else
                accumulated_distance = accumulated_distance + segment_length
            end
        end
    end

    -- Merge beams that are too close horizontally
    local merged_beams = {}
    local i = 1
    while i <= #initial_beam_positions do
        local beam_group = { initial_beam_positions[i] }
        local j = i + 1
        while j <= #initial_beam_positions do
            local dx = math.abs(initial_beam_positions[j].x - initial_beam_positions[i].x)
            if dx < min_horizontal_spacing then
                table.insert(beam_group, initial_beam_positions[j])
                j = j + 1
            else
                break
            end
        end

        -- Select the beam with the highest point (smallest y value)
        local highest_beam = beam_group[1]
        for _, beam in ipairs(beam_group) do
            if beam.y < highest_beam.y then
                highest_beam = beam
            end
        end
        table.insert(merged_beams, highest_beam)

        i = j
    end

    support_beam_positions = merged_beams
end

-- Function to calculate total track length and segment lengths
function calculateTrackLengths()
    totalTrackLength = 0
    segment_lengths = {}

    for i = 1, #coaster_track_points do
        local p1 = coaster_track_points[i]
        local p2 = coaster_track_points[i % #coaster_track_points + 1] -- Wrap around
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local segment_length = math.sqrt(dx * dx + dy * dy)
        segment_lengths[i] = segment_length
        totalTrackLength = totalTrackLength + segment_length
    end
end

-- Function to initialize the cart after track creation
function initializeCart()
    if #coaster_track_points < 2 then
        print("Error: Not enough points to form a track.")
        cartInitialized = false
        return
    end

    cart.positionOnTrack = 0
    cart.velocity = 0        -- Starting velocity
    cart.acceleration = 0    -- Starting acceleration
    cartInitialized = true
    cart.offsetDirection = 1 -- Start above the track
    cart.lastFlipIndex = nil
    cart.lastAccelIndex = nil
    cart.lastBrakeIndex = nil

    -- Set initial position
    local p1 = coaster_track_points[1]
    local p2 = coaster_track_points[2]
    cart.x = p1.x
    cart.y = p1.y

    -- Calculate initial direction based on the first segment
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    cart.direction = math.atan2(dy, dx)
end

-- Function to update the cart's position
function updateCartPosition(dt)
    if not cartInitialized then return end

    -- Get the cart's current position on the track
    local cartPos, segmentIndex, t = getPointOnTrack(cart.positionOnTrack)
    cart.x = cartPos.x
    cart.y = cartPos.y

    -- Ensure segmentIndex is valid
    if segmentIndex > #coaster_track_points then
        segmentIndex = 1
    elseif segmentIndex < 1 then
        segmentIndex = 1
    end

    -- Update the cart's direction based on the current segment
    local p1 = coaster_track_points[segmentIndex]
    local p2 = coaster_track_points[segmentIndex % #coaster_track_points + 1]
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y

    -- Calculate the length of the segment
    local length = math.sqrt(dx * dx + dy * dy)
    if length == 0 then length = 1 end -- Prevent division by zero

    -- Unit vector along the track
    local ux = dx / length
    local uy = dy / length

    -- Update the cart's direction (angle in radians)
    cart.direction = math.atan2(dy, dx)

    -- Calculate sine and cosine of the track angle
    local sin_theta = uy
    local cos_theta = ux

    -- Calculate acceleration due to gravity along the slope
    local gravity_component = gravity * sin_theta

    -- Calculate friction acceleration (opposes motion)
    local friction_acceleration = 0
    if cart.velocity ~= 0 then
        friction_acceleration = -friction_coefficient * gravity * cos_theta * (cart.velocity / math.abs(cart.velocity))
    else
        friction_acceleration = 0
    end

    -- Total acceleration
    cart.acceleration = gravity_component + friction_acceleration

    -- Update velocity
    cart.velocity = cart.velocity + cart.acceleration * dt

    -- Check for acceleration point at p1
    if p1.accelerate and cart.lastAccelIndex ~= segmentIndex then
        cart.velocity = cart.velocity + acceleration_value
        cart.lastAccelIndex = segmentIndex
        print('Cart accelerated at index', segmentIndex)
    end

    -- Check for deceleration point at p1
    if p1.decelerate and cart.lastBrakeIndex ~= segmentIndex then
        cart.velocity = cart.velocity - deceleration_value
        cart.lastBrakeIndex = segmentIndex
        print('Cart decelerated at index', segmentIndex)
    end

    -- Apply speed limits
    if cart.velocity > max_speed then
        cart.velocity = max_speed
    elseif cart.velocity < min_speed then
        cart.velocity = min_speed
    end

    -- Update position along the track
    cart.positionOnTrack = cart.positionOnTrack + cart.velocity * dt

    -- Loop the track if necessary
    if cart.positionOnTrack > totalTrackLength then
        cart.positionOnTrack = cart.positionOnTrack - totalTrackLength
        cart.lastFlipIndex = nil -- Reset flip tracking when looping
        cart.lastAccelIndex = nil
        cart.lastBrakeIndex = nil
    elseif cart.positionOnTrack < 0 then
        cart.positionOnTrack = cart.positionOnTrack + totalTrackLength
        cart.lastFlipIndex = nil -- Reset flip tracking when looping
        cart.lastAccelIndex = nil
        cart.lastBrakeIndex = nil
    end

    -- Check for flip point at p1
    if p1.flip and cart.lastFlipIndex ~= segmentIndex then
        cart.offsetDirection = cart.offsetDirection * -1
        cart.lastFlipIndex = segmentIndex
        print('Cart flipped at index', segmentIndex)
    end

    -- Calculate the normal vector
    local nx = uy
    local ny = -ux

    -- Apply offset along the normal vector
    local offset_distance = 10 -- Adjust this value as needed
    cart.x = cart.x + nx * offset_distance * cart.offsetDirection
    cart.y = cart.y + ny * offset_distance * cart.offsetDirection
end

-- Function to get the point on the track at a given distance
function getPointOnTrack(distance)
    local accumulated_distance = 0

    for i = 1, #coaster_track_points do
        local p1 = coaster_track_points[i]
        local p2 = coaster_track_points[i % #coaster_track_points + 1] -- Wrap around
        local segment_length = segment_lengths[i]

        if accumulated_distance + segment_length >= distance then
            local remaining_distance = distance - accumulated_distance
            local t = remaining_distance / segment_length

            -- Interpolate between p1 and p2
            local x = p1.x + (p2.x - p1.x) * t
            local y = p1.y + (p2.y - p1.y) * t
            return { x = x, y = y }, i, t
        else
            accumulated_distance = accumulated_distance + segment_length
        end
    end

    -- If distance exceeds total length, return to the start
    return coaster_track_points[1], 1, 0
end
