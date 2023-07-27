

function love.keypressed(k) 
    if k == 'escape' then love.event.quit() end
    
end

function love.load()
    success = love.window.setMode( 1024, 1024 , {vsync=false})
    sprites = {"Evening.png", "Morning.png", "Sunrise.png", "Sunset.png"}
    images = {}

    testsize = 100

    --https://love2d.org/wiki/love.graphics.newSpriteBatch
   -- local Image = love.graphics.newImage( 'atlas.png' )
   --local batch = love.graphics.newSpriteBatch(Image)

  --  local q1 = love.graphics.newQuad



    atlasImg = love.graphics.newImage( 'floweratlas.png' )
   -- atlasImg:setMipmapFilter( )
    --atlasArray = love.graphics.newArrayImage({'atlas.png'})
   -- batch2 = love.graphics.newSpriteBatch(atlasImg)
    
    q1 = love.graphics.newQuad(24, 22,380,380, atlasImg)
    q2 = love.graphics.newQuad(38, 532, 520, 520,atlasImg)
    q3 = love.graphics.newQuad(634,522, 264, 776, atlasImg)
    q4 = love.graphics.newQuad(1 + 35 , 1 + 35, 34, 34, atlasImg)
    q5 = love.graphics.newQuad(1 + 70 , 1 , 200, 200, atlasImg)
    local quads = {q1,   q2, q3}

    for i =1, # sprites do
    images[i] = love.graphics.newImage(sprites[i])
    end

    way1 = false
    if way1 then
        image = love.graphics.newArrayImage(sprites)

        batch1 = love.graphics.newSpriteBatch(image)

        local count = #sprites
        local rand = love.math.random
        local w, h = love.graphics.getDimensions()
        for i =1 , testsize do
        batch1:addLayer(math.ceil(rand()*count), rand()*w, rand()*h, rand()*math.pi*2, rand()*2.5, rand()*2.5)
        
        end
    end

    way2 = true
    if way2 then
        atlasArray = love.graphics.newArrayImage({'floweratlas.png'})
        batch2 = love.graphics.newSpriteBatch(atlasArray)
        local count = #quads
        local rand = love.math.random
        local w, h = love.graphics.getDimensions()

        for i =1 , testsize do
            batch2:addLayer(1, quads[math.ceil(rand()*count)], rand()*w, rand()*h, rand()*math.pi*2, .3, .3)
            
            end

    end
    love.graphics.setBackgroundColor( 238/255, 193/255, 163/255)
end

shader = love.graphics.newShader[[
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
   love.graphics.setColor(1,1,1)
   love.graphics.setColor(0,0,0)
   if way1 then
    love.graphics.draw(batch1)
   end

   if way2 then
    love.graphics.draw(batch2)
   end

    if false then
    local count = #sprites
    local rand = love.math.random
    local w, h = love.graphics.getDimensions()
    for i =1 , testsize do
        love.graphics.draw(images[math.ceil(rand()*count)], rand()*w, rand()*h, rand()*math.pi*2, rand()*2.5, rand()*2.5)
        --batch:addLayer(math.ceil(rand()*count), rand()*w, rand()*h, rand()*math.pi*2, rand()*2.5, rand()*2.5)
        
        end
    end




    --love.graphics.setShader()
    love.graphics.setColor(1,1,1)
     love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end