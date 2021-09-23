package.path = package.path .. ";../../?.lua"


require 'lib.editor-utils'
require 'lib.poly'
require 'lib.bbox'
require 'lib.basics'

require 'lib.toolbox'

flux = require "vendor.flux"
require 'lib.main-utils'
inspect = require 'vendor.inspect'


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
   love.window.setMode( 1600, 1000 )
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={400,400,0,1,1,0,0}},
      children ={}
   }



   
   baas = parseFile('eindbaas.polygons.txt')[1]
   
   --table.insert(root.children, baas)

   root = {
      folder = true,
      name = 'root',
      transforms =  {l={200,200,0,1,1,0,0,0,0}},
      children = {
         {
            name="roodchild:"..1,
            color = {.5,.1,1, 0.8},
            points = {{-100,0},{200,0},{200,200},{100,200}},
         },
         {
            folder = true,
            transforms =  {l={300,300,0,.5,.5,0,0,0,0}},
            name="rood",
            children ={
               {
                  name="roodchild:"..1,
                  color = {.5,.3,.3, 0.8},
                  points = {{0,0},{200,0},{200,200},{0,200}},
               },
                        {
            folder = true,
            transforms =  {l={50,10,0,.5,.5,0,0,0,0}},
            name="rood",
            children ={
               {
                  name="roodchild:"..1,
                  color = {.5,.3,.3, 0.8},
                  points = {{0,0},{200,0},{200,200},{0,200}},
                  -- using these points and it breaks ;/?
                  --points = {{300,0},{200,0},{1200,200},{0,600}},

               }
            }
         }

            }
         }
      }
   }
   

   


   parentize(root)
   meshAll(root)
   renderThings(root)
   
   b = getRecursiveBBox({math.huge, math.huge, -math.huge, -math.huge}, root)
end


function getRecursiveBBox(bounds, node)
   
   if node.children then
      --print(node.name, inspect(bounds))
      setTransforms(node)

      for i = 1, #node.children do
         if node.children[i].folder then
            local bounds2 = getRecursiveBBox(bounds, node.children[i])
            if bounds2[1] < bounds[1] then bounds[1] = bounds2[1] end
            if bounds2[2] < bounds[2] then bounds[2] = bounds2[2] end
            if bounds2[3] > bounds[3] then bounds[3] = bounds2[3] end
            if bounds2[4] > bounds[4] then bounds[4] = bounds2[4] end
         end
      end

      for i = 1, #node.children do
         if node.children[i].points then
            local tlx, tly, brx, bry =  getPointsBBox(node.children[i].points)
            if tlx < bounds[1] then bounds[1] = tlx end
            if tly < bounds[2] then bounds[2] = tly end
            if brx > bounds[3] then bounds[3] = brx end
            if bry > bounds[4] then bounds[4] = bry end
         end
      end


      local tlxg , tlyg =
         node._localTransform:transformPoint(bounds[1], bounds[2])
      local brxg , bryg =
         node._localTransform:transformPoint(bounds[3], bounds[4])

      --local tlxg , tlyg = node._globalTransform:transformPoint(bounds[1], bounds[2])
      --local brxg , bryg = node._globalTransform:transformPoint(bounds[3], bounds[4])

      bounds = {tlxg, tlyg, brxg, bryg}
   end
   print('->'..node.name)
   return bounds
end



function love.draw()
   
   renderThings(root)
   love.graphics.setColor(1,1,1)
   love.graphics.line(b[1], b[2], b[3], b[2])
   love.graphics.line(b[1], b[2], b[1], b[4])
   love.graphics.line(b[3], b[2], b[3], b[4])
   love.graphics.line(b[1], b[4], b[3], b[4])

end
