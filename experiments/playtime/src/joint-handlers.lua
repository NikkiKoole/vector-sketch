-- joint-handlers.lua
-- Per joint type: create (the Box2D joint), apply (set its properties from data)
-- and extract (read them back). apply sets back everything extract reads, so a
-- joint rebuilt from extract (recreate, resize, clone, flip) keeps its motor,
-- springs and limits. apply skips what data doesn't have: a new joint keeps
-- Box2D's defaults.
local jointHandlers = {}
local JT = require('src.joint-types')

local function setLimits(joint, data)
    if data.lowerLimit or data.upperLimit then
        -- setLimits errors on nil or lower > upper; normalize both
        local lower = data.lowerLimit or data.upperLimit
        local upper = data.upperLimit or data.lowerLimit
        joint:setLimits(math.min(lower, upper), math.max(lower, upper))
    end
    local enabled = data.limitsEnabled
    if enabled == nil then enabled = data.areLimitsEnabled end
    if enabled ~= nil then joint:setLimitsEnabled(enabled) end
end

local function setMotor(joint, data, maxKey, setMax)
    if data.motorEnabled ~= nil then joint:setMotorEnabled(data.motorEnabled) end
    if data.motorSpeed then joint:setMotorSpeed(data.motorSpeed) end
    if data[maxKey] then setMax(joint, data[maxKey]) end
end

local function setSpring(joint, data)
    if data.frequency then joint:setFrequency(data.frequency) end
    if data.dampingRatio then joint:setDampingRatio(data.dampingRatio) end
end

