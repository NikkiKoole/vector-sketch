local debug = true


function love.conf(t)
    t.window.width = 1024
    t.window.height = 768

    t.window.title = "mipomi-lang"

    t.window.highdpi = true
    t.window.vsync = 0
    t.window.msaa = 2
    -- t.window.highdpi = true
    -- t.window.vsync = true
end
