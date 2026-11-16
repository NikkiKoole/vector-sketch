-- fours-optimize: let the computer find the all-fours numbers (docs/ALL-FOURS.md; Nikki 2026-11-16: "is this
-- also something we can solve with some better ai? so mipos really learn to move through the world?").
-- An evolution strategy (a (mu/mu_w, lambda)-ES with a step size per number and cumulative step-size
-- adaptation, the diagonal cousin of CMA-ES) over scripts/spikes/all-fours.lua's tuning: each candidate walks
-- a batch of random Mipos (lib.prepare's: two torsos, even limbs) headless, faster than real time, scored on
-- how well they went. The look stays Nikki's: the body's tip (bend) and the head (look) aren't searched.
--
--   OPT_OUT=/tmp/fours.txt love . --specs claudetools/fours-optimize_spec.lua
--   OPT_GENS=12 OPT_LAMBDA=10 OPT_SEEDS=4 OPT_SECONDS=5 OPT_SEED=1   (defaults)
--
-- Score (lower is better), per Mipo, averaged: 2 x how far off the speed asked it went (a share of it),
-- the body's mean tip away from level / 30 degrees, its worst / 90, and 3 for a fall (the body more than 60
-- degrees off level, or the head on the floor). The best numbers are checked again on Mipos it never saw.

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
local contactTracker = require('src.physics.contact-tracker')
local units = require('src.physics-units')
local mipoWalk = require('src.mipo-walk')

local fours = love.filesystem.load('scripts/spikes/all-fours.lua')()

local DT = 1 / units.stepsPerSecond()
local GENS = tonumber(os.getenv('OPT_GENS') or '') or 12
local LAMBDA = tonumber(os.getenv('OPT_LAMBDA') or '') or 10
local NSEEDS = tonumber(os.getenv('OPT_SEEDS') or '') or 4
local DRIVE_S = tonumber(os.getenv('OPT_SECONDS') or '') or 5
local SEED = tonumber(os.getenv('OPT_SEED') or '') or 1
local OUT = os.getenv('OPT_OUT')

-- what's searched, and its range (the panel's)
local PARAMS = {
    { 'kp', 5, 80 }, { 'maxOmega', 1, 14 }, { 'bodyKp', 10, 250 }, { 'stride', 5, 50 }, { 'lift', 0, 90 },
    { 'legBend', 0, 1 }, { 'minBend', 0, 45 }, { 'cycle', 0.15, 1.2 }, { 'push', 0.05, 1.5 },
}

