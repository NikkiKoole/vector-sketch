local dir = (...):gsub('%.[^%.]+$', '')
require(dir .. ".util")

local softbody = setmetatable({}, {
    __call = function(self, world, x, y, r, s, t, options, reinit, texture)
        local new = copy(self);
        new:init(world, x, y, r, s, t, options, reinit, texture);

        return setmetatable(new, getmetatable(self));
    end,
    __index = function(self, i)
        return self.nodes[i] or false;
    end,
    __tostring = function(self)
        return "softbody";
    end
});
function softbody:init(world, x, y, r, s, t, options, reinit, texture)
    options          = options or {}
    self.stiffness   = options.stiffness or 0.8 -- Default stiffness (frequency)
    self.damping     = options.damping or 0.2   -- Default damping ratio
    self.friction    = options.friction or 0.5  -- Default friction
    self.restitution = options.restitution or 0 -- Default restitution
    self.texture     = texture or nil           -- Texture (optional)
    self.radius      = r
    self.world       = world
    print(texture)
    -- Create the center body
    self.centerBody    = physics.newBody(world, x, y, "dynamic")
    self.centerShape   = physics.newCircleShape(r / 4)
    self.centerFixture = physics.newFixture(self.centerBody, self.centerShape)
    self.centerFixture:setMask(1)
    self.centerBody:setAngularDamping(300)

    -- Create 'nodes' (outer bodies) & connect to center body
    self.nodeShape = physics.newCircleShape(r / 8)
    self.nodes = {}

    local nodes = r / 2

    for node = 1, nodes do
        local angle = (2 * math.pi) / nodes * node
        local posx = x + r * math.cos(angle)
        local posy = y + r * math.sin(angle)

        local b = physics.newBody(world, posx, posy, "dynamic")
        b:setAngularDamping(5000)
        b:setBullet(true)

        local f = physics.newFixture(b, self.nodeShape)
        f:setFriction(self.friction)       -- Apply friction to node fixtures
        f:setRestitution(self.restitution) -- Apply restitution (bounciness)
        f:setUserData(node)

        -- Create a joint between the center and the nodes
        local j = physics.newDistanceJoint(self.centerBody, b, posx, posy, posx, posy, false)
        j:setDampingRatio(self.damping) -- Apply damping ratio to joints
        j:setFrequency(self.stiffness)  -- Apply stiffness (frequency) to joints

        table.insert(self.nodes, { body = b, fixture = f, joint = j })
    end

    -- Connect nodes to each other
    for i = 1, #self.nodes do
        if i < #self.nodes then
            local j = physics.newDistanceJoint(self.nodes[i].body, self.nodes[i + 1].body,
                self.nodes[i].body:getX(), self.nodes[i].body:getY(),
                self.nodes[i + 1].body:getX(), self.nodes[i + 1].body:getY(), false)
            self.nodes[i].joint2 = j
        else
            local j = physics.newDistanceJoint(self.nodes[i].body, self.nodes[1].body,
                self.nodes[i].body:getX(), self.nodes[i].body:getY(),
                self.nodes[1].body:getX(), self.nodes[1].body:getY(), false)
            self.nodes[i].joint3 = j
        end
    end

    if not reinit then
        -- Set tessellation and smoothing
        self.smooth = s or 2

        local tess = t or 4
        self.tess = {}
        for i = 1, tess do
            self.tess[i] = {}
        end
    end

    self.dead = false
    self:update()
end

-- API functions to control properties dynamically

-- Set stiffness (frequency) for all joints
function softbody:setStiffness(stiffness)
    self.stiffness = stiffness
    for i, node in ipairs(self.nodes) do
        node.joint:setFrequency(self.stiffness)
        if node.joint2 then node.joint2:setFrequency(self.stiffness) end
        if node.joint3 then node.joint3:setFrequency(self.stiffness) end
    end
end

-- Set damping ratio for all joints
function softbody:setDamping(damping)
    self.damping = damping
    for i, node in ipairs(self.nodes) do
        node.joint:setDampingRatio(self.damping)
        if node.joint2 then node.joint2:setDampingRatio(self.damping) end
        if node.joint3 then node.joint3:setDampingRatio(self.damping) end
    end
end

-- Set friction for all fixtures
function softbody:setFriction(friction)
    self.friction = friction
    for i, node in ipairs(self.nodes) do
        node.fixture:setFriction(self.friction)
    end
end

-- Set restitution (bounciness) for all fixtures
function softbody:setRestitution(restitution)
    self.restitution = restitution
    for i, node in ipairs(self.nodes) do
        node.fixture:setRestitution(self.restitution)
    end
end

