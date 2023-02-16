local inspect = require 'inspect'
--https://love2d.org/forums/viewtopic.php?t=88854
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec3 backgroundColor;
    uniform mat2 uvTransform;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        vec2 transformedUV = uv * uvTransform;

        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, transformedUV).a * color.a);

        return vec4(patternMix, Texel(mask, uv).r);
	}
]])

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.load()
    line = love.graphics.newImage('outlineW.png')
    texture = love.graphics.newImage('textureW.png')
    texture:setFilter("linear", 'linear')
    texture:setWrap('mirroredrepeat', 'mirroredrepeat')
    texture7 = love.graphics.newImage('texture7.png')
    mask = love.graphics.newImage('mask.png')
    maskBW = love.graphics.newImage('maskBW.png')
    maskBWA = love.graphics.newImage('maskBWA.png')

    delta = 0
end

function love.update(dt)
    delta = delta + dt
end


function love.draw()

    local w,h = texture:getDimensions()
    love.graphics.clear(0,1,0)
    love.graphics.setColor(1,1,1)
        
         love.graphics.setShader(maskShader)

         local transform = love.math.newTransform( )
         local s = love.math.random()*12
         transform:rotate((delta / 10) % (math.pi*2))
         transform:scale(.5,.5)
         
       --  transform:translate(w/2, h/2)
           
            local m1,m2,_,_,m5,m6 = transform:getMatrix()

         maskShader:send('fill', texture)
         maskShader:send('backgroundColor', {0,0,1, 1})
         maskShader:send('uvTransform', {{m1,m2}, {m5,m6}})
  
        love.graphics.setColor(1,0,0,1)
        love.graphics.draw(maskBWA)
        love.graphics.setShader()

        love.graphics.setColor(1,0,0)
        love.graphics.draw(line)

end