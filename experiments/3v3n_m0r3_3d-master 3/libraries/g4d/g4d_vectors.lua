local Vectors = {}

function Vectors:add(a, b)
	return {a[1]+b[1], a[2]+b[2], a[3]+b[3]}
end

function Vectors:subtract(a, b)
	return {a[1]-b[1], a[2]-b[2], a[3]-b[3]}
end

function Vectors:scalar_multiply(v, scalar)
	return {v[1]*scalar, v[2]*scalar, v[3]*scalar}
end

function Vectors:scalar_divide(v, scalar)
	return {v[1]/scalar, v[2]/scalar, v[3]/scalar}
end

function Vectors:invert(v)
	return {-v[1], -v[2], -v[3]}
end

function Vectors:magnitude(v)
	return math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
end

function Vectors:normalize(v)
	local dist = math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
	return { v[1]/dist, v[2]/dist, v[3]/dist }
end

function Vectors:dot_product(a, b)
	return a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
end

function Vectors:cross_product(a, b)
	return { a[2]*b[3] - a[3]*b[2], a[3]*b[1] - a[1]*b[3], a[1]*b[2] - a[2]*b[1] }
end

function Vectors:fast_add(a1, a2 , a3, b1, b2, b3)
	return a1+b1, a2+b2, a3+b3
end

function Vectors:fast_subtract(a1, a2, a3, b1, b2, b3)
	return a1-b1, a2-b2, a3-b3
end

function Vectors:fast_scalar_multiply(scalar, v1, v2, v3)
	return v1*scalar, v2*scalar, v3*scalar
end

function Vectors:fast_magnitude(x, y, z)
	return math.sqrt(x^2 + y^2 + z^2)
end

function Vectors:fast_normalize(x, y, z)
	local mag = math.sqrt(x^2 + y^2 + z^2)
	return x/mag, y/mag, z/mag
end

function Vectors:fast_dot_product(a1, a2, a3, b1, b2, b3)
	return a1*b1 + a2*b2 + a3*b3
end

function Vectors:fast_cross_product(a1, a2, a3, b1, b2, b3)
	return a2*b3 - a3*b2, a3*b1 - a1*b3, a1*b2 - a2*b1
end

return Vectors
