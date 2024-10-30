-- love2d_coaster_with_mass_and_train.lua

function love.load()
    -- Set up the window
    success = love.window.setMode(1800, 1000)

    -- Initialize tables and variables
    coaster_track_points = {}                     -- Table to store the track points
    support_beam_positions = {}                   -- Table to store support beam positions
    mousepressed = false
    min_distance = 30                             -- Minimum distance between points
    support_spacing = 100                         -- Distance between support beams along the track
    min_horizontal_spacing = 50                   -- Minimum horizontal spacing between beams
    ground_level = love.graphics.getHeight() - 50 -- Define where the ground is

    -- Physical constants
    gravity = 90.81              -- Gravitational acceleration (pixels/s^2)
    mass = 1                     -- Mass of the carts (arbitrary units)
    friction_coefficient = 0.015 -- Friction coefficient for realistic deceleration
    max_speed = 15000            -- Maximum speed of the cart (pixels/s)
    min_speed = -15000           -- Minimum speed (to prevent negative speeds)

    -- Cart Train Variables
    carts = {}              -- Table to store multiple carts
    number_of_carts = 13    -- Initial number of carts in the train
    cart_spacing = 25       -- Fixed distance between each cart (pixels)
    flip_offset = 10        -- Adjustable flip offset for visual flipping
    cartInitialized = false -- Flag to check if carts are initialized

    -- Define external forces
    acceleration_force = 10000 -- Adjusted for balanced acceleration
    deceleration_force = 10000 -- Adjusted for balanced deceleration

    -- Initialize segment_lengths globally
    segment_lengths = {}
    totalTrackLength = 0
end

function love.update(dt)
    if cartInitialized then
        updateTrainPosition(dt)
    end
end

