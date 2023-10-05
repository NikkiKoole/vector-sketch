require 'lib.basics'
local formats = require 'lib.formats'
-- https://codepen.io/bork/pen/wJhEm
local gradients = {
    { from = { hex2rgb('#012459') }, to = { hex2rgb('#001322') } },
    { from = { hex2rgb('#003972') }, to = { hex2rgb('#001322') } },
    { from = { hex2rgb('#003972') }, to = { hex2rgb('#001322') } },
    { from = { hex2rgb('#004372') }, to = { hex2rgb('#00182b') } },
    { from = { hex2rgb('#004372') }, to = { hex2rgb('#011d34') } },
    { from = { hex2rgb('#016792') }, to = { hex2rgb('#00182b') } },
    { from = { hex2rgb('#07729f') }, to = { hex2rgb('#042c47') } },
    { from = { hex2rgb('#12a1c0') }, to = { hex2rgb('#07506e') } },
    { from = { hex2rgb('#74d4cc') }, to = { hex2rgb('#1386a6') } },
    -- { from = { hex2rgb('#efeebc') }, to = { hex2rgb('#61d0cf') } },
    { from = { hex2rgb('#61d0cf') }, to = { hex2rgb('#efeebc') } },
    { from = { hex2rgb('#fee154') }, to = { hex2rgb('#a3dec6') } },
    { from = { hex2rgb('#fdc352') }, to = { hex2rgb('#e8ed92') } },
    { from = { hex2rgb('#ffac6f') }, to = { hex2rgb('#ffe467') } },
    { from = { hex2rgb('#fda65a') }, to = { hex2rgb('#ffe467') } },
    { from = { hex2rgb('#fd9e58') }, to = { hex2rgb('#ffe467') } },
    { from = { hex2rgb('#f18448') }, to = { hex2rgb('#ffd364') } },
    { from = { hex2rgb('#f06b7e') }, to = { hex2rgb('#f9a856') } },
    { from = { hex2rgb('#ca5a92') }, to = { hex2rgb('#f4896b') } },
    { from = { hex2rgb('#5b2c83') }, to = { hex2rgb('#d1628b') } },
    { from = { hex2rgb('#371a79') }, to = { hex2rgb('#713684') } },
    { from = { hex2rgb('#28166b') }, to = { hex2rgb('#45217c') } },
    { from = { hex2rgb('#192861') }, to = { hex2rgb('#372074') } },
    { from = { hex2rgb('#040b3c') }, to = { hex2rgb('#233072') } },
    { from = { hex2rgb('#040b3c') }, to = { hex2rgb('#012459') } }

}



local function gradientMesh(dir, ...)
    local COLOR_MUL = love._version >= "11.0" and 1 or 255
    -- Check for direction
    local isHorizontal = true
    if dir == "vertical" then
        isHorizontal = false
    elseif dir ~= "horizontal" then
        error("bad argument #1 to 'gradient' (invalid value)", 2)
    end

    -- Check for colors
    local colorLen = select("#", ...)
    if colorLen < 2 then
        error("color list is less than two", 2)
    end

    -- Generate mesh
    local meshData = {}
    if isHorizontal then
        for i = 1, colorLen do
            local color = select(i, ...)
            local x = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = { x, 1, x, 1, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL) }
            meshData[#meshData + 1] = { x, 0, x, 0, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL) }
        end
    else
        for i = 1, colorLen do
            local color = select(i, ...)
            local y = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = { 1, y, 1, y, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL) }
            meshData[#meshData + 1] = { 0, y, 0, y, color[1], color[2], color[3], color[4] or (1 * COLOR_MUL) }
        end
    end

    -- Resulting Mesh has 1x1 image size
    return love.graphics.newMesh(meshData, "strip", "static")
end

local lib = {}
lib.makeSkyGradient = function(timeIndex)
    return gradientMesh(
            "vertical",
            gradients[timeIndex].from, gradients[timeIndex].to
        )
end
lib.makeBackdropMesh = function()
    local w, h = love.graphics.getDimensions()

    local vertices = {
        {
            -- top-left corner (red-tinted)
            0, 0, -- position of the vertex
            1, 0, 0, -- color of the vertex
        },
        {
            -- top-right corner (green-tinted)
            w, 0,
            0, 1, 0
        },
        {
            -- bottom-right corner (blue-tinted)
            w, h,
            0, 0, 1
        },
        {
            -- bottom-left corner (yellow-tinted)
            0, h,
            1, 1, 0
        },
    }

    return love.graphics.newMesh(formats.other_format_colors, vertices)
end
return lib
