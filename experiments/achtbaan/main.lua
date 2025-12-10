-- love2d_coaster_improved.lua

-- Constants
local CONSTANTS = {
    WINDOW = {
        WIDTH = 1800,
        HEIGHT = 1000
    },
    TRACK = {
        MIN_DISTANCE = 40,
        SUPPORT_SPACING = 100,
        MIN_BEAM_SPACING = 50
    },
    PHYSICS = {
        GRAVITY = 90.81,            -- pixels/s^2
        DEFAULT_MASS = 1,           -- arbitrary units per cart
        FRICTION = 0.015,           -- friction coefficient
        MAX_SPEED = 15000,          -- pixels/s
        MIN_SPEED = -15000,         -- pixels/s
        ACCELERATION_FORCE = 10000, -- px/s^2
        DECELERATION_FORCE = 10000, -- px/s^2
        AIR_RESISTANCE = 0.0001     -- v^2 drag coefficient
    },
    TRAIN = {
        DEFAULT_CARTS = 13, -- Initial number of carts
        CART_SPACING = 25,  -- pixels
        FLIP_OFFSET = 10    -- pixels
    },
    HOIST = {
        SPEED = 100 -- pixels/s
    }
}

local mouseState = {
    pressed = false
}

-- GameState
local GameState = {
    track = nil,
    train = nil,
    ground_level = 0,
    pause = false,
    new = true,
    draggingPointIndex = nil,
    show_help = true
}

-- Utility function to calculate distance between two points
local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function inRect(x, y, rx, ry, rw, rh)
    if x < rx or y < ry then return false end
    if x > rx + rw or y > ry + rh then return false end
    return true
end

-- Track class
local Track = {}
Track.__index = Track

function Track.new(ground_level)
    local self = setmetatable({}, Track)
    self.points = {}
    self.support_beams = {}
    self.segment_lengths = {}
    self.total_length = 0
    self.ground_level = ground_level
    self.is_drawing = false
    return self
end

function Track:addPoint(x, y)
    local point = {
        x = x,
        y = y,
        flip = false,
        accelerate = false,
        decelerate = false,
        hoist = false
    }
    table.insert(self.points, point)
    return point
end

function Track:removeLastPoint()
    if #self.points > 1 then
        table.remove(self.points)
        return true
    end
    return false
end

