-- where should this thing go, its duplciated all over the place right now
-- THIS IS MIGHTY GLOBAL
-- todo @global imageCache
imageCache = {}
function recursivelyMakeTextures(root)

   if root.texture then
      if not imageCache[root.texture.url] then
         print('making texture', root.texture.url)
         local img = love.graphics.newImage(root.texture.url, { mipmaps = true })
         img:setWrap(root.texture.wrap or 'clampzero')
         img:setFilter(root.texture.filter or 'linear')
         imageCache[root.texture.url] = img
      end

   end

   if root.children then
      for i = 1, #root.children do
         recursivelyMakeTextures(root.children[i])
      end
   end

end

-- end where, its duplcaited all over teh place right now ?
