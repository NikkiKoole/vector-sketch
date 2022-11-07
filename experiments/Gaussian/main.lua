
img = love.graphics.newImage("Logo3.png")

function love.load()

	canvas = love.graphics.newCanvas( )

	blur1 = love.graphics.newShader [[

		vec4 effect(vec4 color, Image texture, vec2 vTexCoord, vec2 pixel_coords)
		{
			vec4 sum = vec4(0.0);
			number blurSize = 0.005;

			// take nine samples, with the distance blurSize between them
			sum += texture2D(texture, vec2(vTexCoord.x - 4.0*blurSize, vTexCoord.y)) * 0.05;
			sum += texture2D(texture, vec2(vTexCoord.x - 3.0*blurSize, vTexCoord.y)) * 0.09;
			sum += texture2D(texture, vec2(vTexCoord.x - 2.0*blurSize, vTexCoord.y)) * 0.12;
			sum += texture2D(texture, vec2(vTexCoord.x - blurSize, vTexCoord.y)) * 0.15;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y)) * 0.16;
			sum += texture2D(texture, vec2(vTexCoord.x + blurSize, vTexCoord.y)) * 0.15;
			sum += texture2D(texture, vec2(vTexCoord.x + 2.0*blurSize, vTexCoord.y)) * 0.12;
			sum += texture2D(texture, vec2(vTexCoord.x + 3.0*blurSize, vTexCoord.y)) * 0.09;
			sum += texture2D(texture, vec2(vTexCoord.x + 4.0*blurSize, vTexCoord.y)) * 0.05;
			
			
			return sum;
		}
		]]
	blur2 = love.graphics.newShader [[
		
		vec4 effect(vec4 color, Image texture, vec2 vTexCoord, vec2 pixel_coords)
		{
			vec4 sum = vec4(0.0);
			number blurSize = 0.005;

			// take nine samples, with the distance blurSize between them
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y - 4.0*blurSize)) * 0.05;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y - 3.0*blurSize)) * 0.09;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y - 2.0*blurSize)) * 0.12;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y- blurSize)) * 0.15;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y)) * 0.16;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y + blurSize)) * 0.15;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y + 2.0*blurSize)) * 0.12;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y + 3.0*blurSize)) * 0.09;
			sum += texture2D(texture, vec2(vTexCoord.x, vTexCoord.y + 4.0*blurSize)) * 0.05;

			return sum;
		}
		]]
	love.graphics.setBackgroundColor(25, 25, 25)
end

function love.draw()
   love.graphics.clear(0.5,0.5,0.5)
	love.graphics.setShader()

--	love.graphics.setCanvas(canvas)
    if not love.keyboard.isDown("x") then-- LOOK AT THE PRETTY COLORS!
       love.graphics.setShader(blur1)
       --love.graphics.setShader(blur2)
	end
    love.graphics.draw(img, 0, 0)
    --love.graphics.rectangle('fill', 10,10, love.graphics.getWidth()-20, love.graphics.getHeight()-20)
--	love.graphics.setCanvas()
	
    
    --love.graphics.draw(img, 0, 0)
    --love.graphics.draw(canvas, 0, love.graphics.getHeight()/2)
    --if not love.keyboard.isDown("y") then-- LOOK AT THE PRETTY COLORS!
--	    love.graphics.setShader(blur2)
--	end
    --love.graphics.draw(canvas, love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    love.graphics.draw(canvas, 0,0)
end