local lines = {}
local function say(fmt, ...)
    local line = string.format(fmt, ...)
    print(line)
    lines[#lines + 1] = line
    if OUT then
        local f = io.open(OUT, 'w')
        if f then f:write(table.concat(lines, '\n'), '\n') f:close() end
    end
end

local simTime, realGetTime = 0, nil
local world, inst

-- one tick in main.lua's order: the world, the scene (all fours), the systems (walk, stance), the joint guard,
-- the actions (the gaze sets the head's muscle again after all fours turned it off), the muscles
local function step()
    simTime = simTime + DT
    world:update(DT)
    fours.update(DT)
    mipoWalk.update(DT)
    mipoStance.update()
    jointGuard.update()
    mipoActions.update()
    keepAngle.update(DT, {})
end

local function seconds(s, each)
    for _ = 1, math.floor(s / DT) do
        step()
        if each and each() then return true end
    end
end

local function teardown()
    pointerJoints.resetPointerJoints()
    if world and not world:isDestroyed() then
        world:setCallbacks()
        world:destroy()
    end
    world, inst = nil, nil
end

-- one Mipo (by seed) down on all fours, walking right at the spike's speed for DRIVE_S: its score
local function trial(seed)
    simTime = 0
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(unpack(callbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    pointerJoints.resetPointerJoints()
    mipoWalk.load(nil)
    local floor = love.physics.newBody(world, 0, 1000, 'static')
    love.physics.newFixture(floor, love.physics.newRectangleShape(80000, 100)):setFriction(0.9)
    inst = CM.createCharacter('humanoid', 0, 600, 0.3)
    fours.prepare(inst)
    seconds(1.5) -- landed, standing
    fours.down(inst, 1)
    seconds(1.5) -- down
    local torso = inst.parts.torso1.body
    local H = inst._fours.height
    local want = fours.tuning.speed * H
    local x0 = torso:getX()
    fours.drive(inst, fours.tuning.speed, 'walk')
    local sum, n, worst, fell = 0, 0, 0, false
    local head = inst.parts.head and inst.parts.head.body
    local floorOnly = function(_, _, otherBody) return otherBody == floor end
    local tick = 0
    seconds(DRIVE_S, function()
        tick = tick + 1
        if os.getenv('OPT_DEBUG') and tick % math.floor(0.5 / DT) == 0 then
            local r = inst._fours
            print(string.format('  t %.1f x %.0f vx %.0f angle %.0f want %.0f phase %.2f grounded %s speed %s',
                tick * DT, torso:getX() - x0, torso:getLinearVelocity(), math.deg(torso:getAngle()), want,
                r and r.phase or -1, tostring(mipoActions.isGrounded(inst)), tostring(r and r.speed)))
        end
        local a = math.deg(torso:getAngle())
        local off = math.abs(((a - 90) + 180) % 360 - 180) -- from level, facing right
        sum, n, worst = sum + off, n + 1, math.max(worst, off)
        if off > 60 or (head and contactTracker.any(head, floorOnly)) then fell = true return true end
    end)
    local went = (torso:getX() - x0) / DRIVE_S
    local speedErr = math.min(2, math.abs(went - want) / want)
    local score = 2 * speedErr + (sum / math.max(1, n)) / 30 + worst / 90 + (fell and 3 or 0)
    teardown()
    return score, { speed = went / want, mean = sum / math.max(1, n), worst = worst, fell = fell }
end

local function setParams(x) -- x: 0..1 per param
    for i, p in ipairs(PARAMS) do
        local v = math.max(0, math.min(1, x[i]))
        fours.tuning[p[1]] = p[2] + v * (p[3] - p[2])
    end
end

local function evaluate(x, seeds)
    setParams(x)
    local total, falls, details = 0, 0, {}
    for _, s in ipairs(seeds) do
        local ok, score, d = pcall(trial, s)
        if not ok then teardown() score, d = 10, { err = tostring(score) } end
        total = total + score
        if d.fell or d.err then falls = falls + 1 end
        details[#details + 1] = d
    end
    return total / #seeds, falls, details
end

local function describeX(x)
    local parts = {}
    for i, p in ipairs(PARAMS) do
        local v = p[2] + math.max(0, math.min(1, x[i])) * (p[3] - p[2])
        parts[#parts + 1] = string.format('%s=%.3g', p[1], v)
    end
    return table.concat(parts, ' ')
end

local function gauss() -- Box-Muller
    local u1, u2 = math.max(1e-12, love.math.random()), love.math.random()
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

describe('all-fours optimizer', function()
    before_each(function()
        realGetTime = love.timer.getTime
        love.timer.getTime = function() return simTime end
    end)
    after_each(function()
        teardown()
        love.timer.getTime = realGetTime
    end)

    it('searches the all-fours numbers', function()
        local D = #PARAMS
        local seeds, heldOut = {}, {}
        for i = 1, NSEEDS do seeds[i] = 100 * SEED + i end
        for i = 1, 8 do heldOut[i] = 9000 + 100 * SEED + i end

        -- start from today's numbers
        local m = {}
        for i, p in ipairs(PARAMS) do m[i] = (fours.tuning[p[1]] - p[2]) / (p[3] - p[2]) end
        local start = {}
        for i = 1, D do start[i] = m[i] end
        local t0 = os.clock()
        local baseScore, baseFalls = evaluate(m, seeds)
        say('fours-optimize: %d numbers, %d Mipos a try, %d tries a generation, %d generations, %.1f s each walk',
            D, NSEEDS, LAMBDA, GENS, DRIVE_S)
        say('today: score %.3f, %d of %d fell  (%.1f s for one try)  %s', baseScore, baseFalls, NSEEDS,
            os.clock() - t0, describeX(m))

        -- (mu/mu_w, lambda)-ES, a step size per number, cumulative step-size adaptation
        local mu = math.floor(LAMBDA / 2)
        local w, wsum = {}, 0
        for i = 1, mu do w[i] = math.log(mu + 0.5) - math.log(i) wsum = wsum + w[i] end
        local mueff = 0
        for i = 1, mu do w[i] = w[i] / wsum mueff = mueff + w[i] ^ 2 end
        mueff = 1 / mueff
        local cs = (mueff + 2) / (D + mueff + 5)
        local ds = 1 + 2 * math.max(0, math.sqrt((mueff - 1) / (D + 1)) - 1) + cs
        local chiN = math.sqrt(D) * (1 - 1 / (4 * D) + 1 / (21 * D * D))
        local sigma, scale, ps = 0.15, {}, {}
        for i = 1, D do scale[i], ps[i] = 1, 0 end
        local best, bestScore = m, baseScore

        for gen = 1, GENS do
            local pop = {}
            for k = 1, LAMBDA do
                local z, x = {}, {}
                for i = 1, D do
                    z[i] = gauss()
                    -- reflected back into 0..1 (clamped, candidates past an edge all came out the same and the
                    -- search went flat: every try 4.045 from generation 8 on, the first run)
                    local v = m[i] + sigma * scale[i] * z[i]
                    v = v % 2
                    if v > 1 then v = 2 - v end
                    x[i] = v
                end
                local score, falls = evaluate(x, seeds)
                pop[k] = { x = x, z = z, score = score, falls = falls }
            end
            table.sort(pop, function(a, b) return a.score < b.score end)
            if pop[1].score < bestScore then best, bestScore = pop[1].x, pop[1].score end
            -- recombine the best mu, move the mean, adapt sigma by the path's length
            local zmean = {}
            for i = 1, D do
                local mi, zi = 0, 0
                for r = 1, mu do mi, zi = mi + w[r] * pop[r].x[i], zi + w[r] * pop[r].z[i] end
                m[i], zmean[i] = math.max(0, math.min(1, mi)), zi -- the centre stays in range
                ps[i] = (1 - cs) * ps[i] + math.sqrt(cs * (2 - cs) * mueff) * zmean[i]
            end
            local norm = 0
            for i = 1, D do norm = norm + ps[i] ^ 2 end
            sigma = sigma * math.exp((cs / ds) * (math.sqrt(norm) / chiN - 1))
            sigma = math.max(0.01, math.min(0.25, sigma))
            say('gen %2d: best %.3f (%d fell)  median %.3f  sigma %.3f  so far %.3f', gen, pop[1].score,
                pop[1].falls, pop[math.ceil(LAMBDA / 2)].score, sigma, bestScore)
        end

        -- the best and today's on Mipos neither saw
        local bS, bF, bD = evaluate(best, heldOut)
        local tS, tF, tD = evaluate(start, heldOut)
        local function summary(d)
            local sp, mean = 0, 0
            for _, r in ipairs(d) do sp, mean = sp + (r.speed or 0), mean + (r.mean or 0) end
            return string.format('speed %.0f%% of asked, tip %.0f deg on average', 100 * sp / #d, mean / #d)
        end
        say('')
        say('on 8 new Mipos:  today %.3f, %d fell, %s', tS, tF, summary(tD))
        say('                 best  %.3f, %d fell, %s', bS, bF, summary(bD))
        say('best numbers: %s', describeX(best))
        say('(as lua) %s', (describeX(best):gsub(' ', ', ')))
        assert.is_true(true)
    end)
end)
