-- love2d_coaster_with_mass_and_train.lua

-- Constants
local CONSTANTS = {
    WINDOW = {
        WIDTH = 1800,
        HEIGHT = 1000
    },
    TRACK = {
        MIN_DISTANCE = 30,
        SUPPORT_SPACING = 100,
        MIN_BEAM_SPACING = 50
    },
    PHYSICS = {
        GRAVITY = 90.81,            -- pixels/s^2
        DEFAULT_MASS = 1,           -- arbitrary units
        FRICTION = 0.015,           -- friction coefficient
        MAX_SPEED = 15000,          -- pixels/s
        MIN_SPEED = -15000,         -- pixels/s
        ACCELERATION_FORCE = 10000, -- px/s^2
        DECELERATION_FORCE = 10000  -- px/s^2
    },
    TRAIN = {
        DEFAULT_CARTS = 13, -- Initial number of carts
        CART_SPACING = 25,  -- pixels
        FLIP_OFFSET = 10    -- pixels
    },
    HOIST = {
        SPEED = 100 -- pixels/s, adjust as needed
    }
}

-- Utility function to calculate distance between two points
local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- Track class
local Track = {}
Track.__index = Track

function Track.new(ground_level)
    local self = setmetatable({}, Track)
    self.points = {}                 -- Table to store track points
    self.support_beams = {}          -- Table to store support beam positions
    self.segment_lengths = {}        -- Table to store lengths of each segment
    self.total_length = 0            -- Total length of the track
    self.ground_level = ground_level -- Y-coordinate of the ground
    self.is_drawing = false          -- Flag to indicate if track is being drawn
    return self
end

function Track:addPoint(x, y)
    table.insert(self.points, {
        x = x,
        y = y,
        flip = false,
        accelerate = false,
        decelerate = false,
        hoist = false -- Added hoist field
    })
end

