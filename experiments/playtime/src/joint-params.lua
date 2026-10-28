-- joint-params.lua
-- What the inspector (src/ui/inspector.lua) shows for each joint type. Rows
-- read and write the Box2D joint through get/set. A set that has to rebuild the
-- joint (collide, axis) returns the new joint, so the panel stops drawing the
-- old one. `visible(joint)` hides rows (limit sliders while limits are off).
-- Ranges are the ones the old panel (src/ui/joint-update.lua) used.
local JT = require('src.joint-types')

local lib = {}

-- lazy: joints -> registry -> snap -> ...
local function recreate(joint, settings)
    local state = require('src.state')
    local newJoint = require('src.joints').recreateJoint(joint, settings)
    state.selection.selectedJoint = newJoint
    return newJoint
end

-- On top of every joint panel: its name, then destroy.
lib.header = {
    { key = 'label', kind = 'text', keepSpaces = true,
      get = function(joint) return (joint:getUserData() or {}).label or '' end,
      set = function(joint, v)
          local ud = joint:getUserData() or {}
          ud.label = v
          joint:setUserData(ud)
      end },
    { kind = 'action', label = 'destroy',
      run = function(_, joint)
          local joints = require('src.joints')
          require('src.registry').unregisterJoint(joints.getJointId(joint))
          joint:destroy()
          require('src.state').selection.selectedJoint = nil
          return true -- gone: stop drawing this panel
      end },
}

local function number(key, min, max, get, set, extra)
    local row = { key = key, kind = 'number', min = min, max = max,
        get = get, set = function(joint, v) set(joint, v) end }
    for k, v in pairs(extra or {}) do row[k] = v end
    return row
end

local function deg(f) return function(joint) return math.deg(f(joint)) end end

local collide = { key = 'collide', kind = 'bool', advanced = true,
    get = function(joint) return joint:getCollideConnected() end,
    set = function(joint, v) return recreate(joint, { collideConnected = v }) end }

local anchorA = { kind = 'action', label = '∆ anchor',
    run = function() local modes = require('src.modes'); modes.set(modes.SET_OFFSET_A) end }
local anchorB = { kind = 'action', label = '∆ anchor B',
    run = function() local modes = require('src.modes'); modes.set(modes.SET_OFFSET_B) end }

local function limitsOn(joint) return joint:areLimitsEnabled() end
local function motorOn(joint) return joint:isMotorEnabled() end

local limits = { key = 'limits', kind = 'bool',
    get = function(joint) return joint:areLimitsEnabled() end,
    set = function(joint, v) joint:setLimitsEnabled(v) end }

local angularLimits = {
    limits,
    number('lower', -180, function(joint) return math.deg(joint:getUpperLimit()) end,
        deg(function(joint) return joint:getLowerLimit() end),
        function(joint, v) joint:setLowerLimit(math.rad(v)) end, { visible = limitsOn, step = 1 }),
    number('upper', function(joint) return math.deg(joint:getLowerLimit()) end, 180,
        deg(function(joint) return joint:getUpperLimit() end),
        function(joint, v) joint:setUpperLimit(math.rad(v)) end, { visible = limitsOn, step = 1 }),
}

local linearLimits = {
    limits,
    number('lower', -1000, function(joint) return joint:getUpperLimit() end,
        function(joint) return joint:getLowerLimit() end,
        function(joint, v) joint:setLowerLimit(v) end, { visible = limitsOn }),
    number('upper', function(joint) return joint:getLowerLimit() end, 1000,
        function(joint) return joint:getUpperLimit() end,
        function(joint, v) joint:setUpperLimit(v) end, { visible = limitsOn }),
}

local function motor(useForce)
    local rows = {
        { key = 'motor', kind = 'bool',
          get = function(joint) return joint:isMotorEnabled() end,
          set = function(joint, v) joint:setMotorEnabled(v) end },
        number('speed', -1000, 1000, function(joint) return joint:getMotorSpeed() end,
            function(joint, v) joint:setMotorSpeed(v) end, { visible = motorOn }),
    }
    if useForce then
        rows[#rows + 1] = number('max force', 0, 100000, function(joint) return joint:getMaxMotorForce() end,
            function(joint, v) joint:setMaxMotorForce(v) end, { visible = motorOn, advanced = true })
    else
        rows[#rows + 1] = number('max torque', 0, 100000, function(joint) return joint:getMaxMotorTorque() end,
            function(joint, v) joint:setMaxMotorTorque(v) end, { visible = motorOn, advanced = true })
    end
    return rows
