local state = {}
local BT = require('src.body-types')

state.scene = {
    sceneScript = nil,
    scriptPath = nil,
    checkpoints = {},
    activeCheckpointIndex = 0
}

state.selection = {
    selectedObj = nil,
    selectedJoint = nil,
    selectedSFixture = nil,
    selectedBodies = nil,
}

state.interaction = { -- State directly related to ongoing user actions
    draggingObj = nil,
    offsetDragging = { nil, nil },
    polyVerts = {},       -- Temporary vertices while drawing
    lastPolyPt = nil,
    startSelection = nil, -- For selection rect
}

state.panelVisibility = {
    worldSettingsOpened = false,
    recordingPanelOpened = false,
    saveDialogOpened = false,
    quitDialogOpened = false,
    showPalette = nil,
    addBehavior = false,
    customBehavior = false,
    customBehaviorDescription = false,
    bgSettingsOpened = false
}

state.rightColumn = { tab = 'properties' } -- src/ui/right-column.lua
state.toolRail = { open = nil, last = {} } -- src/ui/tool-rail.lua

state.editorPreferences = { -- Less volatile state
    showGrid = false,
    nextType = BT.DYNAMIC,
    lastUsedRadius = 20,
    lastUsedWidth = 40,
    lastUsedWidth2 = 5,
    lastUsedHeight = 40,
    lastUsedHeight2 = 40,
    saveName = 'untitled',
    minPointDistance = 50, -- Could be editor config
}

state.polyEdit = {
    dragIdx = 0,
    tempVerts = nil,
    lockedVerts = true,
    centroid = nil
}

state.texFixtureEdit = {
    dragIdx = 0,
    lockedVerts = true,
    tempVerts = nil,
    centroid = nil,
}

state.triangleEditor = {
    selectedTriangles = {}, -- Array of triangle indices that are selected
    selectedGroup = 1,      -- Group/layer number triangles get tagged with (drives z-order)
    selectedBone = 1,       -- Node index triangles get assigned to (drives per-triangle DQS)
    brushSize = 20,         -- Radius for triangle selection brush (tested against tri centroid)
}

-- Mode constants live in src/modes.lua — use modes.set/clear/is to manage this field
state.currentMode = nil
state.jointParams = nil
state.showPaletteFunc = nil
state.pickAutoRopifyModeHitted = nil

state.world = {
    darkMode = true,
    drawFixtures = true,
    drawOutline = true,
    debugDrawMode = true,
    debugAlpha = 1,
    debugDrawBodies = true,
    debugDrawJoints = false,
    profiling = false,
    meter = 200, -- px per metre (Mipos ~2-4 m); tuned numbers are at 100, src/physics-units.lua
    isRecordingPointers = false,
    paused = true,
    gravity = 9.80,
    dragStrength = 40, -- a drag pulls with up to this many times the weight of what it holds
    mouseDamping = 0.5,
    speedMultiplier = 1.0,
    -- Box2D solver iterations per step (its defaults are 8 and 3); more is stiffer joints and
    -- steadier piles, at a cost in every step
    velocityIterations = 16,
    positionIterations = 6,
    showTextures = true,
    showDebugIds = false,
}


-- Backdrops are now persisted per-scene (see io.lua gatherSaveData / buildWorld).
-- Sessions that open a scene with a `backdrops` field replace this list wholesale;
-- sessions that open a pre-persistence scene inherit whatever is here.
state.backdrops = {}

state.snap = {
    snapDistance = 40, -- snap points click together when they nearly touch (140 grabbed from afar)
    jointBreakThreshold = 100000,
    cooldownTime = 0.5,
    onlyConnectWhenInteracted = true,
    onlyBreakWhenInteracted = true,
}

state.physicsWorld = nil

return state
