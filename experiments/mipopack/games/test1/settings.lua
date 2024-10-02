local scene = {}

function scene:load(args)
    -- print(inspect(args))
    --  print("Scenery is awesome")
    --self.setScene("test2", { score = 52 })
end

function scene:keypressed(k)
    print(k)
end

function scene:keypressed(k)
    if k == 'escape' then self.setScene("test1", { score = 12 }) end
end

function scene:draw()
    love.graphics.clear(1, 1, .5)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("SETTINGS TEST 1", 200, 300)
    love.graphics.setColor(1, 1, 1)
end

function scene:update(dt)
    --print("You agree, don't you?")
end

return scene
