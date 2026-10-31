-- src/game-loop.lua
-- Fixed-timestep game loop for LÖVE2D
-- Extracted from main.lua (Phase 6.3)

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
        local MAX_STEPS_PER_FRAME = math.ceil(4 / 60 / tickrate - 1e-9) -- hard cap to prevent death spiral
                                                                         -- (4 at 60 steps a second)
        local PANIC_HORIZON = 30      -- frames before we say "we're saturated"
        local panicFrames = 0
        local adaptiveSleep = 0       -- additional sleep to soften render rate under load

        local previous = love.timer.getTime()
        local lag = 0.0

        -- carry for deterministic speed multiplier (optional)

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

            -- time. The step is only for love.timer.getFPS/getDelta (the HUD, the bridge):
            -- without it they read 0 here; the loop keeps its own clock below
            if love.timer then love.timer.step() end
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
            -- the speed slider is not handled here but in the physics step (lib.physicsSteps):
            -- skipping whole updates for slow motion also skipped input (BUG6)

            -- cap steps to avoid runaway
            local didPanic = false
            if steps > MAX_STEPS_PER_FRAME then
                steps = MAX_STEPS_PER_FRAME
                -- drop anything older than our budget
                lag = lag - steps * dt
                -- ditch remaining backlog (panic): render latest state
                lag = 0
                didPanic = true
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

            -- tiny sleep to yield + adaptive backoff under sustained load. Not with vsync:
            -- present() already waits, and the 1 ms (~1.2 on macOS) came out of a frame
            -- that has to fit in 16.7 ms or drop to 30 fps
            if love.timer and (adaptiveSleep > 0 or not (love.window and love.window.getVSync() ~= 0)) then
                love.timer.sleep(0.001 + adaptiveSleep)
            end
        end
    end
end

-- How main steps the physics world for one update of dt at the speed slider's
-- speed: the step shrinks for slow motion, and fast speeds take more steps so a
-- Box2D step is never longer than dt (big steps tunnel and explode).
function lib.physicsSteps(dt, speed)
    local steps = math.max(1, math.ceil(speed - 1e-9))
    return steps, dt * speed / steps
end

return lib
