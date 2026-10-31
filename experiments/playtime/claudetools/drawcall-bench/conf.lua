function love.conf(t)
    t.identity = 'drawcall-bench' -- results in the save folder too: drawcall-bench.txt (a phone has no console)
    t.window.width, t.window.height, t.window.vsync = 1200, 768, 0 -- iOS keeps vsync on whatever this says
end
