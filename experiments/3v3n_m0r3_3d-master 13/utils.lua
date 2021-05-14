function uid()
	return ('xxxxxxxxxxxxxxxx'):gsub('[x]', function() 
		local r = math.random(16) return ('0123456789ABCDEF'):sub(r, r) 
	end)
end

function cmyk(...)
	local args = {...}
	local c, m, y, k, a
	if type(args[1]) == 'table' then 
		c, m, y, k, a = args[1][1], args[1][2], args[1][3], args[1][4], args[1][5]
	else
		c, m, y, k, a = args[1], args[2], args[3], args[4], args[5]
	end
	local r = 1 - (c * (1 - k) + k)
	local g = 1 - (m * (1 - k) + k)
	local b = 1 - (y * (1 - k) + k)
	return {r, g, b, a}
end

function get(object, path, default)
	local value = object

	if type(object) == 'table' then
		if type(path) == 'table' then
			local c = 1
			while type(path[c]) ~= 'nil' do
				if type(value) ~= 'table' then return default end
				value = value[path[c]]
				c = c + 1
			end
		elseif type(path) == 'string' then
			local keys = {}
			for match in (path..'.'):gmatch('(.-)%.') do table.insert(keys, match) end
			return get(object, keys, default)
		end
	end

	if type(value) ~= 'nil' then 
		return value
	else
		return default
	end
end

function map(t, func)
	local tbl = {}
	for k, v in pairs(t) do
		local result = func(v, k)
		table.insert(tbl, result)
	end
	return tbl
end

function foreach(iterable, func)
	if type(iterable) == 'nil' then
		return
	elseif type(iterable) == 'number' then 
		for i = 1, iterable do func(i) end
	elseif type(iterable) == 'table' and not iterable[1] then
		for k, v in pairs(iterable) do func(v, k) end
	elseif type(iterable) == 'table' and iterable[1] then
		for k, v in ipairs(iterable) do func(v, k) end
	end
end

function sign(x)
	if x >= 0 then return 1 else return -1 end
end

function insert(...)
	return table.insert(...)
end

function lerp(a, b, x) 
	return a + (b - a) * x 
end

function framerate_independent_lerp(a, b, x, dt) 
	return a + (b - a) * (1.0 - math.exp(-x * dt)) 
end

function cerp(a, b, x) 
	local f=(1-math.cos(x*math.pi))*.5 
	return a*(1-f)+b*f 
end

function clamp(low, n, high) 
	return math.min(math.max(low, n), high) 
end

function almost_equal(a, b, x)
	return a + x >= b and a - x <= b
end

function require_all(path, opts)
	local items = love.filesystem.getDirectoryItems(path)
	for _, item in pairs(items) do
		if love.filesystem.getInfo(path .. '/' .. item, 'file') then 
			require(path .. '/' .. item:gsub('.lua', '')) 
		end
	end
	if opts and opts.recursive then 
		for _, item in pairs(items) do
			if love.filesystem.getInfo(path .. '/' .. item, 'directory') then 
				require_all(path .. '/' .. item, {recursive = true}) 
			end
		end
	end
end

function size(t)
	local s = 0 
	for _ in pairs(t) do s = s + 1 end 
	return s 
end

function uniq(t)
	local filtered = {}
	local temp = {}
	for _, v in ipairs(t) do 
		temp[v] = true
	end
	for k, _ in pairs(temp) do 
		table.insert(filtered, k)
	end
  return filtered
end

