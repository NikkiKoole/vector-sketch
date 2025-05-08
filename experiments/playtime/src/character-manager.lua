local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'

-- todo, the data here below is correctly set to the texturefixture, i will kinda need those dimenions too, to figure out
-- how to scale that fixture, we need the actual textures to be a tad bit bigger then the polygon, how much is the question.

local shape8Dict = {
    ['shapeA1.png'] = {
        v = {
            1.61, -272.46, 112.13, -133.04, 154.81, 76.67, 123.57, 229.44, 1.21, 273.51, -134.54, 225.43, -145.28, 73.64, -91.99, -132.77
        }
    },
    ['shapeA2.png'] = {
        v = {
            11.62, -224.06, 60.89, -144.08, 59.89, -20.57, 133.96, 135.02, 4.30, 224.06, -133.96, 131.49, -51.71, -20.97, -39.30, -147.16,

        }
    },
    ['shapeA3.png'] = {
        v = {
            -6.62, -189.25, 135.88, -69.67, 160.54, 45.82, 123.85, 154.90, -6.37, 189.25, -92.40, 153.92, -164.61, 53.37, -155.10, -67.94
        }
    }
}
local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = false,
            neckSegments = 4,
            torsoSegments = 4
        },
        parts = {
            ['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 }, shape8URL = 'shapeA3.png', shape = 'shape8', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = { dims = { w = 80, w2 = 4, h = 150 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = { dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 }, shape = 'shape8', shape8URL = 'shapeA2.png', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['luleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['ruleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi } } },
            ['ruarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi, up = 0 } } },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['lfoot'] = { dims = { w = 80, h = 150 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['rfoot'] = { dims = { w = 80, h = 150 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = { dims = { w = 40, h = 40 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['rhand'] = { dims = { w = 40, h = 40 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = -math.pi / 2 },
            ['rear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = math.pi / 2 }
        },
    }
}
local function makeTransformedVertices(vertices, scaleX, scaleY)
    -- Initialize result array
    local transformedVertices = {}
    -- Loop through input vertices (stepping by 2)
    for i = 1, #vertices, 2 do
        -- Get original x, y
        local x = vertices[i]
        local y = vertices[i + 1]
        -- Calculate transformed x, y (scaling handles flipping)
        local newX = x * scaleX
        local newY = y * scaleY
        -- Add transformed pair to result array
        table.insert(transformedVertices, newX)
        table.insert(transformedVertices, newY)
    end
    -- Return the new array
    return transformedVertices
end

local function getTransformedIndex(index, flipX, flipY)
    if flipY == -1 and flipX == 1 then
        local values = { 5, 4, 3, 2, 1, 8, 7, 6 }
        return values[index]
    end
    if flipX == -1 and flipY == 1 then
        local values = { 1, 8, 7, 6, 5, 4, 3, 2 }
        return values[index]
    end
    if flipX == -1 and flipY == -1 then
        local values = { 5, 6, 7, 8, 1, 2, 3, 4 }
        return values[index]
    end
    if flipX == 1 and flipY == 1 then
        local values = { 1, 2, 3, 4, 5, 6, 7, 8 }
        return values[index]
    end
    -- print(index, flipX, flipY)
    -- logger:warn('why are we getting here?')
end

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end

local function lerp(a, b, amount)
    return a + (b - a) * clamp(amount, 0, 1)
end

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end

local function getParentAndChildrenFromPartName(partName, guy)
    local creation      = guy.dna.creation
    local neckSegments  = creation.neckSegments or 0
    local torsoSegments = creation.torsoSegments or 1

    local highestTorso  = 'torso' .. torsoSegments
    local lowestTorso   = 'torso1'

    local map           = {

        head = { p = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso, c = { 'lear', 'rear' } },
        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = highestTorso, c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = highestTorso, c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = lowestTorso, c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = lowestTorso, c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' },

    }

    local neckIndex     = extractNeckIndex(partName)
    if neckIndex then
        if neckIndex == 1 then
            map[partName] = { p = highestTorso, c = (neckIndex == neckSegments) and 'head' or 'neck2' }
        else
            map[partName] = {
                p = 'neck' .. (neckIndex - 1),
                c = (neckIndex == neckSegments) and 'head' or
                    'neck' .. neckIndex + 1
            }
        end
    end
    --print(partName)
    local torsoIndex = extractTorsoIndex(partName)
    --logger:info('torsoIndex', torsoIndex)
    if torsoIndex then
        -- logger:info('torsoIndex', torsoIndex)
        if torsoIndex then
            local children = {}
            -- Middle segments connect only to the next torso segment
            if torsoIndex < torsoSegments then
                table.insert(children, 'torso' .. (torsoIndex + 1))
            end

            -- Highest segment connects to arms and neck/head
            if torsoIndex == torsoSegments then
                table.insert(children, (neckSegments > 0) and 'neck1' or 'head')
                table.insert(children, 'luarm')
                table.insert(children, 'ruarm')
                if creation.isPotatoHead then -- Potato ears attach to highest torso
                    table.insert(children, 'lear')
                    table.insert(children, 'rear')
                end
            end

            -- Lowest segment connects to legs
            if torsoIndex == 1 then
                table.insert(children, 'luleg')
                table.insert(children, 'ruleg')
            end



            if torsoIndex == 1 then
                map[partName] = { c = children } -- Torso1 has no parent
            else
                map[partName] = { p = 'torso' .. (torsoIndex - 1), c = children }
            end
        end
    end

    -- Overrides for special cases

    -- Head connects directly to highest torso if no neck
    if partName == 'head' and neckSegments == 0 then
        map[partName] = { p = highestTorso, c = { 'lear', 'rear' } }
    end

    -- If Potato Head, ears parent is highest torso (head doesn't exist as parent)
    if creation.isPotatoHead then
        map['lear'] = { p = highestTorso }
        map['rear'] = { p = highestTorso }
        -- Remove head connection if it exists from map
        map['head'] = nil -- No head part in potato mode
    end

    -- If only one torso segment, it has all children directly
    if torsoSegments == 1 and partName == 'torso1' then
        local children = {}
        if creation.isPotatoHead then
            children = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear' }
        else
            children = { (neckSegments > 0) and 'neck1' or 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' }
        end

        map[partName] = { c = children }
    end


    local result = map[partName]



    return result or {} -- Return empty table if partName not found
end

local function sign(value)
    if value < 0 or value == nil then return -1 else return 1 end
end

local function getOwnOffset(partName, guy)
    local parts = guy.dna.parts


    -- upward
    if extractNeckIndex(partName) then
        return 0, -parts[partName].dims.h / 2
    end
    if extractTorsoIndex(partName) then
        if parts[partName].shape == 'shape8' then
            -- local vertices = shape8Dict[parts[partName].shape8URL].v

            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)

            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))

            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end
    if partName == 'head' then
        -- return 0, -parts.head.dims.h / 2
        if parts[partName].shape == 'shape8' then
            --local vertices = shape8Dict[parts[partName].shape8URL].v


            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)

            --local topIndex = 1
            --local bottomIndex = 5
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))


            --return vertices[(index * 2) - 1], vertices[(index * 2)]
            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end
    if partName == 'lear' then
        return 0, -parts.lear.dims.h / 2
    end
    if partName == 'rear' then
        return 0, -parts.rear.dims.h / 2
    end


    -- downward
    if partName == 'luleg' then
        return 0, parts.luleg.dims.h / 2
    end
    if partName == 'ruleg' then
        return 0, parts.ruleg.dims.h / 2
    end
    if partName == 'llleg' then
        return 0, parts.llleg.dims.h / 2
    end
    if partName == 'lfoot' then
        return 0, parts.lfoot.dims.h / 2
    end
    if partName == 'rlleg' then
        return 0, parts.rlleg.dims.h / 2
    end
    if partName == 'rfoot' then
        return 0, parts.rfoot.dims.h / 2
    end
    if partName == 'luarm' then
        return 0, parts.luarm.dims.h / 2
    end
    if partName == 'ruarm' then
        return 0, parts.ruarm.dims.h / 2
    end
    if partName == 'rhand' then
        return 0, parts.rhand.dims.h / 2
    end
    if partName == 'llarm' then
        return 0, parts.llarm.dims.h / 2
    end
    if partName == 'rlarm' then
        return 0, parts.rlarm.dims.h / 2
    end
    if partName == 'lhand' then
        return 0, parts.lhand.dims.h / 2
    end
    return 0, 0