function Track:finalizeDrawing()
    if #self.points < 2 then return end

    local first_point = self.points[1]
    local last_point = self.points[#self.points]
    local minDist = CONSTANTS.TRACK.MIN_DISTANCE

    local dist = distance(last_point.x, last_point.y, first_point.x, first_point.y)

    if dist > minDist then
        local steps = math.floor(dist / minDist)
        local dx_step = (first_point.x - last_point.x) / (steps + 1)
        local dy_step = (first_point.y - last_point.y) / (steps + 1)

        for i = 1, steps do
            local px = last_point.x + dx_step * i
            local py = last_point.y + dy_step * i
            self:addPoint(px, py)
        end
    end
end

function Track:calculateLengths()
    self.total_length = 0
    self.segment_lengths = {}

    for i = 1, #self.points do
        local p1 = self.points[i]
        local p2 = self.points[(i % #self.points) + 1]
        local seg_length = distance(p1.x, p1.y, p2.x, p2.y)
        self.segment_lengths[i] = seg_length
        self.total_length = self.total_length + seg_length
    end
end

function Track:calculateSupportBeams()
    self.support_beams = {}
    local initial_beam_positions = {}

    local total_length = self.total_length
    local num_beams = math.floor(total_length / CONSTANTS.TRACK.SUPPORT_SPACING)

    for i = 1, num_beams do
        local target_distance = i * CONSTANTS.TRACK.SUPPORT_SPACING
        local accumulated_distance = 0

        for j = 1, #self.points do
            local seg_length = self.segment_lengths[j]
            if accumulated_distance + seg_length >= target_distance then
                local remaining_distance = target_distance - accumulated_distance
                local t = remaining_distance / seg_length

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

function Track:getPointOnTrack(distance)
    if #self.points == 0 then
        return nil, nil, nil
    elseif #self.points == 1 then
        return self.points[1], 1, 0
    end

    if self.total_length == 0 then
        return nil, nil, nil
    end

    -- Wrap distance
    if distance < 0 then
        distance = distance + math.ceil(math.abs(distance) / self.total_length) * self.total_length
    elseif distance > self.total_length then
        distance = distance % self.total_length
    end

    local accumulated_distance = 0

    for i = 1, #self.points do
        local p1 = self.points[i]
        local p2 = self.points[(i % #self.points) + 1]
        local seg_length = self.segment_lengths[i]

        if accumulated_distance + seg_length >= distance then
            local remaining_distance = distance - accumulated_distance
            local t = remaining_distance / seg_length

            local x = p1.x + (p2.x - p1.x) * t
            local y = p1.y + (p2.y - p1.y) * t

            return { x = x, y = y }, i, t
        else
            accumulated_distance = accumulated_distance + seg_length
        end
    end

    return self.points[1], 1, 0
end

function Track:draw()
    -- Draw the track
    if #self.points > 1 then
        for i = 1, #self.points do
            local p1 = self.points[i]
            local p2 = self.points[(i % #self.points) + 1]
            love.graphics.setColor(1, 1, 1)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)

            -- Draw points with color coding
            if p1.flip then
                love.graphics.setColor(0, 0, 1) -- Blue
            elseif p1.accelerate then
                love.graphics.setColor(0, 1, 0) -- Green
            elseif p1.decelerate then
                love.graphics.setColor(1, 0, 0) -- Red
            elseif p1.hoist then
                love.graphics.setColor(1, 1, 0) -- Yellow
            else
                love.graphics.setColor(1, 1, 1) -- White
            end
            love.graphics.circle('fill', p1.x, p1.y, 3)
        end
    elseif #self.points == 1 then
        local p1 = self.points[1]
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle('fill', p1.x, p1.y, 3)
    end

    -- Draw preview line while drawing
    if self.is_drawing and #self.points > 0 then
        local last = self.points[#self.points]
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.line(last.x, last.y, mx, my)
    end

    -- Draw support beams
    if #self.support_beams > 0 then
        love.graphics.setColor(0.25, 0.25, 0.25)
        for _, beam in ipairs(self.support_beams) do
            love.graphics.line(beam.x, beam.y, beam.x, self.ground_level)
            love.graphics.setColor(0.37, 0.37, 0.37)
            love.graphics.circle('fill', beam.x, beam.y, 5)
            love.graphics.setColor(0.25, 0.25, 0.25)
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
    self.in_hoist_zone = false
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
end

function Cart:update(dt, mass, constants)
    local cartPos, segmentIndex, t = self.track:getPointOnTrack(self.position_on_track)

    if not cartPos then
        return
    end

    self.x = cartPos.x
    self.y = cartPos.y

    if segmentIndex > #self.track.points then
        segmentIndex = 1
    elseif segmentIndex < 1 then
        segmentIndex = 1
    end
    self:resetCartIndexCounters(segmentIndex)

    local p1 = self.track.points[segmentIndex]
    local p2 = self.track.points[(segmentIndex % #self.track.points) + 1]
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local seg_length = self.track.segment_lengths[segmentIndex]
    if seg_length == 0 then seg_length = 1 end

    local ux = dx / seg_length
    local uy = dy / seg_length

    self.direction = math.atan2(dy, dx)

    -- Check if in hoist zone
    if p1.hoist then
        -- In hoist: override physics completely
        self.in_hoist_zone = true
        self.velocity = constants.HOIST.SPEED
        self.acceleration = 0
        self.position_on_track = (self.position_on_track + self.velocity * dt) % self.track.total_length
    else
        -- Normal physics
        self.in_hoist_zone = false

        -- Gravity component
        local gravity_component = constants.PHYSICS.GRAVITY * uy

        -- Linear friction
        local friction_acceleration = -constants.PHYSICS.FRICTION * self.velocity

        -- Air resistance (v^2)
        local air_resistance = -constants.PHYSICS.AIR_RESISTANCE * self.velocity * math.abs(self.velocity)

        self.acceleration = gravity_component + friction_acceleration + air_resistance

        -- Handle acceleration zones
        if p1.accelerate and self.last_accel_index ~= segmentIndex then
            local applied_acceleration = constants.PHYSICS.ACCELERATION_FORCE / mass
            self.acceleration = self.acceleration + applied_acceleration
            self.last_accel_index = segmentIndex
        end

        if p1.decelerate and self.last_brake_index ~= segmentIndex then
            local applied_deceleration = constants.PHYSICS.DECELERATION_FORCE / mass
            self.acceleration = self.acceleration - applied_deceleration
            self.last_brake_index = segmentIndex
        end

        -- Update velocity
        self.velocity = self.velocity + self.acceleration * dt

        -- Prevent velocity from crossing zero due to friction alone
        if self.prev_velocity > 0 and self.velocity < 0 and self.acceleration < 0 then
            self.velocity = 0
        elseif self.prev_velocity < 0 and self.velocity > 0 and self.acceleration > 0 then
            self.velocity = 0
        end

        -- Apply speed limits
        if self.velocity > constants.PHYSICS.MAX_SPEED then
            self.velocity = constants.PHYSICS.MAX_SPEED
        elseif self.velocity < constants.PHYSICS.MIN_SPEED then
            self.velocity = constants.PHYSICS.MIN_SPEED
        end

        -- Update position
        self.position_on_track = (self.position_on_track + self.velocity * dt) % self.track.total_length
    end

    -- Check for flip point
    if p1.flip and self.last_flip_index ~= segmentIndex then
        self.offset_direction = self.offset_direction * -1
        self.last_flip_index = segmentIndex
    end

    -- Apply visual offset
    local nx = uy
    local ny = -ux
    self.x = self.x + nx * constants.TRAIN.FLIP_OFFSET * self.offset_direction
    self.y = self.y + ny * constants.TRAIN.FLIP_OFFSET * self.offset_direction

    self.prev_velocity = self.velocity
end

function Cart:draw()
    love.graphics.setColor(1, 0, 0)
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
    self.mass = CONSTANTS.PHYSICS.DEFAULT_MASS * self.num_carts -- Total mass
    self:initialize()
    return self
end

function Train:initialize()
    if #self.track.points < 2 then
        self.carts = {}
        return
    end

    self.carts = {}
    for i = 1, self.num_carts do
        local initial_position = (0 - (i - 1) * CONSTANTS.TRAIN.CART_SPACING) % self.track.total_length
        local cart = Cart.new(initial_position, self.track)
        table.insert(self.carts, cart)
    end

    for i, cart in ipairs(self.carts) do
        cart:update(0, self.mass, CONSTANTS)
    end

    if #self.carts > 0 then
        self.carts[1].velocity = 100
        self.carts[1].prev_velocity = self.carts[1].velocity
    end
end

function Train:update(dt)
    if #self.carts == 0 then return end

    local lead_cart = self.carts[1]
    lead_cart:update(dt, self.mass, CONSTANTS)

    -- Check for direction reversal
    if (lead_cart.velocity > 0 and lead_cart.prev_velocity < 0) or
        (lead_cart.velocity < 0 and lead_cart.prev_velocity > 0) then
        self:reverseDirection()
    end

    -- Update following carts
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
end

function Train:draw()
    -- Draw connections between carts
    if #self.carts > 1 then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
        for i = 1, #self.carts - 1 do
            love.graphics.line(self.carts[i].x, self.carts[i].y,
                self.carts[i + 1].x, self.carts[i + 1].y)
        end
    end

    -- Draw carts
    for _, cart in ipairs(self.carts) do
        cart:draw()
    end

    -- Display info
    if #self.carts > 0 then
        local lead_cart = self.carts[1]
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Snelheid: %5.0f px/s", lead_cart.velocity), 10, 50)
        love.graphics.print(string.format("Massa: %.1f", self.mass), 10, 80)
        if lead_cart.in_hoist_zone then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("TAKEL ACTIEF", 10, 110)
        end
    end
end

-- Event Handlers
function love.mousepressed(x, y, button)
    if button == 1 and GameState.new == false then
        for i = 1, #GameState.track.points do
            local point = GameState.track.points[i]
            local dist = distance(point.x, point.y, x, y)
            if dist < 10 then
                GameState.draggingPointIndex = i
                return
            end
        end
    end

    if button == 1 and GameState.new then
        GameState.track.points = {}
        GameState.track.support_beams = {}
        GameState.train.carts = {}
        GameState.track:addPoint(x, y)
        GameState.track.is_drawing = true
        GameState.new = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if GameState.track.is_drawing then
        local last_point = GameState.track.points[#GameState.track.points]
        local minDist = CONSTANTS.TRACK.MIN_DISTANCE
        local dist = distance(last_point.x, last_point.y, x, y)

        if dist >= minDist then
            local steps = math.floor(dist / minDist)
            local dx_step = (x - last_point.x) / (steps + 1)
            local dy_step = (y - last_point.y) / (steps + 1)

            for i = 1, steps do
                local px = last_point.x + dx_step * i
                local py = last_point.y + dy_step * i
                local p = GameState.track:addPoint(px, py)

                if love.keyboard.isDown('a') or love.keyboard.isDown('b') then
                    p.accelerate = true
                end
                if love.keyboard.isDown('d') or love.keyboard.isDown('r') then
                    p.decelerate = true
                end
                if love.keyboard.isDown('h') or love.keyboard.isDown('t') then
                    p.hoist = true
                end
                if love.keyboard.isDown('f') then
                    p.flip = true
                end
            end
        end
    end

    if GameState.draggingPointIndex then
        GameState.track.points[GameState.draggingPointIndex].x = x
        GameState.track.points[GameState.draggingPointIndex].y = y
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and GameState.track.is_drawing then
        GameState.track.is_drawing = false
        GameState.track:finalizeDrawing()
        GameState.track:calculateLengths()
        GameState.track:calculateSupportBeams()
        GameState.train:initialize()
    end

    if GameState.draggingPointIndex then
        GameState.track:calculateLengths()
        GameState.track:calculateSupportBeams()
        GameState.draggingPointIndex = nil
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'n' then
        GameState.new = true
        GameState.track.points = {}
        GameState.track.support_beams = {}
        GameState.train.carts = {}
    elseif key == 'space' then
        GameState.pause = not GameState.pause
    elseif key == 'z' and GameState.track.is_drawing then
        GameState.track:removeLastPoint()
    elseif key == 'f' then
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.flip = not closest_point.flip
        end
    elseif key == 'b' or key == 'a' then
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.accelerate = not closest_point.accelerate
            if closest_point.accelerate then
                closest_point.decelerate = false
            end
        end
    elseif key == 'r' or key == 'd' then
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.decelerate = not closest_point.decelerate
            if closest_point.decelerate then
                closest_point.accelerate = false
            end
        end
    elseif key == 't' or key == 'h' then
        local x, y = love.mouse.getPosition()
        local closest_point, index = GameState.track:findClosestPoint(x, y)
        if closest_point then
            closest_point.hoist = not closest_point.hoist
        end
    elseif key == 'up' then
        GameState.train.num_carts = GameState.train.num_carts + 1
        GameState.train.mass = CONSTANTS.PHYSICS.DEFAULT_MASS * GameState.train.num_carts
        GameState.train:initialize()
    elseif key == 'down' then
        GameState.train.num_carts = math.max(1, GameState.train.num_carts - 1)
        GameState.train.mass = CONSTANTS.PHYSICS.DEFAULT_MASS * GameState.train.num_carts
        GameState.train:initialize()
    elseif key == 'tab' then
        GameState.show_help = not GameState.show_help
    end
end

function love.load()
    love.window.setMode(CONSTANTS.WINDOW.WIDTH, CONSTANTS.WINDOW.HEIGHT, { fullscreen = true })
    GameState.ground_level = CONSTANTS.WINDOW.HEIGHT - 50
    GameState.track = Track.new(GameState.ground_level)
    GameState.train = Train.new(GameState.track, CONSTANTS.TRAIN.DEFAULT_CARTS)

    local success, font = pcall(love.graphics.newFont, 'Seattle Avenue.ttf', 32)
    if success then
        love.graphics.setFont(font)
    end
end

function love.update(dt)
    if GameState.train and GameState.track and not GameState.pause then
        GameState.train:update(dt)
    end
end

function love.draw()
    -- Main instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("'N'ieuw  'B'oost 'R'em 'T'akel 'F'lip  'Z' Ongedaan  SPATIE Pauzeer  TAB Help", 20, 10)

    if GameState.track then
        GameState.track:draw()
    end

    if GameState.train then
        GameState.train:draw()
    end

    -- Draw ground
    love.graphics.setColor(0, 1, 0)
    love.graphics.line(0, GameState.ground_level, CONSTANTS.WINDOW.WIDTH, GameState.ground_level)

    -- Help overlay
    if GameState.show_help then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle('fill', 20, 150, 400, 320)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("HELP (TAB om te verbergen)", 30, 160)
        love.graphics.print("Teken: Klik en sleep", 30, 190)
        love.graphics.print("Tijdens tekenen:", 30, 220)
        love.graphics.print("  Hou B = Boost zone", 30, 250)
        love.graphics.print("  Hou R = Rem zone", 30, 280)
        love.graphics.print("  Hou T = Takel zone", 30, 310)
        love.graphics.print("  Hou F = Flip kant", 30, 340)
        love.graphics.print("  Z = Ongedaan laatste punt", 30, 370)
        love.graphics.print("Na tekenen:", 30, 400)
        love.graphics.print("  Klik punten om te slepen", 30, 430)
    end

    love.graphics.setColor(1, 1, 1)
    mouseState.pressed = love.mouse.isDown(1)
end
