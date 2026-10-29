-- sky-atmosphere — can one sky hold the ground's horizon, the day and the night, and
-- black space, all the way up to the moon? Drag the Mipo (or anything) up, and keep
-- dragging near the top of the window to keep climbing.
--
-- The sky is a shader: every pixel works out its own altitude from the camera and
-- looks up a colour in a list of stops (palettes.lua). The palettes for night, dawn,
-- day and dusk share their stop positions, so the time of day blends them stop by
-- stop (in linear RGB, like ../skies/SkyGradient.lua). Stars fade in with the night
-- *and* with altitude, so space is starry at noon too. Gravity fades out above the
-- atmosphere; near the moon, the moon pulls.
--
-- Keys: left/right = time of day, t = let time run, 1-4 = night/dawn/day/dusk,
-- wheel = zoom, space = Mipo back to the ground, r = reload palettes.lua

local palettes = require('palettes')

local W, H = 1200, 768
local MOON_RADIUS = 2500
local GRAVITY = 900

local world, ground, moon, mipo
local things = {}   -- every dynamic body, for gravity and drawing
local clouds = {}
local drag = nil     -- { joint, body }
local cam = { x = 0, y = -300, zoom = 1, userZoom = 1 }
local hour, autoTime = 12, false
local stops = {}     -- the current sky: { pos, r, g, b } in linear RGB
local night = 0
local skyShader
local selftest = nil -- `love . --selftest`: run through the day and up to the moon, print, quit

-- colour helpers --------------------------------------------------------------
local function toLinear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function toSRGB(c) return c <= 0.0031308 and c * 12.92 or 1.055 * c ^ (1 / 2.4) - 0.055 end
local function hexLinear(hex)
    return toLinear(tonumber(hex:sub(1, 2), 16) / 255), toLinear(tonumber(hex:sub(3, 4), 16) / 255),
        toLinear(tonumber(hex:sub(5, 6), 16) / 255)