function softbody:update()
    --update tesselation (for drawing)
    local pos = {};
    for i = 1, #self.nodes, self.smooth do
        v = self.nodes[i];

        table.insert(pos, v.body:getX());
        table.insert(pos, v.body:getY());
    end

    tessellate(pos, self.tess[1]);
    for i = 1, #self.tess - 1 do
        tessellate(self.tess[i], self.tess[i + 1]);
    end
end

function softbody:destroy()
    if self.dead then
        return;
    end

    for i = #self.nodes, 1, -1 do
        self.nodes[i].body:destroy();
        self.nodes[i] = nil;
    end

    self.centerBody:destroy();
    self.dead = true;
end

function softbody:setFrequency(f)
    for i, v in pairs(self.nodes) do
        v.joint:setFrequency(f);
    end
end

function softbody:setDamping(d)
    for i, v in pairs(self.nodes) do
        v.joint:setDampingRatio(d);
    end
end

function softbody:setFriction(f)
    for i, v in ipairs(self.nodes) do
        v.fixture:setFriction(f);
    end
end

function softbody:getPoints()
    return self.tess[#self.tess];
end

-- Drawing function with texture support
-- Shader to handle texture mapping on the polygon
-- Define a basic shader that handles texture mapping
local shader = love.graphics.newShader [[
    varying vec2 vTexCoord;
    vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
        return Texel(texture, tex_coords) * color;
    }
]]
function softbody:draw(type, debug)
    if self.dead then
        return
    end

    if self.texture then
        -- Get tessellated points for the softbody
        local points = self:getPoints()

        -- Get the angle of the center body for rotation
        local angle = self.centerBody:getAngle()

        -- Calculate UV coordinates for each vertex based on position
        local centerX, centerY = self.centerBody:getX(), self.centerBody:getY()
        local vertices = {}

        -- Stretch factors for UVs (optional)
        local stretchX = 10 -- Stretch horizontally
        local stretchY = 1  -- Stretch vertically

        -- Loop through points and create vertices with UVs
        for i = 1, #points, 2 do
            local vx, vy = points[i], points[i + 1]

            -- Translate vertex to be relative to the center
            local relX, relY = vx - centerX, vy - centerY

            -- Apply rotation using the center body's angle (rotation matrix)
            local rotatedX = relX * math.cos(angle) - relY * math.sin(angle)
            local rotatedY = relX * math.sin(angle) + relY * math.cos(angle)

            -- Calculate UVs with rotation and stretch
            local uvx = (rotatedX / (2 * self.radius) * stretchX) + 0.5
            local uvy = (rotatedY / (2 * self.radius) * stretchY) + 0.5

            -- Insert each vertex as {x, y, u, v}
            table.insert(vertices, { vx, vy, uvx, uvy })
        end

        -- Create the mesh with the vertices and texture
        local mesh = love.graphics.newMesh({
            { "VertexPosition", "float", 2 }, -- 2 floats for x, y position
            { "VertexTexCoord", "float", 2 }, -- 2 floats for u, v texture coords
        }, vertices, "fan")

        mesh:setTexture(self.texture)

        -- Draw the mesh (textured softbody)
        love.graphics.draw(mesh)
    else
        -- Fallback to color rendering
        love.graphics.setLineStyle("smooth")
        love.graphics.setLineJoin("miter")
        love.graphics.setLineWidth(self.nodeShape:getRadius() * 2.5)

        if type == "line" then
            love.graphics.polygon("line", self.tess[#self.tess])
        elseif type == "fill" then
            love.graphics.polygon("fill", self.tess[#self.tess])
            love.graphics.polygon("line", self.tess[#self.tess])
        end
    end

    love.graphics.setLineWidth(1)

    if debug then
        for i, v in ipairs(self.nodes) do
            love.graphics.setColor(255, 255, 255)
            love.graphics.circle("line", v.body:getX(), v.body:getY(), self.nodeShape:getRadius())
        end
    end
end

function softbody:draw2(type, debug)
    if self.dead then
        return;
    end

    graphics.setLineStyle("smooth");
    graphics.setLineJoin("miter");
    graphics.setLineWidth(self.nodeShape:getRadius() * 2.5);

    if type == "line" then
        graphics.polygon("line", self.tess[#self.tess]);
    elseif type == "fill" then
        graphics.polygon("fill", self.tess[#self.tess]);
        graphics.polygon("line", self.tess[#self.tess]);
    end

    graphics.setLineWidth(1);

    if debug then
        for i, v in ipairs(self.nodes) do
            graphics.setColor(255, 255, 255)
            graphics.circle("line", v.body:getX(), v.body:getY(), self.nodeShape:getRadius());
        end
    end
end

return softbody;
