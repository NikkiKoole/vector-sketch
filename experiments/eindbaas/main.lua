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
   
   table.insert(root.children, baas)

   roo2t = {
      folder = true,
      name = 'root',
      transforms =  {l={200,200,0,1,1,0,0,0,0}},
      children = {
         {
            name="blauw:"..1,
            color = {0,0,1, 0.8},
            points = {{-100,0},{200,0},{200,200},{100,200}},
         },
         {
            folder = true,
            transforms =  {l={100,300,0,1,1,0,0,0,0}},
            name="rood",
            children ={
               {
                  folder = true,
                  transforms =  {l={0,0,0,1,1,0,0,0,0}},
                  name="rood",
                  children ={
                     {
                        name="rood:"..1,
                        color = {1,0, 0, 0.8},
                        points = {{200,-400},{200,-100},{400,200},{0,200}},
                        -- using these points and it breaks ;/?
                        --points = {{300,0},{200,0},{1200,200},{0,600}},

                     }
                  }
               },
               {
                  name="groen:"..1,
                  color = {0,1,0, 0.8},
                  points = {{0,0},{200,0},{200,200},{0,200}},
               },


            }
         }
      }
   }

   parentize(root)
   meshAll(root)
   renderThings(root)

   b = getBBoxRecursive(root)
   --b = getRecursiveBBox({math.huge, math.huge, -math.huge, -math.huge}, root)
end







function love.draw()
   
   renderThings(root)
   love.graphics.setColor(1,1,1)
   
   love.graphics.line(b[1], b[2], b[3], b[2])
   love.graphics.line(b[1], b[2], b[1], b[4])
   love.graphics.line(b[3], b[2], b[3], b[4])
   love.graphics.line(b[1], b[4], b[3], b[4])

   local cw = b[3] - b[1]
   local ch = b[4] - b[2]
   --print(cw/100, ch/100)

   local oldScaleW = root.transforms.l[4]
   local oldScaleH = root.transforms.l[5]

   --scale = scaleX < scaleY ? scaleX : scaleY;
   local oldX = root.transforms.l[1]
   local oldY = root.transforms.l[2]


   local newScaleW = root.transforms.l[4] / (cw/200)
   local newScaleH = root.transforms.l[5] / (cw/200)
   
   root.transforms.l[4] = newScaleW 
   root.transforms.l[5] = newScaleH

   --print(oldScaleW, newScaleW)

   local c = getBBoxRecursive(root)

   love.graphics.push()
   love.graphics.translate(-c[1],0)
   renderThings(root)
   --print(c[1], b[1])
   love.graphics.pop()

   root.transforms.l[4] = oldScaleW
   root.transforms.l[5] = oldScaleH
   root.transforms.l[1] = oldX
   root.transforms.l[2] = oldY
   
   love.graphics.setColor(1,1,1)
--   love.graphics.line(0,0,200,0)
   love.graphics.line(0,0,200,200)

end
