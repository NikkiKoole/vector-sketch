--[[
 4v0v - MIT license
 based on groverbuger's g3d 
 https://github.com/groverburger/g3d
      __ __        __     
     /\ \\ \      /\ \    
   __\ \ \\ \     \_\ \   
 /'_ `\ \ \\ \_   /'_` \  
/\ \L\ \ \__ ,__\/\ \L\ \ 
\ \____ \/_/\_\_/\ \___,_\
 \/___L\ \ \/_/   \/__,_ /
   /\____/                
   \_/__/                 
--]]

love.graphics.setDepthMode('lequal', true)

G4D_PATH     = ...
local model  = require(G4D_PATH .. '/g4d_model')
local camera = require(G4D_PATH .. '/g4d_camera')
G4D_PATH     = nil

local G4d = {
	Model  = model,
	Camera = camera,
	Canvas = love.graphics.newCanvas(),
}

function G4d:attach() 
	love.graphics.setCanvas({self.Canvas, depth=true})
	love.graphics.clear()
end

function G4d:detach() 
	love.graphics.setCanvas()
end

function G4d:draw(x, y)
   --print(self.Canvas:getWidth())
   love.graphics.draw(self.Canvas, x or 0, y or 0)
end

function G4d:resize(w,h)
   love.graphics.setCanvas()
   love.graphics.clear()
   self.Camera:resize(w,h/1.1)

   self.Canvas = love.graphics.newCanvas(w,h)
   love.graphics.setCanvas({self.Canvas, depth=true})
end

return G4d
