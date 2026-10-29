-- contact-tracker.lua
-- Which fixtures touch which, kept from beginContact/endContact (src/physics/physics-callbacks.lua),
-- so "does this leg touch another Mipo?" is a table walk instead of body:getContacts(),
-- which builds a new table and a Contact object per contact on every call (~700 calls a
-- step with 20 Mipos: two thirds of keep-angle's time).
-- Every touching pair is kept, sensors too: the questions filter as before, at the time
-- they're asked (a limb can turn into a sensor while it touches, see mipo-joint-guard).
-- A world needs these callbacks for it to know anything: specs that make their own world
-- set them with world:setCallbacks(contactTracker.beginContact, contactTracker.endContact).
local state = require('src.state')

local lib = {}

-- [body] = { [otherFixture] = { [ownFixture] = true } }. On state, so a hot reload keeps it;
-- weak keys, so destroyed bodies drop out.
state.touching = state.touching or setmetatable({}, { __mode = 'k' })

local function add(body, own, other)
    local byOther = state.touching[body]
    if not byOther then
        byOther = setmetatable({}, { __mode = 'k' })
        state.touching[body] = byOther
    end
    local owns = byOther[other]
    if not owns then
        owns = {}
        byOther[other] = owns
    end
    owns[own] = true
end

local function remove(body, own, other)
    local byOther = state.touching[body]
    local owns = byOther and byOther[other]
    if owns then
        owns[own] = nil
        if next(owns) == nil then byOther[other] = nil end
    end
end

function lib.beginContact(fix1, fix2)
    add(fix1:getBody(), fix1, fix2)
    add(fix2:getBody(), fix2, fix1)
end

function lib.endContact(fix1, fix2)
    remove(fix1:getBody(), fix1, fix2)
    remove(fix2:getBody(), fix2, fix1)
end

-- Does `test(ownFixture, otherFixture, otherBody, arg)` hold for any fixture pair touching
-- `body`? Pairs whose fixtures were destroyed without an endContact (the bridge switches
-- the callbacks off while it deletes) are dropped here.
function lib.any(body, test, arg)
    local byOther = state.touching[body]
    if not byOther then return false end
    for other, owns in pairs(byOther) do
        if other:isDestroyed() then
            byOther[other] = nil
        else
            for own in pairs(owns) do
                if own:isDestroyed() then
                    owns[own] = nil
                elseif test(own, other, other:getBody(), arg) then
                    return true
                end
            end
        end
    end
    return false
end

-- Forget everything (a new world).
function lib.reset()
    state.touching = setmetatable({}, { __mode = 'k' })
end

return lib
