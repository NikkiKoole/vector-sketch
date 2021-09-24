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
   if key == 'p' then
      renderNodeIntoCanvas(root, love.graphics.newCanvas(1000, 1000))
   end
end

function love.load()
   love.window.setMode( 1600, 1200 )
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={400,700,0,2,2,0,0}},
      children ={}
   }

   baas = parseFile('boat.polygons.txt')[1]

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

  --- canvas = love.graphics.newCanvas(1000, 1000)
end

function renderNodeIntoCanvas(node, canvas)

   love.graphics.setCanvas({canvas, stencil=true})
   love.graphics.clear()
   love.graphics.setBlendMode("alpha")

   drawNodeIntoRect(node, 0,0,canvas:getWidth(),canvas:getHeight())

   love.graphics.setCanvas()

   canvas:newImageData():encode("png","aPngImage.png")
end




function drawNodeIntoRect(node, x,y,w,h)
   -- first get the nodes bbox
   local bboxbefore = getBBoxRecursive(node)
   local cw = bboxbefore[3] - bboxbefore[1]
   local ch = bboxbefore[4] - bboxbefore[2]

   local oldScaleW = node.transforms.l[4]
   local oldScaleH = node.transforms.l[5]

   local newScaleW = oldScaleW / (cw/w)
   local newScaleH = oldScaleH / (ch/h)

   local biggestRatio = math.max(cw, ch)
   local newScaleW2 = oldScaleW / (biggestRatio/w)
   local newScaleH2 = oldScaleH / (biggestRatio/h)


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW
   node.transforms.l[5] = newScaleH
   local bboxafter = getBBoxRecursive(node) -- this bbox describes the squashed image


   -- here i am scaling the original
   node.transforms.l[4] = newScaleW2
   node.transforms.l[5] = newScaleH2
   local bboxafter2 = getBBoxRecursive(node) -- this bbox descirbes the image at the same ratio as original

   -- now i need to calculate the offset, which is the same as the difference between the 2 bounding boxes

   local w1 = bboxafter[3] - bboxafter[1]
   local w2 = bboxafter2[3] - bboxafter2[1]
   local h1 = bboxafter[4] - bboxafter[2]
   local h2 = bboxafter2[4] - bboxafter2[2]
   local offsetX = (w1 - w2)/2
   local offsetY = (h1 - h2)/2

   love.graphics.push()
   love.graphics.translate(-bboxafter2[1] + x + offsetX, -bboxafter2[2] + y + offsetY)
   renderThings(node)
   love.graphics.pop()



      -- here i am restoring the original
   node.transforms.l[4] = oldScaleW
   node.transforms.l[5] = oldScaleH

   love.graphics.setColor(1,1,1)
   love.graphics.line(x,y, x+w, y)
   love.graphics.line(x+w,y, x+w, y+h)
   love.graphics.line(x,y+h, x+w, y+h)
   love.graphics.line(x,y, x, y+h)
end

function love.draw()

   renderThings(root)
   love.graphics.setColor(1,1,1)
   love.graphics.line(b[1], b[2], b[3], b[2])
   love.graphics.line(b[1], b[2], b[1], b[4])
   love.graphics.line(b[3], b[2], b[3], b[4])
   love.graphics.line(b[1], b[4], b[3], b[4])


  -- drawNodeIntoRect(root, 100,100,300,100)
end
