Some things to think about / Google:

* You have a song, but it needs to be turned into data — basically, you need to know at which beat each note or circle should appear and be clicked.
* The core gameplay is just matching those beats with player input, then adding scoring and feedback.
* Most of the rest of the work is polish — visuals, effects, menus, etc.
* Right now you don’t have a GitHub repository for people to look at. Having one (even with a rough prototype) will make it much easier for potential contributors to jump in.

If you don’t have a programmer to work with, you could try ChatGPT for “vibe coding” — just talking it through what you want and letting it suggest code, step by step. I made a small starting point for you here: . I literally just gave ChatGPT your Reddit post and it generated this (untested). It might be a fun way to start building while you wait for collaborators.

    -- Minimal LÖVE rhythm prototype
    -- Features: BPM clock, falling notes, hit windows, latency offset, scoring/combo
    -- Drop this into main.lua and run with love2d

    local bpm           = 120
    local secondsPerBeat= 60 / bpm
    local approachTime  = 1.5        -- seconds from spawn to hit line
    local approachPixels= 350
    local hitLineY      = 420
    local laneX         = { 220, 320, 420, 520 }
    local latencyOffset = 0.00       -- seconds (+ means hit a little earlier)
    local audio, songStart, started  = nil, 0, false

    -- Simple chart in beats (you can replace with JSON later):
    -- Each note = { beat = <number>, lane = 1..4 }
    local chart = {
      {beat=4, lane=1}, {beat=4.5, lane=2}, {beat=5, lane=3}, {beat=5.5, lane=4},
      {beat=6, lane=1}, {beat=6.5, lane=2}, {beat=7, lane=3}, {beat=7.5, lane=4},
      {beat=8, lane=1}, {beat=8.25, lane=2}, {beat=8.5, lane=3}, {beat=8.75, lane=4},
    }

    -- Convert beats -> seconds
    for _,n in ipairs(chart) do
      n.time = n.beat * secondsPerBeat
      n.hit  = false
    end

    -- Input map per lane
    local keysForLane = {
      [1] = {"a","left"},
      [2] = {"s","down"},
      [3] = {"k","up"},
      [4] = {"l","right"},
    }

    -- Judgement windows (seconds)
    local judge = {
      {name="PERFECT", window=0.050, score=1000},
      {name="GREAT",   window=0.090, score= 700},
      {name="GOOD",    window=0.120, score= 400},
      {name="MISS",    window=0.180, score=   0},
    }

    local events   = {}  -- recent judgements to display
    local score    = 0
    local combo    = 0
    local bestCombo= 0

    local function musicTime()
      if not started then return 0 end
      return (love.timer.getTime() - songStart) + latencyOffset
    end

    local function currentBeat()
      return musicTime() / secondsPerBeat
    end

    local function spawnable(note)
      -- We render notes when they’re within approachTime of being hit
      return (note.time - musicTime()) <= approachTime
    end

    local function tryHit(lane)
      -- Find the closest unhit note in that lane within the widest window
      local mt = musicTime()
      local bestI, bestErr = nil, 1e9
      for i,n in ipairs(chart) do
        if (not n.hit) and n.lane == lane then
          local err = math.abs(mt - n.time)
          if err < bestErr then
            bestErr = err; bestI = i
          end
        end
      end
      if not bestI then return end

      -- Judge
      local n = chart[bestI]
      local used = false
      for j=1,#judge do
        local jg = judge[j]
        if bestErr <= jg.window then
          n.hit = true
          score = score + jg.score
          if jg.name == "MISS" then
            combo = 0
          else
            combo = combo + 1
            if combo > bestCombo then bestCombo = combo end
          end
          table.insert(events, {text=jg.name, x=laneX[lane], y=hitLineY-40, t=0})
          used = true
          break
        end
      end

      -- If outside MISS window, count as miss & break combo
      if not used and bestErr > judge[#judge].window then
        combo = 0
        table.insert(events, {text="MISS", x=laneX[lane], y=hitLineY-40, t=0})
      end
    end

    function love.load()
      love.window.setMode(760, 520, {resizable=false})
      love.graphics.setFont(love.graphics.newFont(16))

      -- Replace "song.ogg" with your audio file (put it next to main.lua).
      -- If not present, the game runs silent.
      if love.filesystem.getInfo("song.ogg") then
        audio = love.audio.newSource("song.ogg", "stream")
      end
    end

    function love.keypressed(k)
      -- lane hits
      for lane=1,4 do
        for _,kk in ipairs(keysForLane[lane]) do
          if k == kk then tryHit(lane) end
        end
      end

      if k == "space" then
        -- Start/Restart song
        if audio then audio:stop(); audio:play() end
        songStart = love.timer.getTime()
        started   = true
        score, combo, bestCombo, events = 0, 0, 0, {}
        for _,n in ipairs(chart) do n.hit = false end
      end

      -- Quick latency nudge (±5ms)
      if k == "q" then latencyOffset = latencyOffset - 0.005 end
      if k == "e" then latencyOffset = latencyOffset + 0.005 end
    end

    function love.update(dt)
      -- Fade out floating judgement text
      for i=#events,1,-1 do
        local ev = events[i]
        ev.t = ev.t + dt
        if ev.t > 0.8 then table.remove(events, i) end
      end
    end

    function love.draw()
      love.graphics.clear(22/255, 24/255, 28/255)

      -- Lanes
      for i=1,4 do
        love.graphics.setColor(0.18, 0.2, 0.25)
        love.graphics.rectangle("fill", laneX[i]-40, 60, 80, 360)
      end

      -- Hit line
      love.graphics.setColor(1,1,1)
      love.graphics.line(160, hitLineY, 600, hitLineY)

      -- Notes (simple falling rectangles)
      local mt = musicTime()
      for _,n in ipairs(chart) do
        if (not n.hit) and spawnable(n) then
          local tRem = math.max(0, n.time - mt)
          local y = hitLineY - (tRem/approachTime) * approachPixels
          love.graphics.setColor(0.9, 0.9, 0.1)
          love.graphics.rectangle("fill", laneX[n.lane]-30, y-18, 60, 36, 6, 6)
        end
      end

      -- Floating judgements
      for _,ev in ipairs(events) do
        local a = 1.0 - (ev.t/0.8)
        love.graphics.setColor(1,1,1, math.max(0,a))
        love.graphics.print(ev.text, ev.x-24, ev.y - ev.t*40)
      end

      -- HUD
      love.graphics.setColor(1,1,1)
      love.graphics.print(("Beat: %.2f"):format(currentBeat()), 20, 20)
      love.graphics.print(("Score: %d  Combo: %d  Best: %d"):format(score, combo, bestCombo), 20, 44)
      love.graphics.print(("Latency: %+d ms (Q/E)"):format(math.floor(latencyOffset*1000)), 20, 68)
      love.graphics.print("Press SPACE to start. Lanes: A/S/K/L or arrows.", 20, 92)
    end

Then i noticed it obviously didnt look like your circle thing, so i just gave it the screenshot of your circles and told it to try again using that image to figure out the looks and mechanics.

    -- LÖVE Rhythm Circles (4-pad, concentric/approach style)
    -- Save as main.lua and run with LÖVE (https://love2d.org/)
    -- Keys: Left pad=A, Right pad=L, Top pad=K/Up, Bottom pad=S/Down
    -- Press SPACE to start song/restart. Adjust latency with Q/E (+/-5ms).

    -----------------------
    -- CONFIG
    -----------------------
    local bpm                       = 120
    local secondsPerBeat            = 60 / bpm
    local latencyOffset             = 0.00 -- (+) = hit a little earlier

    -- Layout
    local W, H                      = 900, 640
    local cx, cy                    = W / 2, H / 2
    local gridSpacing               = 160

    -- Pad radii
    local hitR                      = 68 -- target hit circle radius
    local approachR0                = 120 -- starting radius of approach circle
    local approachTime              = 1.20 -- seconds for approach circle to shrink to hitR
    local lineWidthBase             = 2.0

    -- Colors (r,g,b)
    local colBG                     = { 22 / 255, 24 / 255, 28 / 255 }
    local colPadBase                = { 0.70, 0.72, 0.74 } -- neutral ring color
    local colTop                    = { 0.80, 0.80, 0.82 }
    local colLeft                   = { 0.85, 0.20, 0.20 } -- red
    local colRight                  = { 0.85, 0.20, 0.20 } -- red
    local colBottom                 = { 0.62, 0.52, 0.86 } -- purple

    -- Judgement windows (seconds)
    local judge                     = {
        { name = "PERFECT", window = 0.050, score = 1000 },
        { name = "GREAT", window = 0.085, score = 700 },
        { name = "GOOD",  window = 0.120, score = 400 },
        { name = "MISS",  window = 0.180, score = 0 },
    }

    -----------------------
    -- STATE
    -----------------------
    local pads                      = {
        -- lane=1..4, pos, color, input keys
        { lane = 1, x = cx - gridSpacing, y = cy,     col = colLeft, keys = { "a", "left" } },
        { lane = 2, x = cx + gridSpacing, y = cy,     col = colRight, keys = { "l", "right" } },
        { lane = 3, x = cx,         y = cy - gridSpacing, col = colTop, keys = { "k", "up" } },
        { lane = 4, x = cx,         y = cy + gridSpacing, col = colBottom, keys = { "s", "down" } },
    }

    local audio, songStart, started = nil, 0, false
    local score, combo, bestCombo   = 0, 0, 0
    local floatTexts                = {}        -- hit feedback
    local flashTimers               = { 0, 0, 0, 0 } -- brief glow when hit

    -- Minimal demo chart (beats)
    local chart                     = {
        -- a simple ramp through the four pads
        { beat = 4.0, lane = 1 }, { beat = 4.5, lane = 2 }, { beat = 5.0, lane = 3 }, { beat = 5.5, lane = 4 },
        { beat = 6.0, lane = 1 }, { beat = 6.5, lane = 2 }, { beat = 7.0, lane = 3 }, { beat = 7.5, lane = 4 },
        -- little burst
        { beat = 8.0, lane = 1 }, { beat = 8.25, lane = 2 }, { beat = 8.5, lane = 3 }, { beat = 8.75, lane = 4 },
        { beat = 9.00, lane = 1 }, { beat = 9.50, lane = 2 }, { beat = 10.0, lane = 3 }, { beat = 10.5, lane = 4 },
    }

    -- Convert beats to seconds and mark unhit
    for _, n in ipairs(chart) do
        n.time = n.beat * secondsPerBeat
        n.hit  = false
    end

    -----------------------
    -- HELPERS
    -----------------------
    local function setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

    local function musicTime()
        if not started then return 0 end
        return (love.timer.getTime() - songStart) + latencyOffset
    end

    local function drawRing(x, y, r, thickness, segments)
        love.graphics.setLineWidth(thickness or lineWidthBase)
        love.graphics.circle("line", x, y, r, segments or 64)
    end

    local function approachRadius(tRemaining)
        -- tRemaining: seconds until scheduled time (>=0)
        local p = 1 - math.min(1, math.max(0, tRemaining / approachTime)) -- 0..1
        -- ease slightly
        p = 1 - (1 - p) * (1 - p)
        return approachR0 + (hitR - approachR0) * p
    end

    local function laneFromKey(k)
        for i, p in ipairs(pads) do
            for _, kk in ipairs(p.keys) do
                if kk == k then return p.lane end
            end
        end
    end

    local function judgeHit(lane)
        local t              = musicTime()
        local bestI, bestErr = nil, 1e9
        for i, n in ipairs(chart) do
            if (not n.hit) and n.lane == lane then
                local err = math.abs(t - n.time)
                if err < bestErr then bestErr, bestI = err, i end
            end
        end
        if not bestI then return end
        local n = chart[bestI]
        -- Determine judgement
        local used = false
        for j = 1, #judge do
            local J = judge[j]
            if bestErr <= J.window then
                n.hit = true
                score = score + J.score
                if J.name == "MISS" then
                    combo = 0
                else
                    combo = combo + 1; if combo > bestCombo then bestCombo = combo end
                end
                table.insert(floatTexts, { text = J.name, x = pads[lane].x, y = pads[lane].y - hitR - 30, t = 0 })
                flashTimers[lane] = 0.18
                used = true
                break
            end
        end
        if not used and bestErr > judge[#judge].window then
            combo = 0
            table.insert(floatTexts, { text = "MISS", x = pads[lane].x, y = pads[lane].y - hitR - 30, t = 0 })
        end
    end

    -----------------------
    -- LOVE CALLBACKS
    -----------------------
    function love.load()
        love.window.setMode(W, H, { resizable = false })
        love.graphics.setFont(love.graphics.newFont(16))
        if love.filesystem.getInfo("song.ogg") then
            audio = love.audio.newSource("song.ogg", "stream")
        end
    end

    function love.keypressed(k)
        if k == "space" then
            if audio then
                audio:stop(); audio:play()
            end
            songStart, started = love.timer.getTime(), true
            score, combo, bestCombo, floatTexts = 0, 0, 0, {}
            for _, n in ipairs(chart) do n.hit = false end
            return
        end
        if k == "q" then latencyOffset = latencyOffset - 0.005 end
        if k == "e" then latencyOffset = latencyOffset + 0.005 end

        local lane = laneFromKey(k)
        if lane then judgeHit(lane) end
    end

    function love.update(dt)
        -- decay pad flashes
        for i = 1, #flashTimers do
            flashTimers[i] = math.max(0, flashTimers[i] - dt)
        end
        -- float texts
        for i = #floatTexts, 1, -1 do
            local ev = floatTexts[i]; ev.t = ev.t + dt
            if ev.t > 0.8 then table.remove(floatTexts, i) end
        end
    end

    function love.draw()
        love.graphics.clear(colBG[1], colBG[2], colBG[3])

        -- pads (base concentric rings)
        local t = musicTime()
        for i, p in ipairs(pads) do
            -- subtle glow on hit
            local glow = flashTimers[i] > 0 and (flashTimers[i] / 0.18) or 0
            local aGlow = 0.25 * glow
            -- neutral rings
            setColor(colPadBase, 0.5); drawRing(p.x, p.y, hitR + 26, 1.5)
            setColor(colPadBase, 0.35); drawRing(p.x, p.y, hitR + 8, 1.5)
            setColor(colPadBase, 0.25); drawRing(p.x, p.y, hitR + 40, 1.5)
            -- inner hit ring (lane color)
            setColor(p.col, 0.9); love.graphics.setLineWidth(3); drawRing(p.x, p.y, hitR, 3)
            -- faint colored outline (glow)
            setColor(p.col, aGlow); love.graphics.setLineWidth(10); drawRing(p.x, p.y, hitR + 14, 10)
        end
        love.graphics.setLineWidth(lineWidthBase)

        -- approach circles for imminent notes (shrink toward hitR)
        for _, n in ipairs(chart) do
            if not n.hit then
                local dtRemain = n.time - t
                if dtRemain <= approachTime and dtRemain >= -judge[#judge].window then
                    local p = pads[n.lane]
                    local r = approachRadius(math.max(0, dtRemain))
                    setColor(p.col, 0.9)
                    love.graphics.setLineWidth(2.5)
                    drawRing(p.x, p.y, r, 2.5, 96)
                    -- optional double echo ring
                    setColor(p.col, 0.35)
                    drawRing(p.x, p.y, r + 10, 1.5, 96)
                end
            end
        end

        -- floating judgement labels
        for _, ev in ipairs(floatTexts) do
            local alpha = 1 - (ev.t / 0.8)
            setColor({ 1, 1, 1 }, math.max(0, alpha))
            love.graphics.print(ev.text, ev.x - 28, ev.y - ev.t * 40)
        end

        -- HUD
        setColor({ 1, 1, 1 })
        love.graphics.print(("Beat: %.2f"):format(t / secondsPerBeat), 20, 20)
        love.graphics.print(("Score: %d  Combo: %d  Best: %d"):format(score, combo, bestCombo), 20, 44)
        love.graphics.print(("Latency: %+d ms (Q/E)"):format(math.floor(latencyOffset * 1000)), 20, 68)
        love.graphics.print("SPACE: start   A/S/K/L or arrows to hit pads", 20, 92)
    end

This is vibe-coding, i just let the ai write this code for me without touching or even looking at the code, there are a lot of issues with this, it's not a sustainable way to write and scale software, you need an understanding of the code you have, but for now it might be a nice place to start and learn and play around.

anyway, i hope it helps, good luck with your project.
