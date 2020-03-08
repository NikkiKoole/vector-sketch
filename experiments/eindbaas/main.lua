require 'util'
require 'poly'
flux = require "flux"
require 'main-utils'
inspect = require 'inspect'


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end

function love.load()
    root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={0,400,400,.25,.25,0,0}},
      children ={}
    }

    baas = parseFile('eindbaas.polygons.txt')
    table.insert(root.children, baas)
    parentize(root)
    meshAll(root)
end

function love.draw()
   
   renderThings(root)
end
