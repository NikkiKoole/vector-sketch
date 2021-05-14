local World, Collider, Shape, Joint, lg, lp = {}, {}, {}, {}, love.graphics, love.physics
local _uid = function() local func = function() local r = math.random(16) return ("0123456789ABCDEF"):sub(r, r) end return ("xxxxxxxxxxxxxxxx"):gsub("[x]", func) end
local _set_funcs = function(a, ...) 
	local args = {...}
	local _f = {__gc=0,__eq=0,__index=0,__tostring=0,isDestroyed=0,testPoint=0,getType=0,rayCast=0,destroy=0,setUserData=0,getUserData=0,release=0,type=0,typeOf=0}
	for _, arg in pairs(args) do for k, v in pairs(arg.__index) do if not _f[k] then a[k] = function(a, ...) return v(arg, ...) end end end end
end

function World:new(xg, yg, sleep)
	local function _callback(callback, fix1, fix2, contact, ...)
		if (not fix1:getUserData()) or (not fix2:getUserData()) then return end

		local shape1, shape2 = fix1:getUserData(), fix2:getUserData()
		local coll1 , coll2  = fix1:getBody():getUserData(), fix2:getBody():getUserData()
		local ctitle         = coll1._id  .. "\t" .. coll2._id
		local stitle         = shape1._id .. "\t" .. shape2._id
		local world          = coll1._world

		world[callback](shape1, shape2, contact, false, ...)
		shape1[callback](shape1, shape2, contact, false, ...)        
		shape2[callback](shape2, shape1, contact, true,  ...) 

		if callback == "_pre" or callback == "_post" then
			coll1[callback](shape1, shape2, contact, false)
			coll2[callback](shape2, shape1, contact, true)
		
		elseif callback == "_enter" then 
			if not world._collisions[ctitle] then 
				world._collisions[ctitle] = {}
				coll1._enter(shape1, shape2, contact, false)
				coll2._enter(shape2, shape1, contact, true)
			end
			table.insert(world._collisions[ctitle], stitle)

		elseif callback == "_exit" then
			for i,v in pairs(world._collisions[ctitle]) do 
				if v == stitle then 
					table.remove(world._collisions[ctitle], i) 
					break 
				end 
			end
			if #world._collisions[ctitle] == 0 then 
				world._collisions[ctitle] = nil
				coll1._exit(shape1, shape2, contact, false)
				coll2._exit(shape2, shape1, contact, true)
			end
		end
	end
	local function _enter(fix1, fix2, contact)     _callback("_enter", fix1, fix2, contact)      end
	local function _exit(fix1, fix2, contact)      _callback("_exit" , fix1, fix2, contact)      end
	local function _pre(fix1, fix2, contact)       _callback("_pre"  , fix1, fix2, contact)      end
	local function _post(fix1, fix2, contact, ...) _callback("_post" , fix1, fix2, contact, ...) end -- ... => normal_impulse1, tangent_impulse1, normal_impulse2, tangent_impulse2

	local _world = {
		_b2d          = lp.newWorld(xg, yg, sleep),
		_colliders    = {},
		_joints       = {},
		_classes      = {},
		_classes_mask = {},
		_collisions   = {},
		_queries      = {},
		_query_color  = {0, .8,  1, 1},
		_joint_color  = {1, .5, .2, 1},
		_enter        = function() end,
		_exit         = function() end,
		_pre          = function() end,
		_post         = function() end,
	}

	_set_funcs(_world, _world._b2d)
	setmetatable(_world, {__index = World})
	_world:setCallbacks(_enter, _exit, _pre, _post)
	_world:add_class("Default")

	return _world
end