function random_value(t) 
	local _values = {} 
	for _, v in pairs(t) do _values[#_values + 1] = v end
	return _values[math.random(#_values)]
end

function random_key(t) 
	local keys = {} 
	for k, _ in pairs(t) do keys[#keys + 1] = k end
	return keys[math.random(#keys)]
end

old_print = print
function print(...)
	local args = {...}
	-- check if table has __tostring metamethod
	if type(args[1]) == 'table' then
		local meta = getmetatable(args[1])
		if meta and meta.__tostring then old_print(args[1]) return end
	else 
		old_print(...) return
	end

	local tables, functions, others = {}, {}, {}
	for k, v in pairs(args[1]) do 
		if type(v) == 'table' then
			local s = 0 for _ in pairs(v) do s = s + 1 end 
			table.insert(tables, {key = k, size = s}) 
		elseif type(v) == 'function' then
			table.insert(functions, {key = k})
		else
			table.insert(others, {key = k, value = v})
		end
	end

	table.sort(tables,    function(a, b) return tostring(a.key) < tostring(b.key) end)
	table.sort(functions, function(a, b) return tostring(a.key) < tostring(b.key) end)
	table.sort(others,    function(a, b) return tostring(a.key) < tostring(b.key) end)

	for k,v in pairs(tables)    do if v.size == 0 then print('[' .. v.key .. '] : {}') else print('[' .. v.key .. '] : {...}') end end
	for k,v in pairs(functions) do print(v.key .. '()') end
	for k,v in pairs(others)    do print('[' .. v.key .. '] : ' .. tostring(v.value)) end
end

function rounded(number, n)
	n = n or 2
	return tonumber(string.format('%.' ..n ..'f', number))
end

function table.keys(t) 
	local _keys = {}
	for k, _ in pairs(t) do _keys[#_keys + 1] = k end 
	return _keys 
end

function table.values(t)
	local _values = {} 
	for _, v in pairs(t) do _values[#_values + 1] = v end 
	return _values 
end

function circ_circ_collision(...)
	local args = {...}
	local c1, c2 = args[1], args[2]

	if #args == 6 then 
		c1, c2 = {args[1], args[2], args[3]}, {args[4], args[5], args[6]}
	end

	if #c1 == 3 then c1 = {x = c1[1], y = c1[2], r = c1[3]} end
	if #c2 == 3 then c2 = {x = c2[1], y = c2[2], r = c2[3]} end

	return (c2.x - c1.x)^2 + (c2.y - c1.y)^2 < ((c1.r + c2.r)^2)
end

function rect_rect_collision(...)
	local args = {...}
	local r1, r2 = args[1], args[2]

	if #args == 8 then 
		r1, r2 = {args[1], args[2], args[3], args[4]}, {args[5], args[6], args[7], args[8]}
	end

	if #r1 == 4 then r1 = {x = r1[1], y = r1[2], w = r1[3], h = r1[4]} end
	if #r2 == 4 then r2 = {x = r2[1], y = r2[2], w = r2[3], h = r2[4]} end

	return r1.x < r2.x + r2.w and r1.x + r1.w > r2.x and r1.y < r2.y + r2.h and r1.h + r1.y > r2.y
end

function circ_rect_collision(...)
	local args = {...}
	local c, r = args[1], args[2]

	if #args == 7 then 
		c, r = {args[1], args[2], args[3]}, {args[4], args[5], args[6], args[7]}
	end

	if #c == 3 then c = {x = c[1], y = c[2], r = c[3]} end
	if #r == 4 then r = {x = r[1], y = r[2], w = r[3], h = r[4]} end

	local _x, _y
  	if c.x < r.x then _x = r.x elseif c.x > r.x + r.w then _x = r.x + r.w else _x = c.x end
  	if c.y < r.y then _y = r.y elseif c.y > r.y + r.h then _y = r.y + r.h else _y = c.y end
	return math.sqrt( (c.x - _x)^2 + (c.y - _y)^2 ) <= c.r
end

function rect_circ_collision(...)
	local args = {...}
	local r, c = args[1], args[2]

	if #args == 7 then 
		r, c = {args[1], args[2], args[3], args[4]}, {args[5], args[6], args[7]}
	end

	if #r == 4 then r = {x = r[1], y = r[2], w = r[3], h = r[4]} end
	if #c == 3 then c = {x = c[1], y = c[2], r = c[3]} end

	local _x, _y
  if c.x < r.x then _x = r.x elseif c.x > r.x + r.w then _x = r.x + r.w else _x = c.x end
  if c.y < r.y then _y = r.y elseif c.y > r.y + r.h then _y = r.y + r.h else _y = c.y end
	return math.sqrt( (c.x - _x)^2 + (c.y - _y)^2 ) <= c.r
end

function rect_point_collision(...)
	local args = {...}
	local r, p = args[1], args[2]

	if #args == 6 then 
		r, p = {args[1], args[2], args[3], args[4]}, {args[5], args[6]}
	end

	if #r == 4 then r = {x = r[1], y = r[2], w = r[3], h = r[4]} end
	if #p == 2 then p = {x = p[1], y = p[2]} end

	return p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h
end

function point_rect_collision(...)
	local args = {...}
	local p, r = args[1], args[2]

	if #args == 6 then 
		p, r = {args[1], args[2]}, {args[3], args[4], args[5], args[6]}
	end

	if #p == 2 then p = {x = p[1], y = p[2]} end
	if #r == 4 then r = {x = r[1], y = r[2], w = r[3], h = r[4]} end

	return p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h
end

function point_circ_collision(...)
	local args = {...}
	local p, c = args[1], args[2]

	if #args == 5 then 
		p, c = {args[1], args[2]}, {args[3], args[4], args[5]}
	end

	if #p == 2 then p = {x = p[1], y = p[2]} end
	if #c == 3 then c = {x = c[1], y = c[2], r = c[3]} end

  return math.sqrt( (p.x - c.x)^2 + (p.y - c.y)^2 ) <= c.r 
end

function circ_point_collision(...)
	local args = {...}
	local c, p = args[1], args[2]

	if #args == 5 then 
		c, p = {args[1], args[2], args[3]}, {args[4], args[5]}
	end

	if #c == 3 then c = {x = c[1], y = c[2], r = c[3]} end
	if #p == 2 then p = {x = p[1], y = p[2]} end

	return math.sqrt( (p.x - c.x)^2 + (p.y - c.y)^2 ) <= c.r 
end

function point_poly_collision(p, poly)
	local tx, ty = p.x, p.y
	if (#pgon < 6) then
		return false
	end
 
	local x1 = pgon[#pgon - 1]
	local y1 = pgon[#pgon]
	local cur_quad
	local next_quad
	local total = 0

	if x1 < tx then
		if y1 < ty then cur_quad = 1
		else cur_quad = 4 end
	else
		if y1 < ty then cur_quad = 2
		else cur_quad = 3 end	
	end

	for i = 1,#pgon,2 do
		local x2 = pgon[i]
		local y2 = pgon[i+1]

		if x2 < tx then
			if y2 < ty then next_quad = 1
			else next_quad = 4 end
		else
			if y2 < ty then next_quad = 2
			else next_quad = 3 end	
		end

		local diff = next_quad - cur_quad
 
		if (diff == 2) or (diff == -2) then
			if (x2 - (((y2 - ty) * (x1 - x2)) / (y1 - y2))) < tx then
				diff = -diff
			end
		elseif diff == 3 then
			diff = -1
		elseif diff == -3 then
			diff = 1
		end
 
		total = total + diff
		cur_quad = next_quad
		x1 = x2
		y1 = y2
	end
 
	return (math.abs(total)==4)
end
 
function rect_rect_inside(r1, r2)
	if #r1 == 4 then r1 = {x = r1[1], y = r1[2], w = r1[3], h = r1[4]} end
	if #r2 == 4 then r2 = {x = r2[1], y = r2[2], w = r2[3], h = r2[4]} end

	return r1.x >= r2.x and r1.y >= r2.y and r1.x + r1.w <= r2.x + r2.w and r1.y + r1.h <= r2.y + r2.h 
end

function rect_center(r)
	if #r == 4 then r = {x = r[1], y = r[2], w = r[3], h = r[4]} end

	return r.x + r.w / 2, r.y + r.h / 2
end

function min_angle_between_3_points(p1, p2, p3)
	if #p1 == 2 then p1 = {x = p1[1], y = p1[2]} end
	if #p2 == 2 then p2 = {x = p2[1], y = p2[2]} end
	if #p3 == 2 then p3 = {x = p3[1], y = p3[2]} end

	local p1c  = math.sqrt((p2.x-p1.x)^2 + (p2.y-p1.y)^2) 
	local p3c  = math.sqrt((p2.x-p3.x)^2 + (p2.y-p3.y)^2)
	local p1p3 = math.sqrt((p3.x-p1.x)^2 + (p3.y-p1.y)^2)
	
	return math.acos((p3c*p3c+p1c*p1c-p1p3*p1p3)/(2*p3c*p1c))
end
