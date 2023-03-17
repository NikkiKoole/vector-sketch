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
        doCircleInTransition(love.math.random() * w, love.math.random() * h, function() SM.load("editGuy") end)
    end
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
    print(myWorld)

    root = {
        folder = true,
        name = 'root',
        transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
        children = {}
    }

    local fg = {}
    for i = 1, #fiveGuys do
        table.insert(root.children, fiveGuys[i].guy)



        local biped = Concord.entity()
        local potato = Concord.entity()
        myWorld:addEntity(biped)
        myWorld:addEntity(potato)


        biped:give('biped', bipedArguments(fiveGuys[i]))
        potato:give('potato', potatoArguments(fiveGuys[i]))

        attachAllFaceParts(fiveGuys[i])
        changePart('hair', fiveGuys[i].values)
        table.insert(fg, { biped = biped, potato = potato })
        --fiveGuys[i].body.transforms.l[1] = 0


        --transforms.setTransforms(fiveGuys[i].body)
        --fiveGuys[i].body.dirty = true


        -- myWorld:emit("bipedInit", biped)
        -- myWorld:emit("potatoInit", potato)
    end



    stripPath(root, '/experiments/puppet%-maker/')
    parentize.parentize(root)
    mesh.meshAll(root)
    render.renderThings(root)

    for i = 1, #fg do
        fiveGuys[i].guy.transforms.l[1] = (i - 3) * 200
        myWorld:emit("bipedInit", fg[i].biped)
        myWorld:emit("potatoInit", fg[i].potato)
        --
        -- myWorld:emit("potatoInit", potato)
    end


    local bx, by = fiveGuys[3].body.transforms._g:transformPoint(0, 0)
    local w, h = love.graphics.getDimensions()

    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(bx, by, w * 4, h * 4)
    cam:update(w, h)
end

function scene.draw()
    love.graphics.clear(1, 1, 1)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    love.graphics.setColor(1, 0, 1)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle('fill', w - 25, 0, 25, 25)

    -- local x,y = love.mouse.getPosition()

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