function World:draw()
	local _r, _g, _b, _a = lg.getColor()
	-- Colliders --
	for k1, body in pairs(self:getBodies()) do 
		for k2, fixture in pairs(body:getFixtures()) do
			local _shape = fixture:getUserData()
			lg.setColor(_shape._color.r, _shape._color.g, _shape._color.b, _shape._color.a)
			if     fixture:getShape():getType() == "circle"  then 
				local _x, _y = fixture:getShape():getPoint()
				lg.push()
				lg.translate(body:getX(), body:getY())
				lg.rotate(body:getAngle())
				lg.circle(_shape._mode, _x, _y, fixture:getShape():getRadius())
				lg.pop()
			elseif fixture:getShape():getType() == "polygon" then 
				lg.polygon(_shape._mode, body:getWorldPoints(fixture:getShape():getPoints()))
			else   
				local _p = {body:getWorldPoints(fixture:getShape():getPoints())} 
				for i=1, #_p, 2 do 
					if i < #_p-2 then lg.line(_p[i], _p[i+1], _p[i+2], _p[i+3]) end 
				end 
			end
		end 
	end
	-- Joints --
	lg.setColor(self._joint_color)
	for _, joint in ipairs(self:getJoints()) do
		local x1, y1, x2, y2 = joint:getAnchors()
		if x1 and y1 then lg.circle('line', x1, y1, 6) end
		if x2 and y2 then lg.circle('line', x2, y2, 6) end
	end
	-- Queries --
	lg.setColor(self._query_color)
	for i = #self._queries, 1, -1 do 
		local _query = self._queries[i] 
		if     _query.type == "circle"   then lg.circle("line", _query.x, _query.y, _query.r)
		elseif _query.type =="rectangle" then lg.rectangle("line", _query.x, _query.y, _query.w, _query.h)
		elseif _query.type == "polygon"  then lg.polygon("line", _query.vertices) 
		elseif _query.type == "line"     then lg.line(_query.x1, _query.y1, _query.x2, _query.y2)  end
		_query.frames = _query.frames - 1
		if _query.frames == 0 then  table.remove(self._queries, i) end
	end
	lg.setColor(_r, _g, _b, _a)
end

function World:get_collisions() 
	return self._collisions 
end

function World:get_colliders() 
	local _colliders = {} 
	for k,v in pairs(self._colliders) do 
		table.insert(_colliders, v) 
	end 
	return _colliders 
end

function World:set_query_color(r,g,b,a)
	self._query_color = {r, g, b, a}
	return self
end

function World:set_joint_color(r,g,b,a)
	self._joint_color = {r, g, b, a}
	return self
end

function World:set_enter(func)
	self._enter = func
	return self
end

function World:set_exit(func)
	self._exit = func 
	return self
end

function World:set_presolve(func)
	self._pre   = func 
	return self 
end

function World:set_postsolve(func)
	self._post  = func 
	return self
end

function World:add_class(tag, ignore)
	local function sa(t1, t2) for k in pairs(t1) do if not t2[k] then return false end end for k in pairs(t2) do if not t1[k] then return false end end return true end
	local function a(g) local r = {} for l, _ in pairs(g) do r[l] = {} for k,v in pairs(g) do for _ ,v2 in pairs(v) do if v2 == l then r[l][k] = "" end end end end return r end
	local function b(g) local r = {} for k,v in pairs(g) do table.insert(r, v) end for i = #r, 1,-1 do  local s = false for j = #r, 1, -1 do if i ~= j and sa(r[i], r[j]) then s = true end end if s then table.remove( r, i ) end end return r end
	local function c(t1, t2) local r = {} for i, v in pairs(t2) do for l,v2 in pairs(t1) do if sa(v, v2) then r[l] = i end end end return r end
	local ignore = ignore or {}
	self._classes[tag] = ignore
	self._classes_mask = c(a(self._classes), b(a(self._classes)))
	for k,v in pairs(self._colliders) do v:setClass(v._class) end
	return self
end

