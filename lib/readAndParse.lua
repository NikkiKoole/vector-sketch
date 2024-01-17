local lib   = {}

local parse = require 'lib.parse-file'
local node  = require 'lib.node'
local mesh  = require 'lib.mesh'


local function loadGroupFromFile(url, groupName)
    local imgs = {}
    local parts = {}
    local whole = parse.parseFile(url)
    local group = node.findNodeByName(whole, groupName) or {}

    for i = 1, #group.children do
        local p = group.children[i]

        lib.stripPath(p, '/experiments/puppet%-maker/')
        for j = 1, #p.children do
            if p.children[j].texture then
                imgs[i] = p.children[j].texture.url
                parts[i] = group.children[i]
            end
        end
    end
    return imgs, parts
end

local function zeroTransform(arr)
    for i = 1, #arr do
        if arr[i].transforms then
            arr[i].transforms.l[1] = 0
            arr[i].transforms.l[2] = 0
        end
    end
end

local function loadVectorSketch(path, groupName, getImagesToo)
    local img, bodyParts = loadGroupFromFile(path, groupName)
    zeroTransform(bodyParts)

    local result = {}
    for i = 1, #bodyParts do
        local me = {
            pivotX = bodyParts[i].transforms.l[6] - bodyParts[i].transforms.l[1],
            pivotY = bodyParts[i].transforms.l[7] - bodyParts[i].transforms.l[2]
        }
        for j = 1, #bodyParts[i].children do
            local child = bodyParts[i].children[j]
            if child.texture and child.texture.url then
                local img = mesh.getImage(child.texture.url)
                me.url = child.texture.url
                me.texturePoints = child.points
            end
            if child.type == 'meta' then
                --print(inspect(child.points))
                me.points = child.points
            end
        end
        table.insert(result, me)
    end

    return result, img
end

lib.stripPath = function(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url

        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
    end

    if root.children then
        for i = 1, #root.children do
            lib.stripPath(root.children[i], path)
        end
    end

    return root
end

lib.loadVectorSketchAndGetImages = function(path, groupName)
    local parts, img = loadVectorSketch(path, groupName, true)
    return img, parts
end



return lib
