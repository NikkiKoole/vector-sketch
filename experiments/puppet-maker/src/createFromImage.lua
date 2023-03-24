local mesh   = require 'lib.mesh'
local canvas = require 'lib.canvas'

local lib    = {}

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


local function makeTexture(url, textured)
    local t = {}
    t.url = url
    t.wrap = 'repeat'
    t.filter = 'linear'
    if (textured) then
        if (t.retexture) then
            t.retexture:release()
        end
        t.retexture = love.graphics.newImage(textured)
    end
    return t
end


lib.vanillaline = function(url, textured, hairWidthMultiplier, hairTension, optionalPoints
)
    local img = mesh.getImage(url)
    local width, height = img:getDimensions()

    local currentNode = {}
    currentNode.texture = makeTexture(url, textured)
    currentNode.type = 'vanillaline'
    currentNode.color = { 1, 1, 1 }

    currentNode.points = optionalPoints or { { 0, 0 }, { 0, 100 }, { 100, 100 } }
    local length = getLengthOfPath(currentNode.points)

    local factor = (length / height)
    currentNode.data = {}
    currentNode.data.width = (width * factor) * hairWidthMultiplier
    currentNode.data.tension = hairTension
    currentNode.data.spacing = 5

   
    return currentNode
end

lib.rubberhose = function(url, textured, flop, length, widthMultiplier, optionalPoints, optionalScaleX)
    local img = mesh.getImage(url)
    local width, height = img:getDimensions()
    local magic = 4.46
    local currentNode = {}

    currentNode.type = 'rubberhose'
    currentNode.texture = makeTexture(url, textured)

    currentNode.data = currentNode.data or {}
    currentNode.data.length = height * magic
    currentNode.data.width = width * 2 * widthMultiplier
    currentNode.data.flop = flop
    currentNode.data.borderRadius = .5
    currentNode.data.steps = 20
    currentNode.data.scaleX = optionalScaleX or 1
    currentNode.data.scaleY = length / height

    currentNode.color = { 1, 1, 1 }
    currentNode.points = optionalPoints or { { 0, 0 }, { 0, height / 2 } }
    
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
        texture = makeTexture(url, textured),
        type = "bezier"
    }

    local result = {}
    result.folder = true
    result.transforms = {
        l = { 0, 0, 0, 1, 1, 0, 0 }
    }
    result.children = { currentNode }

    return result
end


return lib