function World:add_joint(a, b, c, d, ...) -- id, type, collider1, collider2, args
	local _id, _jt, _col1, _col2, _args, _j

	if type(a) == 'string' and type(b) == 'string' then 
		_id, _jt, _col1, _col2, _args = a, b, c, d, {...}
	else
		_id, _jt, _col1, _col2, _args = uid(), a, b, c, {d, ...}
	end

	assert(not self._joints[_id], "Joint already called '" .. tostring(_id) .."'.")

	if     _jt == "distance"  then _j = lp.newDistanceJoint(_col1._body, _col2._body, unpack(_args))
	elseif _jt == "friction"  then _j = lp.newFrictionJoint(_col1._body, _col2._body, unpack(_args))
	elseif _jt == "motor"     then _j = lp.newMotorJoint(_col1._body, _col2._body, unpack(_args))             
	elseif _jt == "prismatic" then _j = lp.newPrismaticJoint(_col1._body, _col2._body, unpack(_args))
	elseif _jt == "pulley"    then _j = lp.newPulleyJoint(_col1._body, _col2._body, unpack(_args))  
	elseif _jt == "revolute"  then _j = lp.newRevoluteJoint(_col1._body, _col2._body, unpack(_args))
	elseif _jt == "rope"      then _j = lp.newRopeJoint(_col1._body, _col2._body, unpack(_args))    
	elseif _jt == "weld"      then _j = lp.newWeldJoint(_col1._body, _col2._body, unpack(_args))    
	elseif _jt == "wheel"     then _j = lp.newWheelJoint(_col1._body, _col2._body, unpack(_args)) 
	elseif _jt == "gear"      then _j = lp.newGearJoint(_col1._joint, _col2._joint, unpack(_args))
	elseif _jt == "mouse"     then _j = lp.newMouseJoint(_col1._body, _col2, unpack(_args)) -- _col2 = x, ... = y
	else error("Unknow joint type")
	end     

	local _joint = {}
	_joint._world = self
	_joint._id    = _id
	_joint._type  = _jt
	_joint._joint = _j
	_joint._color = {r=1, g=0.5, b=0.25, a=1}

	_set_funcs(_joint, _joint._joint) 
	self._joints[_joint._id] = _joint

	return setmetatable(_joint , {__index = Joint})
end

function World:add_collider(id, collider_type, ...)
	assert( (not id) or not self._colliders[id], "Collider already called '" .. tostring(id) .."'.")

	local _w, _ct, _args, _collider, _b, _s = self._b2d, collider_type, {...}, {}
	if     _ct == "circle"    then _b, _s = lp.newBody(_w, _args[1], _args[2], _args[4] or "dynamic"), lp.newCircleShape(_args[3])
	elseif _ct == "rectangle" then _b, _s = lp.newBody(_w, _args[1], _args[2], _args[6] or "dynamic"), lp.newRectangleShape(0, 0, _args[3], _args[4], _args[5] or 0)
	elseif _ct == "polygon"   then _b, _s = lp.newBody(_w, _args[1], _args[2], _args[4] or "dynamic"), lp.newPolygonShape(unpack(_args[3]))
	elseif _ct == "line"      then _b, _s = lp.newBody(_w,        0,        0, _args[5] or "static" ), lp.newEdgeShape(_args[1], _args[2], _args[3], _args[4])
	elseif _ct == "chain"     then _b, _s = lp.newBody(_w,        0,        0, _args[3] or "static" ), lp.newChainShape(_args[1], unpack(_args[2]))  end
   
	_collider._world  = self
	_collider._id     = id or _uid()
	_collider._tag    = _collider._id
	_collider._class  = ""
	_collider._data   = {}
	_collider._color  = {r = 1, g = 1, b = 1, a = 1}
	_collider._mode   = "line"
	_collider._enter  = function() end
	_collider._exit   = function() end
	_collider._pre    = function() end
	_collider._post   = function() end
	_collider._body   = _b
	_collider._shapes = {
		main = {
			_collider = _collider,
			_id       = "main_" .. _collider._id,
			_tag      = "main",
			_shape    = _s,
			_fixture  = lp.newFixture(_b, _s, 1),
			_enter    = function() end,
			_exit     = function() end,
			_pre      = function() end,
			_post     = function() end,
			_color    = {r = 1, g = 1, b = 1, a = 1},
			_mode     = "line"
		}
	}
	_collider._shapes["main"]._fixture:setUserData(_collider._shapes["main"])
	_collider._body:setUserData(_collider)

	_set_funcs(_collider._shapes["main"], _collider._body, _collider._shapes["main"]._shape, _collider._shapes["main"]._fixture)
	_set_funcs(_collider, _collider._body, _collider._shapes["main"]._shape, _collider._shapes["main"]._fixture)

	setmetatable(_collider._shapes["main"], {__index = Shape})
	setmetatable(_collider, {__index = Collider})

	_collider:set_class("Default")
	self._colliders[_collider._id] = _collider

	return _collider
end

