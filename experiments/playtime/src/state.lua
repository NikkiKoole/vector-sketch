local state = {}


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
}

state.editorPreferences = { -- Less volatile state
    showGrid = false,
    nextType = 'dynamic',
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
    verts = {}
}

--state.scrollers = {}    -- will be filled with scrollers ({value=0})

state.currentMode = nil -- 'jointCreationMode' 'pickAutoRopifyMode' 'drawFreePoly' 'drawClickPoly', 'positioningSFixture', 'setOffsetA', 'setOffsetB' , 'addNodeToConnectedTexture'
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
}

state.backdrop = {
    show = true,
    url = 'backdrops/5-1536x1075.jpg'
}

state.physicsWorld = nil



return state
