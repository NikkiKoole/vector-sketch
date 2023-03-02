package.path = package.path .. ";../../?.lua"

local inspect = require 'vendor.inspect'

function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end

function doImageFromData(data, name)
   return doImage(nil, name, data)
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


function putAlphaChannelInRGB(url,name, data )
   local imageData     = love.image.newImageData(data or url)
   local width, height = imageData:getDimensions()
   local format = imageData:getFormat( )
   local result = love.image.newImageData( width, height,format)
   for y = 0, height -1 do
      for x = 0, width-1 do
         local r, g, b, a = imageData:getPixel(x, y)
         result:setPixel(x,y,a,a,a,1)
      end
   end
   image = love.graphics.newImage(result, {mipmaps=true})
   local t = mysplit(name, '.')
   local newname = (t[1]..'.rgb.'..t[2])
  
   name= newname
   result:encode("png",name)
   love.system.openURL("file://"..love.filesystem.getSaveDirectory())

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
           --if a > biggestAlpha then biggestAlpha = a end
           
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

              result:setPixel(x,y,r,g,b,a*alphaMultiplier)
           end
           
	end
   end

   image = love.graphics.newImage(result, {mipmaps=true})
   if (alphaMultiplier ~= 1) then
      local t = mysplit(name, '.')
      local newname = (t[1]..'.'..(alphaMultiplier*100)..'.'..t[2])
      print(newname)
      name= newname--name..(alphaMultiplier*100)
   end
   
   result:encode("png",name)
   love.system.openURL("file://"..love.filesystem.getSaveDirectory())
end



function love.load()

   alphaMultiplier = 1
   doTheRGBDance = false
   love.keyboard.setKeyRepeat( true)
end

function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
   
   if (key == '1') then alphaMultiplier = alphaMultiplier-0.05 end
   if (key == '2') then alphaMultiplier = alphaMultiplier+0.05 end
   if (key == '3') then doTheRGBDance = true end
   
end

function getFiledata(filename)
  local f = io.open(filename, 'r')
  local filedata = love.filesystem.newFileData(f:read("*all"), filename)
  f:close()
  return filedata
end

function love.filedropped(file)
   local fullPath = file:getFilename()
   local d = getFiledata(fullPath)
   local splitted = mysplit(fullPath, "/")
   local name = splitted[#splitted]

   if doTheRGBDance then
      putAlphaChannelInRGB(d, name)
   else
   doImageFromData(d, name)
   end
end

function love.directorydropped(path)
   love.filesystem.mount(path, "content")
   files = love.filesystem.getDirectoryItems( "content" )

   for i =1, #files do
      local url =  path..'/'..files[i]
      local d = getFiledata(url)
      local splitted = mysplit(url, "/")
      local name = splitted[#splitted]
      --print(name, files[i])
      if doTheRGBDance then
         putAlphaChannelInRGB(d, name)
      else
      doImageFromData(d, name)
      end
   end
end


function love.draw()
   love.graphics.clear(.5,.6,.4)

   love.graphics.setColor(0,0,0)
   love.graphics.print("drop image file to fix padding issues", 300,300)
      love.graphics.setColor(1,1,1)

   love.graphics.print("drop image file to fix padding issues", 301,301)

   love.graphics.print('use 1 and 2 to change alpha multiplier', 300, 500)
   love.graphics.print('alpha multiplier: '..alphaMultiplier, 300, 530 )
   love.graphics.print('use 3 for the rgbDance', 300, 560)
   love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)
end
