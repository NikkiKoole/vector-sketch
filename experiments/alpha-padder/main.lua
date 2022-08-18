

function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end

function doImageFromData(data, name)
   return doImage(nil, name, data)
end


function doImage(url, name, data)
   local imageData     = love.image.newImageData(data or url)
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
   
   image = love.graphics.newImage(result, {mipmaps=true})
   result:encode("png",name)
   love.system.openURL("file://"..love.filesystem.getSaveDirectory())
end

function mysplit (inputstr, sep)
   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
   end
   return t
end

function love.load()
--  local filename = 'moreleaves3.png'--'Naamloos.png' --'ding.png'-
--  doImage(filename, filename) 
end


function getFiledata(filename)
  local f = io.open(filename, 'r')
  local filedata = love.filesystem.newFileData(f:read("*all"), filename)
  f:close()
  return filedata
end


--function mountZip(filename, mountpoint)
--   local filedata = getFiledata(filename)
--   return love.filesystem.mount(filedata, mountpoint or 'zip')
--end

function love.filedropped(file)
   local fullPath = file:getFilename()
   local d = getFiledata(fullPath)
   local splitted = mysplit(fullPath, "/")
   local name = splitted[#splitted]

   doImageFromData(d, name)
   
end


function love.draw()
   love.graphics.clear(.5,.6,.4)

   love.graphics.setColor(0,0,0)
   love.graphics.print("drop image file to fix padding issues", 300,300)
   love.graphics.setColor(1,1,1)

   love.graphics.print("drop image file to fix padding issues", 301,301)
   love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)
end
