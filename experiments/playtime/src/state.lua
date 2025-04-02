local state = {}


state.selection = {
    selectedObj = nil,
    selectedJoint = nil,
    selectedSFixture = nil,
    selectedBodies = nil,
    lastSelectedBody = nil, -- Maybe belongs here? Or separate interaction tracker?
    --state.ui.lastSelectedJoint = nil,
}
state.interaction = { -- State directly related to ongoing user actions
    draggingObj = nil,
    offsetDragging = { nil, nil },
    capturingPoly = false, -- Linked to drawing modes
    polyVerts = {},        -- Temporary vertices while drawing
    lastPolyPt = nil,
    minPointDistance = 50, -- Could be editor config
    startSelection = nil,  -- For selection rect
    setOffsetAFunc = nil,  -- These callback funcs are tricky, maybe replace with mode state
    setOffsetBFunc = nil,
    setUpdateSFixturePosFunc = nil,
    maybeHideSelectedPanel = false, -- This suggests UI logic leaking into state
}

state.panelVisibility = {
    addShapeOpened = false,
    addJointOpened = false,
    worldSettingsOpened = false,
    recordingPanelOpened = false,
    saveDialogOpened = false,
    quitDialogOpened = false,
    showPalette = nil,
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
}


state.ui = {
    jointCreationMode = nil,
    jointUpdateMode = nil,
    drawFreePoly = false,
    drawClickPoly = false,

    showTexFixtureDim = false,
    --worldText = '',
    polyDragIdx = 0,
    polyLockedVerts = true,
    polyTempVerts = nil, -- used when dragging a vertex
    polyCentroid = nil,
    texFixtureDragIdx = 0,
    texFixtureLockedVerts = true,
    texFixtureVerts = {},

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
