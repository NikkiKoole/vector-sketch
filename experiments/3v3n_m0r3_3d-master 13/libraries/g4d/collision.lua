local Vec3       = require(G4D_PATH .. '/vec3')
local Collision = {}

local DBL_EPSILON = 2.2204460492503131e-16 -- the smallest possible value for a double, 'double epsilon'

function Collision:generate_aabb(vertices)
	local aabb = {
		 min = { math.huge   , math.huge   , math.huge   },
		 max = { math.huge*-1, math.huge*-1, math.huge*-1}
	}

	for _, vert in ipairs(vertices) do
		 aabb.min[1] = math.min(aabb.min[1], vert[1])
		 aabb.min[2] = math.min(aabb.min[2], vert[2])
		 aabb.min[3] = math.min(aabb.min[3], vert[3])
		 aabb.max[1] = math.max(aabb.max[1], vert[1])
		 aabb.max[2] = math.max(aabb.max[2], vert[2])
		 aabb.max[3] = math.max(aabb.max[3], vert[3])
	end

	return aabb
end

function Collision:collide_with_aabb(other)
	local a_min = self.aabb.min
	local a_max = self.aabb.max
	local b_min = other.aabb.min
	local b_max = other.aabb.max

	local x = a_min[1] * self.sx + self.x <= b_max[1] * other.sx + other.x and a_max[1] * self.sx + self.x >= b_min[1] * other.sx + other.x
	local y = a_min[2] * self.sy + self.y <= b_max[2] * other.sy + other.y and a_max[2] * self.sy + self.y >= b_min[2] * other.sy + other.y
	local z = a_min[3] * self.sz + self.z <= b_max[3] * other.sz + other.z and a_max[3] * self.sz + self.z >= b_min[3] * other.sz + other.z

	return x and y and z
end

