local state = require('src.state')

local modes = {}

modes.DRAW_CLICK             = 'drawClickMode'
modes.DRAW_FREE_PATH         = 'drawFreePath'
modes.DRAW_FREE_POLY         = 'drawFreePoly'
modes.DRAW_TRACK             = 'drawTrack' -- a coaster track (src/track.lua)
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

-- drawing by dragging: a freeform polygon, a freepath ribbon or a coaster track
function modes.isFreehand()
    local m = state.currentMode
    return m == modes.DRAW_FREE_POLY or m == modes.DRAW_FREE_PATH or m == modes.DRAW_TRACK
end

function modes.set(mode)
    if not validModes[mode] then
        print('[modes] WARNING: unknown mode "' .. tostring(mode) .. '"')
    end
    state.currentMode = mode
end

function modes.clear()
    state.currentMode = nil
end

function modes.is(mode)
    return state.currentMode == mode
end

function modes.get()
    return state.currentMode
end

-- a LÖVE object still there (one released with its world can't be asked: gone)
local function alive(object)
    if not object then return false end
    local ok, destroyed = pcall(object.isDestroyed, object)
    return ok and not destroyed
end

-- What each tool works on, from the selection; a tool whose thing is gone (destroyed from its
-- panel, or a rebuild made a new one) ends.
local NEEDS_JOINT = { [modes.SET_OFFSET_A] = true, [modes.SET_OFFSET_B] = true }
local NEEDS_SFIXTURE = { [modes.POSITIONING_SFIXTURE] = true, [modes.ADD_NODE_CONNECTED_TEX] = true,
    [modes.ADD_NODE_MESHUSERT] = true, [modes.EDIT_MESH_TRIS] = true }

-- Before the editor acts on a press or a move: a tool whose thing is gone ends, a body picked for
-- a joint that's gone is unpicked, corners being edited of something gone stop being edited.
-- (claudetools/tool-modes_spec.lua: the next click after such a cut died.)
function modes.dropWhatsGone()
    local sel = state.selection
    local mode = state.currentMode
    local bodyThere = sel.selectedObj and alive(sel.selectedObj.body)
    if (NEEDS_JOINT[mode] and not alive(sel.selectedJoint))
        or (NEEDS_SFIXTURE[mode] and not alive(sel.selectedSFixture))
        or (mode == modes.PLACE_STEINER and not bodyThere) then
        state.currentMode = nil
    end
    local jp = state.jointParams
    if jp and ((jp.body1 and not alive(jp.body1)) or (jp.body2 and not alive(jp.body2))) then
        jp.body1, jp.body2, jp.p1, jp.p2 = nil, nil, nil, nil
    end
    if state.polyEdit.tempVerts and not bodyThere then
        state.polyEdit.tempVerts, state.polyEdit.centroid = nil, nil
        state.polyEdit.lockedVerts, state.polyEdit.dragIdx = true, 0
    end
    if state.texFixtureEdit.tempVerts and not alive(sel.selectedSFixture) then
        state.texFixtureEdit.tempVerts, state.texFixtureEdit.centroid = nil, nil
        state.texFixtureEdit.lockedVerts, state.texFixtureEdit.dragIdx = true, 0
    end
end

-- A new room: no tool on, nothing half made or half edited (the selection is cleared with it).
function modes.endAll()
    state.currentMode = nil
    state.jointParams = nil
    state.pickAutoRopifyModeHitted = nil
    state.polyEdit.tempVerts, state.polyEdit.centroid = nil, nil
    state.polyEdit.lockedVerts, state.polyEdit.dragIdx = true, 0
    state.texFixtureEdit.tempVerts, state.texFixtureEdit.centroid = nil, nil
    state.texFixtureEdit.lockedVerts, state.texFixtureEdit.dragIdx = true, 0
    state.interaction.draggingObj = nil
    state.interaction.polyVerts, state.interaction.lastPolyPt = {}, nil
    state.interaction.capturingPoly = false
end

return modes
