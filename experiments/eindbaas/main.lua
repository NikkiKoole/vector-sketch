package.path = package.path .. ";../../?.lua"

local inspect = require 'vendor.inspect'

local parse = require 'lib.parse-file'
local parentize = require 'lib.parentize'
local render = require 'lib.render'
local mesh = require 'lib.mesh'
local bbox = require 'lib.'

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
   if key == 'p' then
      render.renderNodeIntoCanvas(root, love.graphics.newCanvas(1000, 1000))
   end
end

function love.load()
   love.window.setMode( 1700, 1200 )
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={400,700,0,2,2,0,0}},
      children ={}
   }

   baas = parse.parseFile('deurlaag3.polygons.txt')[1]

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

   parentize.parentize(root)
   mesh.meshAll(root)
   render.renderThings(root)

   b = bbox.getBBoxRecursive(root)

  --- canvas = love.graphics.newCanvas(1000, 1000)
end



function love.draw()

   render.renderThings(root)
   love.graphics.setColor(1,1,1)
   love.graphics.line(b[1], b[2], b[3], b[2])
   love.graphics.line(b[1], b[2], b[1], b[4])
   love.graphics.line(b[3], b[2], b[3], b[4])
   love.graphics.line(b[1], b[4], b[3], b[4])


  -- drawNodeIntoRect(root, 100,100,300,100)
end
