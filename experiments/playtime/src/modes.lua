local modes = {}

modes.DRAW_CLICK             = 'drawClickMode'
modes.DRAW_FREE_PATH         = 'drawFreePath'
modes.DRAW_FREE_POLY         = 'drawFreePoly'
modes.PICK_AUTO_ROPIFY       = 'pickAutoRopifyMode'
modes.EDIT_MESH_TRIS         = 'editMeshTriangles'
modes.JOINT_CREATION         = 'jointCreationMode'
modes.SET_OFFSET_A           = 'setOffsetA'
modes.SET_OFFSET_B           = 'setOffsetB'
modes.POSITIONING_SFIXTURE   = 'positioningSFixture'
modes.ADD_NODE_MESHUSERT     = 'addNodeToMeshUsert'
modes.ADD_NODE_CONNECTED_TEX = 'addNodeToConnectedTexture'
modes.PLACE_STEINER          = 'placeSteiner'

-- Build reverse lookup for validation
local validModes = {}
for k, v in pairs(modes) do
    if type(v) == 'string' then
        validModes[v] = k
    end
end

function modes.set(mode)
    if not validModes[mode] then
        print('[modes] WARNING: unknown mode "' .. tostring(mode) .. '"')
    end
    local state = require('src.state')
    state.currentMode = mode
end

function modes.clear()
    local state = require('src.state')
    state.currentMode = nil
end

function modes.is(mode)
    local state = require('src.state')
    return state.currentMode == mode
end

function modes.get()
    local state = require('src.state')
    return state.currentMode
end

return modes
