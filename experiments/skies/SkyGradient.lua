-- SkyGradient.lua
local SkyGradient = {}
SkyGradient.__index = SkyGradient

-- Utility function to convert hex to RGB
local function hex2rgb(hex)
    hex = hex:gsub("#","")
    return {
        tonumber(hex:sub(1,2), 16) / 255,
        tonumber(hex:sub(3,4), 16) / 255,
        tonumber(hex:sub(5,6), 16) / 255,
        1 -- Default alpha
    }
end

-- Function to apply inverse gamma correction (sRGB to linear RGB)
local function inverseGammaCorrect(c)
    if c <= 0.04045 then
        return c / 12.92
    else
        return ((c + 0.055) / 1.055) ^ 2.4
    end
end

-- Function to apply gamma correction (linear RGB to sRGB)
local function gammaCorrect(c)
    if c <= 0.0031308 then
        return c * 12.92
    else
        return 1.055 * (c ^ (1/2.4)) - 0.055
    end
end

-- Function to interpolate between two colors in linear RGB space
local function lerpColorLinearRgb(a, b, t)
    -- Apply inverse gamma correction to both colors
    local r1 = inverseGammaCorrect(a[1])
    local g1 = inverseGammaCorrect(a[2])
    local b1 = inverseGammaCorrect(a[3])

    local r2 = inverseGammaCorrect(b[1])
    local g2 = inverseGammaCorrect(b[2])
    local b2 = inverseGammaCorrect(b[3])

    -- Linear interpolation in linear RGB space
    local r = r1 + (r2 - r1) * t
    local g = g1 + (g2 - g1) * t
    local b_interp = b1 + (b2 - b1) * t

    -- Apply gamma correction back to sRGB space
    r = gammaCorrect(r)
    g = gammaCorrect(g)
    b_interp = gammaCorrect(b_interp)

    -- Interpolate Alpha linearly
    local a_interp = a[4] + (b[4] - a[4]) * t

    return {r, g, b_interp, a_interp}
end

-- Function to sort colorStops by position
local function sortColorStops(colorStops)
    table.sort(colorStops, function(a, b)
        return a.position < b.position
    end)
end

-- Function to get color at a specific y position based on color stops
local function getColorAt(y, colorStops)
    local numStops = #colorStops
    if numStops == 0 then
        return {0, 0, 0, 1} -- Default to black if no color stops
    elseif numStops == 1 then
        return colorStops[1].color
    end

    -- Handle y below the first color stop
    if y < colorStops[1].position then
        return colorStops[1].color
    end

    -- Handle y above the last color stop
    if y > colorStops[numStops].position then
        return colorStops[numStops].color
    end

    -- Iterate through color stops to find the correct segment
    for i = 1, numStops - 1 do
        local currentStop = colorStops[i]
        local nextStop = colorStops[i + 1]

        if y >= currentStop.position and y <= nextStop.position then
            local t = (y - currentStop.position) / (nextStop.position - currentStop.position)
            return lerpColorLinearRgb(currentStop.color, nextStop.color, t)
        end
    end

    -- If y is exactly at the last stop, return its color
    return colorStops[numStops].color
end

-- Function to create the gradient mesh
local function createGradientMesh(colorStops, screenHeight)
    local meshData = {}

    for i = 0, screenHeight - 1 do
        local ratio = i / (screenHeight - 1) -- 0 at bottom, 1 at top
        local color = getColorAt(ratio, colorStops)

        -- Add two vertices for each horizontal line (left and right)
        meshData[#meshData + 1] = { 0, ratio, 0, ratio, color[1], color[2], color[3], color[4] }
        meshData[#meshData + 1] = { 1, ratio, 1, ratio, color[1], color[2], color[3], color[4] }
    end

    return love.graphics.newMesh(meshData, "strip", "static")
end

-- Constructor
function SkyGradient:new(colorStops)
    local obj = setmetatable({}, self)
    obj.colorStops = colorStops or {}
    sortColorStops(obj.colorStops)
    obj.mesh = createGradientMesh(obj.colorStops, love.graphics.getHeight())
    return obj
end

-- Function to update the mesh based on camera frame
function SkyGradient:updateMesh(cameraY, cameraHeight, screenHeight, zoom)
    -- Calculate the gradient range visible on the screen
    local halfHeight = (cameraHeight / 2) / zoom
    local topY = cameraY + halfHeight
    local bottomY = cameraY - halfHeight

    -- Normalize y based on the gradient's span
    local function normalize(y)
        return y
    end

    -- Create mesh data based on normalized y
    local meshData = {}

    for i = 0, screenHeight - 1 do
        local ratio = i / (screenHeight - 1) -- 0 at bottom, 1 at top
        local gradientY = bottomY + (topY - bottomY) * ratio
        local normalizedY = normalize(gradientY)
        local color = getColorAt(normalizedY, self.colorStops)

        meshData[#meshData + 1] = { 0, ratio, 0, ratio, color[1], color[2], color[3], color[4] }
        meshData[#meshData + 1] = { 1, ratio, 1, ratio, color[1], color[2], color[3], color[4] }
    end

    -- Release previous mesh if it exists
    if self.mesh then
        self.mesh:release()
    end

    -- Create new mesh
    self.mesh = love.graphics.newMesh(meshData, "strip", "static")
end

-- Draw function
function SkyGradient:draw(x, y, width, height)
    if self.mesh then
        love.graphics.draw(self.mesh, x, y, 0, width, height)
    end
end

return SkyGradient
