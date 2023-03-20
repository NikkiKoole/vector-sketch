local scene       = {}
local gradient    = require 'lib.gradient'
local hit         = require 'lib.hit'
local skygradient = gradient.makeSkyGradient(6)
local Timer       = require 'vendor.timer'

local transition  = nil
local parentize   = require 'lib.parentize'
local render      = require 'lib.render'
local mesh        = require 'lib.mesh'

local camera      = require 'lib.camera'
local cam         = require('lib.cameraBase').getInstance()
local transforms  = require 'lib.transform'
local geom = require 'lib.geom'
local function myCircleStencilFunction(x, y, r, s)
    love.graphics.circle("fill", x, y, r, s)
end
local function drawCircleMask(backgroundAlpha, x, y, size, segments)
    love.graphics.stencil(function() myCircleStencilFunction(x, y, size, segments) end, "replace", 1)
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.setStencilTest("less", 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setStencilTest()
end

local function myRectStencilFunction(x, y, w, h)
    love.graphics.push()
    --love.graphics.translate( -x, -y)
    love.graphics.rotate(0.5)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.pop()
end
local function drawRectangleMask(backgroundAlpha, x, y, w, h)
    love.graphics.stencil(function() myRectStencilFunction(x, y, w, h) end, "replace", 1)
    love.graphics.setColor(0, 0, 0, backgroundAlpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.setStencilTest("less", 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setStencilTest()
end


local function doCircleInTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    transition = { type = 'circle', segments = 7, alpha = 0, x = x, y = y, radius = math.max(w, h) }
    Timer.tween(.3, transition, { alpha = 1 })
    Timer.tween(1, transition, { radius = 0 }, 'out-back')
    Timer.after(1, function()
        onAfter();
        transition = nil;
    end)
end

local function doCircleOutTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    transition = { type = 'circle', segments = 7, alpha = 1, x = x, y = y, radius = 0 }
    Timer.tween(1.3, transition, { alpha = 0 })
    Timer.tween(1, transition, { radius = math.max(w, h), segments = 7 }, 'in-back')
    Timer.after(1, function()
        onAfter();
        transition = nil;
    end)
end

local function doRectOutTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    -- I amdrawing a much higher rectangle so it will cover the screen when rotated
    local h2 = math.max(w, h) * 3
    transition = { type = 'rectangle', alpha = 1, x = x, y = y, w = 0, h = h2 * 3 }
    Timer.tween(2, transition, { alpha = 0 })
    Timer.tween(3, transition, { w = x < w / 2 and w * 1.5 or -w * 1.5 }, 'out-back')
    Timer.after(3, function()
        onAfter();
        transition = nil;
    end)
end
local function doRectInTransition(x, y, onAfter)
    local w, h = love.graphics.getDimensions()
    -- I amdrawing a much higher rectangle so it will cover the screen when rotated
    local h2 = math.max(w, h) * 3
    transition = { type = 'rectangle', alpha = 0, x = x, y = y, w = x < w / 2 and w * 1.5 or -w * 1.5, h = h2 * 3 }
    Timer.tween(.6, transition, { alpha = 1 })
    Timer.tween(1.2, transition, { w = 0 }, 'out-back')
    Timer.after(1.2, function()
        onAfter();
        transition = nil;
    end)
end
local function pointerPressed(x, y, id)
    local w, h = love.graphics.getDimensions()
    if (hit.pointInRect(x, y, w - 22, 0, 25, 25)) then
        local w, h = love.graphics.getDimensions()
        local bx, by = editingGuy.head.transforms._g:transformPoint(0, 0)
        local sx, sy = cam:getScreenCoordinates(bx, by)
        doCircleInTransition(sx, sy, function() SM.load("editGuy") end)
    end
    myWorld:emit("eyeLookAtPoint", x, y)
end
local function stripPath(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url
        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
        --print(shortened)
    end

    if root.children then
        for i = 1, #root.children do
            stripPath(root.children[i], path)
        end
    end

    return root
end

function scene.unload()
    myWorld:clear()
end

function scene.load()
   
    if (PROF_CAPTURE) then 
        ProFi:start()
     
     end
    
    prof.push('frame')
    -- print(myWorld)

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }

    local fg = {}
    prof.push('initguys')
    
    for i = 1, #fiveGuys do
        table.insert(root.children, fiveGuys[i].guy)

        local biped = Concord.entity()
        local potato = Concord.entity()
        myWorld:addEntity(biped)
        myWorld:addEntity(potato)


        biped:give('biped', bipedArguments(fiveGuys[i]))
        potato:give('potato', potatoArguments(fiveGuys[i]))

        attachAllFaceParts(fiveGuys[i])
        editingGuy = fiveGuys[i]
        changePart('hair', fiveGuys[i].values)
        table.insert(fg, { biped = biped, potato = potato })
    end
    prof.pop('initguys')
   -- editingGuy = fiveGuys[1]



    stripPath(root, '/experiments/puppet%-maker/')
    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)
    prof.push('moveguys')
    for i = 1, #fg do
        --- this will reset the position you made
        local resetPos = false
        if resetPos then
            fiveGuys[i].body.transforms.l[1] = 0
            fiveGuys[i].body.transforms.l[2] = 0
            myWorld:emit('movedBody', fg[i].biped)
        end
        fiveGuys[i].guy.transforms.l[1] = (i - math.ceil(#fiveGuys / 2)) * 700
        myWorld:emit("bipedInit", fg[i].biped)
        myWorld:emit("potatoInit", fg[i].potato)
        --
        -- myWorld:emit("potatoInit", potato)
    end
    prof.pop('moveguys')

    local bx, by = fiveGuys[3].body.transforms._g:transformPoint(0, 0)
    local w, h = love.graphics.getDimensions()

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(bx, by, w * 8, h * 5)
    cam:update(w, h)
    prof.pop('frame')

    depthMinMax = { min = -1.0, max = 1.0 }
    -- foregroundFactors = { far=.5, near=1}
    --backgroundFactors = { far=.4, near=.7}
    tileSize = 600
    foregroundFar = camera.generateCameraLayer('foregroundFar', 1)
    foregroundNear = camera.generateCameraLayer('foregroundNear', 1)
    groundimg8 = love.graphics.newImage('assets/ground3.png', { mipmaps = true })
    ding = love.graphics.newImage('assets/ground52.png', { mipmaps = true })
    print(groundimg8)
    heights = {}
    minpos = -1000
    maxpos = 1000
    for i = minpos, maxpos do
       heights[i] = love.math.random() * 100
    end
 

    if (PROF_CAPTURE) then 
        ProFi:stop()
        ProFi:writeReport('profilingReportInit.txt') 
     end
    
    
end


function drawGroundPlaneLinesSimple(far, near)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    local W, H = love.graphics.getDimensions()
 
    local x1, y1 = cam:getWorldCoordinates(0, 0, far)
    local x2, y2 = cam:getWorldCoordinates(W, 0, far)
 
    local s = math.floor(x1 / tileSize) * tileSize
    local e = math.ceil(x2 / tileSize) * tileSize
 
    --[[
    local imgarr = {groundimg1, groundimg2, groundimg3, groundimg4, groundimg5,
                    groundimg6, groundimg7, groundimg8, groundimg9, groundimg10,
                    groundimg10, groundimg11, groundimg12,groundimg12,groundimg12,
                    groundimg12,groundimg13,groundimg13,groundimg13}
    ]]
    --
    -- local imgarr = { groundimg6b, groundimg3, groundimg8, groundimg9, groundimg10 }
    local imgarr = { groundimg8 }
 
    local woohoo = 1
 
    for i = s, e, tileSize do
       local groundIndex = (i / tileSize)
       local tileIndex = (groundIndex % (#imgarr)) + 1
             --print(tileIndex)
       local index = (i - s) / tileSize
 
       if groundIndex >= minpos and groundIndex <= maxpos - 1 then
          local height1 = heights[groundIndex]
          local height2 = heights[groundIndex + 1]
          local s = cam:getScale() -- 50 -> 0.01
 
 
          local x4, y4 = cam:getScreenCoordinates(i + 0.0001, height1 * woohoo, near)
          local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2 * woohoo, near)
          local x1, y1 = x4, y4 - s * tileSize
          local x2, y2 = x3, y3 - s * tileSize
 
          local m = mesh.createTexturedRectangle(imgarr[tileIndex])
 
          m:setVertex(1, { x1, y1, 0, 0, 1, 1, 1, .5 })
          m:setVertex(2, { x2, y2, 1, 0, 1, 1, 1, .5 })
          m:setVertex(3, { x3, y3, 1, 1 })
          m:setVertex(4, { x4, y4, 0, 1 })
 
          love.graphics.setColor(.9, .9, .9, .9)
          love.graphics.draw(m)
          --love.graphics.setColor(.1, .9, .3, .9)
          --love.graphics.draw(m, 0, 400 * s)
 
 
          local newuvs = { .05, .08, -- tl x and y}
              .92, .95 - .09 } --width and height
 
          local rect1 = { x1, y1, x2, y2, x3, y3, x4, y4 }
          local outward = geom.coloredOutsideTheLines(rect1, newuvs)
 
          local m = mesh.createTexturedRectangle(ding)
          m:setVertex(1, { outward[1], outward[2], 0, 0 })
          m:setVertex(2, { outward[3], outward[4], 1, 0 })
          m:setVertex(3, { outward[5], outward[6], 1, 1 })
          m:setVertex(4, { outward[7], outward[8], 0, 1 })
 
 
          -- love.graphics.setColor(168 / 255, 175 / 255, 97 / 255, .9)
          love.graphics.setColor(.4, .8, .2, .8)
          love.graphics.draw(m)
          --love.graphics.draw(m, 0, 400 * s)
       end
    end
 end


function scene.draw()
    love.graphics.clear(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    love.graphics.setColor(1, 0, 1)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('fill', w - 25, 0, 25, 25)

    -- local x,y = love.mouse.getPosition()
    drawGroundPlaneLinesSimple('foregroundFar', 'foregroundNear')
    cam:push()
    render.renderThings(root, true)
    cam:pop()

    if transition then
        if transition.type == 'circle' then
            drawCircleMask(transition.alpha, transition.x, transition.y, transition.radius, transition.segments)
        end
        if transition.type == 'rectangle' then
            drawRectangleMask(transition.alpha, transition.x, transition.y, transition.w, transition.h)
        end
    end
end

function scene.update(dt)
    function love.touchpressed(id, x, y, dx, dy, pressure)
        pointerPressed(x, y, id)
    end

    function love.mousepressed(x, y, button, istouch, presses)
        if not istouch then
            pointerPressed(x, y, 'mouse')
        end
    end

    function love.keypressed(k)
        if k == '1' then
            editingGuy = fiveGuys[1]
        end
        if k == '2' then
            editingGuy = fiveGuys[2]
        end
        if k == '3' then
            editingGuy = fiveGuys[3]
        end
        if k == '4' then
            editingGuy = fiveGuys[4]
        end
        if k == '5' then
            editingGuy = fiveGuys[5]
        end
        if k == 'escape' then
            love.event.quit()
        end

        if k == 'c' then
            local w, h = love.graphics.getDimensions()
            doCircleInTransition(love.math.random() * w, love.math.random() * h, function() print('done!') end)
        end
        if k == 'w' then
            local w, h = love.graphics.getDimensions()
            doCircleOutTransition(love.math.random() * w, love.math.random() * h, function() print('done!') end)
        end
        if k == 'r' then
            local w, h = love.graphics.getDimensions()
            local offset = w * 0.25
            local rand = love.math.random()
            -- I am drawing a rectangle that is 3 times the height of the screen
            -- that is to make it able to rotate and still cover the whole screen
            h = math.max(w, h) * 3
            if rand < 0.5 then
                doRectOutTransition( -offset, -h, function() print('done!') end)
            else
                doRectOutTransition(w + offset, -h, function() print('done!') end)
            end
        end
        if k == 't' then
            local w, h = love.graphics.getDimensions()
            local offset = w * 0.25
            local rand = love.math.random()
            -- I am drawing a rectangle that is 3 times the height of the screen
            -- that is to make it able to rotate and still cover the whole screen
            h = math.max(w, h) * 3
            if rand < 0.5 then
                doRectInTransition( -offset, -h, function() print('done!') end)
            else
                doRectInTransition(w + offset, -h, function() print('done!') end)
            end
        end
    end

    Timer.update(dt)
end

return scene
