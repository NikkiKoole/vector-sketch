-- love2d_coaster_with_mass_and_train_and_characters.lua

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
        -- GRAVITY = 90.81, -- Replaced by GRAVITY_VEC
        GRAVITY_VEC = { x = 0, y = 90.81 }, -- pixels/s^2 (Using vector form now)
        DEFAULT_MASS = 1,                   -- arbitrary units
        FRICTION = 0.015,                   -- friction coefficient
        MAX_SPEED = 15000,                  -- pixels/s
        MIN_SPEED = -15000,                 -- pixels/s
        ACCELERATION_FORCE = 10000,         -- px/s^2 applied force (mass independent)
        DECELERATION_FORCE = 10000          -- px/s^2 applied force (mass independent)
    },
    TRAIN = {
        DEFAULT_CARTS = 13, -- Initial number of carts
        CART_SPACING = 25,  -- pixels
        FLIP_OFFSET = 10    -- pixels
    },
    HOIST = {
        SPEED = 100 -- pixels/s, adjust as needed
    },
    CHARACTER = {
        TORSO_WIDTH = 8,
        TORSO_HEIGHT = 12,
        HEAD_RADIUS = 4,
        UPPER_ARM_LENGTH = 8,
        LOWER_ARM_LENGTH = 7,
        ARM_SPRING_K = 50,     -- Stiffness of the arm joints (how quickly they react)
        ARM_DAMPING_D = 5,     -- Damping factor (how much they resist swinging)
        SHOULDER_OFFSET_Y = -4 -- How far down from the torso top the shoulders are
    }
}

-- Utility function to calculate distance between two points
local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- Helper function to normalize angles between -pi and pi
local function normalizeAngle(angle)
    return math.atan2(math.sin(angle), math.cos(angle))
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
    local point = {
        x = x,
        y = y,
        flip = false,
        accelerate = false,
        decelerate = false,
        hoist = false -- Added hoist field
    }
    table.insert(self.points, point)
    return point
end

