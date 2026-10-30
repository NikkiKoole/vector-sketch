-- slide-sound.lua
-- A slide whistle for anything riding a slide (props.makeSlide, label 'slide'): one held
-- synth note per rider. Height on the slide is the pitch (riding down falls "wheeeooo";
-- dragging a Mipo up and down plays it like a real slide whistle) and speed along the
-- surface is the volume, so a rider at rest is quiet. The rider's own velocity is used,
-- not the slip at the contact, so rolling things (balls, the skateboard) whistle too.
-- Driven by src/sound.lua.

local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local units = require('src.physics-units')

local lib = {}

lib.enabled = false       -- off: a continuous whistle on the slide was too much (tried pipe + cassette, 2026-10-27)
lib.patch = 'whistle'     -- src/synth.lua patch
lib.minSpeed = 120        -- along the slide (world units/s at 100 px per metre); slower riders are quiet
lib.loudSpeed = 1200      -- full volume; a ride down the dollhouse slide reaches ~600-1200
lib.topNote = 84          -- pitch at the top of the slide...
lib.bottomNote = 67       -- ...and at the bottom
lib.grace = 0.12          -- seconds a rider may bounce off or slow down before the note stops
lib.rescanEvery = 1       -- seconds between looking for slide bodies

-- On `state` so a hot reload doesn't orphan sounding notes.
state.slideSound = state.slideSound or { riders = {}, slides = {}, scannedAt = -math.huge }
local S = state.slideSound

local function scanSlides(world)
    S.slides = {}
    for _, body in ipairs(world:getBodies()) do
        local ud = body:getUserData()
        if ud and ud.thing and ud.thing.label == 'slide' then
            local top, bottom = math.huge, -math.huge
            for _, fixture in ipairs(body:getFixtures()) do
                local _, y0, _, y1 = fixture:getBoundingBox()
                top, bottom = math.min(top, y0), math.max(bottom, y1)
            end
            table.insert(S.slides, { body = body, top = top, bottom = bottom })
        end
    end
end

-- One note per Mipo (it touches with several parts) and per skateboard (two wheels).
local function riderKey(body)
    local instance = mipoRegistry.getFromBody(body)
    if instance then return 'mipo:' .. instance.id end
    local ud = body:getUserData()
    if ud and ud.thing and ud.thing.label == 'skateboard-wheel' then
        for _, joint in ipairs(body:getJoints()) do
            local a, b = joint:getBodies()
            local other = a == body and b or a
            local otherUd = other:getUserData()
            if otherUd and otherUd.thing and otherUd.thing.label == 'skateboard' then return other end
        end
    end
    return body
end

-- The fastest touching part of every rider: { speed, x, y, slide }.
local function findRiders()
    local found = {}
    for _, slide in ipairs(S.slides) do
        if not slide.body:isDestroyed() then
            for _, contact in ipairs(slide.body:getContacts()) do
                local x, y = contact:getPositions()
                if contact:isTouching() and x then
                    local fixtureA, fixtureB = contact:getFixtures()
                    local other = fixtureA:getBody() == slide.body and fixtureB or fixtureA
                    if not other:isSensor() then
                        local body = other:getBody()
                        local nx, ny = contact:getNormal()
                        local vx, vy = body:getLinearVelocity()
                        local speed = units.toReferenceSpeed(math.abs(-vx * ny + vy * nx)) -- along the surface tangent
                        local key = riderKey(body)
                        if not found[key] or speed > found[key].speed then
                            found[key] = { speed = speed, x = x, y = y, slide = slide }
                        end
                    end
                end
            end
        end
    end
    return found
end

local function lerpClamped(x, inMin, inMax, outMin, outMax)
    local t = math.max(0, math.min(1, (x - inMin) / (inMax - inMin)))
    return outMin + (outMax - outMin) * t
end

function lib.update(synth, now)
    local world = state.physicsWorld
    if not (lib.enabled and world) then
        for key, rider in pairs(S.riders) do
            synth.noteOff(rider.handle)
            S.riders[key] = nil
        end
        return
    end
    if now - S.scannedAt > lib.rescanEvery then
        scanSlides(world)
        S.scannedAt = now
    end

    for key, hit in pairs(findRiders()) do
        if hit.speed >= lib.minSpeed then
            local rider = S.riders[key]
            local midi = lerpClamped(hit.y, hit.slide.top, hit.slide.bottom, lib.topNote, lib.bottomNote)
            local vol = lerpClamped(hit.speed, lib.minSpeed, lib.loudSpeed, 1.5, 6)
            if rider and rider.handle then
                synth.noteSet(rider.handle, midi, vol, hit.x, hit.y)
            else
                rider = { handle = synth.noteOn(lib.patch, math.floor(midi + 0.5), vol, hit.x, hit.y) }
                synth.noteSet(rider.handle, midi) -- the fractional pitch
                S.riders[key] = rider
            end
            rider.fastAt = now
        end
    end

    for key, rider in pairs(S.riders) do
        if now - rider.fastAt > lib.grace then
            synth.noteOff(rider.handle)
            S.riders[key] = nil
        end
    end
end

return lib
