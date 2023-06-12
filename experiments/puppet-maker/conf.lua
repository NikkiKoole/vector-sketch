local debug = false

function love.conf(t)
    t.window.width = 1024
    t.window.height = 768
    --t.window.width = 2388
    --t.window.height= 1668

    t.window.title = "Mipo pupppetmaker"
    t.window.icon = "icoon.png"

    -- t.window.resizable = true
    --t.window.msaa = 4
    t.window.highdpi = true
    t.window.vsync = 1
    t.window.msaa = 2
    t.window.highdpi = true
    t.window.vsync = true
    if debug then
        --t.window.resizable = true
        t.window.resizable = true

        --t.window.minwidth = 1024 / 2
        --t.window.minheight = 768 / 2
    else
        t.window.borderless = true -- setting this will hide the status bar
        t.window.fullscreen = true
        t.window.resizable = false
    end
end
