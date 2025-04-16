local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'


local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function getParentAndChildrenFromPartName(partName, guy)
    local creation  = guy.dna.creation

    local map       = {
        torso = { c = { 'neck1', 'luarm', 'ruarm', 'luleg', 'ruleg' } },
        --neck1 = { p = 'torso', c = 'neck2' },
        -- neck2 = { p = 'neck1', c = 'head' },
        head = { p = 'neck' .. creation.neckParts, c = { 'lear', 'rear' } },

        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = 'torso', c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = 'torso', c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = 'torso', c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = 'torso', c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' },
        --  butt = {p = 'torso'}
    }
    -- print(partName)
    local neckIndex = extractNeckIndex(partName)
    if neckIndex then
        if neckIndex == 1 then
            map[partName] = { p = 'torso', c = (neckIndex == creation.neckParts) and 'head' or 'neck2' }
        else
            map[partName] = {
                p = 'neck' .. (neckIndex - 1),
                c = (neckIndex == creation.neckParts) and 'head' or
                    'neck' .. neckIndex + 1
            }
        end
    end
    --print(partName)

    if creation and partName == 'head' and (creation.hasNeck == false or creation.neckParts == 0) then
        return { p = 'torso', c = { 'lear', 'rear', } }
    end

    if creation and partName == 'torso' and creation.isPotatoHead then
        return { c = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear', } }
    end
    if creation and partName == 'torso' and (creation.hasNeck == false or creation.neckParts == 0) then
        return { c = { 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' } }
    end

    local result = map[partName]

    if result.p == 'head' and creation.isPotatoHead then
        result.p = 'torso'
    end
    --logger:info(partName, inspect(map[partName]))
    return map[partName]
end

local function getOwnOffset(partName, guy)
    local creation = guy.dna.parts
    if extractNeckIndex(partName) then
        return 0, -creation[partName].dims.h / 2
    end
    if partName == 'head' then
        return 0, -creation.head.dims.h / 2
    end
    if partName == 'luleg' then
        return 0, creation.luleg.dims.h / 2
    end
    if partName == 'ruleg' then
        return 0, creation.ruleg.dims.h / 2
    end
    if partName == 'llleg' then
        return 0, creation.llleg.dims.h / 2
    end
    if partName == 'lfoot' then
        return 0, creation.lfoot.dims.h / 2
    end
    if partName == 'rlleg' then
        return 0, creation.rlleg.dims.h / 2
    end
    if partName == 'rfoot' then
        return 0, creation.rfoot.dims.h / 2
    end
    if partName == 'luarm' then
        return 0, creation.luarm.dims.h / 2
    end
    if partName == 'ruarm' then
        return 0, creation.ruarm.dims.h / 2
    end
    if partName == 'rhand' then
        return 0, creation.rhand.dims.h / 2
    end
    if partName == 'llarm' then
        return 0, creation.llarm.dims.h / 2
    end
    if partName == 'rlarm' then
        return 0, creation.rlarm.dims.h / 2
    end
    if partName == 'lhand' then
        return 0, creation.lhand.dims.h / 2
    end
    return 0, 0
end

local function getOffsetFromParent(partName, guy)
    local parts       = guy.dna.parts
    local creation    = guy.dna.creation
    local positioners = guy.dna.positioners
    local data        = getParentAndChildrenFromPartName(partName, guy)


    if extractNeckIndex(partName) then
        local index = extractNeckIndex(partName)
        if index == 1 then
            return 0, -parts.torso.dims.h / 2
        else
            return 0, -parts['neck' .. (index - 1)].dims.h / 2
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
        -- if creation.isPotatoHead then
        --     if creation.torso.metaPoints then
        --         return getScaledTorsoMetaPoint(7, guy)
        --     end
        -- else
        --     if creation.torso.metaPoints then
        --         return getScaledTorsoMetaPoint(8, guy)
        --     end
        -- end
        return -parts.torso.dims.w / 2, -parts.torso.dims.h / 2
    elseif partName == 'ruarm' then
        -- if creation.isPotatoHead then
        --     if creation.torso.metaPoints then
        --         return getScaledTorsoMetaPoint(3, guy)
        --     end
        -- else
        --     if creation.torso.metaPoints then
        --         return getScaledTorsoMetaPoint(2, guy)
        --     end
        -- end
        return parts.torso.dims.w / 2, -parts.torso.dims.h / 2
    elseif partName == 'luleg' then
        local t = 0.5 --positioners.leg.x
        -- if creation.torso.metaPoints then
        --     local ax, ay = getScaledTorsoMetaPoint(6, guy)
        --     local bx, by = getScaledTorsoMetaPoint(5, guy)
        --     local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
        --     return rx, ry
        -- end
        return (-parts.torso.dims.w / 2) * (1 - t), parts.torso.dims.h / 2
    elseif partName == 'ruleg' then
        local t = 0.5 -- positioners.leg.x
        -- if creation.torso.metaPoints then
        --     local ax, ay = getScaledTorsoMetaPoint(4, guy)
        --     local bx, by = getScaledTorsoMetaPoint(5, guy)
        --     local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
        --     return rx, ry
        -- end
        return (parts.torso.dims.w / 2) * (1 - t), parts.torso.dims.h / 2
    elseif partName == 'lear' then
        -- if creation.isPotatoHead then
        --     if creation.torso.metaPoints then
        --         local t = positioners.ear.y
        --         local ax, ay = getScaledTorsoMetaPoint(8, guy)
        --         local bx, by = getScaledTorsoMetaPoint(7, guy)
        --         local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

        --         return rx, ry
        --     end
        -- else
        --     if creation.head.metaPoints then
        --         local t = positioners.ear.y
        --         local ax, ay = getScaledHeadMetaPoint(8, guy)
        --         local bx, by = getScaledHeadMetaPoint(6, guy)
        --         local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

        --         return rx, ry
        --     end
        -- end

        return -parts.head.w / 2, -parts.head.h / 2
    elseif partName == 'rear' then
        -- if creation.isPotatoHead then
        --     if creation.torso.metaPoints then
        --         local t = positioners.ear.y
        --         local ax, ay = getScaledTorsoMetaPoint(2, guy)
        --         local bx, by = getScaledTorsoMetaPoint(3, guy)
        --         local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

        --         return rx, ry
        --     end
        -- else
        --     if creation.head.metaPoints then
        --         local t = positioners.ear.y
        --         local ax, ay = getScaledHeadMetaPoint(2, guy)
        --         local bx, by = getScaledHeadMetaPoint(4, guy)
        --         local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)

        --         return rx, ry
        --     end
        -- end
        return parts.head.w / 2, -parts.head.h / 2
    elseif (partName == 'head') then
        --  then
        --     return 0, -creation.neck1.dims.h / 2
        -- else
        --     return 0, -creation.torso.dims.h / 2





        if creation.neckParts == 0 then
            return 0, -parts.torso.dims.h / 2
        else
            local last = 'neck' .. creation.neckParts
            return 0, -parts[last].dims.h / 2
        end
    else
        if false then
            if (partName == 'head') then
                if creation.hasNeck then
                    return 0, creation.neck1.h / (creation.neck1.links or 1)
                else
                    if creation.torso.metaPoints then
                        return getScaledTorsoMetaPoint(1, guy)
                    end

                    return 0, -creation.torso.h / 2
                end
            end

            local p = data.p
            -- now look for the alias of the parent...
            local temp = getParentAndChildrenFromPartName(p, guy)
            local part = p
            --  local s = canvas.getShrinkFactor()
            -- wscale = wscale * s
            --  hscale = hscale * s
            return 0, creation[part].h --/ s
        end

        return 0, 0
    end
end

local function getAngleOffset(partName, guy)
    local creation = guy.dna.parts
    if partName == 'lfoot' then
        return math.pi / 2
    elseif partName == 'rfoot' then
        return -math.pi / 2
    else
        return 0
    end
end

local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = false,
            neckParts = 2
        },
        parts = {
            ['torso'] = { dims = { w = 300, w2 = 350, h = 300 }, shape = 'trapezium' },
            ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = 'capsule', },
            ['luleg'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule' },
            ['ruleg'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['llleg'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['rlleg'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['luarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['ruarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', },
            ['lfoot'] = { dims = { w = 80, h = 150 }, shape = 'rectangle', },
            ['rfoot'] = { dims = { w = 80, h = 150 }, shape = 'rectangle', },
            ['lhand'] = { dims = { w = 40, h = 40 }, shape = 'rectangle', },
            ['rhand'] = { dims = { w = 40, h = 40 }, shape = 'rectangle', },
        },
        joints = {
            { a = 'torso', b = 'luleg', type = 'revolute', limits = { low = 0, up = math.pi / 2 } },
            { a = 'torso', b = 'ruleg', type = 'revolute', limits = { low = -math.pi / 2, up = 0 } },
            { a = 'luleg', b = 'llleg', type = 'revolute', limits = { low = -math.pi / 2, up = 0 } },
            { a = 'llleg', b = 'lfoot', type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } },
            { a = 'ruleg', b = 'rlleg', type = 'revolute', limits = { low = 0, up = math.pi / 2 } },
            { a = 'rlleg', b = 'rfoot', type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } },
            { a = 'torso', b = 'luarm', type = 'revolute', limits = { low = 0, up = math.pi / 2 } },
            { a = 'torso', b = 'ruarm', type = 'revolute', limits = { low = -math.pi / 2, up = 0 } },
            { a = 'luarm', b = 'llarm', type = 'revolute', },
            { a = 'ruarm', b = 'rlarm', type = 'revolute', },
            { a = 'llarm', b = 'lhand', type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } },
            { a = 'rlarm', b = 'rhand', type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } },
        }
    }
}


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
        local hasNeck = instance.dna.creation.neckParts > 0
        local ordered = {}

        table.insert(ordered, 'torso')

        if hasNeck and not isPotato then
            for i = 1, (instance.dna.creation.neckParts or 2) do
                table.insert(ordered, 'neck' .. i)
                instance.dna.parts['neck' .. i] = { dims = { w = 40, w2 = 4, h = 150 }, shape = 'capsule' }
            end
        end
        if not isPotato then
            table.insert(ordered, 'head')
        end
        -- Common limbs
        local limbs = {
            'luleg', 'ruleg', 'llleg', 'rlleg', 'lfoot', 'rfoot',
            'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand',
        }
        for _, part in ipairs(limbs) do table.insert(ordered, part) end


        --  ok lets create the correct joints
        if not hasNeck and not isPotato then
            table.insert(instance.dna.joints,
                { a = 'torso', b = 'head', type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } })
        end
        if not isPotato and instance.dna.creation.neckParts > 0 then
            table.insert(instance.dna.joints,
                { a = 'torso', b = 'neck1', type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } })
            for i = 1, instance.dna.creation.neckParts - 1 do
                table.insert(instance.dna.joints,
                    { a = 'neck' .. i, b = 'neck' .. (i + 1), type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } })
            end

            table.insert(instance.dna.joints,
                { a = 'neck' .. instance.dna.creation.neckParts, b = 'head', type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } })
        end

        logger:inspect(ordered)

        for i = 1, #ordered do
            local partName = ordered[i]
            local partData = instance.dna.parts[partName]

            local settings = {
                x = x,
                y = y,
                bodyType = 'dynamic',       -- Start as dynamic, will be adjusted later if inactive
                shapeType = partData.shape, -- Use shape defined in template
                label = partName,           -- Use part name as initial label
                density = partData.density or 1,
                radius = partData.dims.r,
                width = partData.dims.w,
                width2 = partData.dims.w2,
                height = partData.dims.h,
                -- Add other physics properties if needed (friction, restitution?)
            }
            --logger:info('getting offset for ', partName)

            local prevA = 0
            local data = getParentAndChildrenFromPartName(partName, instance)
            if data.p then
                if instance.parts[data.p] then
                    local parentPosX, parentPosY = instance.parts[data.p].body:getPosition()
                    settings.x = parentPosX
                    settings.y = parentPosY
                end
                prevA = instance.parts[data.p].body:getAngle()
            end

            local offX, offY = getOffsetFromParent(partName, instance)
            settings.x = settings.x + offX
            settings.y = settings.y + offY
            local offX, offY = getOwnOffset(partName, instance) -- because all shapes are drawn from their center it needs extra offsetting
            local xangle = getAngleOffset(partName, instance)
            local rx, ry = mathutils.rotatePoint(offX, offY, 0, 0, xangle)

            settings.x = settings.x + rx
            settings.y = settings.y + ry
            local thing = ObjectManager.addThing(settings.shapeType, settings)

            if thing then
                thing.body:setAngle(prevA + xangle)
                instance.parts[partName] = thing
            end
        end

        for jointName, jointData in pairs(instance.dna.joints) do
            local partA_thing = instance.parts[jointData.a]
            local partB_thing = instance.parts[jointData.b]
            if (partA_thing and partB_thing) then
                local jointCreationData = {
                    body1 = partA_thing.body,
                    body2 = partB_thing.body,
                    jointType = jointData.type,
                    collideConnected = false, -- Default to false
                    id = uuid.generateID(),
                    offsetA = { x = 0, y = 0 },
                    offsetB = { x = 0, y = 0 },
                }
                local offX, offY = getOffsetFromParent(jointData.b, instance)
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
end

return lib
