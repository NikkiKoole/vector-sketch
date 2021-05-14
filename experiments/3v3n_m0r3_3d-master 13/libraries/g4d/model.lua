local Vec3       = require(G4D_PATH .. '/vec3')
local Mat4       = require(G4D_PATH .. '/mat4')
local Collision  = require(G4D_PATH .. '/collision')
local Quaternion = require(G4D_PATH .. '/quaternion')
local Shaders    = require(G4D_PATH .. '/shaders')
local load_obj  = require(G4D_PATH .. '/obj_loader')
local vertex_format = {
	{'VertexPosition', 'float', 3},
	{'VertexTexCoord', 'float', 2},
	{'initial_vertex_surface_normal', 'float', 4},
	{'initial_vertex_normal', 'float', 4},
}

local Model = {}

function Model:new(vertices, texture, pos, rot, sca)
	local model = setmetatable({}, {__index = Model})

	model.x , model.y , model.z  = 0, 0, 0
	model.rx, model.ry, model.rz, model.rw = 0, 0, 0, nil
	model.sx, model.sy, model.sz = 1, 1, 1
	model.texture  = nil
	model.vertices = nil
	model.mesh     = nil
	model.aabb     = nil
	model.shader   = {
		name     = '',
		shader   = nil,
		data     = {},
	}

	model:set_vertices(vertices)
	model:set_texture(texture)

	model:move(pos)
	model:scale(sca)
	model:rotate(rot)

	model:set_shader('default.glsl')
	model:set_shader_data('color'         , {1, 1, 1, 1})
	model:set_shader_data('matrix'        , model:get_matrix())
	model:set_shader_data('inverse_matrix', model:get_inverse_matrix())
	model:set_shader_data('position'      , model:position())

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
function Model:drawReuseShader(shader)

	for k, v in pairs(self.shader.data) do
		if self.shader.shader:hasUniform('model.' .. k) then 
                   shader:send('model.' .. k, v) 
		end
	end

	love.graphics.draw(self.mesh)
end
-- function Model:draw3(transform)
-- 	love.graphics.setShader(self.shader.shader)
	
-- 	for k, v in pairs(self.shader.data) do
-- 		if self.shader.shader:hasUniform('model.' .. k) then 
-- 			self.shader.shader:send('model.' .. k, v) 
-- 		end
-- 	end

