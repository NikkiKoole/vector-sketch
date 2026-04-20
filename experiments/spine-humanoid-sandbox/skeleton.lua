-- skeleton.lua — humanoid joint schema for the spine-mesh sandbox.
--
-- ~12 named joints arranged in a T-pose. Each has a name, a default
-- world position, and a parent (or nil for pelvis, the root).
--
-- Distances are in pixels; scene centered at (400, 300) in a 1200x768
-- window to match playtime's convention.
--
-- Limb chains are derived by walking parent links from the chain's
-- tip back up (wrist → elbow → shoulder etc.) — see `chain` below.

local M = {}

local cx, cy = 400, 300 -- scene center

M.joints = {
    pelvis         = { x = cx,         y = cy,         parent = nil },
    spine          = { x = cx,         y = cy - 80,    parent = 'pelvis' },
    chest          = { x = cx,         y = cy - 150,   parent = 'spine' },
    neck           = { x = cx,         y = cy - 200,   parent = 'chest' },
    head           = { x = cx,         y = cy - 250,   parent = 'neck' },

    leftShoulder   = { x = cx - 70,    y = cy - 150,   parent = 'chest' },
    leftElbow      = { x = cx - 130,   y = cy - 80,    parent = 'leftShoulder' },
    leftWrist      = { x = cx - 170,   y = cy,         parent = 'leftElbow' },

    rightShoulder  = { x = cx + 70,    y = cy - 150,   parent = 'chest' },
    rightElbow     = { x = cx + 130,   y = cy - 80,    parent = 'rightShoulder' },
    rightWrist     = { x = cx + 170,   y = cy,         parent = 'rightElbow' },

    leftHip        = { x = cx - 40,    y = cy,         parent = 'pelvis' },
    leftKnee       = { x = cx - 45,    y = cy + 100,   parent = 'leftHip' },
    leftAnkle      = { x = cx - 50,    y = cy + 200,   parent = 'leftKnee' },

    rightHip       = { x = cx + 40,    y = cy,         parent = 'pelvis' },
    rightKnee      = { x = cx + 45,    y = cy + 100,   parent = 'rightHip' },
    rightAnkle     = { x = cx + 50,    y = cy + 200,   parent = 'rightKnee' },
}

-- Named limb chains. Each limb is an ordered list of joint names from
-- root-of-limb → tip. The spine-mesh bind/evaluate walks these.
M.limbs = {
    leftArm  = { 'leftShoulder',  'leftElbow',  'leftWrist'  },
    rightArm = { 'rightShoulder', 'rightElbow', 'rightWrist' },
    leftLeg  = { 'leftHip',  'leftKnee',  'leftAnkle'  },
    rightLeg = { 'rightHip', 'rightKnee', 'rightAnkle' },
    -- Body axis: top-to-bottom midline. Useful for binding a whole-body
    -- silhouette to get soft sway (not independent limb articulation).
    bodyAxis = { 'head', 'neck', 'chest', 'spine', 'pelvis' },
}

-- All parent-child edges, useful for rendering the skeleton as lines.
function M.edges()
    local out = {}
    for name, j in pairs(M.joints) do
        if j.parent then out[#out + 1] = { name, j.parent } end
    end
    return out
end

-- Live copy of joint positions for this session. main.lua mutates `pos`
-- as the user drags. Schema (parent links, limb chains) stays in M.
function M.newInstance()
    local inst = { pos = {} }
    for name, j in pairs(M.joints) do
        inst.pos[name] = { x = j.x, y = j.y }
    end
    return inst
end

-- Return {x1,y1,x2,y2,...} for a limb's joints in chain order.
function M.chainPoints(inst, limbName)
    local chain = M.limbs[limbName]
    if not chain then return nil end
    local pts = {}
    for _, jn in ipairs(chain) do
        local p = inst.pos[jn]
        if p then
            pts[#pts + 1] = p.x
            pts[#pts + 1] = p.y
        end
    end
    return pts
end

return M
