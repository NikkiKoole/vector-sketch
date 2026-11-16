-- windup: wind-up toys on a tabletop — turn a key and let go: Mipos waddle and hop, a car zooms off, a top spins, a jack-in-the-box pops, a music box plays.
-- The key and its spring are their own piece (scripts/spikes/windup-key.lua): a key on any body; drag round it to
-- wind (clockwise; the ratchet clicks), let go and the spring's power (0..1) runs the toy until it's empty. Wind
-- past full: *sproing*. Honest physics: Mipos walk by mipoWalk.drive (feet push only on something), the car's
-- wheels are motors, the top is held up by a torque as long as it spins (a gyroscope's stand-in) and topples
-- when it slows, the jack is a spring joint.
--   Mipos: waddler (walks), hopper (hops), drummer (stands, arms bang), jumper (walks, jumps now and then).
--     Wound they tense (crouch, grit, shiver); picked up while running their legs keep going in the air.
--   car: two wheels on wheel joints, the motor's speed from the spring. It drives off the table.
--   top: spins up straight, wobbles more as it slows, then falls over. Wind it again and it stands up.
--   jack-in-the-box: a crank (it only winds): each click a note of Pop Goes the Weasel; on "pop" the lid flies
--     open and the clown comes up on a spring. Winding again pushes him back in.
--   music box: wound, it plays Twinkle Twinkle, slowing down as the spring runs out; a little dancer turns.
--
-- play mode: drag round a key to wind it; grab things as always.
-- keys: m a Mipo at the mouse   k the kind of the Mipo nearest the mouse   r reset   space wind them all

local s = {}

local windupKey = love.filesystem.load('scripts/spikes/windup-key.lua')()
local walk = mipoWalk
local TABLE_Y = 0
local TABLE_X1, TABLE_X2 = -3800, 3800
local FLOOR_Y = 1300
local HALF = 7500
local KINDS = { 'waddler', 'hopper', 'drummer', 'jumper' }
local tune = { speed = 2.4, unwind = 0.75 }

local function sd()
    state.windup = state.windup or { toys = {}, things = {}, bodies = {}, mipos = {}, input = {} }
    return state.windup
end

local function alive(body) return body and not body:isDestroyed() end
local function hide(body)
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
    local d = sd()
    d.bodies[#d.bodies + 1] = body
end

---------------------------------------------------------------- Mipo toys

local function torsoOf(inst) return inst.parts.torso1.body end

local function torsoSize(inst)
    local hw, hh = 60, 80
    for _, fixture in ipairs(torsoOf(inst):getFixtures()) do
        if not fixture:isSensor() then
            local shape = fixture:getShape()
            if shape:getType() == 'polygon' then
                local pts = { shape:getPoints() }
                for i = 1, #pts, 2 do
                    hw, hh = math.max(hw, math.abs(pts[i])), math.max(hh, math.abs(pts[i + 1]))
                end
            elseif shape:getType() == 'circle' then
                local cx, cy = shape:getPoint()
                hw = math.max(hw, math.abs(cx) + shape:getRadius())
                hh = math.max(hh, math.abs(cy) + shape:getRadius())
            end
        end
    end
    return hw, hh
end

local function heldByHand(inst)
    for _, part in pairs(inst.parts) do
        if alive(part.body) and getPJAttachedTo(part.body) then return true end
    end
    return false
end

-- an arm or leg steered to a world angle, as a muscle (equal and opposite on the torso)
local function steer(inst, partName, angle, strong)
    local part = inst.parts[partName]
    if not (part and alive(part.body)) then return end
    if strong then -- the drummer's arms: against what else holds them (60 hardly moved them)
        mipoActions.steerJointToward(torsoOf(inst), part.body, angle, 400, 25, 4000)
    else
        mipoActions.steerJointToward(torsoOf(inst), part.body, angle, 60, 9, 260)
    end
end

local function mipoRun(toy, power, dt)
    local inst, key = toy.inst, toy.key
    local now = love.timer.getTime()
    toy.t = toy.t + dt
    toy.boost = math.max(0, (toy.boost or 0) - dt)
    if toy.spinAt and now >= toy.spinAt then -- overwound: it turns round and back
        toy.dir, toy.spinAt = -toy.dir, toy.boost > 0.4 and now + 0.45 or nil
    end
    local left = math.min(1, key.spring / 1.2) -- slows over the last turn or so
    local start = 0.75 + 0.5 * math.min(1, (key.wound0 or 0) / key.full)
    local jerk = 0.8 + 0.2 * (math.sin(toy.t * 2 * math.pi * 2.5) > 0 and 1 or -1) -- the clockwork's stutter
    local speed = tune.speed * start * (0.3 + 0.7 * left) * jerk * (toy.boost > 0 and 2.2 or 1)
    local torso = torsoOf(inst)
    local held = heldByHand(inst)
    if toy.kind == 'drummer' then
        walk.drive(inst, nil)
        local bang = math.sin(toy.t * 2 * math.pi * (1 + 0.8 * left)) > 0 and 1 or 0 -- slow enough for the arms to follow
        local a = torso:getAngle()
        steer(inst, 'luarm', a - (0.3 + 1.9 * bang), true)
        steer(inst, 'ruarm', a + (0.3 + 1.9 * bang), true)
        steer(inst, 'llarm', a - (0.6 + 2.2 * bang), true)
        steer(inst, 'rlarm', a + (0.6 + 2.2 * bang), true)
    elseif not held then
        walk.drive(inst, toy.dir * speed, toy.kind == 'hopper' and 'hop' or 'walk')
        if toy.kind == 'jumper' then
            toy.jumpAt = toy.jumpAt or now + 1.5
            if now >= toy.jumpAt then
                walk.jump(inst, toy.dir * 300)
                toy.jumpAt = now + 1.6 + love.math.random()
            end
        end
    else -- in the hand the legs keep going, the classic wind-up thing
        local a = torso:getAngle()
        local swing = math.sin(toy.t * 2 * math.pi * 2.2) * 0.7
        steer(inst, 'luleg', a + swing)
        steer(inst, 'ruleg', a - swing)
    end
    if power > 0 and not toy.happy then
        toy.happy = true
        walk.squat(inst, false)
        mipoEmotion.set(inst, 'happy', 0.7)
    end
end

local function addMipoToy(x, y, kind, dir)
    local d = sd()
    local inst = mipoKit.spawn(d.mipos, x, y)
    if not inst then return end
    local hw, hh = torsoSize(inst)
    local toy = { inst = inst, kind = kind or KINDS[love.math.random(#KINDS)], dir = dir or 1, t = 0, hw = hw, hh = hh }
    toy.key = windupKey.new {
        body = torsoOf(inst), x = -toy.dir * hw * 0.85, y = -hh * 0.15, out = { -toy.dir, 0 }, size = 1.7,
        unwind = tune.unwind, label = 'mipo',
        run = function(_, power, dt) mipoRun(toy, power, dt) end,
        stop = function()
            walk.drive(inst, nil) -- a last step and it stands (the stopping step)
            mipoEmotion.set(inst, 'neutral')
            toy.happy, toy.boost, toy.spinAt = nil, 0, nil
        end,
        overwind = function()
            mipoEmotion.set(inst, 'surprised', 1, 1.5)
            camera.shake(12, 0.25)
            toy.boost = 1.6
            if toy.kind == 'waddler' or toy.kind == 'jumper' then toy.spinAt = love.timer.getTime() + 0.5 end
        end,
        tense = function(_, fill) -- wound, not let go: down into a crouch, gritted, a shiver that grows
            walk.squat(inst, fill > 0.12)
            if fill > 0.12 then mipoEmotion.set(inst, 'angry', 0.3 + 0.6 * fill) end
            local m = torsoOf(inst):getMass()
            torsoOf(inst):applyLinearImpulse((love.math.random() * 2 - 1) * m * 60 * fill * fill, 0)
            walk.turnTo(inst, toy.dir > 0 and 'right' or 'left')
        end,
    }
    d.toys[#d.toys + 1] = toy
    return toy
end

---------------------------------------------------------------- the car

local function addCar(x, dir)
    local d = sd()
    local car = { kind = 'car', dir = dir }
    local chassis = love.physics.newBody(world, x, TABLE_Y - 160, 'dynamic')
    love.physics.newFixture(chassis, love.physics.newPolygonShape(-150, 30, -140, -40, -60, -90, 70, -90, 140, -30, 150, 30), 1)
    car.chassis, car.wheels, car.joints = chassis, {}, {}
    hide(chassis)
    for _, wx in ipairs({ -95, 95 }) do
        local wheel = love.physics.newBody(world, x + wx, TABLE_Y - 100, 'dynamic')
        love.physics.newFixture(wheel, love.physics.newCircleShape(55), 1):setFriction(1.2)
        local joint = love.physics.newWheelJoint(chassis, wheel, x + wx, TABLE_Y - 100, 0, 1)
        joint:setSpringFrequency(5)
        joint:setSpringDampingRatio(0.7)
        -- enough to push the car along at a few metres a second² (torque is in LÖVE's units: N·m × meter²)
        joint:setMaxMotorTorque(60000 * (love.physics.getMeter() / 200) ^ 2)
        joint:setMotorEnabled(false)
        hide(wheel)
        car.wheels[#car.wheels + 1], car.joints[#car.joints + 1] = wheel, joint
    end
    car.key = windupKey.new {
        body = chassis, x = -dir * 120, y = -40, out = { -dir, -0.3 }, size = 1.6, stem = 90, full = 4, unwind = 0.6,
        label = 'car',
        run = function(_, power)
            for _, joint in ipairs(car.joints) do
                if not joint:isDestroyed() then
                    joint:setMotorEnabled(true)
                    joint:setMotorSpeed(car.dir * (6 + 22 * power))
                end
            end
        end,
        stop = function()
            for _, joint in ipairs(car.joints) do
                if not joint:isDestroyed() then joint:setMotorEnabled(false) end
            end
        end,
    }
    d.things[#d.things + 1] = car
end

local function drawCar(car)
    if not alive(car.chassis) then return end
    love.graphics.push()
    love.graphics.translate(car.chassis:getPosition())
    love.graphics.rotate(car.chassis:getAngle())
    love.graphics.setColor(0.85, 0.25, 0.2)
    love.graphics.polygon('fill', -150, 30, -140, -40, -60, -90, 70, -90, 140, -30, 150, 30)
    love.graphics.setColor(0.75, 0.9, 1)
    love.graphics.polygon('fill', -50, -78, 60, -78, 115, -32, -60, -32)
    love.graphics.setColor(0.35, 0.12, 0.1)
    love.graphics.setLineWidth(8)
    love.graphics.polygon('line', -150, 30, -140, -40, -60, -90, 70, -90, 140, -30, 150, 30)
    love.graphics.line(5, -78, 5, -32)
    love.graphics.pop()
    for _, wheel in ipairs(car.wheels) do
        if alive(wheel) then
            local wx, wy = wheel:getPosition()
            local a = wheel:getAngle()
            love.graphics.setColor(0.2, 0.2, 0.22)
            love.graphics.circle('fill', wx, wy, 55)
            love.graphics.setColor(0.8, 0.8, 0.75)
            love.graphics.circle('fill', wx, wy, 24)
            love.graphics.setColor(0.2, 0.2, 0.22)
            love.graphics.line(wx, wy, wx + math.cos(a) * 24, wy + math.sin(a) * 24)
        end
    end
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the spinning top

local TOP = { 0, 120, -115, -5, -100, -45, -40, -70, 40, -70, 100, -45, 115, -5 }

local function addTop(x)
    local d = sd()
    local top = { kind = 'top', spin = 0, phase = 0, t = 0 }
    local body = love.physics.newBody(world, x, TABLE_Y - 125, 'dynamic')
    love.physics.newFixture(body, love.physics.newPolygonShape(unpack(TOP)), 1):setFriction(0.25)
    love.physics.newFixture(body, love.physics.newRectangleShape(0, -110, 30, 80), 1)
    body:setAngle(1.2) -- it starts lying on its side
    hide(body)
    top.body = body
    top.key = windupKey.new {
        body = body, x = 0, y = -150, out = { 0, -1 }, size = 1.4, stem = 60, full = 5, unwind = 0.45, label = 'top',
        quiet = true,
        run = function(_, power, dt)
            top.t = top.t + dt
            top.spin = power
            -- a gyroscope's stand-in: upright as long as it spins fast, wobbling more as it slows
            local wobble = (1 - power) * 0.35 * math.sin(top.t * 5)
            local diff = ((wobble - body:getAngle()) + math.pi) % (2 * math.pi) - math.pi
            local strength = power > 0.12 and (0.4 + power) or 0
            local alpha = (120 * diff - 14 * body:getAngularVelocity()) * strength
            body:applyTorque(body:getInertia() * alpha)
            -- it wanders a little, as a spinning top does
            body:applyForce(math.sin(top.t * 0.9) * body:getMass() * 150 * power, 0)
        end,
        stop = function() top.spin = 0 end,
    }
    d.things[#d.things + 1] = top
end

local function drawTop(top)
    local body = top.body
    if not alive(body) then return end
    top.phase = top.phase + (top.spin or 0) * 0.9
    love.graphics.push()
    love.graphics.translate(body:getPosition())
    love.graphics.rotate(body:getAngle())
    love.graphics.setColor(0.4, 0.3, 0.2)
    love.graphics.rectangle('fill', -15, -150, 30, 80)
    love.graphics.setColor(0.98, 0.85, 0.3)
    love.graphics.polygon('fill', unpack(TOP))
    -- stripes that slide round as it spins (they squash at the sides: it's round)
    love.graphics.setColor(0.25, 0.45, 0.85)
    for k = 0, 3 do
        local u = math.sin(top.phase + k * math.pi / 2)
        local w = 18 * math.cos(top.phase + k * math.pi / 2)
        if w > 0 then love.graphics.polygon('fill', u * 100 - w, -30, u * 100 + w, -30, u * 10 + w * 0.2, 100, u * 10 - w * 0.2, 100) end
    end
    love.graphics.setColor(0.4, 0.25, 0.1)
    love.graphics.setLineWidth(7)
    love.graphics.polygon('line', unpack(TOP))
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the jack-in-the-box

-- Pop Goes the Weasel, one note a click; the last phrase's first note is the pop
local WEASEL = { 55, 60, 60, 62, 62, 64, 67, 64, 60, 55, 60, 60, 62, 62, 64, 60,
    55, 60, 60, 62, 62, 64, 67, 64, 60, 69, 62, 65, 64, 60 }
local POP_AT = 26 -- the 'pop' (A)

local BOX_W, BOX_H = 380, 360

local function setJackIn(jack, inside)
    if jack.spring:isDestroyed() then return end
    if inside then
        jack.spring:setLength(80)
        jack.spring:setFrequency(6)
        jack.spring:setDampingRatio(0.9)
    else
        jack.spring:setLength(760)
        jack.spring:setFrequency(2.6)
        jack.spring:setDampingRatio(0.08) -- boing boing
    end
end

local function popJack(jack)
    jack.popped, jack.poppedAt = true, love.timer.getTime()
    jack.gesture = sd().input.winding -- cranking on in the same turn doesn't push him back in
    setJackIn(jack, false)
    windupKey.play('pop', 1)
    camera.shake(14, 0.3)
    if alive(jack.lid) then
        jack.lid:applyAngularImpulse(-jack.lid:getInertia() * 14)
        jack.lid:applyLinearImpulse(0, -jack.lid:getMass() * 900)
    end
end

local function addJack(x)
    local d = sd()
    local jack = { kind = 'jack', note = 0 }
    local by = TABLE_Y - BOX_H / 2
    local box = love.physics.newBody(world, x, by, 'dynamic')
    local hw, hh = BOX_W / 2, BOX_H / 2
    love.physics.newFixture(box, love.physics.newRectangleShape(0, hh - 15, BOX_W, 30), 4)      -- bottom
    love.physics.newFixture(box, love.physics.newRectangleShape(-hw + 15, 0, 30, BOX_H), 4)    -- sides
    love.physics.newFixture(box, love.physics.newRectangleShape(hw - 15, 0, 30, BOX_H), 4)
    hide(box)
    local lid = love.physics.newBody(world, x, by - hh - 12, 'dynamic')
    love.physics.newFixture(lid, love.physics.newRectangleShape(BOX_W + 10, 24), 1)
    hide(lid)
    local hinge = love.physics.newRevoluteJoint(box, lid, x - hw, by - hh, false)
    hinge:setLimits(-2.4, 0)
    hinge:setLimitsEnabled(true)
    local head = love.physics.newBody(world, x, by + 40, 'dynamic')
    love.physics.newFixture(head, love.physics.newCircleShape(95), 0.3)
    hide(head)
    local spring = love.physics.newDistanceJoint(box, head, x, by + hh - 30, x, by + 40, false)
    -- he comes straight up and goes straight down: a slide in the box, the spring along it
    local slide = love.physics.newPrismaticJoint(box, head, x, by + 40, 0, -1, false)
    slide:setLimits(-40, 800)
    slide:setLimitsEnabled(true)
    jack.box, jack.lid, jack.head, jack.hinge, jack.spring, jack.slide = box, lid, head, hinge, spring, slide
    setJackIn(jack, true)
    jack.key = windupKey.new {
        body = box, x = hw, y = 30, out = { 1, 0 }, size = 1.5, stem = 70, full = 1e9, notch = 1 / 6,
        keepWound = true, crank = true, colour = { 0.85, 0.2, 0.25 }, label = 'jack',
        onNotch = function()
            if jack.popped then -- winding again (a new turn): he goes back in, the tune starts over
                local g = sd().input.winding
                if (g and g == jack.gesture) or love.timer.getTime() - jack.poppedAt < 1 then return end
                jack.popped, jack.note = false, 0
                setJackIn(jack, true)
                jack.closeUntil = love.timer.getTime() + 1.2 -- the lid comes down after him (a hinge motor)
                if not jack.hinge:isDestroyed() then
                    jack.hinge:setMotorEnabled(true)
                    jack.hinge:setMotorSpeed(3)
                    jack.hinge:setMaxMotorTorque(jack.lid:getInertia() * 400)
                end
                return
            end
            jack.note = jack.note + 1
            windupKey.note(WEASEL[(jack.note - 1) % #WEASEL + 1] + 12, 0.8)
            if jack.note == POP_AT then popJack(jack) end
        end,
    }
    d.things[#d.things + 1] = jack
end

local function drawJack(jack)
    if not alive(jack.box) then return end
    local bx, by = jack.box:getWorldPoint(0, BOX_H / 2 - 30)
    -- the spring and the clown's head (inside the box until it pops)
    if alive(jack.head) then
        local hx, hy = jack.head:getPosition()
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.setLineWidth(10)
        local n, pts = 9, {}
        for k = 0, n do
            local u = k / n
            local side = (k % 2 == 0) and 0 or (k % 4 == 1 and 40 or -40)
            pts[#pts + 1] = bx + (hx - bx) * u + side
            pts[#pts + 1] = by + (hy - by) * u
        end
        love.graphics.line(pts)
        love.graphics.setColor(1, 0.92, 0.85)
        love.graphics.circle('fill', hx, hy, 95)
        love.graphics.setColor(0.9, 0.2, 0.25)
        love.graphics.circle('fill', hx, hy + 5, 22) -- the nose
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.circle('fill', hx - 35, hy - 25, 10)
        love.graphics.circle('fill', hx + 35, hy - 25, 10)
        love.graphics.arc('line', 'open', hx, hy + 20, 50, 0.3, math.pi - 0.3)
        love.graphics.setColor(0.3, 0.6, 0.9) -- the hat
        love.graphics.polygon('fill', hx - 70, hy - 70, hx + 70, hy - 70, hx, hy - 210)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.circle('fill', hx, hy - 210, 22)
    end
    -- the box (over the head while he's in it)
    love.graphics.push()
    love.graphics.translate(jack.box:getPosition())
    love.graphics.rotate(jack.box:getAngle())
    love.graphics.setColor(0.3, 0.55, 0.85)
    love.graphics.rectangle('fill', -BOX_W / 2, -BOX_H / 2, BOX_W, BOX_H)
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.polygon('fill', 0, -90, 70, 0, 0, 90, -70, 0)
    love.graphics.setColor(0.15, 0.25, 0.45)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle('line', -BOX_W / 2, -BOX_H / 2, BOX_W, BOX_H)
    love.graphics.pop()
    if alive(jack.lid) then
        love.graphics.push()
        love.graphics.translate(jack.lid:getPosition())
        love.graphics.rotate(jack.lid:getAngle())
        love.graphics.setColor(0.85, 0.2, 0.25)
        love.graphics.rectangle('fill', -(BOX_W + 10) / 2, -12, BOX_W + 10, 24)
        love.graphics.setColor(0.4, 0.08, 0.1)
        love.graphics.rectangle('line', -(BOX_W + 10) / 2, -12, BOX_W + 10, 24)
        love.graphics.pop()
    end
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the music box

-- Twinkle Twinkle: midi note, beats
local TWINKLE = {
    { 72, 1 }, { 72, 1 }, { 79, 1 }, { 79, 1 }, { 81, 1 }, { 81, 1 }, { 79, 2 },
    { 77, 1 }, { 77, 1 }, { 76, 1 }, { 76, 1 }, { 74, 1 }, { 74, 1 }, { 72, 2 },
    { 79, 1 }, { 79, 1 }, { 77, 1 }, { 77, 1 }, { 76, 1 }, { 76, 1 }, { 74, 2 },
    { 79, 1 }, { 79, 1 }, { 77, 1 }, { 77, 1 }, { 76, 1 }, { 76, 1 }, { 74, 2 },
}
local MB_W, MB_H = 420, 240

local function addMusicBox(x)
    local d = sd()
    local mb = { kind = 'musicbox', beat = 0, nextNote = 1, nextAt = 0, dance = 0, power = 0 }
    local body = love.physics.newBody(world, x, TABLE_Y - MB_H / 2, 'dynamic')
    love.physics.newFixture(body, love.physics.newRectangleShape(MB_W, MB_H), 3):setFriction(0.9)
    hide(body)
    mb.body = body
    mb.key = windupKey.new {
        body = body, x = -MB_W / 2, y = 20, out = { -1, 0 }, size = 1.5, stem = 70, full = 5, unwind = 0.22,
        quiet = true, colour = { 0.85, 0.85, 0.9 }, label = 'musicbox',
        run = function(_, power, dt)
            mb.power = power
            -- the tune slows as the spring runs down (and stops on its last turn)
            local tempo = 3.2 * (0.25 + 0.75 * math.min(1, power * 1.6))
            mb.beat = mb.beat + dt * tempo
            mb.dance = mb.dance + dt * tempo * 1.2
            while mb.beat >= mb.nextAt do
                local note = TWINKLE[mb.nextNote]
                windupKey.note(note[1], 0.8)
                mb.nextAt = mb.nextAt + note[2]
                mb.nextNote = mb.nextNote % #TWINKLE + 1
            end
        end,
        stop = function() mb.power = 0 end,
    }
    d.things[#d.things + 1] = mb
end

local function drawMusicBox(mb)
    local body = mb.body
    if not alive(body) then return end
    love.graphics.push()
    love.graphics.translate(body:getPosition())
    love.graphics.rotate(body:getAngle())
    -- the dancer on top: turning, so she narrows and widens (a fake 3D turn)
    local turn = math.cos(mb.dance * math.pi)
    love.graphics.setColor(0.95, 0.7, 0.8)
    love.graphics.polygon('fill', -60 * turn, -MB_H / 2 - 20, 60 * turn, -MB_H / 2 - 20, 0, -MB_H / 2 - 130)
    love.graphics.setColor(0.95, 0.85, 0.75)
    love.graphics.circle('fill', 0, -MB_H / 2 - 160, 32)
    love.graphics.setColor(0.4, 0.25, 0.3)
    love.graphics.setLineWidth(6)
    love.graphics.line(-50 * turn, -MB_H / 2 - 120, 50 * turn, -MB_H / 2 - 150) -- her arms
    love.graphics.line(0, -MB_H / 2 - 20, 0, -MB_H / 2)
    -- the box
    love.graphics.setColor(0.55, 0.3, 0.45)
    love.graphics.rectangle('fill', -MB_W / 2, -MB_H / 2, MB_W, MB_H, 18)
    love.graphics.setColor(0.95, 0.8, 0.4)
    for k = -1, 1 do love.graphics.circle('fill', k * 120, 0, 18) end
    love.graphics.setColor(0.3, 0.12, 0.25)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle('line', -MB_W / 2, -MB_H / 2, MB_W, MB_H, 18)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- the scene

local function allKeys()
    local d, keys = sd(), {}
    for _, toy in ipairs(d.toys) do keys[#keys + 1] = toy.key end
    for _, thing in ipairs(d.things) do keys[#keys + 1] = thing.key end
    return keys
end

local function destroyAll()
    local d = sd()
    for _, toy in ipairs(d.toys) do
        if mipoKit.isAlive(toy.inst) then characterManager.removeCharacter(toy.inst) end
    end
    for _, body in ipairs(d.bodies) do
        if state.hiddenBodies then state.hiddenBodies[body] = nil end
        if alive(body) then body:destroy() end -- its joints go with it
    end
    d.toys, d.things, d.bodies, d.mipos, d.input = {}, {}, {}, {}, {}
end

local function makeTable()
    local top = love.physics.newBody(world, (TABLE_X1 + TABLE_X2) / 2, TABLE_Y + 40, 'static')
    love.physics.newFixture(top, love.physics.newRectangleShape(TABLE_X2 - TABLE_X1, 80)):setFriction(0.9)
    hide(top)
    local floor = love.physics.newBody(world, 0, FLOOR_Y + 50, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(HALF * 2, 100)):setFriction(0.9)
    hide(floor)
    for _, side in ipairs({ -1, 1 }) do
        local wall = love.physics.newBody(world, side * (HALF + 50), FLOOR_Y - 2500, 'static')
        love.physics.newFixture(wall, love.physics.newRectangleShape(100, 5000))
        hide(wall)
    end
end

-- everything new; the Mipos come in later updates, one a frame (a build of five Mipos at once is heavy)
local function resetAll()
    destroyAll()
    makeTable()
    addCar(-1000, 1)
    addTop(0)
    addJack(1300)
    addMusicBox(2700)
    sd().pending = { { -3200, 'waddler', 1 }, { -2200, 'hopper', 1 } }
end

function s.onStart()
    worldState.paused = false
    local midis = {}
    for _, m in ipairs(WEASEL) do midis[#midis + 1] = m + 12 end
    for _, n in ipairs(TWINKLE) do midis[#midis + 1] = n[1] end
    windupKey.preload(midis)
    local d = sd()
    local any = false
    for _, body in ipairs(d.bodies) do any = any or alive(body) end
    if not any then resetAll() end
    camera.setBounds(-HALF, -3600, HALF, FLOOR_Y + 1500)
    camera.zoomTo(0.12, 0.4)
end

function s.onUnload()
    destroyAll()
end

local panelRect = { 20, 20, 300, 0 }
local function overPanel()
    if ui.isPanelFolded('•• windup ••') then return false end
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local d = sd()
    if d.pending and #d.pending > 0 then
        local p = table.remove(d.pending, 1)
        addMipoToy(p[1], TABLE_Y - 700, p[2], p[3])
    end
    local mx, my = mouseWorldPos()
    windupKey.input(allKeys(), d.input, function() return not overPanel() end, mx, my,
        state.playMode and love.mouse.isDown(1))
    local keep = {}
    for _, toy in ipairs(d.toys) do
        if mipoKit.isAlive(toy.inst) then
            toy.key.x, toy.key.out[1] = -toy.dir * toy.hw * 0.85, -toy.dir -- the key stays on its back
            windupKey.update(toy.key, dt)
            keep[#keep + 1] = toy
        end
    end
    d.toys = keep
    for _, thing in ipairs(d.things) do
        windupKey.update(thing.key, dt)
        if thing.closeUntil and love.timer.getTime() > thing.closeUntil then
            thing.closeUntil = nil
            if not thing.hinge:isDestroyed() then thing.hinge:setMotorEnabled(false) end
        end
    end
end

-- From the bridge: s.wind(label or index into allKeys, turns, hold)
function s.wind(which, turns, hold)
    local keys = allKeys()
    local key = type(which) == 'number' and keys[which]
    if not key then
        for _, k in ipairs(keys) do if k.label == which then key = k break end end
    end
    if not key then return end
    local steps = math.ceil(turns * 24)
    for _ = 1, steps do windupKey.wind(key, turns / steps * 2 * math.pi) end
    if not hold then windupKey.release(key) end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local d = sd()
    if key == 'm' then
        local mx = mouseWorldPos()
        d.pending = d.pending or {}
        d.pending[#d.pending + 1] = { mx, KINDS[love.math.random(#KINDS)], love.math.random() < 0.5 and -1 or 1 }
    elseif key == 'r' then
        resetAll()
    elseif key == 'space' then
        for i, k in ipairs(allKeys()) do
            if not k.keepWound then s.wind(i, k.full * 0.8) end
        end
    elseif key == 'k' then
        local mx, my = mouseWorldPos()
        local best, bestD
        for _, toy in ipairs(d.toys) do
            local x, y = torsoOf(toy.inst):getPosition()
            local dd = (x - mx) ^ 2 + (y - my) ^ 2
            if not bestD or dd < bestD then best, bestD = toy, dd end
        end
        if best then
            for i, k in ipairs(KINDS) do
                if k == best.kind then best.kind = KINDS[i % #KINDS + 1] break end
            end
        end
    end
end

---------------------------------------------------------------- drawing

local WOOD, WOOD_DARK, WALL, FLOOR = { 0.72, 0.5, 0.3 }, { 0.52, 0.34, 0.2 }, { 0.93, 0.89, 0.8 }, { 0.62, 0.55, 0.48 }

function s.drawBelow()
    local d = state.windup
    if not d then return end
    love.graphics.setColor(WALL)
    love.graphics.rectangle('fill', -HALF, -3600, HALF * 2, FLOOR_Y + 3600)
    love.graphics.setColor(FLOOR)
    love.graphics.rectangle('fill', -HALF, FLOOR_Y, HALF * 2, 1500)
    love.graphics.setColor(WOOD_DARK)
    for _, x in ipairs({ TABLE_X1 + 120, TABLE_X2 - 220 }) do
        love.graphics.rectangle('fill', x, TABLE_Y + 80, 100, FLOOR_Y - TABLE_Y - 80)
    end
    love.graphics.setColor(WOOD)
    love.graphics.rectangle('fill', TABLE_X1, TABLE_Y, TABLE_X2 - TABLE_X1, 80)
    love.graphics.setColor(WOOD_DARK)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle('line', TABLE_X1, TABLE_Y, TABLE_X2 - TABLE_X1, 80)
    for x = TABLE_X1 + 300, TABLE_X2 - 100, 700 do love.graphics.line(x, TABLE_Y + 25, x + 240, TABLE_Y + 30) end
    love.graphics.setLineWidth(1)
    -- the Mipos' keys behind them (in their backs)
    for _, toy in ipairs(d.toys) do windupKey.draw(toy.key) end
    for _, thing in ipairs(d.things) do
        if thing.kind == 'car' then drawCar(thing)
        elseif thing.kind == 'top' then drawTop(thing)
        elseif thing.kind == 'jack' then drawJack(thing)
        elseif thing.kind == 'musicbox' then drawMusicBox(thing) end
        windupKey.draw(thing.key)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local d = state.windup
    if not (d and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 6
    local h = BH * rows + pad * (rows + 1) + 20
    local x0, y0 = 20, 20
    panelRect[3], panelRect[4] = w, h
    ui.panel(x0, y0, w, h, '•• windup ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'wind them all (space)') then s.onKeyPress('space') end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (r)') then resetAll() end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('windupspeed', x, y, 140, 0.4, 4, tune.speed)
        if v then tune.speed = v + 0 end
        ui.label(x + 240, y, 'Mipo speed')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('windupunwind', x, y, 140, 0.2, 2, tune.unwind)
        if v then
            tune.unwind = v + 0
            for _, toy in ipairs(d.toys) do toy.key.unwind = tune.unwind end
        end
        ui.label(x + 240, y, 'Mipo unwind')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local parts = {}
        for _, toy in ipairs(d.toys) do parts[#parts + 1] = toy.kind:sub(1, 3) .. string.format(' %.1f', toy.key.spring) end
        ui.label(x, y, table.concat(parts, '  '))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'turn a key  k kind  m Mipo')
    end)
end

return s
