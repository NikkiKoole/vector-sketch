local debug = true
function love.conf(t)
    t.window.width = 1200
    t.window.height = 800

    t.window.title = "JizzJazzToo"
    t.window.icon = "quack.png"
    -- t.window.resizable = true
    --t.window.msaa = 4
    t.window.highdpi = true
    --t.window.vsync = 0
    t.window.msaa = 2
    t.window.highdpi = true
    t.window.vsync = true
    if debug then
        --t.window.resizable = true
        t.window.resizable = true
        t.window.borderless = false
        --t.window.minwidth = 1024 / 2
        --t.window.minheight = 768 / 2
    else
        t.window.borderless = true -- setting this will hide the status bar
        t.window.fullscreen = true
        t.window.resizable = false
    end
end
