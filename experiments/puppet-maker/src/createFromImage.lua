local mesh   = require 'lib.mesh'
local canvas = require 'lib.canvas'

local lib = {}

local function getDistance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt((dx * dx) + (dy * dy))

    return distance
end

local function getLengthOfPath(path)
    local result = 0
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i + 1]
        result = result + getDistance(a[1], a[2], b[1], b[2])
    end
    return result
end


lib.vanillaline = function(url, textured, hairWidthMultiplier, hairTension, optionalPoints
)
    local img = mesh.getImage(url)
    local width, height = img:getDimensions()

    local currentNode = {}
    currentNode.texture = {}
    currentNode.texture.url = url
    currentNode.texture.wrap = 'repeat'
    currentNode.texture.filter = 'linear'
    currentNode.type = 'vanillaline'
    currentNode.color = { 1, 1, 1 }

    currentNode.points = optionalPoints or { { 0, 0 }, { 0, 100 }, { 100, 100 } }
    local length = getLengthOfPath(currentNode.points)

    local factor = (length / height)
    currentNode.data = {}
    currentNode.data.width = (width * factor) * hairWidthMultiplier
    currentNode.data.tension = hairTension
    currentNode.data.spacing = 5

    if (textured) then
        currentNode.texture.retexture = love.graphics.newImage(textured)
    end

    return currentNode
end

lib.rubberhose = function(url, textured, flop, length, widthMultiplier, optionalPoints, optionalScaleX)
    local img = mesh.getImage(url)
    local width, height = img:getDimensions()
    local magic = 4.46
    local currentNode = {}

    currentNode.type = 'rubberhose'
    currentNode.data = currentNode.data or {}
    currentNode.texture = {}
    currentNode.texture.url = url
    currentNode.texture.wrap = 'repeat'
    currentNode.texture.filter = 'linear'
    currentNode.data.length = height * magic
    currentNode.data.width = width * 2 * widthMultiplier
    currentNode.data.flop = flop
    currentNode.data.borderRadius = .5
    currentNode.data.steps = 20
    currentNode.color = { 1, 1, 1 }
    currentNode.data.scaleX = optionalScaleX or 1
    currentNode.data.scaleY = length / height
    currentNode.points = optionalPoints or { { 0, 0 }, { 0, height / 2 } }

    if (textured) then
        currentNode.texture.retexture = love.graphics.newImage(textured)
    end

    return currentNode
end

lib.bezier = function(url, textured, widthMultiplier, optionalPoints)
    local img = mesh.getImage(url)
    local width, height = img:getDimensions()
    local currentNode = {}

    currentNode = {
        color = { 1, 1, 1, 1 },
        data = {
            length = height,
            steps = 15,
            width = (widthMultiplier and widthMultiplier or 1) * (width / 2)
        },
        name = "beziered",
        points = optionalPoints or { { height / 2, 0 }, { 0, 0 }, { -height / 2, 0 } },
        texture = {
            filter = "linear",
            url = url,
            wrap = "repeat"
        },
        type = "bezier"
    }

    if (textured) then
        currentNode.texture.retexture = love.graphics.newImage(textured)
    end

    local result = {}
    result.folder = true
    result.transforms = {
        l = { 0, 0, 0, 1, 1, 0, 0 }
    }
    result.children = { currentNode }
    --print('jo!')
    return result
end

return lib