

function love.keypressed(k) 
    if k == 'escape' then love.event.quit() end
    
end

function love.load()
    success = love.window.setMode( 1024, 1024 , {vsync=false})
    sprites = {"Evening.png", "Morning.png", "Sunrise.png", "Sunset.png", "bigger.png"}
    images = {}

    testsize = 100

    --https://love2d.org/wiki/love.graphics.newSpriteBatch
    local Image = love.graphics.newImage( 'atlas.png' )
   local batch = love.graphics.newSpriteBatch(Image)

    local q1 = love.graphics.newQuad


    for i =1, # sprites do
    images[i] = love.graphics.newImage(sprites[i])
    end
    image = love.graphics.newArrayImage(sprites)

    batch = love.graphics.newSpriteBatch(image)
    local count = #sprites
    local rand = love.math.random
    local w, h = love.graphics.getDimensions()
    for i =1 , testsize do
    batch:addLayer(math.ceil(rand()*count), rand()*w, rand()*h, rand()*math.pi*2, rand()*2.5, rand()*2.5)
    
    end
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
    love.graphics.draw(batch)
    
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
     love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end