function Collision:collide_with_point(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end

	local min = self.aabb.min
	local max = self.aabb.max

	local in_x = x >= min[1] * self.sx + self.x and x <= max[1] * self.sx + self.x
	local in_y = y >= min[2] * self.sy + self.y and y <= max[2] * self.sy + self.y
	local in_z = z >= min[3] * self.sz + self.z and z <= max[3] * self.sz + self.z

	return in_x and in_y and in_z
end

function Collision:get_distance_from(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end

	return math.sqrt((x - self.x)^2 + (y - self.y)^2 + (z - self.z)^2)
end

function Collision:collide_with_directional_ray(src, dir) -- vec3 position, vec3 direction
	local src_x, src_y, src_z = src[1], src[2], src[3]
	local dir_x, dir_y, dir_z = Vec3:fast_normalize(dir[1], dir[2], dir[3])

	local t1 = (self.aabb.min[1] * self.sx + self.x - src_x) / dir_x
	local t2 = (self.aabb.max[1] * self.sx + self.x - src_x) / dir_x
	local t3 = (self.aabb.min[2] * self.sy + self.y - src_y) / dir_y
	local t4 = (self.aabb.max[2] * self.sy + self.y - src_y) / dir_y
	local t5 = (self.aabb.min[3] * self.sz + self.z - src_z) / dir_z
	local t6 = (self.aabb.max[3] * self.sz + self.z - src_z) / dir_z

	local distance_from_ray_origin = math.max(math.max(math.min(t1, t2), math.min(t3, t4)), math.min(t5, t6))
	local tmax                     = math.min(math.min(math.max(t1, t2), math.max(t3, t4)), math.max(t5, t6))

	if tmax < 0                        then return false end -- ray is intersecting aabb, but whole aabb is behind us
	if distance_from_ray_origin > tmax then return false end -- ray does not intersect aabb

	local intersection_point = {
		src_x + dir_x * distance_from_ray_origin,
		src_y + dir_y * distance_from_ray_origin,
		src_z + dir_z * distance_from_ray_origin,
	}

	return intersection_point, distance_from_ray_origin
end

function Collision:collide_with_positional_ray(src, target) -- vec3 position, vec3 target
	return self:collide_with_directional_ray(src, {target[1] - src[1], target[2] - src[2], target[3] - src[3]})
end

function Collision:closest_point(src_x, src_y, src_z)
	return find_closest(self, self.verts, triangle_point, src_x, src_y, src_z)
end

function Collision:ray_intersection(src_x, src_y, src_z, dir_x, dir_y, dir_z)
    return find_closest(self, self.verts, triangle_ray, src_x, src_y, src_z, dir_x, dir_y, dir_z)
end

function Collision:sphere_intersection(src_x, src_y, src_z, radius)
    return find_closest(self, self.verts, triangle_sphere, src_x, src_y, src_z, radius)
end

function Collision:capsule_intersection(tip_x, tip_y, tip_z, base_x, base_y, base_z, radius)
    -- the normal vector coming out the tip of the capsule
    local norm_x, norm_y, norm_z = Vec3:fast_normalize(tip_x - base_x, tip_y - base_y, tip_z - base_z)

    -- the base and tip, inset by the radius
    -- these two coordinates are the actual extent of the capsule sphere line
    local a_x, a_y, a_z = base_x + norm_x*radius, base_y + norm_y*radius, base_z + norm_z*radius
    local b_x, b_y, b_z = tip_x  - norm_x*radius, tip_y  - norm_y*radius, tip_z  - norm_z*radius

    return find_closest(self, self.verts, triangle_capsule, tip_x, tip_y, tip_z, base_x, base_y, base_z, a_x, a_y, a_z, b_x, b_y, b_z, norm_x, norm_y, norm_z, radius)
end

function Collision:generate_collision_zone(zone_size)
    local aabb = self:generate_aabb(self.vertices)

    local min_1 = math.floor(aabb.min[1]/zone_size) * zone_size
    local min_2 = math.floor(aabb.min[2]/zone_size) * zone_size
    local min_3 = math.floor(aabb.min[3]/zone_size) * zone_size

    local max_1 = math.floor(aabb.max[1]/zone_size) * zone_size
    local max_2 = math.floor(aabb.max[2]/zone_size) * zone_size
    local max_3 = math.floor(aabb.max[3]/zone_size) * zone_size

    local translation_x = self.x
    local translation_y = self.y
    local translation_z = self.z
    local scale_x       = self.sx
    local scale_y       = self.sy
    local scale_z       = self.sz
    local verts         = self.verts

    local zones = {}
    for x=min_1, max_1, zone_size do
        for y=min_2, max_2, zone_size do
            for z=min_3, max_3, zone_size do
                local hash = x .. ', ' .. y .. ', ' .. z

                for v=1, #verts, 3 do
                    local n_x, n_y, n_z = Vec3:fast_normalize(
                        verts[v][6]*scale_x,
                        verts[v][7]*scale_x,
                        verts[v][8]*scale_x
                    )

                    local inside = triangle_aabb(
                        verts[v][1]   * scale_x + translation_x,
                        verts[v][2]   * scale_y + translation_y,
                        verts[v][3]   * scale_z + translation_z,
                        verts[v+1][1] * scale_x + translation_x,
                        verts[v+1][2] * scale_y + translation_y,
                        verts[v+1][3] * scale_z + translation_z,
                        verts[v+2][1] * scale_x + translation_x,
                        verts[v+2][2] * scale_y + translation_y,
                        verts[v+2][3] * scale_z + translation_z,
                        n_x, n_y, n_z,
                        x,y,z,
                        x+zone_size,y+zone_size,z+zone_size
                    )

                    if inside then
                        if not zones[hash] then
                            zones[hash] = {}
                        end

                        table.insert(zones[hash], verts[v])
                        table.insert(zones[hash], verts[v+1])
                        table.insert(zones[hash], verts[v+2])
                    end
                end
                
                if zones[hash] then
                    print(hash, #zones[hash])
                end
            end
        end
    end

    self.zones = zones
    return zones
end

-- http://stackoverflow.com/a/23976134/1190664
-- ray_position   - vec3
-- ray_direction  - vec3
-- plane_position - vec3
-- plane_normal   - vec3
function Collision:ray_plane(ray_position, ray_direction, plane_position, plane_normal)
	local denom = Vec3.dot_product(plane_normal, ray_direction)

	if math.abs(denom) < DBL_EPSILON then return false end -- ray does not intersect plane

	local direction                = Vec3.sub(plane_position, ray_position) 
	local distance_from_ray_origin = Vec3.dot_product(direction, plane_normal) / denom

	if distance_from_ray_origin < DBL_EPSILON then return false end

	local intersection_point = Vec3.add(ray_position, Vec3.mul_scalar(ray_direction, distance_from_ray_origin))

	return intersection_point, distance_from_ray_origin
end

-- http://www.lighthouse3d.com/tutorials/maths/ray-triangle-intersection/
-- ray_position  - vec3
-- ray_direction - vec3
-- triangles     - {vec3, vec3, vec3}
-- backface_cull - boolean (optional)
function Collision:ray_triangle(ray_position, ray_direction, triangles, backface_cull)
	local e1 = Vec3.sub(triangles[2], triangles[1])
	local e2 = Vec3.sub(triangles[3], triangles[1])
	local h  = Vec3.cross_product(ray_direction, e2)
	local a  = Vec3.dot_product(h, e1)

	if backface_cull and a < 0    then return false end -- if a is negative, ray hits the backface
	if math.abs(a) <= DBL_EPSILON then return false end -- if a is too close to 0, ray does not intersect triangles

	local f = 1 / a
	local s = ray_position:sub(triangles[1])
	local u = s:dot_product(h) * f

	if u < 0 or u > 1 then return false end

	local q = Vec3.cross_product(s, e1)
	local v = Vec3.dot_product(ray_direction, q) * f

	if v < 0 or u + v > 1 then return false end

	local distance_from_ray_origin = Vec3.dot_product(q, e2) * f

	if distance_from_ray_origin < DBL_EPSILON then return false end

	local intersection_point = Vec3.add(ray_position, Vec3.mul_scalar(ray_direction, distance_from_ray_origin))

	return intersection_point, distance_from_ray_origin
end

-- finds the closest point to the source point on the given line segment
-- a_x, a_y, a_z - point one of line segment
-- b_x, b_y, b_z - point two of line segment
-- x  , y  , z   - source point
local function closest_point_on_line_segment(a_x,a_y,a_z, b_x,b_y,b_z, x,y,z)
    local ab_x, ab_y, ab_z = b_x - a_x, b_y - a_y, b_z - a_z
    local t = Vec3:fast_dot_product(x - a_x, y - a_y, z - a_z, ab_x, ab_y, ab_z) / (ab_x^2 + ab_y^2 + ab_z^2)
    t = math.min(1, math.max(0, t))
    return a_x + t*ab_x, a_y + t*ab_y, a_z + t*ab_z
end

-- https://github.com/excessive/cpml/blob/master/modules/intersect.lua
-- http://www.lighthouse3d.com/tutorials/maths/ray-triangle-intersection/
-- model - ray intersection
-- based off of triangle - ray collision from excessive's CPML library
-- does a triangle - ray collision for every face in the model to find the shortest collision
local function triangle_ray(
        tri0_x, tri0_y, tri0_z,
        tri1_x, tri1_y, tri1_z,
        tri2_x, tri2_y, tri2_z,
        n_x, n_y, n_z,
        src_x, src_y, src_z,
        dir_x, dir_y, dir_z
    )

    -- cache these variables for efficiency
    local e11, e12, e13 = Vec3:fast_sub(tri1_x,tri1_y,tri1_z, tri0_x,tri0_y,tri0_z)
    local e21, e22, e23 = Vec3:fast_sub(tri2_x,tri2_y,tri2_z, tri0_x,tri0_y,tri0_z)
    local h1 , h2 , h3  = Vec3:fast_cross_product(dir_x,dir_y,dir_z, e21,e22,e23)
    local a             = Vec3:fast_dot_product(h1,h2,h3, e11,e12,e13)

    -- if a is too close to 0, ray does not intersect triangle
    if math.abs(a) <= DBL_EPSILON then return end

    local s1, s2, s3 = Vec3:fast_sub(src_x,src_y,src_z, tri0_x,tri0_y,tri0_z)
    local u          = Vec3:fast_dot_product(s1,s2,s3, h1,h2,h3) / a

    -- ray does not intersect triangle
    if u < 0 or u > 1 then return end

    local q1, q2, q3 = Vec3:fast_cross_product(s1,s2,s3, e11,e12,e13)
    local v          = Vec3:fast_dot_product(dir_x,dir_y,dir_z, q1,q2,q3) / a

    -- ray does not intersect triangle
    if v < 0 or u + v > 1 then return end

    -- at this stage we can compute t to find out where
    -- the intersection point is on the line
    local thisLength = Vec3:fast_dot_product(q1,q2,q3, e21,e22,e23) / a

    -- if hit this triangle and it's closer than any other hit triangle
    if thisLength >= DBL_EPSILON and (not finalLength or thisLength < finalLength) then
        --local norm_x, norm_y, norm_z = Vec3:fast_cross_product(e11,e12,e13, e21,e22,e23)

        return thisLength, src_x + dir_x*thisLength, src_y + dir_y*thisLength, src_z + dir_z*thisLength, n_x,n_y,n_z
    end
end

-- https://wickedengine.net/2020/04/26/capsule-collision-detection/
-- detects a collision between a triangle and a sphere
local function triangle_sphere(tri0_x, tri0_y, tri0_z, tri1_x, tri1_y, tri1_z, tri2_x, tri2_y, tri2_z, trin_x, trin_y, trin_z, src_x, src_y, src_z, radius)

    -- recalculate surface normal of this triangle
    local side1_x, side1_y, side1_z = tri1_x - tri0_x, tri1_y - tri0_y, tri1_z - tri0_z
    local side2_x, side2_y, side2_z = tri2_x - tri0_x, tri2_y - tri0_y, tri2_z - tri0_z
    local n_x, n_y, n_z = Vec3:fast_normalize(Vec3:fast_cross_product(side1_x, side1_y, side1_z, side2_x, side2_y, side2_z))

    -- distance from src to a vertex on the triangle
    local dist = Vec3:fast_dot_product(src_x - tri0_x, src_y - tri0_y, src_z - tri0_z, n_x, n_y, n_z)

    -- collision not possible, just return
    if dist < -radius or dist > radius then return end

    -- itx stands for intersection
    local itx_x, itx_y, itx_z = src_x - n_x * dist, src_y - n_y * dist, src_z - n_z * dist

    -- determine whether itx is inside the triangle
    -- project it onto the triangle and return if this is the case
    local c0_x, c0_y, c0_z = Vec3:fast_cross_product(itx_x - tri0_x, itx_y - tri0_y, itx_z - tri0_z, tri1_x - tri0_x, tri1_y - tri0_y, tri1_z - tri0_z)
    local c1_x, c1_y, c1_z = Vec3:fast_cross_product(itx_x - tri1_x, itx_y - tri1_y, itx_z - tri1_z, tri2_x - tri1_x, tri2_y - tri1_y, tri2_z - tri1_z)
    local c2_x, c2_y, c2_z = Vec3:fast_cross_product(itx_x - tri2_x, itx_y - tri2_y, itx_z - tri2_z, tri0_x - tri2_x, tri0_y - tri2_y, tri0_z - tri2_z)
    if  Vec3:fast_dot_product(c0_x, c0_y, c0_z, n_x, n_y, n_z) <= 0
    and Vec3:fast_dot_product(c1_x, c1_y, c1_z, n_x, n_y, n_z) <= 0
    and Vec3:fast_dot_product(c2_x, c2_y, c2_z, n_x, n_y, n_z) <= 0 then
        n_x, n_y, n_z = src_x - itx_x, src_y - itx_y, src_z - itx_z
        
        -- the sphere is inside the triangle, so the normal is zero
        -- instead, just return the triangle's normal
        if n_x == 0 and n_y == 0 and n_z == 0 then
            return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, trin_x, trin_y, trin_z
        end

        return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, n_x, n_y, n_z
    end

    -- itx is outside triangle
    -- find points on all three line segments that are closest to itx
    -- if distance between itx and one of these three closest points is in range, there is an intersection
    local radiussq = radius * radius
    local smallestDist

    local line1_x, line1_y, line1_z = closest_point_on_line_segment(tri0_x, tri0_y, tri0_z, tri1_x, tri1_y, tri1_z, src_x, src_y, src_z)
    local dist = (src_x - line1_x)^2 + (src_y - line1_y)^2 + (src_z - line1_z)^2
    if dist <= radiussq then
        smallestDist = dist
        itx_x, itx_y, itx_z = line1_x, line1_y, line1_z
    end

    local line2_x, line2_y, line2_z = closest_point_on_line_segment(tri1_x, tri1_y, tri1_z, tri2_x, tri2_y, tri2_z, src_x, src_y, src_z)
    local dist = (src_x - line2_x)^2 + (src_y - line2_y)^2 + (src_z - line2_z)^2
    if (smallestDist and dist < smallestDist or not smallestDist) and dist <= radiussq then
        smallestDist = dist
        itx_x, itx_y, itx_z = line2_x, line2_y, line2_z
    end

    local line3_x, line3_y, line3_z = closest_point_on_line_segment(tri2_x, tri2_y, tri2_z, tri0_x, tri0_y, tri0_z, src_x, src_y, src_z)
    local dist = (src_x - line3_x)^2 + (src_y - line3_y)^2 + (src_z - line3_z)^2
    if (smallestDist and dist < smallestDist or not smallestDist) and dist <= radiussq then
        smallestDist = dist
        itx_x, itx_y, itx_z = line3_x, line3_y, line3_z
    end

    if smallestDist then
        n_x, n_y, n_z = src_x - itx_x, src_y - itx_y, src_z - itx_z

        -- the sphere is inside the triangle, so the normal is zero
        -- instead, just return the triangle's normal
        if n_x == 0 and n_y == 0 and n_z == 0 then
            return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, trin_x, trin_y, trin_z
        end

        return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, n_x, n_y, n_z
    end
end

-- https://wickedengine.net/2020/04/26/capsule-collision-detection/
-- finds the closest point on the triangle from the source point given
local function triangle_point(tri0_x, tri0_y, tri0_z, tri1_x, tri1_y, tri1_z, tri2_x, tri2_y, tri2_z, trin_x, trin_y, trin_z, src_x, src_y, src_z)

    -- recalculate surface normal of this triangle
    local side1_x, side1_y, side1_z = tri1_x - tri0_x, tri1_y - tri0_y, tri1_z - tri0_z
    local side2_x, side2_y, side2_z = tri2_x - tri0_x, tri2_y - tri0_y, tri2_z - tri0_z
    local n_x    , n_y    , n_z     = Vec3:fast_normalize(Vec3:fast_cross_product(side1_x, side1_y, side1_z, side2_x, side2_y, side2_z))

    -- distance from src to a vertex on the triangle
    local dist = Vec3:fast_dot_product(src_x - tri0_x, src_y - tri0_y, src_z - tri0_z, n_x, n_y, n_z)

    -- itx stands for intersection
    local itx_x, itx_y, itx_z = src_x - n_x * dist, src_y - n_y * dist, src_z - n_z * dist

    -- determine whether itx is inside the triangle
    -- project it onto the triangle and return if this is the case
    local c0_x, c0_y, c0_z = Vec3:fast_cross_product(itx_x - tri0_x, itx_y - tri0_y, itx_z - tri0_z, tri1_x - tri0_x, tri1_y - tri0_y, tri1_z - tri0_z)
    local c1_x, c1_y, c1_z = Vec3:fast_cross_product(itx_x - tri1_x, itx_y - tri1_y, itx_z - tri1_z, tri2_x - tri1_x, tri2_y - tri1_y, tri2_z - tri1_z)
    local c2_x, c2_y, c2_z = Vec3:fast_cross_product(itx_x - tri2_x, itx_y - tri2_y, itx_z - tri2_z, tri0_x - tri2_x, tri0_y - tri2_y, tri0_z - tri2_z)
    if  Vec3:fast_dot_product(c0_x, c0_y, c0_z, n_x, n_y, n_z) <= 0
    and Vec3:fast_dot_product(c1_x, c1_y, c1_z, n_x, n_y, n_z) <= 0
    and Vec3:fast_dot_product(c2_x, c2_y, c2_z, n_x, n_y, n_z) <= 0 then
        n_x, n_y, n_z = src_x - itx_x, src_y - itx_y, src_z - itx_z

        -- the sphere is inside the triangle, so the normal is zero
        -- instead, just return the triangle's normal
        if n_x == 0 and n_y == 0 and n_z == 0 then
            return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, trin_x, trin_y, trin_z
        end

        return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, n_x, n_y, n_z
    end

    -- itx is outside triangle
    -- find points on all three line segments that are closest to itx
    -- if distance between itx and one of these three closest points is in range, there is an intersection
    local line1_x, line1_y, line1_z = closest_point_on_line_segment(tri0_x, tri0_y, tri0_z, tri1_x, tri1_y, tri1_z, src_x, src_y, src_z)
    local dist = (src_x - line1_x)^2 + (src_y - line1_y)^2 + (src_z - line1_z)^2
    local smallestDist = dist
    itx_x, itx_y, itx_z = line1_x, line1_y, line1_z

    local line2_x, line2_y, line2_z = closest_point_on_line_segment(tri1_x, tri1_y, tri1_z, tri2_x, tri2_y, tri2_z, src_x, src_y, src_z)
    local dist = (src_x - line2_x)^2 + (src_y - line2_y)^2 + (src_z - line2_z)^2
    if smallestDist and dist < smallestDist then
        smallestDist = dist
        itx_x, itx_y, itx_z = line2_x, line2_y, line2_z
    end

    local line3_x, line3_y, line3_z = closest_point_on_line_segment(tri2_x, tri2_y, tri2_z, tri0_x, tri0_y, tri0_z, src_x, src_y, src_z)
    local dist = (src_x - line3_x)^2 + (src_y - line3_y)^2 + (src_z - line3_z)^2
    if smallestDist and dist < smallestDist then
        smallestDist = dist
        itx_x, itx_y, itx_z = line3_x, line3_y, line3_z
    end

    if smallestDist then
        n_x, n_y, n_z = src_x - itx_x, src_y - itx_y, src_z - itx_z

        -- the sphere is inside the triangle, so the normal is zero
        -- instead, just return the triangle's normal
        if n_x == 0 and n_y == 0 and n_z == 0 then
            return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, trin_x, trin_y, trin_z
        end

        return Vec3:fast_magnitude(n_x, n_y, n_z), itx_x, itx_y, itx_z, n_x, n_y, n_z
    end
end

-- https://wickedengine.net/2020/04/26/capsule-collision-detection/
-- finds the collision point between a triangle and a capsule
-- capsules are defined with two points and a radius
local function triangle_capsule(
        tri0_x, tri0_y, tri0_z,
        tri1_x, tri1_y, tri1_z,
        tri2_x, tri2_y, tri2_z,
        n_x, n_y, n_z,
        tip_x, tip_y, tip_z,
        base_x, base_y, base_z,
        a_x, a_y, a_z,
        b_x, b_y, b_z,
        capn_x, capn_y, capn_z,
        radius
    )

    -- find the normal of this triangle
    -- tbd if necessary, this sometimes fixes weird edgecases
    local side1_x, side1_y, side1_z = tri1_x - tri0_x, tri1_y - tri0_y, tri1_z - tri0_z
    local side2_x, side2_y, side2_z = tri2_x - tri0_x, tri2_y - tri0_y, tri2_z - tri0_z
    local n_x, n_y, n_z = Vec3:fast_normalize(Vec3:fast_cross_product(side1_x, side1_y, side1_z, side2_x, side2_y, side2_z))

    local dotOfNormals = math.abs(Vec3:fast_dot_product(n_x, n_y, n_z, capn_x, capn_y, capn_z))

    -- default reference point to an arbitrary point on the triangle
    -- for when dotOfNormals is 0, because then the capsule is parallel to the triangle
    local ref_x, ref_y, ref_z = tri0_x, tri0_y, tri0_z

    if dotOfNormals > 0 then
        -- capsule is not parallel to the triangle's plane
        -- find where the capsule's normal vector intersects the triangle's plane
        local t = Vec3:fast_dot_product(n_x, n_y, n_z, (tri0_x - base_x) / dotOfNormals, (tri0_y - base_y) / dotOfNormals, (tri0_z - base_z) / dotOfNormals)
        local plane_itx_x, plane_itx_y, plane_itx_z = base_x + capn_x*t, base_y + capn_y*t, base_z + capn_z*t
        local _

        -- then clamp that plane intersect point onto the triangle itself
        -- this is the new reference point
        _, ref_x, ref_y, ref_z = triangle_point(
            tri0_x, tri0_y, tri0_z,
            tri1_x, tri1_y, tri1_z,
            tri2_x, tri2_y, tri2_z,
            n_x, n_y, n_z,
            plane_itx_x, plane_itx_y, plane_itx_z
        )
    end

    -- find the closest point on the capsule line to the reference point
    local c_x, c_y, c_z = closest_point_on_line_segment(a_x, a_y, a_z, b_x, b_y, b_z, ref_x, ref_y, ref_z)

    -- do a sphere cast from that closest point to the triangle and return the result
    return triangle_sphere(
        tri0_x, tri0_y, tri0_z,
        tri1_x, tri1_y, tri1_z,
        tri2_x, tri2_y, tri2_z,
        n_x, n_y, n_z,
        c_x, c_y, c_z, radius
    )
end

-- finds whether or not a triangle is inside an aabb
local function triangle_aabb(
        tri0_x, tri0_y, tri0_z,
        tri1_x, tri1_y, tri1_z,
        tri2_x, tri2_y, tri2_z,
        n_x, n_y, n_z,
        min_x, min_y, min_z,
        max_x, max_y, max_z
    )

    -- get the closest point from the centerpoint on the triangle
    local len,x,y,z,nx,ny,nz = triangle_point(
        tri0_x, tri0_y, tri0_z,
        tri1_x, tri1_y, tri1_z,
        tri2_x, tri2_y, tri2_z,
        n_x, n_y, n_z,
        (min_x+max_x)*0.5, (min_y+max_y)*0.5, (min_z+max_z)*0.5
    )

    -- if the point is not inside the aabb, return nothing
    if not (x >= min_x and x <= max_x) then return end
    if not (y >= min_y and y <= max_y) then return end
    if not (z >= min_z and z <= max_z) then return end

    -- the point is inside the aabb, return the collision data
    return len, x,y,z, nx,ny,nz
end

-- runs a given intersection function on all of the triangles made up of a given vert table
local function find_closest(self, verts, func, ...)
    -- declare the variables that will be returned by the function
    local finalLength, where_x, where_y, where_z, norm_x, norm_y, norm_z

    -- cache references to this model's properties for efficiency
    local translation_x = self.x
    local translation_y = self.y
    local translation_z = self.z
    local scale_x       = self.sx
    local scale_y       = self.sy
    local scale_z       = self.sz

    for v=1, #verts, 3 do
        -- apply the function given with the arguments given
        -- also supply the points of the current triangle
        local n_x, n_y, n_z = Vec3:fast_normalize(
            verts[v][6]*scale_x,
            verts[v][7]*scale_x,
            verts[v][8]*scale_x
        )

        local length, wx, wy, wz, nx, ny, nz = func(
            verts[v][1]   * scale_x + translation_x,
            verts[v][2]   * scale_y + translation_y,
            verts[v][3]   * scale_z + translation_z,
            verts[v+1][1] * scale_x + translation_x,
            verts[v+1][2] * scale_y + translation_y,
            verts[v+1][3] * scale_z + translation_z,
            verts[v+2][1] * scale_x + translation_x,
            verts[v+2][2] * scale_y + translation_y,
            verts[v+2][3] * scale_z + translation_z,
            n_x, 
				n_y,
            n_z,
            ...
        )

        -- if something was hit
        -- and either the finalLength is not yet defined or the new length is closer
        -- then update the collision information
        if length and (not finalLength or length < finalLength) then
            finalLength = length
            where_x     = wx
            where_y     = wy
            where_z     = wz
            norm_x      = nx
            norm_y      = ny
            norm_z      = nz
        end
    end

    if finalLength then
        norm_x, norm_y, norm_z = Vec3:fast_normalize(norm_x, norm_y, norm_z)
    end

    -- return all the information in a standardized way
    return finalLength, where_x, where_y, where_z, norm_x, norm_y, norm_z
end

return Collision