end

local axis = {
    { key = 'axis x', kind = 'number', min = -1, max = 1, advanced = true,
      get = function(joint) return (joint:getAxis()) end,
      set = function(joint, v) local _, ay = joint:getAxis(); return recreate(joint, { axisX = v, axisY = ay }) end },
    { key = 'axis y', kind = 'number', min = -1, max = 1, advanced = true,
      get = function(joint) local _, ay = joint:getAxis(); return ay end,
      set = function(joint, v) local ax = joint:getAxis(); return recreate(joint, { axisX = ax, axisY = v }) end },
    { kind = 'action', label = 'normalize axis', advanced = true,
      run = function(_, joint)
          local ax, ay = require('src.math-utils').normalizeAxis(joint:getAxis())
          return recreate(joint, { axisX = ax, axisY = ay })
      end },
}

local function springRows(freqMax)
    return {
        number('freq', 0, freqMax, function(joint) return joint:getFrequency() end,
            function(joint, v) joint:setFrequency(v) end),
        number('damp', 0, 20, function(joint) return joint:getDampingRatio() end,
            function(joint, v) joint:setDampingRatio(v) end),
    }
end

local function forceTorque()
    return {
        number('force', 0, 100000, function(joint) return joint:getMaxForce() end,
            function(joint, v) joint:setMaxForce(v) end),
        number('torque', 0, 100000, function(joint) return joint:getMaxTorque() end,
            function(joint, v) joint:setMaxTorque(v) end),
    }
end

local function concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, row in ipairs(list) do out[#out + 1] = row end
    end
    return out
end

lib.byType = {
    [JT.REVOLUTE] = concat(angularLimits, motor(false), { anchorA, collide }),
    [JT.PRISMATIC] = concat(linearLimits, motor(true), { anchorA, anchorB, collide }, axis),
    [JT.WHEEL] = concat({
        number('spring', 0, 100, function(joint) return joint:getSpringFrequency() end,
            function(joint, v) joint:setSpringFrequency(v) end),
        number('damp', 0, 1, function(joint) return joint:getSpringDampingRatio() end,
            function(joint, v) joint:setSpringDampingRatio(v) end),
    }, motor(false), { anchorA, anchorB, collide }, axis),
    [JT.DISTANCE] = concat({
        number('length', 0.1, 500, function(joint) return joint:getLength() end,
            function(joint, v) joint:setLength(v) end),
    }, springRows(20), { anchorA, anchorB, collide }),
    [JT.WELD] = concat(springRows(20), { anchorA, anchorB, collide }),
    [JT.ROPE] = {
        number('length', 0.1, 500, function(joint) return joint:getMaxLength() end,
            function(joint, v) joint:setMaxLength(v) end),
        anchorA, anchorB, collide,
    },
    [JT.MOTOR] = concat({
        number('angle', -180, 180, deg(function(joint) return joint:getAngularOffset() end),
            function(joint, v) joint:setAngularOffset(math.rad(v)) end, { step = 1 }),
        number('correction', 0, 1, function(joint) return joint:getCorrectionFactor() end,
            function(joint, v) joint:setCorrectionFactor(v) end),
        number('offset x', -1000, 1000, function(joint) return (joint:getLinearOffset()) end,
            function(joint, v) local _, ly = joint:getLinearOffset(); joint:setLinearOffset(v, ly) end),
        number('offset y', -1000, 1000, function(joint) local _, ly = joint:getLinearOffset(); return ly end,
            function(joint, v) local lx = joint:getLinearOffset(); joint:setLinearOffset(lx, v) end),
    }, forceTorque(), { anchorA, anchorB, collide }),
    [JT.FRICTION] = concat(forceTorque(), { anchorA, anchorB }),
}

return lib