function World:add_circle(...) 
	local args = {...}
	local _id, _x, _y, _r, _type
	if type(args[1]) == 'string' then 
		_id, _x, _y, _r, _type = args[1], args[2], args[3], args[4], args[5]
	else 
		_x, _y, _r, _type = args[1], args[2], args[3], args[4]
	end
	return self:add_collider(_id, "circle", _x, _y, _r, _type) 
end

function World:add_rectangle(...)
	local args = {...}
	local _id, _x, _y, _w, _h, _angle, _type
	if type(args[1]) == 'string' then 
		_id, _x, _y, _w, _h, _angle, _type = args[1], args[2], args[3], args[4], args[5], args[6], args[7]
	else 
		_x, _y, _w, _h, _angle, _type = args[1], args[2], args[3], args[4], args[5], args[6]
	end
	return self:add_collider(_id, "rectangle", _x, _y, _w, _h, _angle, _type) 
end

function World:add_polygon(...)
	local args = {...}
	local _id, _x, _y, _vertices, _type
	if type(args[1]) == 'string' then 
		_id, _x, _y, _vertices, _type = args[1], args[2], args[3], args[4], args[5]
	else 
		_x, _y, _vertices, _type = args[1], args[2], args[3], args[4]
	end
	return self:add_collider(_id, "polygon", _x, _y, _vertices, _type) 
end

function World:add_line(...) 
	local args = {...}
	local _id, _x1, _x2, _y1, _y2, _type
	if type(args[1]) == 'string' then 
		_id, _x1, _x2, _y1, _y2, _type = args[1], args[2], args[3], args[4], args[5], args[6]
	else 
		_x1, _x2, _y1, _y2, _type = args[1], args[2], args[3], args[4], args[5]
	end
	return self:add_collider(_id, "line", _x1, _y1, _x2, _y2, _type) 
end

function World:add_chain(...)
	local args = {...}
	local _id, _loop, _vertices, _type
	if type(args[1]) == 'string' then 
		_id, _loop, _vertices, _type = args[1], args[2], args[3], args[4]
	else 
		_loop, _vertices, _type = args[1], args[2], args[3]
	end
	return self:add_collider(_id, "chain", _loop, _vertices, _type) 
end

function World:query_circle(x, y, r, class)
	local _colliders = {}
	for k,v in pairs(self._colliders) do
		local _x,_y = v:getPosition()
		if math.sqrt((_x - x)^2 + (_y - y)^2) <= r then
			if not class then table.insert(_colliders, v)
			elseif class then if v:getClass() == class then table.insert(_colliders, v) end end
		end
	end
	table.insert(self._queries, {type = "circle", x = x, y = y, r = r, frames = 80 })
	return _colliders
end

function World:query_rectangle(x, y, w, h, class)
	local _colliders = {}
	for k,v in pairs(self._colliders) do
		local _x,_y = v:getPosition()
		if _x >= x and _x <= x + w and _y >= y and _y <= y + h then
			if not class then table.insert(_colliders, v)
			elseif class then if v:getClass() == class then table.insert(_colliders, v) end end
		end
	end
	table.insert(self._queries, {type = "rectangle", x = x, y = y, w = w, h = h, frames = 80 })
	return _colliders
end

function World:query_polygon(vertices, class)
	local _colliders = {}
	for k,v in pairs(self._colliders) do
		local _x,_y = v:getPosition()
		local _collision, _next = false, 1
		for i = 1, #vertices, 2 do
			_next = i + 2
			if _next > #vertices then _next = 1 end
			local _vcx, _vcy,  _vnx, _vny = vertices[i], vertices[i+1], vertices[_next], vertices[_next+1]
			if (((_vcy >= _y and _vny < _y) or (_vcy < _y and _vny >= _y)) 
			and (_x < (_vnx-_vcx)*(_y-_vcy)/ (_vny-_vcy) + _vcx)) then 
					_collision = not _collision 
			end
		end
		if _collision then
			if not class then table.insert(_colliders, v)
			elseif class then if v:getClass() == class then table.insert(_colliders, v) end end
		end
	end
	table.insert(self._queries, {type = "polygon", vertices = vertices, frames = 80 })
	return _colliders
end