end

local function getOffsetFromParent(partName, guy)
    local parts         = guy.dna.parts
    local creation      = guy.dna.creation
    local positioners   = guy.dna.positioners
    local data          = getParentAndChildrenFromPartName(partName, guy)
    -- Define the name of the highest torso segment
    local torsoSegments = creation.torsoSegments or 1
    local highestTorso  = 'torso' .. torsoSegments
    -- Define the name of the lowest torso segment (always torso1)
    local lowestTorso   = 'torso1'



    local function getTorsoPart8(index)
        --local vertices = shape8Dict[parts[highestTorso].shape8URL].v

        local raw = shape8Dict[parts[highestTorso].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts[highestTorso].dims.sx or 1, parts[highestTorso].dims.sy or 1)

        local newIndex = getTransformedIndex(index, sign(parts[highestTorso].dims.sx), sign(parts[highestTorso].dims.sy))

        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    local function hasTorso8()
        if parts[highestTorso].shape == 'shape8' then
            return true
        end
        return false
    end

    local function hasHead8()
        if parts['head'].shape == 'shape8' then
            return true
        end
        return false
    end

    local function getHeadPart8(index)
        local raw = shape8Dict[parts['head'].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts['head'].dims.sx or 1, parts['head'].dims.sy or 1)

        local newIndex = getTransformedIndex(index, sign(parts['head'].dims.sx), sign(parts['head'].dims.sy))

        -- local vertices = shape8Dict[parts['head'].shape8URL].v
        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    if extractNeckIndex(partName) then
        local index = extractNeckIndex(partName)
        if index == 1 then
            if hasTorso8() then
                return getTorsoPart8(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            return 0, -parts['neck' .. (index - 1)].dims.h / 2
        end
    elseif extractTorsoIndex(partName) then
        local index = extractTorsoIndex(partName)
        if index == 1 then
            return 0, 0
        else
            if hasTorso8() then
                --print('getting here')

                return getTorsoPart8(1)
            else
                -- return 0, -parts[highestTorso].dims.h / 2
                return 0, -parts['torso' .. (index - 1)].dims.h / 2
            end


            --return 0, -parts['torso' .. (index - 1)].dims.h / 2
        end
    elseif partName == 'llarm' then
        return 0, parts.luarm.dims.h / 2
    elseif partName == 'rlarm' then
        return 0, parts.ruarm.dims.h / 2
    elseif partName == 'llleg' then
        return 0, parts.luleg.dims.h / 2
    elseif partName == 'lfoot' then
        return 0, parts.llleg.dims.h / 2
    elseif partName == 'rlleg' then
        return 0, parts.ruleg.dims.h / 2
    elseif partName == 'rfoot' then
        return 0, parts.rlleg.dims.h / 2
    elseif partName == 'rhand' then
        return 0, parts.rlarm.dims.h / 2
    elseif partName == 'lhand' then
        return 0, parts.llarm.dims.h / 2
    elseif partName == 'luarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8(7)
            else
                return getTorsoPart8(8)
            end
        else
            return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'ruarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8(3)
            else
                return getTorsoPart8(2)
            end
        else
            return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'luleg' then
        local t = 0.5 --positioners.leg.x
        if hasTorso8() then
            local ax, ay = getTorsoPart8(6)
            local bx, by = getTorsoPart8(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (-parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'ruleg' then
        local t = 0.5 -- positioners.leg.x

        if hasTorso8() then
            local ax, ay = getTorsoPart8(4)
            local bx, by = getTorsoPart8(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'lear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8(8)
                local bx, by = getTorsoPart8(7)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(7)
                local bx, by = getHeadPart8(8)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif partName == 'rear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8(2)
                local bx, by = getTorsoPart8(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(2)
                local bx, by = getHeadPart8(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif (partName == 'head') then
        if creation.neckSegments == 0 then
            if hasTorso8() then
                return getTorsoPart8(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            local last = 'neck' .. creation.neckSegments
            return 0, -parts[last].dims.h / 2
        end
    else
        return 0, 0
    end
end

local function getAngleOffset(partName, guy)
    local parts = guy.dna.parts
    if partName == 'lfoot' then
        return math.pi / 2
    elseif partName == 'rfoot' then
        return -math.pi / 2
    elseif partName == 'lear' then
        return parts.lear.stanceAngle
    elseif partName == 'rear' then
        return parts.rear.stanceAngle
    else
        return 0
    end
end


local function makePart(partName, instance, settings)
    local values = getParentAndChildrenFromPartName(partName, instance)
    local parent = values.p
    -- logger:info(partName, parent)

    local prevA = 0


    if parent then
        if instance.parts[parent] then
            local parentPosX, parentPosY = instance.parts[parent].body:getPosition()

            prevA = instance.parts[parent].body:getAngle()

            local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)
            settings.x = px
            settings.y = py
        end
    end


    --local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
    local ownOffsetX, ownOffsetY = getOwnOffset(partName, instance)
    local xangle = getAngleOffset(partName, instance)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    -- logger:info(partName, prevA, xangle)


    local thing = ObjectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)
        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end
        --  logger:info('setting', partName)
        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]   --instance.parts[jointData.a]
        local partB_thing = instance.parts[partName] --instance.parts[jointData.b]
        -- logger:info(partA_thing, partB_thing)

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
            }
            local offX, offY = getOffsetFromParent(partName, instance)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = Joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
        end
    end
end


lib.updatePart = function(partName, data, instance)
    local poseCache = {}

    local positionTorso = nil
    if partName == 'torso1' then
        positionTorso = { instance.parts[partName].body:getPosition() }
        logger:inspect(positionTorso)
    end

    -- filling the cache
    for partName, part in pairs(instance.parts) do
        local body = part.body
        local groupIndex = body:getFixtures()[1]:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end

    -- update the thing
    lib.updateSinglePart(partName, data, instance)

    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            -- body:setPosition(pose.pos[1], pose.pos[2])
            body:setAngle(pose.angle)
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local fixtures = body:getFixtures()
            for j = 1, #fixtures do
                fixtures[j]:setGroupIndex(pose.groupIndex)
            end
        end
    end

    if positionTorso then
        local newPosX, newPosY = instance.parts[partName].body:getPosition()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end


        --instance.parts[partName].body:setPosition(positionTorso[1], positionTorso[2])
    end
end



lib.updateSinglePart = function(partName, data, instance)
    --print(partName)
    --logger:inspect(instance.dna.parts[partName])
    --logger:inspect(instance.parts[partName])

    local partData = instance.dna.parts[partName]
    if not partData then return end

    -- Apply dimension updates
    for k, v in pairs(data) do
        --print(k, v)
        partData.dims[k] = v
    end

    print(partName)
    local oldBody = instance.parts[partName].body
    local oldPosX, oldPosY = oldBody:getPosition()


    -- Remove old body

    if instance.parts[partName] then
        ObjectManager.destroyBody(instance.parts[partName].body)
        instance.parts[partName] = nil
    end

    -- Recreate the part
    local settings = {
        x = oldPosX,
        y = oldPosY,
        bodyType = 'dynamic',
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        radius = partData.dims.r,
        width = partData.dims.w,
        width2 = partData.dims.w2,
        width3 = partData.dims.w2,
        height = partData.dims.h,
        height2 = partData.dims.h,
        height3 = partData.dims.h,
        height4 = partData.dims.h,
    }

    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = shape8Dict[partData.shape8URL].v
        settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
    end

    local children = getParentAndChildrenFromPartName(partName, instance).c or {}
    logger:inspect(children)
    if type(children) == 'string' then
        children = { children }
    end
    makePart(partName, instance, settings)

    --instance.parts[partName].body:setPosition(oldPosX, oldPosY)
    --instance.parts[partName].body:setAngle(oldAngle)


    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            lib.updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

lib.createCharacter = function(template, x, y)
    if dna[template] then
        local instance = {
            id = uuid.generateID(),
            templateName = template,
            dna = utils.deepCopy(dna[template]), -- Copy template data for potential instance modification
            parts = {},                          -- { [partName] = thingObject, ... }
            joints = {},                         -- { [connectionName] = jointObject, ... }
            appearanceValues = {},               -- Will hold visual overrides (implement later)
            -- Add other instance-specific state if needed
        }

        local isPotato = instance.dna.creation.isPotatoHead
        local hasNeck = instance.dna.creation.neckSegments > 0
        local ordered = {}



        local torsoSegments = instance.dna.creation.torsoSegments or 1 -- Default to 1 torso segment
        -- 1. Add Torso Segments
        for i = 1, torsoSegments do
            local partName = 'torso' .. i
            table.insert(ordered, partName)
            -- Copy template DNA for this segment if it doesn't exist (it shouldn't)
            if not instance.dna.parts[partName] then
                -- Ensure template exists
                if not instance.dna.parts['torso-segment-template'] then
                    error("Missing 'torso-segment-template' in DNA for template: " .. template)
                end
                instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])
                -- Optional: Modify dimensions/properties of specific segments here if needed
                -- e.g., make torso1 wider (pelvis) or torsoN narrower (shoulders)
                instance.dna.parts[partName].dims.w = i * 100
                --logger:inspect(instance.dna.parts[partName])
                --  instance.dna.parts[partName].dims.w = ((torsoSegments + 1) - i) * 100
            end
        end

        if hasNeck and not isPotato then
            for i = 1, (instance.dna.creation.neckSegments or 2) do
                table.insert(ordered, 'neck' .. i)
                instance.dna.parts['neck' .. i] = instance.dna.parts['neck-segment-template']
            end
        end
        if not isPotato then
            table.insert(ordered, 'head')
        end
        -- Common limbs
        local limbs = {
            'luleg', 'ruleg', 'llleg', 'rlleg', 'lfoot', 'rfoot',
            'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand',
            'lear', 'rear'
        }
        for _, part in ipairs(limbs) do table.insert(ordered, part) end


        for i = 1, #ordered do
            local partName = ordered[i]
            local partData = instance.dna.parts[partName]
            --logger:info(partName, partData.shapeName)
            local settings = {
                x = x,
                y = y,
                bodyType = 'dynamic',       -- Start as dynamic, will be adjusted later if inactive
                shapeType = partData.shape, -- Use shape defined in template
                shape8URL = partData.shape8URL,
                label = partName,           --partName,           -- Use part name as initial label
                density = partData.density or 1,
                radius = partData.dims.r,
                width = partData.dims.w,
                width2 = partData.dims.w2,
                width3 = partData.dims.w2,
                height = partData.dims.h,
                height2 = partData.dims.h,
                height3 = partData.dims.h,
                height4 = partData.dims.h,

                -- Add other physics properties if needed (friction, restitution?)
            }

            if (partData.shape8URL) then
                if (shape8Dict[partData.shape8URL]) then
                    local raw = shape8Dict[partData.shape8URL].v
                    settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
                end
            end
            --logger:info('getting offset for ', partName)



            makePart(partName, instance, settings)
        end
        return instance
    end
end


return lib
