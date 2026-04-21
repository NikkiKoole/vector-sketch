local state = {}
local BT = require('src.body-types')

state.positioningMesh = false

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
    lastSelectedBody = nil, -- Maybe belongs here? Or separate interaction tracker?
}

state.interaction = { -- State directly related to ongoing user actions
    draggingObj = nil,
    offsetDragging = { nil, nil },
    polyVerts = {},       -- Temporary vertices while drawing
    lastPolyPt = nil,
    startSelection = nil, -- For selection rect
}

state.panelVisibility = {
    addShapeOpened = false,
    addJointOpened = false,
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

state.editorPreferences = { -- Less volatile state
    showGrid = false,
    nextType = BT.DYNAMIC,
    lastUsedRadius = 20,
    lastUsedWidth = 40,
    lastUsedWidth2 = 5,
    lastUsedHeight = 40,
    lastUsedHeight2 = 40,
    saveName = 'untitled',
    showTexFixtureDim = false,
    axisEnabled = false,
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
    verts = {}
}

state.triangleEditor = {
    selectedTriangles = {}, -- Array of triangle indices that are selected
    selectedGroup = 1,      -- Group/layer number triangles get tagged with (drives z-order)
    selectedBone = 1,       -- Node index triangles get assigned to (drives per-triangle DQS)
    brushSize = 20,         -- Radius for triangle selection brush (tested against tri centroid)
}

--state.scrollers = {}    -- will be filled with scrollers ({value=0})

-- Mode constants live in src/modes.lua — use modes.set/clear/is to manage this field
state.currentMode = nil
state.jointParams = nil
state.jointLengthParams = {}
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
    meter = 100,
    isRecordingPointers = false,
    paused = true,
    gravity = 9.80,
    mouseForce = 500000,
    mouseDamping = 0.5,
    speedMultiplier = 1.0,
    softbodies = {},
    playWithSoftbodies = false,
    showTextures = true,
    showDebugIds = false,
}


-- Backdrops are now persisted per-scene (see io.lua gatherSaveData / buildWorld).
-- Sessions that open a scene with a `backdrops` field replace this list wholesale;
-- sessions that open a pre-persistence scene inherit whatever is here.
state.backdrops = {}

-- MESHUSERT triangulation mode.
-- `basic`  → love.math.triangulate on polygon outline (ear-clipping, fast,
--            but produces long interior spans and sliver triangles on
--            concave shapes — artifacts during deformation).
-- `cdt`    → Delaunay triangulation with interior Steiner points
--            (`src/cdt.lua`). Denser, well-shaped triangles. Smooth
--            deformation across bones. Requires re-bind after toggling.
state.triangulationMode = 'basic'
state.cdtSpacing = nil -- optional override; auto-picked from polygon size


state.snap = {
    fixtures = {},
    activeJoints = {},
    cooldownList = {},
    snapDistance = 140,
    jointBreakThreshold = 100000,
    cooldownTime = 0.5,
    onlyConnectWhenInteracted = true,
    onlyBreakWhenInteracted = true,
}

state.physicsWorld = nil



return state
