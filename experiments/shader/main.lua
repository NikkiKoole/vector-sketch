
--https://love2d.org/forums/viewtopic.php?t=88854
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec3 backgroundColor;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        //return vec4(Texel(img, uv).aaa, 0.5 );


        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, uv).a * color.a);

        return vec4(patternMix, Texel(mask, uv).r);


		//return color * mix(Texel(imageB, uv), Texel(bg, uv), Texel(img, uv));
	}
]])

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.load()
    line = love.graphics.newImage('outlineW.png')
    texture = love.graphics.newImage('textureW.png')
    texture7 = love.graphics.newImage('texture7.png')
    mask = love.graphics.newImage('mask.png')
    maskBW = love.graphics.newImage('maskBW.png')
    maskBWA = love.graphics.newImage('maskBWA.png')
end


function love.draw()
    love.graphics.clear(0,1,0)
    love.graphics.setColor(1,1,1)
   -- if mask then
       -- love.graphics.setBlendMode('alpha', 'premultiplied')
        
         love.graphics.setShader(maskShader)
       -- love.graphics.setColor(color1[1], color1[2], color1[3], alpha1/5)
         maskShader:send('fill', texture)
         maskShader:send('backgroundColor', {0,0,1})
      --  love.graphics.setColor(color2[1], color2[2], color2[3], alpha2/5 )
        -- maskShader:send('imageB', mask)
        
        
        love.graphics.setColor(1,0,0,0.2)
         love.graphics.draw(maskBWA)
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha") ---<<<<
    -- end


   -- love.graphics.draw(line)
end