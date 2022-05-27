-- https://github.com/urraka/alpha-bleeding
--tgis is a windows executa l


function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end


function love.load()
   local filename = 'ding2.png'
   local imageData     = love.image.newImageData(filename)
   local width, height = imageData:getDimensions()

   for y = 1, height do
	for x = 1, width do
	   local r, g, b, a = imageData:getPixel(x-1, y-1)
	   print(r,g,b,a)
	end
   end
   
   image = love.graphics.newImage(imageData, {mipmaps=true})
end

function love.draw()
   love.graphics.clear(.5,.6,.4)
   --love.graphics.setBlendMode("multiply", "premultiplied")
   love.graphics.draw(image, 100,100, 0,4,4)
end
