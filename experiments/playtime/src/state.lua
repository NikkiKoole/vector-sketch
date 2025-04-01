local state = {}

state.ui = {
    lastUsedRadius = 20,
    lastUsedWidth = 40,
    lastUsedWidth2 = 5,
    lastUsedHeight = 40,
    lastUsedHeight2 = 40,

    showGrid = false,
    radiusOfNextSpawn = 100,
    nextType = 'dynamic',
    addShapeOpened = false,
    addJointOpened = false,

    worldSettingsOpened = false,
    maybeHideSelectedPanel = false,

    showTexFixtureDim = false,

    selectedJoint = nil,
    setOffsetAFunc = nil,
    setOffsetBFunc = nil,
    setUpdateSFixturePosFunc = nil,
    selectedSFixture = nil,
    selectedObj = nil,
    draggingObj = nil,
    offsetDragging = { nil, nil },
    worldText = '',
    jointCreationMode = nil,
    jointUpdateMode = nil,
    drawFreePoly = false,
    drawClickPoly = false,
    capturingPoly = false,

    polyDragIdx = 0,
    polyLockedVerts = true,
    polyTempVerts = nil, -- used when dragging a vertex
    polyCentroid = nil,
    polyVerts = {},

    texFixtureDragIdx = 0,
    texFixtureLockedVerts = true,
    texFixtureVerts = {},

    showPalette = nil,
    minPointDistance = 50, -- Default minimum distance
    lastPolyPt = nil,
    lastSelectedBody = nil,
    selectedBodies = nil,
    lastSelectedJoint = nil,
    saveDialogOpened = false,
    quitDialogOpened = false,
    saveName = 'untitled',
    recordingPanelOpened = false,
}

state.world = {
    debugDrawMode = true,
    debugAlpha = 1,
    profiling = false,
    meter = 100,
    isRecordingPointers = false,
    paused = true,
    gravity = 9.80,
    mouseForce = 500000,
    mouseDamping = 0.5,
    speedMultiplier = 1.0,
    softbodies = {},
    playWithSoftbodies = false

}

state.physicsWorld = nil



return state
