function love.conf(t)
    t.identity = 'omp-bench' -- results in the save folder too (a phone has no console)
    t.window.title = 'OMP bench'
    t.window.width = 1000 -- same window as Playtime (conf.lua there)
    t.window.height = 800
    t.window.highdpi = false
    t.window.vsync = 0 -- frame times must not be capped by the display (iOS keeps vsync on)
    t.window.msaa = 4  -- as Playtime
    t.modules.joystick = false
    -- as Playtime on a phone: 667x375 points on an iPhone SE, drawn at 2x
    if love._os == 'iOS' or love._os == 'Android' then
        t.window.highdpi = true
        t.window.usedpiscale = true
        t.window.fullscreen = true
    end
end
