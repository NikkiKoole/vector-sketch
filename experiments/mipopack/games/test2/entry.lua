local scene = {}


function scene:keypressed(k)
    if k == 'escape' then self.setScene("overworld", { score = 52 }) end
end

function scene:load(args)
    print("Scenery 2 is awesome")
end

function scene:draw()
    love.graphics.clear(.3, .5, .5)
    love.graphics.print("Scenery makes life easier TEST 2 ", 200, 300)
end

function scene:update(dt)
    -- print("You agree, don't you?")
end

return scene
