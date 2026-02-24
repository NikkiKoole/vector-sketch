-- src/game-loop.lua
-- Fixed-timestep game loop for LÖVE2D
-- Extracted from main.lua (Phase 6.3)

local state = require 'src.state'

local lib = {}

--- Returns a love.run() function with fixed-timestep physics,
--- panic detection, and adaptive sleep.
function lib.createFixedTimestepRun(tickrate)
    tickrate = tickrate or (1 / 60)

    return function()
        if love.math then love.math.setRandomSeed(123456) end
        if love.load then love.load(arg) end
        if love.timer then love.timer.step() end

        local MAX_ACCUMULATOR = 0.25  -- never try to catch up more than 250ms
        local MAX_STEPS_PER_FRAME = 4 -- hard cap to prevent death spiral
        local PANIC_HORIZON = 30      -- frames before we say "we're saturated"
        local panicFrames = 0
        local adaptiveSleep = 0       -- additional sleep to soften render rate under load

        local previous = love.timer.getTime()
        local lag = 0.0

        -- carry for deterministic speed multiplier (optional)
        local speedCarry = 0.0

        return function()
            -- pump events
            if love.event then
                love.event.pump()
                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then return a or 0 end
                    end
                    love.handlers[name](a, b, c, d, e, f) -- luacheck: ignore 143
                end
            end

            -- time
            local now = love.timer.getTime()
            local elapsed = now - previous
            previous = now

            -- accumulate but clamp to avoid spiral
            lag = lag + elapsed
            if lag > MAX_ACCUMULATOR then
                lag = MAX_ACCUMULATOR
            end

            -- how many base steps this frame?
            local dt = tickrate
            local steps = math.floor(lag / dt)

            -- deterministic speed multiplier => convert fractional speed to extra integer steps
            local s = (state and state.world and state.world.speedMultiplier) or 1.0
            speedCarry = speedCarry + (s - 1.0) * steps
            if speedCarry >= 1.0 then
                local extra = math.floor(speedCarry)
                steps = steps + extra
                speedCarry = speedCarry - extra
            elseif speedCarry <= -1.0 then
                local skip = math.floor(-speedCarry)
                steps = math.max(0, steps - skip)
                speedCarry = speedCarry + skip
            end

            -- cap steps to avoid runaway
            local didPanic = false
            if steps > MAX_STEPS_PER_FRAME then
                steps = MAX_STEPS_PER_FRAME
                -- drop anything older than our budget
                lag = lag - steps * dt
                -- ditch remaining backlog (panic): render latest state
                lag = 0
                didPanic = true
                print('did panic!')
            else
                lag = lag - steps * dt
            end

            -- do fixed updates
            for _ = 1, steps do
                if love.update then love.update(dt) end
            end

            -- render with interpolation (alpha in [0,1))
            if love.graphics and love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()
                if love.draw then love.draw(lag / dt) end
                love.graphics.present()
            end

            -- simple adaptive backoff: if we keep panicking, lower render cadence a tad
            if didPanic then
                panicFrames = panicFrames + 1
                if panicFrames >= PANIC_HORIZON then
                    adaptiveSleep = math.min(adaptiveSleep + 0.001, 0.008) -- up to ~125 FPS → ~60–80 FPS
                end
            else
                panicFrames = math.max(0, panicFrames - 1)
                if panicFrames == 0 then
                    adaptiveSleep = math.max(0, adaptiveSleep - 0.001)
                end
            end

            if love.timer then
                -- tiny sleep to yield + adaptive backoff under sustained load
                love.timer.sleep(0.001 + adaptiveSleep)
            end
        end
    end
end

--- Original simple fixed-timestep loop (historical reference).
--- Superseded by createFixedTimestepRun which adds panic detection
--- and adaptive sleep.
--[[
function lib.createSimpleFixedTimestepRun(tickrate)
    tickrate = tickrate or (1 / 60)

    return function()
        if love.math then
            love.math.setRandomSeed(os.time())
        end

        if love.load then love.load(arg) end

        local previous = love.timer.getTime()
        local lag = 0.0
        while true do
            local current = love.timer.getTime()
            local elapsed = current - previous
            previous = current
            lag = lag + elapsed * ((state and state.world and state.world.speedMultiplier) or 1.0)

            if love.event then
                love.event.pump()
                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            return a
                        end
                    end
                    love.handlers[name](a, b, c, d, e, f)
                end
            end

            while lag >= tickrate do
                if love.update then love.update(tickrate) end
                lag = lag - tickrate
            end

            if love.graphics and love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()
                if love.draw then love.draw(lag / tickrate) end
                love.graphics.present()
            end
        end
    end
end
--]]

return lib
