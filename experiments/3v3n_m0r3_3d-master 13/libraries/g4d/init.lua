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

G4D_PATH         = ...
local Model      = require(G4D_PATH .. '/model')
local Camera     = require(G4D_PATH .. '/camera')
local Mat4       = require(G4D_PATH .. '/mat4')
local Vec3       = require(G4D_PATH .. '/vec3')
local Collision  = require(G4D_PATH .. '/collision')
local Quaternion = require(G4D_PATH .. '/quaternion')
G4D_PATH         = nil

-- TODO: use more than one camera on the same world

local G4d = {
	Mat4       = Mat4,
	Vec3       = Vec3,
	Quaternion = Quaternion,
	Collision  = Collision,
        Model      = Model
}

function G4d:new()
	local world = setmetatable({}, {__index = G4d})

	world.canvas = love.graphics.newCanvas()
	world.models = {}
	world.camera = Camera

	return world
end

function G4d:add_model(...)
	local model = Model(...)
	table.insert(self.models, model)
	return model
end

function G4d:draw(x, y, mine)
	love.graphics.setCanvas({self.canvas, depth=true})
	love.graphics.clear()
	for k, model in pairs(self.models) do model:draw() end
        --mine()

        lg.setShader(defaultshader)
        renderThings3d(mine)
        lg.setShader()
   
	love.graphics.setCanvas()

	love.graphics.draw(self.canvas, x or 0, y or 0)
end

return setmetatable(G4d, {__call = G4d.new})
