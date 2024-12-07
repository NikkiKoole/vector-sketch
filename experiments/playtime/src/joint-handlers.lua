-- jointHandlers.lua (Create a separate module for better organization)
local jointHandlers = {}

jointHandlers["distance"] = {
    create = function(data, x1, y1, x2, y2)
        local length = data.length or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newDistanceJoint(data.body1, data.body2, x1, y1, x2, y2, data.collideConnected)
        joint:setLength(length)
        return joint
    end,

    extract = function(joint)
        return {
            length = joint:getLength(),
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
        }
    end
}
jointHandlers["friction"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newFrictionJoint(data.body1, data.body2, x1, y1, x2, y2, data.collideConnected)
        return joint
    end,

    extract = function(joint)
        return {
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque()
        }
    end
}
jointHandlers["weld"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newWeldJoint(data.body1, data.body2, x1, y1, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            frequency = joint:getFrequency(),
            dampingRatio = joint:getDampingRatio(),
        }
    end
}
jointHandlers["rope"] = {
    create = function(data, x1, y1, x2, y2)
        local maxLength = data.maxLength or math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local joint = love.physics.newRopeJoint(data.body1, data.body2, x1, y1, x2, y2, maxLength, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            maxLength = joint:getMaxLength()
        }
    end
}
jointHandlers["revolute"] = {

    create = function(data, x1, y1, x2, y2)
        --print(x1, y1)
        local joint = love.physics.newRevoluteJoint(data.body1, data.body2, x1, y1, data.collideConnected)
        return joint
    end,
    extract = function(joint)
        return {
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorTorque = joint:getMaxMotorTorque(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),
        }
    end
}
jointHandlers["wheel"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newWheelJoint(data.body1, data.body2, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)

        if data.springFrequency then
            joint:setSpringFrequency(data.springFrequency)
        end
        if data.springDampingRatio then
            joint:setSpringDampingRatio(data.springDampingRatio)
        end
        return joint
    end,
    extract = function(joint)
        return {
            springFrequency = joint:getSpringFrequency(),
            springDampingRatio = joint:getSpringDampingRatio(),
        }
    end
}
jointHandlers["motor"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newMotorJoint(data.body1, data.body2, data.correctionFactor or .3,
            data.collideConnected)
        return joint
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
jointHandlers["prismatic"] = {
    create = function(data, x1, y1, x2, y2)
        local joint = love.physics.newPrismaticJoint(data.body1, data.body2, x1, y1, data.axisX or 0, data.axisY or 1,
            data.collideConnected)
        joint:setLowerLimit(0)
        joint:setUpperLimit(0)
        return joint
    end,
    extract = function(joint)
        return {
            motorEnabled = joint:isMotorEnabled(),
            motorSpeed = joint:getMotorSpeed(),
            maxMotorForce = joint:getMaxMotorForce(),
            limitsEnabled = joint:areLimitsEnabled(),
            lowerLimit = joint:getLowerLimit(),
            upperLimit = joint:getUpperLimit(),

        }
    end
}
jointHandlers["pulley"] = {
    create = function(data, x1, y1, x2, y2)
        local groundAnchorA = data.groundAnchor1 or { 0, 0 }
        local groundAnchorB = data.groundAnchor2 or { 0, 0 }
        local bodyA_centerX, bodyA_centerY = data.body1:getWorldCenter()
        local bodyB_centerX, bodyB_centerY = data.body2:getWorldCenter()
        local ratio = data.ratio or 1

        local joint = love.physics.newPulleyJoint(
            data.body1, data.body2,
            bodyA_centerX or groundAnchorA[1], groundAnchorA[2],
            bodyB_centerX or groundAnchorB[1], groundAnchorB[2],
            bodyA_centerX, bodyA_centerY,
            bodyB_centerX, bodyB_centerY,
            ratio,
            false
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
jointHandlers["friction"] = {
    create = function(data, x1, y1, x2, y2)
        -- Create a Friction Joint
        local x, y = data.body1:getPosition()
        local joint = love.physics.newFrictionJoint(data.body1, data.body2, x1, y1, false)

        if data.maxForce then
            joint:setMaxForce(data.maxForce)
        end
        if data.maxTorque then
            joint:setMaxTorque(data.maxTorque)
        end
        return joint
    end,
    extract = function(joint)
        return {
            maxForce = joint:getMaxForce(),
            maxTorque = joint:getMaxTorque(),
        }
    end
}
return jointHandlers
