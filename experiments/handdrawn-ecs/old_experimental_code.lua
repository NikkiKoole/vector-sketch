function wildstuff()   
   local sin = function(a) return math.sin(totaldt)*100*(a or 1) end
   -- local points = {100+sin(),100, 200, 100, 200+sin(),200-sin(.5),100+sin(-1),200}
   local margin = .1
   --   local uvs = {0+margin,0+margin,
   --                1-margin,0+margin,
   --                1-margin,1-margin,
   --                0+margin,1-margin}

   local newuvs = {.05, .08, -- tl x and y}
                      .92, .95-.14} --width and height



   local rect1 = {400,400+sin(), 600,400+sin(), 600+sin(1),600, 400+sin(), 600}
   local outward = drawTheShizzle(rect1, newuvs)

   --love.graphics.polygon('line', rect1)
   --love.graphics.polygon('line', outward)


   local m = createTexturedRectangle(ding)
   m:setVertex(1, {outward[1], outward[2], 0,0})
   m:setVertex(2, {outward[3], outward[4], 1,0})
   m:setVertex(3, {outward[5], outward[6], 1,1})
   m:setVertex(4, {outward[7], outward[8], 0,1})
   
   
   

   love.graphics.setColor(0,0,0,0.9)
   love.graphics.draw(m)


   local offset = 200
   local rect1 = {400+offset,400+sin(), 600+offset,400+sin(), 600+offset+sin(),600, 400+offset+sin(), 600}
   local outward = drawTheShizzle(rect1, newuvs)

   --   love.graphics.polygon('line', rect1)
   --   love.graphics.polygon('line', outward)


   local m = createTexturedRectangle(ding)

   for j = 1, 4 do
      local _,_, u, v  = m:getVertex(j)
      m:setVertex(j, {outward[((j-1)*2)+1],outward[((j-1)*2)+2], u,v})
   end

   love.graphics.setColor(1,0,0)
   love.graphics.draw(m)
   
end