function Track:calculateLengths()
    self.total_length = 0
    self.segment_lengths = {}

    if #self.points < 2 then
        self.total_length = 0
        return
    end

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

    if self.total_length == 0 then return end -- No supports if no length

    -- Place support beams at regular intervals
    local num_beams = math.floor(self.total_length / CONSTANTS.TRACK.SUPPORT_SPACING)
    if num_beams == 0 and self.total_length > 0 then num_beams = 1 end -- Ensure at least one if track exists

    for i = 1, num_beams do
        local target_distance = i * CONSTANTS.TRACK.SUPPORT_SPACING
        -- Ensure target distance doesn't exceed total length slightly due to calculation
        if target_distance > self.total_length then target_distance = self.total_length end

        local accumulated_distance = 0

        -- Find the segment where the support beam falls
        for j = 1, #self.points do
            local seg_length = self.segment_lengths[j]
            if seg_length > 0 and accumulated_distance + seg_length >= target_distance then
                local remaining_distance = target_distance - accumulated_distance
                local t = remaining_distance / seg_length
                t = math.max(0, math.min(1, t)) -- Clamp t between 0 and 1

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
            -- Safety break if we somehow exceed segments (shouldn't happen if total_length is correct)
            if j == #self.points and accumulated_distance < target_distance then
                -- Place beam at the end if we run out of segments
                local last_point = self.points[#self.points]
                table.insert(initial_beam_positions, { x = last_point.x, y = last_point.y })
                break
            end
        end
    end

    -- Merge beams that are too close horizontally
    if #initial_beam_positions == 0 then return end                         -- Exit if no initial beams calculated

    table.sort(initial_beam_positions, function(a, b) return a.x < b.x end) -- Sort by x for merging

    local merged_beams = {}
    local current_group = { initial_beam_positions[1] }
    local group_start_x = initial_beam_positions[1].x

    for i = 2, #initial_beam_positions do
        local beam = initial_beam_positions[i]
        if beam.x - group_start_x < CONSTANTS.TRACK.MIN_BEAM_SPACING then
            table.insert(current_group, beam)
        else
            -- Finalize the previous group
            local highest_beam = current_group[1]
            for k = 2, #current_group do
                if current_group[k].y < highest_beam.y then
                    highest_beam = current_group[k]
                end
            end
            table.insert(merged_beams, highest_beam)

            -- Start a new group
            current_group = { beam }
            group_start_x = beam.x
        end
    end

    -- Finalize the last group
    local highest_beam = current_group[1]
    for k = 2, #current_group do
        if current_group[k].y < highest_beam.y then
            highest_beam = current_group[k]
        end
    end
    table.insert(merged_beams, highest_beam)


    self.support_beams = merged_beams
end

function Track:findClosestPoint(x, y, threshold_sq)
    threshold_sq = threshold_sq or (100 ^ 2)
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
function Track:getPointOnTrack(distance_along)
    -- Handle cases where the track has no points or length
    if #self.points < 2 or self.total_length == 0 then
        if #self.points == 1 then return self.points[1], 1, 0 end -- Return single point if exists
        -- print("Error: Not enough points or zero length in the track.")
        return nil, nil, nil
    end

    -- Wrap the distance around the track length
    local wrapped_distance = distance_along % self.total_length
    if wrapped_distance < 0 then
        wrapped_distance = wrapped_distance + self.total_length
    end

    local accumulated_distance = 0

    for i = 1, #self.points do
        local p1 = self.points[i]
        local p2 = self.points[(i % #self.points) + 1] -- Wrap around to the first point
        local seg_length = self.segment_lengths[i]

        if seg_length > 0 then -- Avoid division by zero or issues with zero-length segments
            if accumulated_distance + seg_length >= wrapped_distance or i == #self.points then
                -- Check 'i == #self.points' as a fallback for the last segment due to potential float errors
                local remaining_distance = wrapped_distance - accumulated_distance
                local t = remaining_distance / seg_length
                t = math.max(0, math.min(1, t)) -- Clamp t strictly between 0 and 1

                -- Interpolate between p1 and p2
                local x = p1.x + (p2.x - p1.x) * t
                local y = p1.y + (p2.y - p1.y) * t

                return { x = x, y = y }, i, t
            else
                accumulated_distance = accumulated_distance + seg_length
            end
        elseif wrapped_distance == 0 and i == 1 then -- Handle start point exactly
            return { x = p1.x, y = p1.y }, 1, 0
        end
    end

    -- Fallback: should ideally not be reached if logic above is sound
    print("Warning: getPointOnTrack fallback triggered. Returning first point.")
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
            love.graphics.setLineWidth(2)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            love.graphics.setLineWidth(1)

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
            love.graphics.circle('fill', p1.x, p1.y, 4)
        end
        -- Draw last point properties (since loop ends before drawing it)
        local p_last = self.points[#self.points]
        if p_last.flip then
            love.graphics.setColor(0, 0, 1)
        elseif p_last.accelerate then
            love.graphics.setColor(0, 1, 0)
        elseif p_last.decelerate then
            love.graphics.setColor(1, 0, 0)
        elseif p_last.hoist then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.circle('fill', p_last.x, p_last.y, 4)
    elseif #self.points == 1 then
        -- Single point
        local p1 = self.points[1]
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('fill', p1.x, p1.y, 4)
    end

    -- Draw support beams
    if #self.support_beams > 0 then
        love.graphics.setColor(0.5, 0.5, 0.5) -- Gray for beams
        for _, beam in ipairs(self.support_beams) do
            -- Beam line
            love.graphics.setLineWidth(3)
            love.graphics.line(beam.x, beam.y, beam.x, self.ground_level)
            love.graphics.setLineWidth(1)
            -- Connection point
            love.graphics.setColor(0.6, 0.6, 0.6) -- Lighter Gray
            love.graphics.circle('fill', beam.x, beam.y, 6)
            love.graphics.setColor(0.5, 0.5, 0.5) -- Reset Gray
        end
    end
end

-- Character class
local Character = {}
Character.__index = Character

function Character.new(x, y)
    local self = setmetatable({}, Character)
    self.x = x -- Center position relative to cart center
    self.y = y

    -- Left Arm
    self.left_shoulder = { angle = math.pi / 2, ang_vel = 0 } -- Start hanging down relative to cart (pi/2 is down)
    self.left_elbow = { angle = 0, ang_vel = 0 }              -- Start straight relative to upper arm

    -- Right Arm
    self.right_shoulder = { angle = math.pi / 2, ang_vel = 0 } -- Start hanging down relative to cart
    self.right_elbow = { angle = 0, ang_vel = 0 }              -- Start straight relative to upper arm

    return self
end

function Character:update(dt, apparent_gravity_x, apparent_gravity_y, cart_angle)
    -- If apparent gravity is zero vector, default to pointing down (relative to world)
    if apparent_gravity_x == 0 and apparent_gravity_y == 0 then
        apparent_gravity_y = 1 -- Avoid atan2(0,0), point down
    end

    -- Target angle based on apparent gravity (relative to world horizontal axis)
    local target_angle_world = math.atan2(apparent_gravity_y, apparent_gravity_x)

    -- Calculate the target angle relative to the cart's current orientation (cart's local vertical)
    -- Cart angle is relative to world horizontal. We want target relative to cart's "up" which is cart_angle - pi/2
    local target_angle_relative_to_cart = normalizeAngle(target_angle_world - cart_angle)


    -- Define constants locally for readability
    local K = CONSTANTS.CHARACTER.ARM_SPRING_K
    local D = CONSTANTS.CHARACTER.ARM_DAMPING_D

    -- Update Left Shoulder (damped spring towards target angle relative to cart)
    local ls_angle_diff = normalizeAngle(target_angle_relative_to_cart - self.left_shoulder.angle)
    local ls_accel = K * ls_angle_diff - D * self.left_shoulder.ang_vel
    self.left_shoulder.ang_vel = self.left_shoulder.ang_vel + ls_accel * dt
    -- Simple velocity limit to prevent instability
    self.left_shoulder.ang_vel = math.max(-20, math.min(20, self.left_shoulder.ang_vel))
    self.left_shoulder.angle = normalizeAngle(self.left_shoulder.angle + self.left_shoulder.ang_vel * dt)


    -- Update Left Elbow (make elbow try to hang straight down relative to upper arm's direction, target angle = 0)
    local le_target_angle_relative = 0 -- Target angle relative to upper arm direction
    local le_angle_diff = normalizeAngle(le_target_angle_relative - self.left_elbow.angle)
    local le_accel = K * le_angle_diff - D * self.left_elbow.ang_vel
    self.left_elbow.ang_vel = self.left_elbow.ang_vel + le_accel * dt
    self.left_elbow.ang_vel = math.max(-20, math.min(20, self.left_elbow.ang_vel))
    self.left_elbow.angle = normalizeAngle(self.left_elbow.angle + self.left_elbow.ang_vel * dt)

    -- Update Right Shoulder (mirror of left logic)
    local rs_angle_diff = normalizeAngle(target_angle_relative_to_cart - self.right_shoulder.angle)
    local rs_accel = K * rs_angle_diff - D * self.right_shoulder.ang_vel
    self.right_shoulder.ang_vel = self.right_shoulder.ang_vel + rs_accel * dt
    self.right_shoulder.ang_vel = math.max(-20, math.min(20, self.right_shoulder.ang_vel))
    self.right_shoulder.angle = normalizeAngle(self.right_shoulder.angle + self.right_shoulder.ang_vel * dt)

    -- Update Right Elbow (mirror of left logic)
    local re_target_angle_relative = 0 -- Target angle relative to upper arm direction
    local re_angle_diff = normalizeAngle(re_target_angle_relative - self.right_elbow.angle)
    local re_accel = K * re_angle_diff - D * self.right_elbow.ang_vel
    self.right_elbow.ang_vel = self.right_elbow.ang_vel + re_accel * dt
    self.right_elbow.ang_vel = math.max(-20, math.min(20, self.right_elbow.ang_vel))
    self.right_elbow.angle = normalizeAngle(self.right_elbow.angle + self.right_elbow.ang_vel * dt)
end

function Character:draw()
    -- Constants for easier access
    local TORSO_W = CONSTANTS.CHARACTER.TORSO_WIDTH
    local TORSO_H = CONSTANTS.CHARACTER.TORSO_HEIGHT
    local HEAD_R = CONSTANTS.CHARACTER.HEAD_RADIUS
    local UPPER_ARM = CONSTANTS.CHARACTER.UPPER_ARM_LENGTH
    local LOWER_ARM = CONSTANTS.CHARACTER.LOWER_ARM_LENGTH
    local SHOULDER_OFFSET_Y = CONSTANTS.CHARACTER.SHOULDER_OFFSET_Y

    love.graphics.setColor(0.8, 0.8, 1) -- Light blue for character body

    -- Draw Torso (centered at self.x, self.y - adjusted because rect draws from top-left)
    local torso_top_y = self.y - TORSO_H / 2
    love.graphics.rectangle('fill', self.x - TORSO_W / 2, torso_top_y, TORSO_W, TORSO_H)

    -- Draw Head
    local head_y = torso_top_y - HEAD_R
    love.graphics.circle('fill', self.x, head_y, HEAD_R)

    -- Shoulder positions (relative to character center self.x, self.y)
    local shoulder_y = torso_top_y + SHOULDER_OFFSET_Y
    local left_shoulder_x = self.x - TORSO_W / 2
    local right_shoulder_x = self.x + TORSO_W / 2

    love.graphics.setColor(0.7, 0.7, 0.9) -- Slightly different color for arms
    love.graphics.setLineWidth(2)

    -- Draw Left Arm
    local left_upper_arm_angle = self.left_shoulder.angle
    local left_elbow_x = left_shoulder_x + math.cos(left_upper_arm_angle) * UPPER_ARM
    local left_elbow_y = shoulder_y + math.sin(left_upper_arm_angle) * UPPER_ARM

    local left_lower_arm_angle = left_upper_arm_angle + self.left_elbow.angle
    local left_hand_x = left_elbow_x + math.cos(left_lower_arm_angle) * LOWER_ARM
    local left_hand_y = left_elbow_y + math.sin(left_lower_arm_angle) * LOWER_ARM

    love.graphics.line(left_shoulder_x, shoulder_y, left_elbow_x, left_elbow_y)
    love.graphics.line(left_elbow_x, left_elbow_y, left_hand_x, left_hand_y)

    -- Draw Right Arm
    local right_upper_arm_angle = self.right_shoulder.angle
    local right_elbow_x = right_shoulder_x + math.cos(right_upper_arm_angle) * UPPER_ARM
    local right_elbow_y = shoulder_y + math.sin(right_upper_arm_angle) * UPPER_ARM

    local right_lower_arm_angle = right_upper_arm_angle + self.right_elbow.angle
    local right_hand_x = right_elbow_x + math.cos(right_lower_arm_angle) * LOWER_ARM
    local right_hand_y = right_elbow_y + math.sin(right_lower_arm_angle) * LOWER_ARM

    love.graphics.line(right_shoulder_x, shoulder_y, right_elbow_x, right_elbow_y)
    love.graphics.line(right_elbow_x, right_elbow_y, right_hand_x, right_hand_y)

    love.graphics.setLineWidth(1)   -- Reset line width
    love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Cart class
local Cart = {}
Cart.__index = Cart

function Cart.new(initial_position_on_track, track)
    local self = setmetatable({}, Cart)
    self.track = track
    self.position_on_track = initial_position_on_track -- Distance along the track
    self.velocity = 0                                  -- Scalar velocity along the track
    self.acceleration = 0                              -- Scalar acceleration along the track

    -- World position and velocity/acceleration components (for character physics)
    self.x = 0
    self.y = 0
    self.prev_x = 0
    self.prev_y = 0
    self.vx = 0
    self.vy = 0
    self.prev_vx = 0
    self.prev_vy = 0
    self.accel_x = 0          -- Cart's world acceleration X
    self.accel_y = 0          -- Cart's world acceleration Y

    self.direction = 0        -- Angle of the cart tangent to the track
    self.offset_direction = 1 -- For visual flip
    self.last_flip_index = -1 -- Use -1 to indicate never triggered
    self.last_accel_index = -1
    self.last_brake_index = -1
    self.last_hoist_index = -1
    self.prev_velocity = 0 -- Previous scalar velocity for reversal check

    -- Visual position (handles flip offset)
    self.visual_x = 0
    self.visual_y = 0

    -- Create the character for this cart
    self.character = Character.new(0, -CONSTANTS.CHARACTER.TORSO_HEIGHT / 4) -- Position character slightly above cart center

    return self
end

function Cart:resetCartIndexCounters(segmentIndex)
    -- Reset flags if the cart is no longer considered "on" the segment start point
    -- This prevents flags from being reset prematurely if a cart moves very slowly
    -- A small tolerance might be needed, but for now, reset if index changes.
    if segmentIndex ~= self.last_flip_index then self.last_flip_index = -1 end
    if segmentIndex ~= self.last_accel_index then self.last_accel_index = -1 end
    if segmentIndex ~= self.last_brake_index then self.last_brake_index = -1 end
    if segmentIndex ~= self.last_hoist_index then self.last_hoist_index = -1 end
end

function Cart:update(dt, mass, constants)
    -- Store previous world state for calculating current acceleration
    self.prev_x = self.x
    self.prev_y = self.y
    self.prev_vx = self.vx
    self.prev_vy = self.vy

    -- Get current raw position on the track based on scalar distance
    local cartPosData, segmentIndex, t = self.track:getPointOnTrack(self.position_on_track)

    if not cartPosData then return end -- Cannot update if position invalid

    -- Update raw world position
    self.x = cartPosData.x
    self.y = cartPosData.y

    -- Calculate current world velocity vector (approximation from position change)
    if dt > 0 then
        self.vx = (self.x - self.prev_x) / dt
        self.vy = (self.y - self.prev_y) / dt
    else
        self.vx = 0
        self.vy = 0
    end

    -- Calculate current world acceleration vector (approximation from velocity change)
    if dt > 0 then
        self.accel_x = (self.vx - self.prev_vx) / dt
        self.accel_y = (self.vy - self.prev_vy) / dt
    else
        self.accel_x = 0
        self.accel_y = 0
    end

    -- Validate segmentIndex and reset trigger flags if segment changed
    if segmentIndex > #self.track.points or segmentIndex < 1 then segmentIndex = 1 end
    self:resetCartIndexCounters(segmentIndex)

    -- Update direction based on the current segment
    local p1 = self.track.points[segmentIndex]
    local p2 = self.track.points[(segmentIndex % #self.track.points) + 1]
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local seg_length = self.track.segment_lengths[segmentIndex] or 0
    local ux, uy
    if seg_length > 0 then
        ux = dx / seg_length
        uy = dy / seg_length
        self.direction = math.atan2(dy, dx)
    else
        -- Handle zero-length segment (stay pointing based on previous direction or default?)
        -- self.direction remains unchanged, or set to 0? Let's keep it.
        ux = 0
        uy = 0
        -- If needed, find direction from next non-zero segment? For now, keep last direction.
    end

    -- === Physics Calculation (Scalar Velocity along Track) ===

    -- Calculate acceleration due to gravity along the slope (using the normalized segment direction 'uy')
    local gravity_component = constants.PHYSICS.GRAVITY_VEC.y * uy

    -- Calculate friction acceleration (linear drag model)
    local friction_acceleration = -constants.PHYSICS.FRICTION * self.velocity

    -- Base acceleration from gravity and friction
    self.acceleration = gravity_component + friction_acceleration

    -- Handle external forces (Acceleration/Deceleration points)
    local external_force_accel = 0
    if p1.accelerate and self.last_accel_index ~= segmentIndex then
        -- Apply force as acceleration (F/m, where F is constant force value)
        external_force_accel = constants.PHYSICS.ACCELERATION_FORCE / mass
        self.last_accel_index = segmentIndex
        -- print('Cart accelerated at index', segmentIndex)
    end

    if p1.decelerate and self.last_brake_index ~= segmentIndex then
        -- Apply force as deceleration (F/m) - note sign convention
        external_force_accel = -constants.PHYSICS.DECELERATION_FORCE / mass
        self.last_brake_index = segmentIndex
        -- print('Cart decelerated at index', segmentIndex)
    end
    self.acceleration = self.acceleration + external_force_accel

    -- Handle Hoist (Overrides other physics)
    local on_hoist = false
    if p1.hoist and self.last_hoist_index ~= segmentIndex then
        self.velocity = constants.HOIST.SPEED -- Set velocity directly
        self.acceleration = 0                 -- No other acceleration applies on hoist
        self.last_hoist_index = segmentIndex
        on_hoist = true
        -- print('Hoist activated at index', segmentIndex, 'Setting velocity to', self.velocity)
    end

    -- Update scalar velocity along the track
    if not on_hoist then
        local next_velocity = self.velocity + self.acceleration * dt

        -- Prevent velocity sign flip due to friction/gravity opposing motion near zero speed
        if (self.velocity > 0 and next_velocity < 0) or (self.velocity < 0 and next_velocity > 0) then
            -- Check if the acceleration is actually causing the flip (e.g. friction)
            -- If gravity is the main component trying to reverse, allow it
            -- Simplified check: If acceleration has opposite sign to velocity, allow stop.
            if (self.acceleration > 0 and self.velocity < 0) or (self.acceleration < 0 and self.velocity > 0) then
                self.velocity = 0
            else
                self.velocity = next_velocity -- Allow gravity to reverse direction etc.
            end
        else
            self.velocity = next_velocity
        end
    end

    -- Apply speed limits
    self.velocity = math.max(constants.PHYSICS.MIN_SPEED, math.min(constants.PHYSICS.MAX_SPEED, self.velocity))

    -- === Update Position and Visuals ===

    -- Update scalar position along the track
    self.position_on_track = self.position_on_track + self.velocity * dt
    -- Keep position within track bounds using modulo (handled in getPointOnTrack)

    -- Check for flip point trigger at p1
    if p1.flip and self.last_flip_index ~= segmentIndex then
        self.offset_direction = self.offset_direction * -1
        self.last_flip_index = segmentIndex
        -- print('Cart flipped at index', segmentIndex)
    end

    -- Calculate visual offset (perpendicular to track direction)
    -- Normal vector (nx, ny) is (-uy, ux) or (uy, -ux)
    local nx = -uy -- Normal pointing "left" relative to track direction
    local ny = ux
    self.visual_x = self.x + nx * constants.TRAIN.FLIP_OFFSET * self.offset_direction
    self.visual_y = self.y + ny * constants.TRAIN.FLIP_OFFSET * self.offset_direction

    -- === Update Character ===
    -- Apparent gravity felt by character is (world gravity - cart acceleration)
    local apparent_gravity_x = constants.PHYSICS.GRAVITY_VEC.x - self.accel_x
    local apparent_gravity_y = constants.PHYSICS.GRAVITY_VEC.y - self.accel_y

    self.character:update(dt, apparent_gravity_x, apparent_gravity_y, self.direction)

    -- Store previous scalar velocity for train's direction reversal check
    self.prev_velocity = self.velocity
end

function Cart:draw()
    love.graphics.setColor(1, 0, 0) -- Red for cart
    love.graphics.push()
    -- Use visual position which includes the flip offset
    love.graphics.translate(self.visual_x, self.visual_y)
    love.graphics.rotate(self.direction)

    -- Draw cart body
    love.graphics.rectangle('fill', -10, -5, 20, 10)

    -- Draw the character INSIDE the cart's transformed state
    -- Character's draw function uses relative coordinates (0,0 is cart center)
    self.character:draw()

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Train class
local Train = {}
Train.__index = Train

function Train.new(track, num_carts)
    local self = setmetatable({}, Train)
    self.track = track
    self.carts = {}
    self.num_carts = num_carts or CONSTANTS.TRAIN.DEFAULT_CARTS
    self.mass = CONSTANTS.PHYSICS
        .DEFAULT_MASS -- Initial mass for the *whole train*? Or per cart? Let's assume per cart for now.
    -- If per cart, mass passed to Cart:update should be self.mass. If total, self.mass / #self.carts?
    -- Current Cart:update divides force by mass, so passing self.mass implies it's per-cart mass.
    self:initialize()
    return self
end

function Train:initialize()
    -- Clear existing carts
    self.carts = {}

    -- Ensure the track has enough length for initialization
    if #self.track.points < 2 or self.track.total_length == 0 then
        print("Warning: Cannot initialize train. Track has < 2 points or zero length.")
        return
    end

    -- Create carts spaced backwards from position 0
    for i = 1, self.num_carts do
        -- Calculate initial position ensuring it wraps correctly
        local initial_pos = (0 - (i - 1) * CONSTANTS.TRAIN.CART_SPACING)
        -- Manually wrap negative initial positions
        while initial_pos < 0 do
            initial_pos = initial_pos + self.track.total_length
        end
        initial_pos = initial_pos % self.track.total_length

        local cart = Cart.new(initial_pos, self.track)
        table.insert(self.carts, cart)
    end

    -- Initialize carts' world positions, directions, and physics state correctly
    for _, cart in ipairs(self.carts) do
        -- Call update with zero dt to set initial pos/dir/visuals without physics step
        cart:update(0, self.mass, CONSTANTS)
        -- Explicitly set previous world pos to current pos for first frame accel calculation
        cart.prev_x = cart.x
        cart.prev_y = cart.y
        cart.prev_vx = cart.vx -- Should be 0 from dt=0 call
        cart.prev_vy = cart.vy -- Should be 0 from dt=0 call
    end

    -- Set initial velocity for the lead cart only
    if #self.carts > 0 then
        self.carts[1].velocity = 50 -- Starting velocity (adjust as needed)
        self.carts[1].prev_velocity = self.carts[1].velocity
    end
end

function Train:update(dt)
    if #self.carts == 0 or self.track.total_length == 0 then return end

    -- Update the lead cart using its physics
    local lead_cart = self.carts[1]
    lead_cart:update(dt, self.mass, CONSTANTS)

    -- Check for direction reversal based on lead cart scalar velocity
    -- (This is a simplification, real trains might buckle/stretch)
    -- Only reverse if velocity actually crossed zero
    -- if (lead_cart.velocity > 0 and lead_cart.prev_velocity < 0) or
    --    (lead_cart.velocity < 0 and lead_cart.prev_velocity > 0) then
    --    -- DISABLED FOR NOW - can cause jerky motion on hills. Revisit if needed.
    --    -- self:reverseDirection()
    -- end

    -- Update following carts based on the lead cart's position
    for i = 2, #self.carts do
        local cart = self.carts[i]
        -- Desired position is leader's position minus spacing along the track
        local desired_position = lead_cart.position_on_track - (i - 1) * CONSTANTS.TRAIN.CART_SPACING

        -- Wrap desired position correctly around the track
        while desired_position < 0 do
            desired_position = desired_position + self.track.total_length
        end
        cart.position_on_track = desired_position % self.track.total_length

        -- Update the follower cart's state based on its new track position
        -- Pass the same mass for simplicity (assuming identical carts)
        cart:update(dt, self.mass, CONSTANTS)

        -- Crucial: Copy scalar velocity from the lead cart to followers for consistent train speed
        -- This enforces the "rigid train" model where all carts move at the same speed along the track
        cart.velocity = lead_cart.velocity
    end
end

-- function Train:reverseDirection()
--     -- This simple reversal might be problematic. Disabling for now.
--     print("Train direction reversal triggered (currently disabled).")
--     --[[
--     for _, cart in ipairs(self.carts) do
--         cart.velocity = -cart.velocity
--         cart.prev_velocity = cart.velocity -- Reset previous velocity to avoid immediate re-trigger
--     end
--     print("Train direction reversed!")
--     --]]
-- end

function Train:draw()
    -- Draw carts in reverse order so front carts overlap rear carts
    for i = #self.carts, 1, -1 do
        self.carts[i]:draw()
    end

    -- Display lead cart information
    if #self.carts > 0 then
        local lead_cart = self.carts[1]
        love.graphics.setColor(1, 1, 1) -- White
        love.graphics.print(string.format("Lead Speed: %.2f px/s", lead_cart.velocity), 10, 10)
        love.graphics.print(string.format("Lead Accel (Track): %.2f px/s^2", lead_cart.acceleration), 10, 30)
        love.graphics.print(string.format("Cart Mass: %.2f", self.mass), 10, 50)
        -- love.graphics.print(string.format("Lead Pos: %.1f", lead_cart.position_on_track), 10, 70)
        -- love.graphics.print(string.format("Lead World Accel: %.1f, %.1f", lead_cart.accel_x, lead_cart.accel_y), 10, 90)
    end
end

-- GameState
local GameState = {
    track = nil,
    train = nil,
    ground_level = 0
}

-- Event Handlers

function love.load()
    love.window.setMode(CONSTANTS.WINDOW.WIDTH, CONSTANTS.WINDOW.HEIGHT, { resizable = false, vsync = true })
    love.window.setTitle("Love2D Rollercoaster")

    GameState.ground_level = CONSTANTS.WINDOW.HEIGHT - 50
    GameState.track = Track.new(GameState.ground_level)
    GameState.train = Train.new(GameState.track, CONSTANTS.TRAIN.DEFAULT_CARTS)

    -- Example initial track (optional)
    -- GameState.track:addPoint(100, GameState.ground_level - 100)
    -- GameState.track:addPoint(300, GameState.ground_level - 300)
    -- GameState.track:addPoint(600, GameState.ground_level - 250)
    -- GameState.track:addPoint(900, GameState.ground_level - 350)
    -- GameState.track:addPoint(1200, GameState.ground_level - 150)
    -- GameState.track:addPoint(1500, GameState.ground_level - 100)
    -- GameState.track:addPoint(1600, GameState.ground_level - 90)
    -- GameState.track:calculateLengths()
    -- GameState.track:calculateSupportBeams()
    -- GameState.train:initialize() -- Re-initialize train for the example track
end

function love.mousepressed(x, y, button)
    if button == 1 then                      -- Left mouse button
        -- Start drawing new track
        GameState.track.points = {}          -- Clear existing points
        GameState.track.support_beams = {}   -- Clear existing beams
        GameState.track.segment_lengths = {} -- Clear lengths
        GameState.track.total_length = 0     -- Reset length
        GameState.train.carts = {}           -- Clear train carts
        GameState.track:addPoint(x, y)       -- Add first point
        GameState.track.is_drawing = true
        print('Track creation started!')
    elseif button == 2 then                                                         -- Right mouse button (Example: Toggle property at closest point)
        local closest_point, index = GameState.track:findClosestPoint(x, y, 50 ^ 2) -- Smaller threshold for RMB toggle
        if closest_point then
            -- Cycle through properties: None -> Accel -> Decel -> Hoist -> Flip -> None
            if not closest_point.accelerate and not closest_point.decelerate and not closest_point.hoist and not closest_point.flip then
                closest_point.accelerate = true
                print(string.format("Point %d: Accelerate ON", index))
            elseif closest_point.accelerate then
                closest_point.accelerate = false
                closest_point.decelerate = true
                print(string.format("Point %d: Decelerate ON", index))
            elseif closest_point.decelerate then
                closest_point.decelerate = false
                closest_point.hoist = true
                print(string.format("Point %d: Hoist ON", index))
            elseif closest_point.hoist then
                closest_point.hoist = false
                closest_point.flip = true
                print(string.format("Point %d: Flip ON", index))
            elseif closest_point.flip then
                closest_point.flip = false
                print(string.format("Point %d: Properties OFF", index))
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if GameState.track.is_drawing then
        if #GameState.track.points > 0 then
            local last_point = GameState.track.points[#GameState.track.points]
            local dist = distance(last_point.x, last_point.y, x, y)
            if dist >= CONSTANTS.TRACK.MIN_DISTANCE then
                local p = GameState.track:addPoint(x, y)
                -- Add properties based on key press *while drawing*
                if love.keyboard.isDown('a') then p.accelerate = true end
                if love.keyboard.isDown('d') then p.decelerate = true end
                if love.keyboard.isDown('h') then p.hoist = true end
                if love.keyboard.isDown('f') then p.flip = true end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and GameState.track.is_drawing then
        GameState.track.is_drawing = false
        if #GameState.track.points > 1 then
            print('Track creation completed with', #GameState.track.points, 'points.')
            GameState.track:calculateLengths()
            GameState.track:calculateSupportBeams()
            GameState.train:initialize() -- Initialize train on the new track
        else
            print('Track creation cancelled (less than 2 points).')
            -- Clear the single point if drawing is cancelled early
            GameState.track.points = {}
            GameState.track.total_length = 0
        end
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'f' then -- Toggle flip at closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.flip = not closest_point.flip
            print(string.format("Flip point at index %d set to %s", index, tostring(closest_point.flip)))
        end
    elseif key == 'a' then -- Toggle acceleration at closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.accelerate = not closest_point.accelerate
            if closest_point.accelerate then
                closest_point.decelerate = false; closest_point.hoist = false;
            end
            print(string.format("Acceleration point at index %d set to %s", index, tostring(closest_point.accelerate)))
        end
    elseif key == 'd' then -- Toggle deceleration at closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.decelerate = not closest_point.decelerate
            if closest_point.decelerate then
                closest_point.accelerate = false; closest_point.hoist = false;
            end
            print(string.format("Deceleration point at index %d set to %s", index, tostring(closest_point.decelerate)))
        end
    elseif key == 'h' then -- Toggle hoist at closest point
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.hoist = not closest_point.hoist
            if closest_point.hoist then
                closest_point.accelerate = false; closest_point.decelerate = false;
            end
            print(string.format("Hoist point at index %d set to %s", index, tostring(closest_point.hoist)))
        end
    elseif key == 'up' then -- Increase mass
        GameState.train.mass = GameState.train.mass + 0.5
        print("Cart Mass increased to", GameState.train.mass)
    elseif key == 'down' then                                            -- Decrease mass
        GameState.train.mass = math.max(GameState.train.mass - 0.5, 0.1) -- Ensure mass > 0
        print("Cart Mass decreased to", GameState.train.mass)
    elseif key == 'left' then                                            -- Decrease carts
        if GameState.train.num_carts > 1 then
            GameState.train.num_carts = GameState.train.num_carts - 1
            print("Number of carts decreased to", GameState.train.num_carts)
            GameState.train:initialize() -- Reinitialize train with new number of carts
        end
    elseif key == 'right' then           -- Increase carts
        GameState.train.num_carts = GameState.train.num_carts + 1
        print("Number of carts increased to", GameState.train.num_carts)
        GameState.train:initialize() -- Reinitialize train
    elseif key == 'r' then           -- Reset train position and speed
        print("Resetting train...")
        GameState.train:initialize()
    end
end

function love.update(dt)
    -- Prevent large dt spikes (e.g., during debugging pauses or window dragging)
    dt = math.min(dt, 1 / 30) -- Cap delta time to avoid physics explosions

    if GameState.train and GameState.track and not GameState.track.is_drawing then
        GameState.train:update(dt)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2) -- Dark blue background

    -- Draw ground line
    love.graphics.setColor(0.2, 0.6, 0.2) -- Dark Green
    love.graphics.setLineWidth(2)
    love.graphics.line(0, GameState.ground_level, CONSTANTS.WINDOW.WIDTH, GameState.ground_level)
    love.graphics.setLineWidth(1)

    -- Draw track
    if GameState.track then
        GameState.track:draw()
    end

    -- Draw train
    if GameState.train then
        GameState.train:draw()
    end

    -- Draw UI / Info text (already included in Train:draw)
    love.graphics.setColor(1, 1, 1) -- Reset color

    -- Draw mouse position helper (optional)
    -- local mx, my = love.mouse:getPosition()
    -- love.graphics.print(string.format("Mouse: %d, %d", mx, my), mx + 15, my)

    -- Draw Instructions
    local instructions = {
        "LMB Drag: Draw Track",
        "RMB Click Point: Cycle Properties (Accel/Decel/Hoist/Flip)",
        "A/D/H/F Key + LMB Drag: Add point with property",
        "A/D/H/F Key + Mouse Hover: Toggle property on nearest point",
        "Up/Down Arrow: Change Cart Mass",
        "Left/Right Arrow: Change Number of Carts",
        "R: Reset Train",
        "ESC: Quit"
    }
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8) -- Semi-transparent grey
    local start_y = CONSTANTS.WINDOW.HEIGHT - #instructions * 15 - 5
    for i, line in ipairs(instructions) do
        love.graphics.print(line, 5, start_y + (i - 1) * 15, 0, 0.8, 0.8) -- Smaller font
    end
    love.graphics.setColor(1, 1, 1)                                       -- Reset
end