function World:query_line(x1, y1, x2, y2, class)
	local _colliders, _colliders_tag = {}, {}
	self._b2d:rayCast(x1, y1, x2, y2, function(fixture)
		if not class then 
			if not _colliders_tag[fixture:getUserData():getCtag()] then 
				table.insert(_colliders, fixture:getUserData():getCollider())
				_colliders_tag[fixture:getUserData():getCtag()] = "default"
			end
		else
			if fixture:getUserData():getCollider():getClass() == class then 
				if not _colliders_tag[fixture:getUserData():getCtag()] then 
					table.insert(_colliders, fixture:getUserData():getCollider())
					_colliders_tag[fixture:getUserData():getCtag()] = "default"
				end
			end
		end
		return 1
	end)
	table.insert(self._queries, {type = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, frames = 80 })
	return _colliders
end

function World:destroy()
	for k,v in pairs(self._colliders) do v:destroy() end
	for k,v in pairs(self._joints)    do v:destroy() end
	self.box2d:destroy()
	for k,v in pairs(self) do v = nil end
end

function World:get_collider(tag)
	return self._colliders[tag]
end

function World:get_joint(tag)
	return self._joints[tag]
end

function Joint:draw()
	local _r, _g, _b, _a = lg.getColor()
	lg.setColor(self._color.r, self._color.g, self._color.b, self._color.a)
	local x1, y1, x2, y2 = self:getAnchors()
	if x1 and y1 then lg.circle('line', x1, y1, 6) end
	if x2 and y2 then lg.circle('line', x2, y2, 6) end
	lg.setColor(_r, _g, _b, _a)
end

function Joint:set_alpha(a) 
	self._color.a = a 
	return self 
end

function Joint:set_color(r, g, b, a) 
	self._color = {r = r, g = g, b = b, a = a or self._color.a} 
	return self 
end

function Joint:destroy()
	self._world._joints[self._id] = nil 
	self._world = nil
	self._joint:destroy()
	self._joint = nil
end

function Collider:set_class(class)
	local class = class or "Default"
	assert( self._world._classes[class] , "Class "  .. class .. " is undefined.")
	self._class = class
	local tmask = {}
	for _, v in pairs(self._world._classes[class]) do table.insert(tmask, self._world._classes_mask[v]) end
	for k, v in pairs(self._shapes) do  v._fixture:setCategory(self._world._classes_mask[class]) v._fixture:setMask(unpack(tmask))end
	return self
end

function Collider:set_enter(func) 
	self._enter = func 
	return self 
end

function Collider:set_exit(func) 
	self._exit = func 
	return self 
end

function Collider:set_presolve(func) 
	self._pre = func 
	return self 
end

function Collider:set_postsolve(func) 
	self._post = func 
	return self 
end

function Collider:set_data(data) 
	self._data = data 
	return self 
end

function Collider:set_tag(tag)
	self._tag = tag
	return self
end

function Collider:get_class()
	return self._class
end

function Collider:get_tag()
	return self._tag
end

function Collider:get_data(data)
	return self._data
end

function Collider:get_shape(tag)
	return self._shapes[tag]
end

function Collider:add_shape(tag, shape_type, ...)
	assert(not self._shapes[tag], "Collider already have a shape called '" .. tag .."'.")
	local _st, _a, _shape = shape_type, {...}
	if     _st == "circle"    then _shape = lp.newCircleShape(_a[1], _a[2], _a[3])
	elseif _st == "rectangle" then _shape = lp.newRectangleShape(_a[1], _a[2], _a[3], _a[4], _a[5])
	elseif _st == "polygon"   then _shape = lp.newPolygonShape(unpack(_a[1]))
	elseif _st == "line"      then _shape = lp.newEdgeShape(_a[1], _a[2], _a[3], _a[4])
	elseif _st == "chain"     then _shape = lp.newChainShape(_a[1], unpack(_a[2])) end

	local shape = {
		_tag      = tag,
		_type     = _st,
		_id       = tag .. "_" .. self._id,
		_collider = self,
		_shape    = _shape,
		_fixture  = lp.newFixture(self._body, _shape, 1),
		_enter    = function() end,
		_exit     = function() end,
		_pre      = function() end,
		_post     = function() end,
		_color    = {r = self._color.r, g = self._color.g, b =self._color.b, a =self._color.a},
		_mode  = self._mode 
	}
	_set_funcs(shape, self._body, shape._shape, shape._fixture)

	shape._fixture:setUserData(shape)
	local tmask = {}
	for _, v in pairs(self._world._classes[self._class]) do 
		table.insert(tmask, self._world._classes_mask[v]) 
	end
	shape._fixture:setCategory(self._world._classes_mask[self._class])
	shape._fixture:setMask(unpack(tmask))

	setmetatable(shape, {__index = Shape})
	self._shapes[tag] = shape
	
	return shape
