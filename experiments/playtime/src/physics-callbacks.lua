local bridge = require 'vendor.claude-bridge'
local script = require 'src.script'
local state = require 'src.state'

local function beginContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('beginContact', fix1, fix2, contact)
    script.call('beginContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function endContact(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('endContact', fix1, fix2, contact)
    script.call('endContact', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function preSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    script.call('preSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

local function postSolve(fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
    if bridge.destroying_body then return end
    bridge.logCollision('postSolve', fix1, fix2, contact, n_impulse1, tan_impulse1)
    script.call('postSolve', fix1, fix2, contact, n_impulse1, tan_impulse1, n_impulse2, tan_impulse2)
end

-- Expose callbacks on state so the bridge can access them
state.physicsCallbacks = { beginContact, endContact, preSolve, postSolve }

return { beginContact, endContact, preSolve, postSolve }
