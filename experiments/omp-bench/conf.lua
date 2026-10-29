function love.conf(t)
    t.identity = 'omp-bench'
    t.window.title = 'OMP bench'
    t.window.width = 1000 -- same window as Playtime (conf.lua there)
    t.window.height = 800
    t.window.highdpi = false
    t.window.vsync = 0 -- frame times must not be capped by the display
    t.modules.joystick = false
end
