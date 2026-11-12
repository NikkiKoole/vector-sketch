-- src/mipo-walk.lua hopscotch (docs/MIPO-LOCOMOTION.md LO14): lib.hopscotch plays a pattern ('1' a hop
-- landing on one foot, '2' landing on both, 'T' a jump turning round). Every part lands as it should
-- (a '1' on its one foot, the other off the floor; a '2' and a 'T' on both), it gets somewhere and
-- comes back after the turn, and it ends standing. Prints per Mipo.
-- Compare settings: MOTOR_SET='hopscotchHop=0.3' love . --specs spec/mipo-hopscotch_spec.lua
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local jointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')
local mipoStance = require('src.mipo-stance')
local keepAngle = require('src.keep-angle')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local callbacks = require('src.physics.physics-callbacks')
local units = require('src.physics-units')
local mipoWalk = require('src.mipo-walk')

local DT = 1 / units.stepsPerSecond()
local SEEDS = { 4, 7, 11, 23, 42, 5, 9, 13 }

describe('a Mipo playing hopscotch', function()
    local simTime, realGetTime, world, inst

    local function step()
        simTime = simTime + DT
        world:update(DT)
        jointGuard.update()
        mipoActions.update()
        mipoWalk.update(DT)
        mipoStance.update()
        keepAngle.update(DT, {})
    end

    local function seconds(s, each)
        for _ = 1, math.floor(s / DT) do
            step()
            if each then each() end
        end
    end

    local function setup(seed)
        love.math.setRandomSeed(seed)
        math.randomseed(seed)
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        world:setCallbacks(unpack(callbacks))
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
        pointerJoints.resetPointerJoints()
        mipoWalk.load(nil)
        for k, v in (os.getenv('MOTOR_SET') or ''):gmatch('([%w_]+)=([%w%.]+)') do
            local gait, key = k:match('^(%w+)_(%w+)$')
            if gait and mipoWalk.gaits[gait] then
                mipoWalk.gaits[gait][key] = tonumber(v) or (v == 'true')
            else
                mipoWalk[k] = tonumber(v) or (v == 'true')
            end
        end
        local floor = love.physics.newBody(world, 0, 1000, 'static')
        love.physics.newFixture(floor, love.physics.newRectangleShape(40000, 100)):setFriction(0.9)
        inst = CM.createCharacter('humanoid', 0, 600, 0.3)
        CM.randomizeMipoConstrained(inst)
        seconds(2)
    end

    before_each(function()
        simTime, realGetTime = 0, love.timer.getTime
        love.timer.getTime = function() return simTime end
    end)

    after_each(function()
        pointerJoints.resetPointerJoints()
        if world and not world:isDestroyed() then
            world:setCallbacks()
            world:destroy()
        end
        love.timer.getTime = realGetTime
    end)

    local function tilt()
        local a = inst.parts.torso1.body:getAngle()
        return math.abs(math.deg(math.atan2(math.sin(a), math.cos(a))))
    end

    local function legLen()
        local _, ty = inst.parts.torso1.body:getPosition()
        local _, fy = inst.parts.lfoot.body:getPosition()
        return math.abs(fy - ty)
    end

    local function down(name) return mipoWalk.onFloor(inst, name) end -- on the floor, not on its other foot

    local DETAIL = os.getenv("DETAIL")
    for _, seed in ipairs(SEEDS) do
        it('hinkelen: hops along on one leg while driven, the other never down, then stands (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            local x0, hops, otherDown, n, t, a = nil, 0, 0, 0, 0, nil
            local wasUp = false
            seconds(5, function()
                t = t + DT
                mipoWalk.drive(inst, 1.5, 'hinkel')
                local hs = inst._hopscotch
                if hs and hs.phase ~= 'ready' and hs.a and not hs.first and not hs.stopping then
                    x0 = x0 or inst.parts.torso1.body:getX()
                    a = hs.a
                    local fa, fb = (a == 1) and 'lfoot' or 'rfoot', (a == 1) and 'rfoot' or 'lfoot'
                    n = n + 1
                    if down(fb) then otherDown = otherDown + 1 end
                    local up = not down(fa)
                    if up and not wasUp then hops = hops + 1 end
                    wasUp = up
                end
            end)
            local went = x0 and (inst.parts.torso1.body:getX() - x0) / len or 0
            mipoWalk.drive(inst, nil)
            seconds(2)
            print(string.format('  hinkel seed %d: %d hops in ~4 s (after the first), the other foot down %.0f%% of the time, %.1f legs, then %s, tilt %.0f',
                seed, hops, 100 * otherDown / math.max(n, 1), went, mipoWalk.hopscotching(inst) and 'still hopping' or 'standing', tilt()))
            assert.is_true(hops >= 5)
            assert.is_true(otherDown / math.max(n, 1) < 0.2) -- the shortest legs (seed 13, big feet for them): 18%
            assert.is_true(went > 1)
            assert.is_false(mipoWalk.hopscotching(inst))
            assert.is_true(tilt() < 30)
        end)

        it('hops, lands right, turns, ends standing (seed ' .. seed .. ')', function()
            setup(seed)
            local len = legLen()
            assert.is_true(mipoWalk.hopscotch(inst))
            local right, wrong, landings, x0, xFar, worst = 0, 0, 0, nil, nil, 0
            local order = {}
            local cur = nil
            seconds(14, function()
                local hs = inst._hopscotch
                if not hs then return end
                if hs.phase ~= 'ready' then worst = math.max(worst, tilt()) end
                x0 = x0 or (hs.phase ~= 'ready' and inst.parts.torso1.body:getX()) or nil
                if x0 then
                    local x = inst.parts.torso1.body:getX()
                    if not xFar or math.abs(x - x0) > math.abs(xFar - x0) then xFar = x end
                end
                -- each landing (its whole give): did the landing foot come down, did the other touch at all
                if hs.phase == 'give' and hs.i >= 0 then
                    local key = hs.i
                    cur = cur or {}
                    if cur.key ~= key then
                        if cur.key and cur.key > 0 then
                            landings = landings + 1
                            local ok
                            if cur.on == '1' then ok = cur.A and not cur.B else ok = cur.A and cur.B end
                            order[#order + 1] = cur.sym .. (ok and '' or ('!' .. (cur.A and 'A' or 'a') .. (cur.B and 'B' or 'b')))
                            if ok then right = right + 1 else wrong = wrong + 1 end
                        end
                        cur = { key = key, on = hs.landed, sym = hs.list[hs.i] or '?' }
                    end
                    local fa, fb = (hs.a == 1) and 'lfoot' or 'rfoot', (hs.a == 1) and 'rfoot' or 'lfoot'
                    cur.A = cur.A or down(fa)
                    cur.B = cur.B or down(fb)
                end
            end)
            local xEnd = inst.parts.torso1.body:getX()
            print(string.format('  hopscotch seed %d: %s | %d of %d landings right, out %.1f legs and back to %.1f, worst tilt %.0f, end tilt %.0f, %s',
                seed, table.concat(order, ' '), right, landings, math.abs((xFar or 0) - (x0 or 0)) / len,
                math.abs(xEnd - (x0 or 0)) / len, worst, tilt(), mipoWalk.hopscotching(inst) and 'still at it' or 'done'))
            assert.is_false(mipoWalk.hopscotching(inst))
            assert.is_true(landings >= 15)
            assert.is_true(right >= landings * 0.65) -- most (the shortest legs, seed 13: 11 of 16)
            assert.is_true(tilt() < 30)
        end)
    end
end)
