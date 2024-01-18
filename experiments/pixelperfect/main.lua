function love.load() 
    img =  love.graphics.newImage('coggies.png')
    --img =  love.graphics.newImage('car.png')
    img:setFilter("nearest", "nearest")


    local w = 1800
    local h = 800
    success = love.window.setMode( w, h,{resizable=true})

    canvas = makeBestCanvas()
   
end

function makeBestCanvas() 
    local w,h = love.graphics.getDimensions()
    local imgW, imgH = img:getDimensions()
    local perfectScale = math.max( 1, math.floor( math.min (w/imgW, h/imgH)))
   --print(perfectScale)

    local canvas = love.graphics.newCanvas(imgW*perfectScale,imgH*perfectScale)
    canvas:setFilter("linear", "linear")
    --canvas:setFilter("nearest", "nearest")
    love.graphics.setCanvas(canvas)
    love.graphics.draw(img, 0,0,0,perfectScale, perfectScale)
    love.graphics.setCanvas()

    return canvas
end


function love.resize(w,h) 
    canvas = makeBestCanvas()
end

function love.keypressed(k) 
    if k == 'escape' then love.event.quit() end
end

function love.draw() 
    local w,h = love.graphics.getDimensions()
    local cw,ch = canvas:getDimensions()

    local lessPerfectScale = math.min (w/cw, h/ch)

    love.graphics.draw(canvas, 0,0,0,lessPerfectScale,lessPerfectScale)
end