end

function Collider:draw()
	local _r, _g, _b, _a = lg.getColor()
	for _, fixture in pairs(self._body:getFixtures()) do
		local _shape = fixture:getUserData()
		lg.setColor(_shape._color.r, _shape._color.g, _shape._color.b, _shape._color.a)
		if fixture:getShape():getType() == "circle"  then 
			local _x, _y = fixture:getShape():getPoint()
			lg.push()
			lg.translate(self._body:getX(), self._body:getY())
			lg.rotate(self._body:getAngle())
			lg.circle(_shape._mode, _x, _y, fixture:getShape():getRadius())
			lg.pop()
		elseif fixture:getShape():getType() == "polygon" then 
			lg.polygon(_shape._mode, self._body:getWorldPoints(fixture:getShape():getPoints()))
		else   
			local _p = {self._body:getWorldPoints(fixture:getShape():getPoints())} 
			for i=1, #_p, 2 do 
				if i < #_p-2 then lg.line(_p[i], _p[i+1], _p[i+2], _p[i+3]) end 
			end
		end
	end
	lg.setColor(_r, _g, _b, _a)
end

function Collider:set_alpha(a) 
	self._color.a = a
	for _,v in pairs(self._shapes) do v._color.a = a end 
	return self 
end

function Collider:set_color(r, g, b, a)
	self._color = {r = r, g = g, b = b, a = a or self._color.a}    
	for _,v in pairs(self._shapes) do v._color = {r = r, g = g, b = b, a = a or v._color.a} end 
	return self 
end

function Collider:set_mode(mode)
	self._mode = mode
	for _,v in pairs(self._shapes) do v._mode = mode end 
	return self 
end

function Collider:remove_shape(tag)
	assert(self._shapes[tag], "Shape '" .. tag .. "' doesn't exist.")
	for k, v in pairs(self._world._collisions) do 
		if k:find(self._id) then 
			for i = #v, 1, -1 do 
				if v[i]:find(self._shapes[tag]._id) then table.remove(self._world._collisions[k], i) end
			end
		end
		if #v == 0 then self._world._collisions[k] = nil end
	end

	self._shapes[tag]._fixture:setUserData(nil)
	self._shapes[tag]._fixture:destroy()
	self._shapes[tag]._fixture  = nil
	self._shapes[tag]._collider = nil
	self._shapes[tag]._shape    = nil
	self._shapes[tag]           = nil
	return self
end

function Collider:destroy()
	for k, v in pairs(self._world._collisions) do if k:find(self._id) then self._world._collisions[k] = nil end end
	for tag in pairs(self._shapes) do
		self:remove_shape(tag)
	end
	self._world._colliders[self._id] = nil 
	self._world = nil
	self._data = nil
	self._body:setUserData(nil)
	self._body:destroy()
	self._body = nil
end

function Shape:set_enter(func)
	self._enter = func
	return self
end

function Shape:set_exit(func)
	self._exit = func
	return self
end

function Shape:set_presolve(func)
	self._pre = func
	return self
end

function Shape:set_postsolve(func)
	self._post = func 
	return self
end

function Shape:set_alpha(a)
	self._color.a = a
	return self
end

function Shape:set_color(r, g, b, a) 
	self._color = {r = r, g = g, b = b, a = a or self._color.a}
	return self
end

function Shape:set_mode(mode)
	self._mode = mode
	return self
end

function Shape:get_collider()
	return self._collider
end

function Shape:get_class()
	return self._collider._class
end

function Shape:get_collider_tag()
	return self._collider._tag
end

function Shape:get_tag()
	return self._tag
end

function Shape:destroy()
	self._collider:remove_shape(self._tag)
end

return setmetatable({}, {__call = World.new})
