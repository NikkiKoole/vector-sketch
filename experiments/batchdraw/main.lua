--https://www.leshylabs.com/apps/sstool/

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.load()
    success = love.window.setMode(1024, 1024, { vsync = false })
    sprites = { "Evening.png", "Morning.png", "Sunrise.png", "Sunset.png" }
    --sprites = { "spriet1.png", "spriet2.png", "spriet3.png", "spriet4.png",
    --    "spriet5.png", "spriet6.png", "spriet7.png", "spriet8.png", }
    images = {}

    testsize = 300

    --https://love2d.org/wiki/love.graphics.newSpriteBatch
    -- local Image = love.graphics.newImage( 'atlas.png' )
    --local batch = love.graphics.newSpriteBatch(Image)

    --  local q1 = love.graphics.newQuad


    if false then
        atlasImg = love.graphics.newImage('floweratlas.png')
        -- atlasImg:setMipmapFilter( )
        --atlasArray = love.graphics.newArrayImage({'atlas.png'})
        -- batch2 = love.graphics.newSpriteBatch(atlasImg)

        q1 = love.graphics.newQuad(24, 22, 380, 380, atlasImg)
        q2 = love.graphics.newQuad(38, 532, 520, 520, atlasImg)
        q3 = love.graphics.newQuad(634, 522, 264, 776, atlasImg)
        q4 = love.graphics.newQuad(1 + 35, 1 + 35, 34, 34, atlasImg)
        q5 = love.graphics.newQuad(1 + 70, 1, 200, 200, atlasImg)
    end


    atlasImg = love.graphics.newArrayImage('sprieten.png')
    q1 = love.graphics.newQuad(0, 0, 49, 192, atlasImg)
    q2 = love.graphics.newQuad(51, 164, 40, 197, atlasImg)
    q3 = love.graphics.newQuad(51, 0, 41, 162, atlasImg)
    q4 = love.graphics.newQuad(94, 0, 46, 186, atlasImg)
    q5 = love.graphics.newQuad(0, 194, 47, 231, atlasImg)
    q6 = love.graphics.newQuad(94, 188, 45, 236, atlasImg)
    q7 = love.graphics.newQuad(142, 197, 47, 208, atlasImg)
    q8 = love.graphics.newQuad(142, 0, 52, 195, atlasImg)




    local quads = { q1, q2, q3, q4, q5, q6, q7, q8 }
    local origins = { { 22, 185 }, { 12, 187 }, { 19, 144 }, { 25, 176 }, { 27, 224 }, { 16, 210 }, { 22, 190 }, { 30, 173 } }
    for i = 1, # sprites do
        images[i] = love.graphics.newImage(sprites[i])
    end

    way1 = false
    way2 = not way1

    if way1 then
        image = love.graphics.newArrayImage(sprites)

        batch1 = love.graphics.newSpriteBatch(image)

        local count = #sprites
        local rand = love.math.random
        local w, h = love.graphics.getDimensions()
        for i = 1, testsize do
            batch1:addLayer(math.ceil(rand() * count), rand() * w, rand() * h, rand() * math.pi * 2, rand() * 2.5,
                rand() * 2.5)
        end
    end


    -- this way is much faster
    if way2 then
        -- atlasArray = love.graphics.newArrayImage({ 'floweratlas.png' })
        atlasArray = love.graphics.newArrayImage({ 'sprieten.png' })
        batch2 = love.graphics.newSpriteBatch(atlasArray)
        local count = #quads
        local rand = love.math.random
        local w, h = love.graphics.getDimensions()

        for i = 1, testsize do
            local a = rand() * math.pi / 4 - (math.pi / 8)
            local index = math.ceil(rand() * count)
            local ori = origins[index]
            batch2:addLayer(1, quads[index], rand() * w, h, a, 1, 1, ori[1], ori[2])
        end
    end
    love.graphics.setBackgroundColor(238 / 255, 193 / 255, 163 / 255)
end

shader = love.graphics.newShader [[
uniform ArrayImage MainTex;

void effect() {
    // Texel uses a third component of the texture coordinate for the layer index, when an Array Texture is passed in.
    // love sets up the texture coordinates to contain the layer index specified in love.graphics.drawLayer, when
    // rendering the Array Texture.

    love_PixelColor = Texel(MainTex, VaryingTexCoord.xyz) * VaryingColor;

}
]]


function love.draw()
    -- love.graphics.setShader(shader)
    -- love.graphics.setColor(1, 1, 1)
    --   love.graphics.setColor(0, 0, 0)
    if way1 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(batch1)
    end

    if way2 then
        love.graphics.setColor(0, 0, 0)

        love.graphics.draw(batch2)
    end

    if false then
        love.graphics.setColor(1, 1, 1)
        local count = #sprites
        local rand = love.math.random
        local w, h = love.graphics.getDimensions()
        for i = 1, testsize do
            love.graphics.draw(images[math.ceil(rand() * count)], rand() * w, rand() * h, rand() * math.pi * 2,
                rand() * 2.5, rand() * 2.5)
            --batch:addLayer(math.ceil(rand()*count), rand()*w, rand()*h, rand()*math.pi*2, rand()*2.5, rand()*2.5)
        end
    end




    --love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)
    local stats = love.graphics.getStats()
    love.graphics.print(
        "Current FPS: " ..
        tostring(love.timer.getFPS() ..
            ' calls: ' .. stats.drawcalls .. ' dcalls: ' .. stats.drawcallsbatched ..
            ' shaderswitches: ' .. stats.shaderswitches), 10, 10)
end