function love.draw()
    -- Draw the track
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
            love.graphics.circle('fill', p1.x, p1.y, 2)
        end
    elseif #coaster_track_points == 1 then
        -- If there's only one point, draw it
        local p1 = coaster_track_points[1]
        love.graphics.circle('fill', p1.x, p1.y, 3)
    end

    -- Draw support beams
    if #support_beam_positions > 0 then
        love.graphics.setColor(0.25, 0.25, 0.25) -- Gray color for beams
        for _, beam in ipairs(support_beam_positions) do
            -- Draw the beam (line from track to ground)
            love.graphics.line(beam.x, beam.y, beam.x, ground_level)
            -- Draw gray circle at the connection point
            love.graphics.setColor(0.37, 0.37, 0.37) -- Light Gray for connection
            love.graphics.circle('fill', beam.x, beam.y, 5)
            love.graphics.setColor(0.25, 0.25, 0.25) -- Reset color for beams
        end
    end

    -- Draw the carts
    if cartInitialized then
        for i, cart in ipairs(carts) do
            love.graphics.setColor(1, 0, 0) -- Red color for the carts
            love.graphics.push()
            love.graphics.translate(cart.x, cart.y)
            love.graphics.rotate(cart.direction)
            -- Draw the cart as a rectangle
            love.graphics.rectangle('fill', -10, -5, 20, 10)
            love.graphics.pop()
        end

        -- Display lead cart speed, acceleration, and mass
        local lead_cart = carts[1]
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Speed: %.2f px/s", lead_cart.velocity), 10, 10)
        love.graphics.print(string.format("Acceleration: %.2f px/s²", lead_cart.acceleration), 10, 30)
        love.graphics.print(string.format("Mass: %.2f", mass), 10, 50)
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
        carts = {}
        cartInitialized = false
        print('Track creation started!')
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
        print('Track creation completed with', #coaster_track_points, 'points.')

        -- After completing the track, calculate total track lengths first
        calculateTrackLengths()

        -- Then calculate support beam positions using the populated segment_lengths
        calculateSupportBeams()

        -- Initialize the train of carts
        initializeTrain()
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
    elseif key == 'up' then
        -- Increase mass
        mass = mass + 0.5
        print("Mass increased to", mass)
    elseif key == 'down' then
        -- Decrease mass, ensuring it doesn't go below a minimum value
        mass = math.max(mass - 0.5, 0.1) -- Prevent mass from being zero or negative
        print("Mass decreased to", mass)
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

-- Function to calculate total track length and segment lengths
function calculateTrackLengths()
    totalTrackLength = 0
    segment_lengths = {} -- Ensure this is a global table

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

-- Function to calculate support beam positions along the track
function calculateSupportBeams()
    support_beam_positions = {}
    local initial_beam_positions = {}

    -- Ensure segment_lengths is already calculated
    if not segment_lengths or #segment_lengths == 0 then
        print("Error: segment_lengths is not calculated before support beams.")
        return
    end

    -- Total length of the track is already calculated
    local total_length = totalTrackLength

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

-- Function to initialize the train after track creation
function initializeTrain()
    if #coaster_track_points < 2 then
        print("Error: Not enough points to form a track.")
        cartInitialized = false
        return
    end

    carts = {}
    for i = 1, number_of_carts do
        local cart = {
            positionOnTrack = 0,  -- Will set properly below
            velocity = 0,         -- Velocity of the cart (pixels/s)
            acceleration = 0,     -- Acceleration of the cart (pixels/s^2)
            x = 0,                -- Current x-coordinate
            y = 0,                -- Current y-coordinate
            direction = 0,        -- Direction angle in radians
            offsetDirection = 1,  -- 1 for above the track, -1 for below
            lastFlipIndex = nil,  -- To prevent multiple flips at the same flip point
            lastAccelIndex = nil, -- To prevent multiple accelerations at the same point
            lastBrakeIndex = nil, -- To prevent multiple brakes at the same point
            prev_velocity = 0,    -- To track previous velocity for reversal detection
        }
        -- Position each cart based on its spacing behind the lead cart
        cart.positionOnTrack = (0 - (i - 1) * cart_spacing) % totalTrackLength
        table.insert(carts, cart)
    end

    -- Initialize all carts' positions and directions
    for i, cart in ipairs(carts) do
        local pos, segIndex, t = getPointOnTrack(cart.positionOnTrack)
        cart.x = pos.x
        cart.y = pos.y

        -- Calculate initial direction based on the segment
        local p1 = coaster_track_points[segIndex]
        local p2 = coaster_track_points[segIndex % #coaster_track_points + 1]
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        cart.direction = math.atan2(dy, dx)
        cart.prev_velocity = cart.velocity
    end

    -- Set initial velocity for the lead cart
    carts[1].velocity = 100 -- Starting velocity
    carts[1].prev_velocity = carts[1].velocity

    cartInitialized = true
end

-- Function to update the entire train's position
function updateTrainPosition(dt)
    -- Update the lead cart (first cart)
    local lead_cart = carts[1]
    updateSingleCart(lead_cart, dt)

    -- Check for reversal based on lead cart's velocity
    if (lead_cart.velocity > 0 and lead_cart.prev_velocity < 0) or
        (lead_cart.velocity < 0 and lead_cart.prev_velocity > 0) then
        reverseTrainDirection()
    end
    lead_cart.prev_velocity = lead_cart.velocity

    -- Update following carts based on lead cart's position
    for i = 2, #carts do
        local desired_position = (carts[1].positionOnTrack - (i - 1) * cart_spacing) % totalTrackLength
        local cart = carts[i]
        cart.positionOnTrack = desired_position

        -- Get the current position on the track
        local pos, segIndex, t = getPointOnTrack(cart.positionOnTrack)
        cart.x = pos.x
        cart.y = pos.y

        -- Update direction based on the current segment
        local p1 = coaster_track_points[segIndex]
        local p2 = coaster_track_points[segIndex % #coaster_track_points + 1]
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        cart.direction = math.atan2(dy, dx)

        -- Handle flipping
        if p1.flip and cart.lastFlipIndex ~= segIndex then
            cart.offsetDirection = cart.offsetDirection * -1
            cart.lastFlipIndex = segIndex
            print('Cart', i, 'flipped at index', segIndex)
        end

        -- Apply offset for visual flipping
        local angle = math.atan2(dy, dx)
        local sin_theta = math.sin(angle)
        local cos_theta = math.cos(angle)
        local nx = sin_theta
        local ny = -cos_theta

        cart.x = pos.x + nx * flip_offset * cart.offsetDirection
        cart.y = pos.y + ny * flip_offset * cart.offsetDirection
    end
end

function resetCartIndexCounters(cart, segmentIndex)
    if segmentIndex ~= cart.lastFlipIndex then
        cart.lastFlipIndex = -1
    end
    if segmentIndex ~= cart.lastAccelIndex then
        cart.lastAccelIndex = -1
    end
    if segmentIndex ~= cart.lastBrakeIndex then
        cart.lastBrakeIndex = -1
    end
end

-- Function to update a single cart (lead cart)
function updateSingleCart(cart, dt)
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

    resetCartIndexCounters(cart, segmentIndex)
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

    -- Calculate friction acceleration (linear drag)
    local friction_acceleration = -friction_coefficient * cart.velocity

    -- Total acceleration from gravity and friction
    cart.acceleration = gravity_component + friction_acceleration

    -- Handle external forces (Acceleration and Deceleration)
    if p1.accelerate and cart.lastAccelIndex ~= segmentIndex then
        -- Apply external acceleration force
        local applied_acceleration = acceleration_force / mass
        cart.acceleration = cart.acceleration + applied_acceleration
        cart.lastAccelIndex = segmentIndex
        print('Cart accelerated at index', segmentIndex)
    end

    if p1.decelerate and cart.lastBrakeIndex ~= segmentIndex then
        -- Apply external deceleration force
        local applied_deceleration = deceleration_force / mass
        cart.acceleration = cart.acceleration - applied_deceleration
        cart.lastBrakeIndex = segmentIndex
        print('Cart decelerated at index', segmentIndex)
    end

    -- Update velocity based on total acceleration
    cart.velocity = cart.velocity + cart.acceleration * dt

    -- Prevent velocity from reversing due to friction
    if cart.velocity > 0 and cart.acceleration < 0 and (cart.velocity + cart.acceleration * dt) < 0 then
        cart.velocity = 0
    elseif cart.velocity < 0 and cart.acceleration > 0 and (cart.velocity + cart.acceleration * dt) > 0 then
        cart.velocity = 0
    end

    -- Apply speed limits
    if cart.velocity > max_speed then
        cart.velocity = max_speed
    elseif cart.velocity < min_speed then
        cart.velocity = min_speed
    end

    -- Update position along the track
    cart.positionOnTrack = (cart.positionOnTrack + cart.velocity * dt) % totalTrackLength

    -- Check for flip point at p1
    if p1.flip and cart.lastFlipIndex ~= segmentIndex then
        cart.offsetDirection = cart.offsetDirection * -1
        cart.lastFlipIndex = segmentIndex
        print('Cart flipped at index', segmentIndex)
    end

    -- Calculate the normal vector
    local nx = uy
    local ny = -ux

    -- Apply offset along the normal vector for visual flipping
    cart.x = cart.x + nx * flip_offset * cart.offsetDirection
    cart.y = cart.y + ny * flip_offset * cart.offsetDirection
end

-- Function to reverse the direction of all carts in the train
function reverseTrainDirection()
    for i, cart in ipairs(carts) do
        cart.velocity = -cart.velocity
    end
    print("Train direction reversed!")
end

-- Function to get the point on the track at a given distance
function getPointOnTrack(distance)
    -- Handle negative distances by wrapping around the track
    if distance < 0 then
        distance = distance + math.ceil(math.abs(distance) / totalTrackLength) * totalTrackLength
    elseif distance > totalTrackLength then
        distance = distance % totalTrackLength
    end

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