jointHandlers[JT.DISTANCE] = {
    create = function(data, x1, y1, x2, y2)
        local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newDistanceJoint(data.body1, data.body2, x1, y1, x2, y2, data.collideConnected)
        joint:setLength(length)
        return joint
    end,
    apply = setSpring,
    extract = function(joint)
        return {
            length = joint:getLength(),
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
        }
    end
}
jointHandlers[JT.WELD] = {
    create = function(data, x1, y1, _x2, _y2)
        if data.referenceAngle then
            return love.physics.newWeldJoint(data.body1, data.body2, x1, y1, x1, y1,
                data.collideConnected, data.referenceAngle)
        end
        return love.physics.newWeldJoint(data.body1, data.body2, x1, y1, data.collideConnected)
    end,
    apply = setSpring,
    extract = function(joint)
        return {
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
            referenceAngle = joint:getReferenceAngle(),
        }
    end
}
jointHandlers[JT.ROPE] = {
    create = function(data, x1, y1, x2, y2)
        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newRopeJoint(
            data.body1, data.body2, x1, y1, x2, y2, maxLength, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            maxLength = joint:getMaxLength()
        }
    end
}
jointHandlers[JT.REVOLUTE] = {
    -- Without a referenceAngle (a new joint) the short form counts angles from the
    -- pose right now; a rebuilt joint keeps the one it had, or its limits shift.
    create = function(data, x1, y1, _x2, _y2)
        if data.referenceAngle then
            return love.physics.newRevoluteJoint(data.body1, data.body2, x1, y1, x1, y1,
                data.collideConnected, data.referenceAngle)
        end
        return love.physics.newRevoluteJoint(data.body1, data.body2, x1, y1, data.collideConnected)
    end,
    apply = function(joint, data)
        setLimits(joint, data)
        setMotor(joint, data, 'maxMotorTorque', joint.setMaxMotorTorque)
    end,
    extract = function(joint)
        return {
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorTorque = joint:getMaxMotorTorque(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),
            areLimitsEnabled = joint:areLimitsEnabled(),
            referenceAngle = joint:getReferenceAngle(),
        }
    end
}
jointHandlers[JT.WHEEL] = {
    create = function(data, x1, y1, _x2, _y2)
        return love.physics.newWheelJoint(data.body1, data.body2, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)
    end,
    apply = function(joint, data)
        if data.springFrequency then joint:setSpringFrequency(data.springFrequency) end
        if data.springDampingRatio then joint:setSpringDampingRatio(data.springDampingRatio) end
        setMotor(joint, data, 'maxMotorTorque', joint.setMaxMotorTorque)
    end,
    extract = function(joint)
        local axisX, axisY = joint:getAxis()
        return {
            axisX = axisX,
            axisY = axisY,
            springFrequency = joint:getSpringFrequency(),
            springDampingRatio = joint:getSpringDampingRatio(),
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorTorque = joint:getMaxMotorTorque(),
        }
    end
}
jointHandlers[JT.MOTOR] = {
    create = function(data, _x1, _y1, _x2, _y2)
        local joint = love.physics.newMotorJoint(data.body1, data.body2, data.correctionFactor or .3,
            data.collideConnected)
        return joint
    end,
    apply = function(joint, data)
        if data.angularOffset then joint:setAngularOffset(data.angularOffset) end
        if data.linearOffsetX and data.linearOffsetY then
            joint:setLinearOffset(data.linearOffsetX, data.linearOffsetY)
        end
        if data.maxForce then joint:setMaxForce(data.maxForce) end
        if data.maxTorque then joint:setMaxTorque(data.maxTorque) end
    end,
    extract = function(joint)
        local lox, loy = joint:getLinearOffset()
        return {
            correctionFactor = joint:getCorrectionFactor(),
            angularOffset = joint:getAngularOffset(),
            linearOffsetX = lox,
            linearOffsetY = loy,
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque()
        }
    end
}
jointHandlers[JT.PRISMATIC] = {
    create = function(data, x1, y1, _x2, _y2)
        local axisX, axisY = data.axisX or 0, data.axisY or 1
        local joint
        if data.referenceAngle then
            joint = love.physics.newPrismaticJoint(data.body1, data.body2, x1, y1, x1, y1, axisX, axisY,
                data.collideConnected, data.referenceAngle)
        else
            joint = love.physics.newPrismaticJoint(data.body1, data.body2, x1, y1, axisX, axisY,
                data.collideConnected)
        end
        -- a new prismatic joint starts with a zero-length range; apply sets saved limits
        joint:setLowerLimit(0)
        joint:setUpperLimit(0)
        return joint
    end,
    apply = function(joint, data)
        setLimits(joint, data)
        setMotor(joint, data, 'maxMotorForce', joint.setMaxMotorForce)
    end,
    extract = function(joint)
        local axisX, axisY = joint:getAxis()
        return {
            axisX = axisX,
            axisY = axisY,
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorForce = joint:getMaxMotorForce(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),
            referenceAngle = joint:getReferenceAngle(),
        }
    end
}
jointHandlers[JT.PULLEY] = {
    create = function(data, _x1, _y1, _x2, _y2)
        local bodyA_centerX, bodyA_centerY = data.body1:getWorldCenter()
        local bodyB_centerX, bodyB_centerY = data.body2:getWorldCenter()
        -- Ground anchors arrive array-form {x, y} from extract() and keyed
        -- {x=, y=} from saved scenes; accept both. Default: above each body.
        -- (The old code passed body-center X where ground-anchor X belonged.)
        local ga1 = data.groundAnchor1 or {}
        local ga2 = data.groundAnchor2 or {}
        local gx1 = ga1[1] or ga1.x or bodyA_centerX
        local gy1 = ga1[2] or ga1.y or (bodyA_centerY - 100)
        local gx2 = ga2[1] or ga2.x or bodyB_centerX
        local gy2 = ga2[2] or ga2.y or (bodyB_centerY - 100)
        local ratio = data.ratio or 1

        local joint = love.physics.newPulleyJoint(
            data.body1, data.body2,
            gx1, gy1, gx2, gy2,
            bodyA_centerX, bodyA_centerY,
            bodyB_centerX, bodyB_centerY,
            ratio,
            data.collideConnected
        )
        return joint
    end,
    extract = function(joint)
        local x1, y1, x2, y2 = joint:getGroundAnchors()
        return {
            groundAnchor1 = { x1, y1 },
            groundAnchor2 = { x2, y2 },
            ratio = joint:getRatio()
        }
    end
}
jointHandlers[JT.FRICTION] = {
    create = function(data, x1, y1, _x2, _y2)
        return love.physics.newFrictionJoint(data.body1, data.body2, x1, y1, false)
    end,
    apply = function(joint, data)
        if data.maxForce then joint:setMaxForce(data.maxForce) end
        if data.maxTorque then joint:setMaxTorque(data.maxTorque) end
    end,
    extract = function(joint)
        return {
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque(),
        }
    end
}
return jointHandlers