-- 	love.graphics.draw(self.mesh, transform)
-- 	love.graphics.setShader()
-- end
function Model:move(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end
	return self:transform(x, y, z)
end

function Model:rotate(rx, ry, rz, rw) -- euler / quaternion
	if type(rx) == 'table' then rx, ry, rz, rw = rx[1], rx[2], rx[3], rx[4] end
	
	return self:transform(_, _, _, rx, ry, rz, rw)
end

function Model:scale(sca)
	if type(sca) == 'table' then
		return self:transform(_, _, _, _, _, _, _, sca[1], sca[2], sca[3])
	elseif type(sca) == 'number'then
		return self:transform(_, _, _, _, _, _, _, sca, sca, sca)
	end
end

function Model:transform(x, y, z, rx, ry, rz, rw, sx, sy, sz)
	self.x  = x  or self.x 
	self.y  = y  or self.y 
	self.z  = z  or self.z 
	self.rx = rx or self.rx
	self.ry = ry or self.ry
	self.rz = rz or self.rz
	self.rw = rw or self.rw
	self.sx = sx or self.sx
	self.sy = sy or self.sy
	self.sz = sz or self.sz

	self:set_shader_data('matrix'        , self:get_matrix())
	self:set_shader_data('inverse_matrix', self:get_inverse_matrix())
	self:set_shader_data('position'      , self:position())

	return self
end

-- TODO: change the way to load shader using different emplacement
function Model:set_shader(name)
	assert(Shaders[name], name .. ' doesn\'t exists.')
	self.shader.name   = name
	self.shader.shader = Shaders[name]
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
	self:generate_initial_vertex_surface_normals()
	self:generate_initial_vertex_normals()

	self.aabb     = Collision.generate_aabb(self, self.vertices)
	self.mesh     = love.graphics.newMesh(vertex_format, self.vertices, 'triangles')
	self.mesh:setTexture(self.texture)
	return self
end

function Model:generate_initial_vertex_surface_normals(is_flipped)
	local flip = is_flipped and -1 or 1

	for i=1, #self.vertices, 3 do
		local v1 = self.vertices[i]
		local v2 = self.vertices[i+1]
		local v3 = self.vertices[i+2]

		local vec1   = Vec3(v2[1]-v1[1], v2[2]-v1[2], v2[3]-v1[3])
		local vec2   = Vec3(v3[1]-v2[1], v3[2]-v2[2], v3[3]-v2[3])
		local normal = vec1:cross_product(vec2):normalized() 

		v1[6] = normal[1] * flip
		v1[7] = normal[2] * flip
		v1[8] = normal[3] * flip
		v1[9] = 0

		v2[6] = normal[1] * flip
		v2[7] = normal[2] * flip
		v2[8] = normal[3] * flip
		v2[9] = 0

		v3[6] = normal[1] * flip
		v3[7] = normal[2] * flip
		v3[8] = normal[3] * flip
		v3[9] = 0
	end
end

function Model:generate_initial_vertex_normals()
	if #self.vertices > 10000 then -- TODO: make a way to remove this limit
		for i, vert in ipairs(self.vertices) do
			self.vertices[i][10] = self.vertices[i][6]
			self.vertices[i][11] = self.vertices[i][7]
			self.vertices[i][12] = self.vertices[i][8]
			self.vertices[i][13] = 0
		end
		return
	end

	local groups_by_vertex_pos = {} -- {x, y, z, verts = {}, normal = Vec3}

	for i, vert in ipairs(self.vertices) do
		for j, group in ipairs(groups_by_vertex_pos) do
			if vert[1] == group.x and vert[2] == group.y and vert[3] == group.z then
				table.insert(group.verts, i)
				group.normal = group.normal + Vec3(vert[6], vert[7], vert[8])
				goto continue
			end
		end
		table.insert(groups_by_vertex_pos, {
			x = vert[1], y = vert[2], z = vert[3], verts = {i}, normal = Vec3(vert[6], vert[7], vert[8])})
		::continue::
	end

	for i, group in ipairs(groups_by_vertex_pos) do
		group.normal = group.normal / #group.verts

		for j, vert in ipairs(group.verts) do 
			self.vertices[vert][10] = group.normal[1]
			self.vertices[vert][11] = group.normal[2]
			self.vertices[vert][12] = group.normal[3]
			self.vertices[vert][13] = 0
		end
	end

end

function Model:get_matrix()
	return Mat4:get_transformation_matrix(
		self.x , self.y , self.z ,
		self.rx, self.ry, self.rz, self.rw,
		self.sx, self.sy, self.sz
	)
end

function Model:get_inverse_matrix()
	return Mat4.transpose(Mat4.invert(self:get_matrix())) 
end

function Model:position() 
	return Vec3(self.x, self.y, self.z) 
end

function Model:pos() 
	return Vec3(self.x, self.y, self.z) 
end

function Model:rotation()
	if self.rw then
		return Quaternion(self.rx, self.ry, self.rz, self.rw)
	else
		return Vec3(self.rx, self.ry, self.rz)
	end
end

function Model:rot() 
	if self.rw then
		return Quaternion(self.rx, self.ry, self.rz, self.rw)
	else
		return Vec3(self.rx, self.ry, self.rz)
	end
end

function Model:sca() 
	return Vec3(self.sx, self.sy, self.sz) 
end

function Model:get_shader_data(name)
	return self.shader.data[name]
end

function Model:generate_aabb(...)
	return Collision.generate_aabb(self, ...)
end

function Model:generate_collision_zone(...)
	return Collision.generate_collision_zone(self, ...)
end

function Model:collide_with_aabb(...)
	return Collision.collide_with_aabb(self, ...)
end

function Model:collide_with_positional_ray(...)
	return Collision.collide_with_positional_ray(self, ...)
end

function Model:collide_with_directional_ray(...)
	return Collision.collide_with_directional_ray(self, ...)
end

function Model:ray_intersection(...)
	return Collision.ray_intersection(self, ...)
end

function Model:sphere_intersection(...)
	return Collision.sphere_intersection(self, ...)
end

function Model:capsule_intersection(...)
	return Collision.capsule_intersection(self, ...)
end

function Model:closest_point(...)
	return Collision.closest_point(self, ...)
end

function Model:get_distance_from(...)
	return Collision.get_distance_from(self, ...)
end

return setmetatable(Model, {__call = Model.new})