end
local function smoothstep(a, b, x)
    local t = math.max(0, math.min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
end
local function lerp(a, b, t) return a + (b - a) * t end

-- a piecewise-linear lookup in { { x, y }, ... }
local function curve(points, x)
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if x <= b[1] then return lerp(a[2], b[2], (x - a[1]) / (b[1] - a[1])) end
    end
    return points[#points][2]
end

-- the sky right now ------------------------------------------------------------
local function updateStops()
    local tl = palettes.timeline
    local a, b, t = tl[1], tl[1], 0
    for i = 2, #tl do
        if hour <= tl[i][1] then
            a, b = tl[i - 1], tl[i]
            t = smoothstep(0, 1, (hour - a[1]) / (b[1] - a[1]))
            break
        end
    end
    local pa, pb = palettes.palettes[a[2]], palettes.palettes[b[2]]
    for i, pos in ipairs(palettes.positions) do
        local r1, g1, b1 = hexLinear(pa[i])
        local r2, g2, b2 = hexLinear(pb[i])
        stops[i] = { pos, lerp(r1, r2, t), lerp(g1, g2, t), lerp(b1, b2, t) }
    end
    for i = #palettes.positions + 1, #stops do stops[i] = nil end
    night = curve(palettes.nightness, hour)
    return a[2], b[2], t
end

-- the sky's colour (sRGB) at an altitude, for tinting clouds and ground
local function skyAt(altitude)
    local f = altitude / palettes.space
    local r, g, b = stops[1][2], stops[1][3], stops[1][4]
    for i = 2, #stops do
        if f >= stops[i - 1][1] then
            local t = math.max(0, math.min(1, (f - stops[i - 1][1]) / (stops[i][1] - stops[i - 1][1])))
            r, g, b = lerp(stops[i - 1][2], stops[i][2], t), lerp(stops[i - 1][3], stops[i][3], t),
                lerp(stops[i - 1][4], stops[i][4], t)
        end
    end
    return toSRGB(r), toSRGB(g), toSRGB(b)
end

local function makeShader()
    local n = #palettes.positions
    return love.graphics.newShader(([[
        #define N %d
        extern vec3 stopColor[N];
        extern float stopPos[N];
        extern vec2 camPos;
        extern float zoom;
        extern vec2 screenSize;
        extern float space;
        extern float night;
        extern float time;

        float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            float worldY = camPos.y + (sc.y - screenSize.y * 0.5) / zoom;
            float alt = -worldY / space;

            vec3 c = stopColor[0];
            for (int i = 1; i < N; i++) {
                if (alt >= stopPos[i - 1]) {
                    float t = clamp((alt - stopPos[i - 1]) / (stopPos[i] - stopPos[i - 1]), 0.0, 1.0);
                    c = mix(stopColor[i - 1], stopColor[i], t);
                }
            }

            // stars: nearly fixed to the screen (far away), a slow drift with the camera
            vec2 cell = floor((sc + vec2(camPos.x, camPos.y) * zoom * 0.002) / 2.5);
            float h = hash(cell);
            float starVis = max(night * step(0.0, alt), smoothstep(0.3, 0.85, alt));
            if (h > 0.9965) {
                float twinkle = 0.65 + 0.35 * sin(time * 2.5 + h * 300.0);
                c += vec3(starVis * twinkle * (h - 0.9965) / 0.0035);
            }
            return vec4(pow(c, vec3(1.0 / 2.2)), 1.0);
        }
    ]]):format(n))
end

local function sendSky()
    local colors, positions = {}, {}
    for i, s in ipairs(stops) do
        colors[i] = { s[2], s[3], s[4] }
        positions[i] = s[1]
    end
    skyShader:send('stopColor', unpack(colors))
    skyShader:send('stopPos', unpack(positions))
    skyShader:send('camPos', { cam.x, cam.y })
    skyShader:send('zoom', cam.zoom)
    skyShader:send('screenSize', { W, H })
    skyShader:send('space', palettes.space)
    if skyShader:hasUniform('night') then skyShader:send('night', night) end
    if skyShader:hasUniform('time') then skyShader:send('time', love.timer.getTime()) end
end

-- the world ----------------------------------------------------------------------
local function addThing(body, shape, color, isMipo)
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setFriction(0.8)
    fixture:setRestitution(0.2)
    local thing = { body = body, shape = shape, color = color, isMipo = isMipo }
    things[#things + 1] = thing
    return thing
end

local function resetMipo()
    mipo.body:setPosition(0, -80)
    mipo.body:setLinearVelocity(0, 0)
    mipo.body:setAngularVelocity(0)
end

function love.load()
    love.physics.setMeter(100)
    world = love.physics.newWorld(0, 0, true) -- gravity is applied per body (it fades with altitude)

    ground = love.physics.newBody(world, 0, 300, 'static')
    love.physics.newFixture(ground, love.physics.newRectangleShape(40000, 600))

    moon = love.physics.newBody(world, 0, -palettes.moonAltitude, 'static')
    love.physics.newFixture(moon, love.physics.newCircleShape(MOON_RADIUS))

    mipo = addThing(love.physics.newBody(world, 0, -80, 'dynamic'), love.physics.newCircleShape(50),
        { 0.95, 0.6, 0.3 }, true)
    for i = 1, 6 do
        local body = love.physics.newBody(world, -900 + i * 260, -200, 'dynamic')
        if i % 2 == 0 then
            addThing(body, love.physics.newCircleShape(35), { 0.4, 0.7, 0.9 })
        else
            addThing(body, love.physics.newRectangleShape(80, 80), { 0.9, 0.8, 0.4 })
        end
    end

    -- clouds: clusters of puffs between 1500 and 14000 up
    love.math.setRandomSeed(7)
    for _ = 1, 70 do
        local cloud = { x = love.math.random(-12000, 12000), y = -love.math.random(1500, 14000), puffs = {} }
        local size = love.math.random(180, 520)
        for p = 1, love.math.random(5, 9) do
            cloud.puffs[p] = { love.math.random(-size * 1.6, size * 1.6), love.math.random(-size * 0.3, size * 0.3),
                size * (0.5 + love.math.random() * 0.6) }
        end
        clouds[#clouds + 1] = cloud
    end

    skyShader = makeShader()
    updateStops()
    for _, a in ipairs(arg or {}) do
        if a == '--selftest' then
            selftest = { frame = 0 }
            love.errorhandler = function(msg)
                print('selftest ERROR: ' .. tostring(msg) .. '\n' .. debug.traceback())
                return nil
            end
        end
    end
end

local function altitudeOf(y) return -y end

local function toWorld(sx, sy)
    return cam.x + (sx - W / 2) / cam.zoom, cam.y + (sy - H / 2) / cam.zoom
end

function love.update(dt)
    if selftest then
        selftest.frame = selftest.frame + 1
        hour = (selftest.frame * 0.1) % 24
        local alt = selftest.frame / 240 * (palettes.moonAltitude - MOON_RADIUS * 1.5)
        mipo.body:setPosition(0, -alt)
        mipo.body:setLinearVelocity(0, 0)
        if selftest.frame >= 240 then
            print(string.format('selftest ok: %d frames, last altitude %d, night %.2f', selftest.frame, alt, night))
            love.event.quit()
        end
    end
    if autoTime then hour = (hour + dt * 0.25) % 24 end
    local timeKeys = (love.keyboard.isDown('right') and 1 or 0) - (love.keyboard.isDown('left') and 1 or 0)
    if timeKeys ~= 0 then hour = (hour + timeKeys * dt * 3) % 24 end
    updateStops()

    -- gravity: full on the ground, gone above the atmosphere; the moon pulls up close
    for _, thing in ipairs(things) do
        local body = thing.body
        local x, y = body:getPosition()
        local mass = body:getMass()
        local fade = 1 - smoothstep(0.55, 1.0, altitudeOf(y) / palettes.space)
        body:applyForce(0, GRAVITY * fade * mass)
        local mx, my = moon:getPosition()
        local dx, dy = mx - x, my - y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < MOON_RADIUS * 5 then
            local pull = GRAVITY * 0.6 * math.min(1, (MOON_RADIUS / d) ^ 2)
            body:applyForce(dx / d * pull * mass, dy / d * pull * mass)
        end
        -- in space a thrown thing slows down a little, so it doesn't drift off for good
        local drifting = fade < 0.2 and not (drag and drag.body == body)
        body:setLinearDamping(drifting and 0.3 or 0)
    end

    if drag then drag.joint:setTarget(toWorld(love.mouse.getPosition())) end
    world:update(dt)

    -- camera: follow what you drag, else the Mipo; zoom out the higher it goes
    local target = drag and drag.body or mipo.body
    local tx, ty = target:getPosition()
    local k = 1 - math.exp(-dt * 5)
    cam.x, cam.y = lerp(cam.x, tx, k), lerp(cam.y, ty - 100 / cam.zoom, k)
    local alt = math.max(0, altitudeOf(cam.y))
    cam.zoom = cam.userZoom / math.sqrt(1 + alt / 4000)
end

-- drawing ---------------------------------------------------------------------------
local function drawSun()
    -- far away: fixed to the screen, rising and setting on an arc
    local angle = (hour - 6) / 12 * math.pi
    local up = math.sin(angle)
    if up < -0.15 then return end
    local x = W * (0.5 - 0.42 * math.cos(angle))
    local y = H * 0.9 - up * H * 0.7
    local warm = 1 - smoothstep(0, 0.5, up)
    love.graphics.setBlendMode('add')
    for i = 6, 1, -1 do
        love.graphics.setColor(1, lerp(0.9, 0.5, warm), lerp(0.6, 0.2, warm), 0.05)
        love.graphics.circle('fill', x, y, 40 + i * 22)
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, lerp(0.95, 0.7, warm), lerp(0.7, 0.4, warm))
    love.graphics.circle('fill', x, y, 38)
end

local function drawMoon()
    -- from the ground it's a small moon in the sky; climbing, it slides into the real one
    local camAlt = math.max(0, altitudeOf(cam.y))
    local s = smoothstep(palettes.moonAltitude * 0.45, palettes.moonAltitude * 0.95, camAlt)
    local mx, my = moon:getPosition()
    local realX, realY = W / 2 + (mx - cam.x) * cam.zoom, H / 2 + (my - cam.y) * cam.zoom
    local x, y = lerp(W * 0.78, realX, s), lerp(H * 0.22, realY, s)
    local r = lerp(34, MOON_RADIUS * cam.zoom, s)
    local alpha = math.max(lerp(0.25 + 0.75 * night, 1, smoothstep(0, palettes.space, camAlt)), s)
    love.graphics.setColor(0.86, 0.86, 0.82, alpha)
    love.graphics.circle('fill', x, y, r, 96)
    love.graphics.setColor(0.7, 0.7, 0.66, alpha)
    for _, c in ipairs({ { -0.3, -0.2, 0.22 }, { 0.35, 0.1, 0.15 }, { -0.05, 0.4, 0.12 }, { 0.2, -0.45, 0.09 } }) do
        love.graphics.circle('fill', x + c[1] * r, y + c[2] * r, c[3] * r, 48)
    end
end

local function drawMipo(thing)
    local x, y = thing.body:getPosition()
    local r = thing.shape:getRadius()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(thing.body:getAngle())
    love.graphics.setColor(thing.color)
    love.graphics.circle('fill', 0, 0, r)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle('fill', -17, -10, 13)
    love.graphics.circle('fill', 17, -10, 13)
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.circle('fill', -15, -8, 6)
    love.graphics.circle('fill', 19, -8, 6)
    love.graphics.pop()
end

function love.draw()
    love.graphics.setShader(skyShader)
    sendSky()
    love.graphics.rectangle('fill', 0, 0, W, H)
    love.graphics.setShader()

    drawSun()
    drawMoon()

    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    love.graphics.scale(cam.zoom)
    love.graphics.translate(-cam.x, -cam.y)

    -- clouds take the colour of the sky around them, darker at night
    for _, cloud in ipairs(clouds) do
        local r, g, b = skyAt(altitudeOf(cloud.y))
        local light = 1 - 0.65 * night
        love.graphics.setColor(lerp(1, r, 0.35) * light, lerp(1, g, 0.35) * light, lerp(1, b, 0.35) * light, 0.85)
        for _, p in ipairs(cloud.puffs) do
            love.graphics.circle('fill', cloud.x + p[1], cloud.y + p[2], p[3])
        end
    end

    -- ground, darker at night
    local light = 1 - 0.6 * night
    love.graphics.setColor(0.35 * light, 0.6 * light, 0.3 * light)
    love.graphics.rectangle('fill', -20000, 0, 40000, 600)
    love.graphics.setColor(0.25 * light, 0.45 * light, 0.22 * light)
    love.graphics.rectangle('fill', -20000, 0, 40000, 18)

    for _, thing in ipairs(things) do
        if thing.isMipo then
            drawMipo(thing)
        else
            local c = thing.color
            love.graphics.setColor(c[1] * light, c[2] * light, c[3] * light)
            if thing.shape:getType() == 'circle' then
                local x, y = thing.body:getPosition()
                love.graphics.circle('fill', x, y, thing.shape:getRadius())
            else
                love.graphics.polygon('fill', thing.body:getWorldPoints(thing.shape:getPoints()))
            end
        end
    end
    love.graphics.pop()

    local from, to, t = updateStops()
    local alt = math.max(0, altitudeOf(mipo.body:getY()))
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 8, 8, 430, 86, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        'altitude %6d  (space at %d, moon at %d)\ntime %05.2f  sky %s -> %s %.0f%%  night %.2f\n' ..
        'drag things up | left/right time | t run time (%s) | 1-4 night/dawn/day/dusk\n' ..
        'wheel zoom | space reset | r reload palettes',
        alt, palettes.space, palettes.moonAltitude, hour, from, to, t * 100, night, autoTime and 'on' or 'off'), 16, 14)
end

-- input ---------------------------------------------------------------------------------
function love.mousepressed(sx, sy, button)
    if button ~= 1 then return end
    local x, y = toWorld(sx, sy)
    for _, thing in ipairs(things) do
        for _, fixture in ipairs(thing.body:getFixtures()) do
            if fixture:testPoint(x, y) then
                local joint = love.physics.newMouseJoint(thing.body, x, y)
                joint:setMaxForce(thing.body:getMass() * 20000)
                drag = { joint = joint, body = thing.body }
                return
            end
        end
    end
end

function love.mousereleased(_, _, button)
    if button == 1 and drag then
        drag.joint:destroy()
        drag = nil
    end
end

function love.wheelmoved(_, dy)
    cam.userZoom = math.max(0.2, math.min(4, cam.userZoom * (dy > 0 and 1.1 or 1 / 1.1)))
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if key == 't' then autoTime = not autoTime end
    if key == 'space' then resetMipo() end
    if key == 'r' then
        package.loaded['palettes'] = nil
        palettes = require('palettes')
        skyShader = makeShader()
    end
    local jump = ({ ['1'] = 1, ['2'] = 6.8, ['3'] = 12, ['4'] = 19.3 })[key]
    if jump then hour = jump end
end
