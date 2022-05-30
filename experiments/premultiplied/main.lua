-- https://github.com/urraka/alpha-bleeding
--tgis is a windows executa l


function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end


function love.load()
   local filename = 'ground1b_.png' --'ding.png'
   local imageData     = love.image.newImageData(filename)
   local width, height = imageData:getDimensions()
   local format = imageData:getFormat( )
   local result = love.image.newImageData( width, height,format)

   local count = 0

   
   for y = 0, height -1 do
	for x = 0, width-1 do
	   local r, g, b, a = imageData:getPixel(x, y)
           if a == 0 then

              
              for x2 = -1,1 do
                 for y2 = -1,1 do
                    if (x+x2) >=0 and (x+x2)<=width-1 then
                       if (y+y2) >=0 and (y+y2)<=height-1 then
                          
                          local r, g, b, a = imageData:getPixel(x+x2, y+y2)

                          if (a>0) then
                             count = count + 1

                             result:setPixel(x,y,r,g,b,0)

                             --print('want to take')
                          end
                          
                       end
                    end
                 end
              end
           else
           
              result:setPixel(x,y,r,g,b,a)
           end
           
	end
   end
   
   print('work todo', count)
   
   image = love.graphics.newImage(result, {mipmaps=true})
--   image = love.graphics.newImage(imageData, {mipmaps=true})

   result:encode("png",filename)
end

function love.draw()
   love.graphics.clear(.5,.6,.4)
   --love.graphics.setBlendMode("multiply", "premultiplied")
   love.graphics.draw(image,-200,-200, 0.1,4,4)
end
