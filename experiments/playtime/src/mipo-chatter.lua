-- mipo-chatter.lua — Mipos standing around talk to each other: now and then one
-- says MI and a different one answers PO (puppet-maker2's intro,
-- docs/PUPPETMAKER-SOUND.md P5). Needs two free Mipos in view: not held, not
-- dazed, not already talking. Only while playing.
local lib = {}

local state = require('src.state')
local mipoRegistry = require('src.mipo-registry')
local mipoVoice = require('src.mipo-voice')
local mipoActions = require('src.mipo-actions')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local camera = require('src.camera')

lib.enabled = true
lib.gap = { 6, 15 }          -- seconds between conversations
lib.answerGap = { 0.2, 1.2 } -- seconds from the MI to the PO
lib.pitch = { 0.8, 1.2 }     -- on top of each Mipo's own voice pitch
-- puppet-maker2's odds, samples from assets/voices/puppetmaker: { key, weight }
lib.MI = { { 'mi', 80 }, { 'mi2', 16 }, { 'mo', 4 } }
lib.PO = { { 'po', 80 }, { 'po2', 16 }, { 'pi', 4 } }

-- On state so a hot reload doesn't restart a conversation halfway.
state.chatter = state.chatter or { nextAt = nil, answer = nil }
local C = state.chatter

local function between(range)
    return range[1] + love.math.random() * (range[2] - range[1])
end

local function pick(odds)
    local total = 0
    for _, o in ipairs(odds) do total = total + o[2] end
    local r = love.math.random() * total
    for _, o in ipairs(odds) do
        r = r - o[2]
        if r <= 0 then return o[1] end
    end
    return odds[1][1]
end

local function heldMipos()
    local held = {}
    for _, body in ipairs(pointerJoints.getInteractedWithPointer()) do
        local instance = mipoRegistry.getFromBody(body)
        if instance then held[instance.id] = true end
    end
    return held
end

-- The Mipos that could talk right now (in view, not held, dazed or talking),
-- leaving out the one with id `except`.
function lib.free(except)
    local cam = camera.getInstance()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    local held = heldMipos()
    local result = {}
    for id, instance in pairs(mipoRegistry.getAll()) do
        local torso = instance.parts and instance.parts.torso1
        local body = torso and torso.body
        if id ~= except and not held[id] and body and not body:isDestroyed()
            and not mipoActions.isDazed(instance) and not mipoVoice.isTalking(instance) then
            local x, y = body:getPosition()
            if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
                result[#result + 1] = instance
            end
        end
    end
    return result
end

local function say(instance, odds)
    return mipoVoice.say(instance, 'puppetmaker', pick(odds), between(lib.pitch))
end

function lib.update()
    if not lib.enabled or state.world.paused then
        C.answer = nil
        return
    end
    local t = love.timer.getTime()
    if C.answer then
        if t < C.answer.at then return end
        local others = lib.free(C.answer.from)
        C.answer = nil
        if #others > 0 then say(others[love.math.random(#others)], lib.PO) end
        C.nextAt = t + between(lib.gap)
        return
    end
    C.nextAt = C.nextAt or t + between(lib.gap)
    if t < C.nextAt then return end
    local free = lib.free()
    if #free < 2 then
        C.nextAt = t + 1 -- look again soon
        return
    end
    local first = free[love.math.random(#free)]
    say(first, lib.MI)
    C.answer = { from = first.id, at = t + between(lib.answerGap) }
end

return lib