function Track:calculateLengths()
    self.total_length = 0
    self.segment_lengths = {}

    for i = 1, #self.points do
        local p1 = self.points[i]
        local p2 = self.points[(i % #self.points) + 1] -- Wrap around
        local seg_length = distance(p1.x, p1.y, p2.x, p2.y)
        self.segment_lengths[i] = seg_length
        self.total_length = self.total_length + seg_length
    end
end

function Track:calculateSupportBeams()
    self.support_beams = {}
    local initial_beam_positions = {}

    -- Total length of the track
    local total_length = self.total_length

    -- Place support beams at regular intervals
    local num_beams = math.floor(total_length / CONSTANTS.TRACK.SUPPORT_SPACING)
    for i = 1, num_beams do
        local target_distance = i * CONSTANTS.TRACK.SUPPORT_SPACING
        local accumulated_distance = 0

        -- Find the segment where the support beam falls
        for j = 1, #self.points do
            local seg_length = self.segment_lengths[j]
            if accumulated_distance + seg_length >= target_distance then
                local remaining_distance = target_distance - accumulated_distance
                local t = remaining_distance / seg_length

                -- Interpolate position
                local p1 = self.points[j]
                local p2 = self.points[(j % #self.points) + 1]
                local beam_x = p1.x + (p2.x - p1.x) * t
                local beam_y = p1.y + (p2.y - p1.y) * t

                table.insert(initial_beam_positions, { x = beam_x, y = beam_y })
                break
            else
                accumulated_distance = accumulated_distance + seg_length
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
            if dx < CONSTANTS.TRACK.MIN_BEAM_SPACING then
                table.insert(beam_group, initial_beam_positions[j])
                j = j + 1
            else
                break
            end
        end

        -- Select the beam with the highest point (smallest y)
        local highest_beam = beam_group[1]
        for _, beam in ipairs(beam_group) do
            if beam.y < highest_beam.y then
                highest_beam = beam
            end
        end
        table.insert(merged_beams, highest_beam)
        i = j
    end

    self.support_beams = merged_beams
end

function Track:findClosestPoint(x, y, threshold_sq)
    threshold_sq = threshold_sq or 100 ^ 2
    local min_dist_sq = math.huge
    local closest_point = nil
    local closest_index = nil

    for i, point in ipairs(self.points) do
        local dx = point.x - x
        local dy = point.y - y
        local dist_sq = dx * dx + dy * dy
        if dist_sq < min_dist_sq then
            min_dist_sq = dist_sq
            closest_point = point
            closest_index = i
        end
    end

    if min_dist_sq < threshold_sq then
        return closest_point, closest_index
    else
        return nil, nil
    end
end

-- Function to get a point on the track based on distance traveled
function Track:getPointOnTrack(distance)
    -- Handle cases where the track has no points
    if #self.points == 0 then
        print("Error: No points defined in the track.")
        return nil, nil, nil
    elseif #self.points == 1 then
        -- If there's only one point, return its position
        return self.points[1], 1, 0
    end

    -- Handle cases where total_length is zero
    if self.total_length == 0 then
        print("Error: Total track length is zero.")
        return nil, nil, nil
    end

    -- Wrap the distance around the track length
    if distance < 0 then
        distance = distance + math.ceil(math.abs(distance) / self.total_length) * self.total_length
    elseif distance > self.total_length then
        distance = distance % self.total_length
    end

    local accumulated_distance = 0

    for i = 1, #self.points do
        local p1 = self.points[i]
        local p2 = self.points[(i % #self.points) + 1] -- Wrap around to the first point
        local seg_length = self.segment_lengths[i]

        if accumulated_distance + seg_length >= distance then
            local remaining_distance = distance - accumulated_distance
            local t = remaining_distance / seg_length

            -- Interpolate between p1 and p2
            local x = p1.x + (p2.x - p1.x) * t
            local y = p1.y + (p2.y - p1.y) * t

            return { x = x, y = y }, i, t
        else
            accumulated_distance = accumulated_distance + seg_length
        end
    end

    -- Fallback in case of any unforeseen issues
    print("Warning: Distance exceeded track length. Returning the first point.")
    return self.points[1], 1, 0
end

-- Draw function for the Track class
function Track:draw()
    -- Draw the track
    if #self.points > 1 then
        for i = 1, #self.points do
            local p1 = self.points[i]
            local p2 = self.points[(i % #self.points) + 1]
            love.graphics.setColor(1, 1, 1) -- White
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)

            -- Draw points with color coding
            if p1.flip then
                love.graphics.setColor(0, 0, 1) -- Blue
            elseif p1.accelerate then
                love.graphics.setColor(0, 1, 0) -- Green
            elseif p1.decelerate then
                love.graphics.setColor(1, 0, 0) -- Red
            elseif p1.hoist then                -- Added hoist visualization
                love.graphics.setColor(1, 1, 0) -- Yellow
            else
                love.graphics.setColor(1, 1, 1) -- White
            end
            love.graphics.circle('fill', p1.x, p1.y, 2)
        end
    elseif #self.points == 1 then
        -- Single point
        local p1 = self.points[1]
        love.graphics.circle('fill', p1.x, p1.y, 3)
    end

    -- Draw support beams
    if #self.support_beams > 0 then
        love.graphics.setColor(0.25, 0.25, 0.25) -- Gray
        for _, beam in ipairs(self.support_beams) do
            -- Beam line
            love.graphics.line(beam.x, beam.y, beam.x, self.ground_level)
            -- Connection point
            love.graphics.setColor(0.37, 0.37, 0.37) -- Light Gray
            love.graphics.circle('fill', beam.x, beam.y, 5)
            love.graphics.setColor(0.25, 0.25, 0.25) -- Reset Gray
        end
    end
end

-- Cart class
local Cart = {}
Cart.__index = Cart

function Cart.new(initial_position, track)
    local self = setmetatable({}, Cart)
    self.track = track
    self.position_on_track = initial_position
    self.velocity = 0
    self.acceleration = 0
    self.x = 0
    self.y = 0
    self.direction = 0
    self.offset_direction = 1
    self.last_flip_index = nil
    self.last_accel_index = nil
    self.last_brake_index = nil
    self.last_hoist_index = nil -- Added hoist tracking
    self.prev_velocity = 0
    return self
end

function Cart:resetCartIndexCounters(segmentIndex)
    if segmentIndex ~= self.last_flip_index then
        self.last_flip_index = -1
    end
    if segmentIndex ~= self.last_accel_index then
        self.last_accel_index = -1
    end
    if segmentIndex ~= self.last_brake_index then
        self.last_brake_index = -1
    end
    if segmentIndex ~= self.last_hoist_index then -- Reset hoist index
        self.last_hoist_index = -1
    end
end

function Cart:update(dt, mass, constants)
    -- Get current position on the track
    local cartPos, segmentIndex, t = self.track:getPointOnTrack(self.position_on_track)

    if not cartPos then
        -- If cartPos is nil, skip updating position and direction
        return
    end

    self.x = cartPos.x
    self.y = cartPos.y

    -- Validate segmentIndex
    if segmentIndex > #self.track.points then
        segmentIndex = 1
    elseif segmentIndex < 1 then
        segmentIndex = 1
    end
    self:resetCartIndexCounters(segmentIndex)

    -- Update direction based on the current segment
    local p1 = self.track.points[segmentIndex]
    local p2 = self.track.points[(segmentIndex % #self.track.points) + 1]
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local seg_length = self.track.segment_lengths[segmentIndex]
    if seg_length == 0 then seg_length = 1 end -- Prevent division by zero

    local ux = dx / seg_length
    local uy = dy / seg_length

    self.direction = math.atan2(dy, dx)

    -- Calculate acceleration due to gravity along the slope
    local gravity_component = constants.PHYSICS.GRAVITY * uy

    -- Calculate friction acceleration (linear drag)
    local friction_acceleration = -constants.PHYSICS.FRICTION * self.velocity

    -- Total acceleration from gravity and friction
    self.acceleration = gravity_component + friction_acceleration

    -- Handle external forces (Acceleration and Deceleration)
    if p1.accelerate and self.last_accel_index ~= segmentIndex then
        local applied_acceleration = constants.PHYSICS.ACCELERATION_FORCE / mass
        self.acceleration = self.acceleration + applied_acceleration
        self.last_accel_index = segmentIndex
        print('Cart accelerated at index', segmentIndex)
    end

    if p1.decelerate and self.last_brake_index ~= segmentIndex then
        local applied_deceleration = constants.PHYSICS.DECELERATION_FORCE / mass
        self.acceleration = self.acceleration - applied_deceleration
        self.last_brake_index = segmentIndex
        print('Cart decelerated at index', segmentIndex)
    end

    -- Handle Hoist
    if p1.hoist and self.last_hoist_index ~= segmentIndex then
        self.velocity = constants.HOIST.SPEED -- Set velocity to hoist speed
        self.last_hoist_index = segmentIndex
        print('Hoist activated at index', segmentIndex, 'Setting velocity to', self.velocity)
    end

    -- Update velocity
    self.velocity = self.velocity + self.acceleration * dt

    -- Prevent velocity from reversing due to friction
    if self.velocity > 0 and self.acceleration < 0 and (self.velocity + self.acceleration * dt) < 0 then
        self.velocity = 0
    elseif self.velocity < 0 and self.acceleration > 0 and (self.velocity + self.acceleration * dt) > 0 then
        self.velocity = 0
    end

    -- Apply speed limits
    if self.velocity > constants.PHYSICS.MAX_SPEED then
        self.velocity = constants.PHYSICS.MAX_SPEED
    elseif self.velocity < constants.PHYSICS.MIN_SPEED then
        self.velocity = constants.PHYSICS.MIN_SPEED
    end

    -- Update position along the track
    self.position_on_track = (self.position_on_track + self.velocity * dt) % self.track.total_length

    -- Check for flip point at p1
    if p1.flip and self.last_flip_index ~= segmentIndex then
        self.offset_direction = self.offset_direction * -1
        self.last_flip_index = segmentIndex
        print('Cart flipped at index', segmentIndex)
    end

    -- Apply offset for visual flipping
    local nx = uy
    local ny = -ux
    self.x = self.x + nx * constants.TRAIN.FLIP_OFFSET * self.offset_direction
    self.y = self.y + ny * constants.TRAIN.FLIP_OFFSET * self.offset_direction

    -- Update previous velocity for direction reversal detection
    self.prev_velocity = self.velocity
end

function Cart:draw()
    love.graphics.setColor(1, 0, 0) -- Red
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.direction)
    love.graphics.rectangle('fill', -10, -5, 20, 10)
    love.graphics.pop()
end

-- Train class
local Train = {}
Train.__index = Train

function Train.new(track, num_carts)
    local self = setmetatable({}, Train)
    self.track = track
    self.carts = {}
    self.num_carts = num_carts or CONSTANTS.TRAIN.DEFAULT_CARTS
    self.mass = CONSTANTS.PHYSICS.DEFAULT_MASS
    self:initialize()
    return self
end

function Train:initialize()
    -- Ensure the track has at least two points
    if #self.track.points < 2 then
        print("Error: Not enough points to form a track.")
        self.carts = {}
        return
    end

    self.carts = {}
    for i = 1, self.num_carts do
        local initial_position = (0 - (i - 1) * CONSTANTS.TRAIN.CART_SPACING) % self.track.total_length
        local cart = Cart.new(initial_position, self.track)
        table.insert(self.carts, cart)
    end

    -- Initialize carts' positions and directions
    for i, cart in ipairs(self.carts) do
        cart:update(0, self.mass, CONSTANTS) -- Initialize positions without time delta
    end

    -- Set initial velocity for the lead cart
    if #self.carts > 0 then
        self.carts[1].velocity = 100 -- Starting velocity
        self.carts[1].prev_velocity = self.carts[1].velocity
    end
end

function Train:update(dt)
    if #self.carts == 0 then return end

    -- Update the lead cart
    local lead_cart = self.carts[1]
    lead_cart:update(dt, self.mass, CONSTANTS)

    -- Check for direction reversal
    if (lead_cart.velocity > 0 and lead_cart.prev_velocity < 0) or
        (lead_cart.velocity < 0 and lead_cart.prev_velocity > 0) then
        self:reverseDirection()
    end

    -- Update following carts based on the lead cart's position
    for i = 2, #self.carts do
        local desired_position = (self.carts[1].position_on_track - (i - 1) * CONSTANTS.TRAIN.CART_SPACING) %
            self.track.total_length
        local cart = self.carts[i]
        cart.position_on_track = desired_position
        cart:update(dt, self.mass, CONSTANTS)
    end
end

function Train:reverseDirection()
    for _, cart in ipairs(self.carts) do
        cart.velocity = -cart.velocity
    end
    print("Train direction reversed!")
end

function Train:draw()
    for _, cart in ipairs(self.carts) do
        cart:draw()
    end

    -- Display lead cart information
    if #self.carts > 0 then
        local lead_cart = self.carts[1]
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.print(string.format("Speed: %.2f px/s", lead_cart.velocity), 10, 10)
        love.graphics.print(string.format("Acceleration: %.2f px/s²", lead_cart.acceleration), 10, 30)
        love.graphics.print(string.format("Mass: %.2f", self.mass), 10, 50)
    end
end

-- GameState
local GameState = {
    track = nil,
    train = nil,
    ground_level = 0
}

-- Event Handlers

function love.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        -- Start drawing track
        GameState.track.points = {}
        GameState.track.support_beams = {}
        GameState.train.carts = {}
        GameState.train:initialize()
        GameState.track:addPoint(x, y)
        GameState.track.is_drawing = true
        print('Track creation started!')
    end
end

function love.mousemoved(x, y, dx, dy)
    if GameState.track.is_drawing then
        local last_point = GameState.track.points[#GameState.track.points]
        local dist = distance(last_point.x, last_point.y, x, y)
        if dist >= CONSTANTS.TRACK.MIN_DISTANCE then
            GameState.track:addPoint(x, y)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and GameState.track.is_drawing then
        GameState.track.is_drawing = false
        print('Track creation completed with', #GameState.track.points, 'points.')
        GameState.track:calculateLengths()
        GameState.track:calculateSupportBeams()
        GameState.train:initialize()
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'f' then
        -- Toggle flip at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.flip = not closest_point.flip
            print(string.format("Flip point at index %d set to %s", index, tostring(closest_point.flip)))
        end
    elseif key == 'a' then
        -- Toggle acceleration at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.accelerate = not closest_point.accelerate
            if closest_point.accelerate then
                closest_point.decelerate = false -- Ensure deceleration is false
            end
            print(string.format("Acceleration point at index %d set to %s", index, tostring(closest_point.accelerate)))
        end
    elseif key == 'd' then
        -- Toggle deceleration at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.decelerate = not closest_point.decelerate
            if closest_point.decelerate then
                closest_point.accelerate = false -- Ensure acceleration is false
            end
            print(string.format("Deceleration point at index %d set to %s", index, tostring(closest_point.decelerate)))
        end
    elseif key == 'h' then
        -- Toggle hoist at the closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.hoist = not closest_point.hoist
            print(string.format("Hoist point at index %d set to %s", index, tostring(closest_point.hoist)))
        end
    elseif key == 'up' then
        -- Increase mass
        GameState.train.mass = GameState.train.mass + 0.5
        print("Mass increased to", GameState.train.mass)
    elseif key == 'down' then
        -- Decrease mass, ensuring it doesn't go below a minimum value
        GameState.train.mass = math.max(GameState.train.mass - 0.5, 0.1)
        print("Mass decreased to", GameState.train.mass)
    end
end

-- Initialize GameState in love.load
function love.load()
    love.window.setMode(CONSTANTS.WINDOW.WIDTH, CONSTANTS.WINDOW.HEIGHT)
    GameState.ground_level = CONSTANTS.WINDOW.HEIGHT - 50
    GameState.track = Track.new(GameState.ground_level)
    GameState.train = Train.new(GameState.track, CONSTANTS.TRAIN.DEFAULT_CARTS)
end

-- Update GameState in love.update
function love.update(dt)
    if GameState.train and GameState.track then
        GameState.train:update(dt)
    end
end

-- Draw GameState in love.draw
function love.draw()
    if GameState.track then
        GameState.track:draw()
    end

    if GameState.train then
        GameState.train:draw()
    end

    -- Draw ground
    love.graphics.setColor(0, 1, 0) -- Green
    love.graphics.line(0, GameState.ground_level, CONSTANTS.WINDOW.WIDTH, GameState.ground_level)
    love.graphics.setColor(1, 1, 1) -- Reset color
end
