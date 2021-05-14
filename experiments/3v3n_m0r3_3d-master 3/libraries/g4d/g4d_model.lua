local Vectors       = require(G4D_PATH .. '/g4d_vectors')
local Matrices      = require(G4D_PATH .. '/g4d_matrices')
local Collisions    = require(G4D_PATH .. '/g4d_collisions')
local load_obj      = require(G4D_PATH .. '/g4d_obj_loader')
local load_shader   = require(G4D_PATH .. '/g4d_shader_loader') -- TODO: make it possible to load shader using different method
local vertex_format = {
	{'VertexPosition', 'float', 3},
	{'VertexTexCoord', 'float', 2},
	{'VertexNormal'  , 'float', 3},
}

local Model = {}

for k, v in pairs(Collisions) do Model[k] = v end -- TODO: make this cleaner

function Model:new(vertices, texture, pos, rot, sca, parentTransform)
	local model = setmetatable({}, {__index = Model})

	model.x , model.y , model.z  = 0, 0, 0
	model.rx, model.ry, model.rz = 0, 0, 0
	model.sx, model.sy, model.sz = 1, 1, 1
	model.texture  = nil
	model.vertices = nil
	model.mesh     = nil
	model.aabb     = nil
	model.shader   = {
		name   = 'default',
		shader = load_shader('default'),
		data   = {
			matrix  = {},
			color   = {1, 1, 1, 1},
		},
	}

	model:set_vertices(vertices, parentTransform)
	model:set_texture(texture)
	model:move(pos)
	model:scale(sca)
	model:rotate(rot)
	model:update_matrix()
	return model
end

function Model:draw()
	love.graphics.setShader(self.shader.shader)
	
	for k, v in pairs(self.shader.data) do
		if self.shader.shader:hasUniform('model.' .. k) then 
			self.shader.shader:send('model.' .. k, v) 
		end
	end

	love.graphics.draw(self.mesh)
	love.graphics.setShader()
end

function Model:draw2(transform, shader)

	for k, v in pairs(self.shader.data) do
		if self.shader.shader:hasUniform('model.' .. k) then 
                   shader:send('model.' .. k, v) 
		end
	end

	love.graphics.draw(self.mesh, transform)
end

-- function model:draw2(shader, transform)
-- --    local shader = shader or self.shader
--    --   love.graphics.setShader(shader)
--     --print((self.matrix))
--     shader:send("modelMatrix", self.matrix)
--     love.graphics.draw(self.mesh, transform)
--     --love.graphics.setShader()
-- end


function Model:transform(x, y, z, rx, ry, rz, sx, sy, sz)
	self.x  = x  or self.x 
	self.y  = y  or self.y 
	self.z  = z  or self.z 
	self.rx = rx or self.rx
	self.ry = ry or self.ry
	self.rz = rz or self.rz
	self.sx = sx or self.sx
	self.sy = sy or self.sy
	self.sz = sz or self.sz

	return self:update_matrix()
end

function Model:update_matrix()
	self.shader.data.matrix = Matrices:get_transformation_matrix(
		self.x , self.y , self.z ,
		self.rx, self.ry, self.rz,
		self.sx, self.sy, self.sz
	)
	return self
end

function Model:move(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end
	return self:transform(x, y, z)
end

function Model:rotate(rx, ry, rz)
	if type(rx) == 'table' then rx, ry, rz = rx[1], rx[2], rx[3] end
	
	return self:transform(_, _, _, rx, ry, rz)
end

function Model:scale(sca)
	if type(sca) == 'table' then
		return self:transform(sca[1], sca[2], sca[3])
	elseif type(sca) == 'number'then
		return self:transform(_, _, _, _, _, _, sca, sca, sca)
	end
end

-- TODO: make it possible to load shader using different method
function Model:set_shader(name)
	self.shader.name   = name
	self.shader.shader = load_shader(name)
	return self
end

function Model:set_shader_data(name, value)
	self.shader.data[name] = value
	return self
end

function Model:set_texture(texture)
	if type(texture) == 'string' then texture = love.graphics.newImage(path) end
	self.texture = texture
	self.mesh:setTexture(self.texture)
	return self
end

function Model:set_vertices(vertices)
	if type(vertices) == 'string' then vertices = load_obj(vertices) end
	self.vertices = vertices
	self.aabb     = self:generate_aabb(self.vertices, parentTransform)
	self.mesh     = love.graphics.newMesh(vertex_format, self.vertices, 'triangles')
	self.mesh:setTexture(self.texture)
	return self
end

function Model:position() 
	return {self.x, self.y, self.z} 
end

function Model:get_rotation() 
	return {self.rx, self.ry, self.rz} 
end

function Model:get_scale() 
	return {self.sx, self.sy, self.sz} 
end

function Model:get_shader_data(name)
	return self.shader.data[name]
end

return setmetatable(Model, {__call = Model.new})
