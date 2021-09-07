local function groundToScreen(x, y)
	-- Apply any translation/rotation etc. first.
	-- Then do the perspective transform
	local z = 1 - cosAngle * y/h
	x, y = w/2 + (x - w/2) / z,  y * sinAngle / z
	return x, y
end

local function screenToGround(x, y)
	-- Undo the perspective transform first.
	local z = sinAngle / (sinAngle + y/h * cosAngle)
	x, y = w/2 + (x - w/2) * z,  y / sinAngle * z
	-- Then undo any rotation/translation etc.
	return x, y
end

function love.load()
	angle = 0.2 * math.pi
	cosAngle, sinAngle = math.sin(angle), math.cos(angle)
	w, h = love.graphics.getDimensions()
	groundShader = love.graphics.newShader([[
		uniform vec2 size;
		uniform float cosAngle, sinAngle;

		vec4 position(mat4 m, vec4 p) {
			p.z = 1.0 - p.y / size.y * cosAngle;
			p.y *= sinAngle / p.z;
			p.x = 0.5 * size.x + (p.x - 0.5 * size.x) / p.z;
			return m * p;
		}
	]])
end

local function standingRect(left, bottom, width, height)
	local pixelLeft, pixelBottom = groundToScreen(left, bottom)
	local pixelRight = groundToScreen(left + width, bottom)
	local pixelWidth = pixelRight - pixelLeft
	local pixelHeight = height * pixelWidth / width
	return pixelLeft, pixelBottom - pixelHeight, pixelWidth, pixelHeight
end

local function pointInRect(x, y, left, top, width, height)
	local inHorizontal = x >= left and x < left + width
	local inVertical = y >= top and y < top + height
	return inHorizontal and inVertical
end

local function mouseInGroundRect(x, y, w, h)
	local mx, my = screenToGround(love.mouse.getPosition())
	return pointInRect(mx, my, x, y, w, h)
end

function love.draw()
	w, h = love.graphics.getDimensions()
	cosAngle, sinAngle = math.cos(angle), math.sin(angle)
	love.graphics.setShader(groundShader)
	groundShader:send("size", {w, h})
	groundShader:send("cosAngle", cosAngle)
	groundShader:send("sinAngle", sinAngle)
	for y = 0, 11 do
		for x = 0, 15 do
			if (x + y) % 2 == 0 then
				if mouseInGroundRect(x * 50, y * 50, 50, 50) then
					love.graphics.setColor(0.4, 0.4, 0.3)
				else
					love.graphics.setColor(0.3, 0.3, 0.25)
				end
				love.graphics.rectangle('fill', x * 50, y * 50, 50, 50)
			end
		end
	end

	love.graphics.setShader()
	love.graphics.setColor(0.3, 0.2, 0.5)
	love.graphics.rectangle('fill', standingRect(250, 350, 50, 100))
end
