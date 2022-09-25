-- where should this thing go, its duplciated all over the place right now
-- THIS IS MIGHTY GLOBAL
-- todo @global imageCache
--[[
imageCache = {}

local function addToImageCache(url, settings)
   if not imageCache[url] then
      print('making texture', url)
      local img = love.graphics.newImage(url, { mipmaps = true })
      img:setWrap(settings.wrap or 'clampzero')
      img:setFilter(settings.filter or 'linear', settings.filter or 'linear')
      imageCache[url] = img
   end
end

function recursivelyMakeTextures(root)

   if root.texture then
      addToImageCache(root.texture.url, root.texture)
   end

   if root.children then
      for i = 1, #root.children do
         recursivelyMakeTextures(root.children[i])
      end
   end
end
]] --
-- end where, its duplcaited all over teh place right now ?
