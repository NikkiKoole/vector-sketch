-- The selection bar (docs/EDITOR-ARRANGE.md EA2): a small bar under what's selected on the stage, with the
-- few things done most while arranging, so they don't need the properties panel:
--   🎲 another one of the same kind (a Mipo: randomize all, undo in its panel; props: EA3, not yet),
--   copy, flip, delete, and ••• for the full properties (the right column's properties tab).
-- A Mipo part selected stands for the whole Mipo; a box selection (several bodies) gets copy and delete.
-- Drawn in UI units (under ui.scale), in the editor only, not while a tool mode is on.
-- Off for now (Nikki 2026-11-11: "not sold on the bar (yet)", "leave the bar disabled"): state.selectionBar = true
-- turns it on (from the bridge or the console).
local lib = {}

local state = require('src.state')
local ui = require('src.ui.all')
local modes = require('src.modes')
local camera = require('src.camera')
local cam = camera.getInstance()
local mipoRegistry = require('src.mipo-registry')
local objectManager = require('src.object-manager')
local library = require('src.library')
local snap = require('src.physics.snap')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')

local BUTTON_H = 30
local GAP = 4
local PAD = 5
local BELOW = 16       -- UI px under the selection's bottom
local KNOB_ROOM = 48   -- above the selection: past the turn knob (src/transform-handles.lua)

local function alive(body) return body and not body:isDestroyed() end

-- the world box round some bodies: their collision shapes (sfixtures can reach far: a texture, a tile)
local function boundsOf(bodies)
    local minX, minY, maxX, maxY
    local function grow(fixture)
        local x1, y1, x2, y2 = fixture:getBoundingBox()
        minX, minY = math.min(minX or x1, x1), math.min(minY or y1, y1)
        maxX, maxY = math.max(maxX or x2, x2), math.max(maxY or y2, y2)
    end
    for _, body in ipairs(bodies) do
        local any = false
        for _, fixture in ipairs(body:getFixtures()) do
            if fixture:getUserData() == nil then grow(fixture); any = true end
        end
        if not any then -- only sfixtures: at least its spot
            local x, y = body:getPosition()
            minX, minY = math.min(minX or x, x), math.min(minY or y, y)
            maxX, maxY = math.max(maxX or x, x), math.max(maxY or y, y)
        end
    end
    return minX, minY, maxX, maxY
end

-- what's selected, as the bar sees it: { kind = 'mipo' | 'thing' | 'many', bodies, ... } or nil
local function target()
    local sel = state.selection
    if sel.selectedSFixture or sel.selectedJoint or state.polyEdit.tempVerts then return nil end
    if sel.selectedBodies and #sel.selectedBodies > 0 then
        local bodies, things = {}, {}
        for _, thing in ipairs(sel.selectedBodies) do
            if alive(thing.body) then
                bodies[#bodies + 1] = thing.body
                things[#things + 1] = thing
            end
        end
        if #things == 0 then return nil end
        return { kind = 'many', bodies = bodies, things = things }
    end
    local thing = sel.selectedObj
    if not thing or not alive(thing.body) then return nil end
    local instance = mipoRegistry.getFromBody(thing.body)
    if instance then
        local bodies = {}
        for _, part in pairs(instance.parts or {}) do
            if alive(part.body) then bodies[#bodies + 1] = part.body end
        end
        return { kind = 'mipo', bodies = bodies, instance = instance, thing = thing }
    end
    return { kind = 'thing', bodies = { thing.body }, thing = thing }
end

local function selectCopies(copies)
    local sel = state.selection
    if #copies == 1 then
        sel.selectedObj, sel.selectedBodies = copies[1], nil
    elseif #copies > 1 then
        sel.selectedObj, sel.selectedBodies = nil, copies
    end
end

local function clearSelection()
    local sel = state.selection
    sel.selectedObj, sel.selectedBodies, sel.selectedJoint, sel.selectedSFixture = nil, nil, nil, nil
end

-- the buttons for this selection: { label, run }
local function buttonsFor(t)
    local list = {}
    if t.kind == 'mipo' then
        list[#list + 1] = { 'dice', function()
            local mipoBreeds = require('src.mipo-breeds')
            mipoBreeds.remember(t.instance) -- undo: the Mipo panel's undo goes back a step
            require('src.character-manager').randomizeMipo(t.instance)
            require('src.mipo-voice').dice(t.instance)
        end }
    end
    list[#list + 1] = { 'copy', function()
        -- a Mipo part brings its whole Mipo along (library.clone); select the copy's same part
        local copies = library.clone(t.things or { t.thing })
        if t.kind == 'mipo' then
            local _, partName = mipoRegistry.getFromBody(t.thing.body)
            for _, copy in ipairs(copies) do
                local _, name = mipoRegistry.getFromBody(copy.body)
                if name == partName then copies = { copy } break end
            end
        end
        selectCopies(copies)
    end }
    if t.kind == 'mipo' then
        list[#list + 1] = { 'flip', function()
            local facing = t.instance.dna.facing
            require('src.character-manager').switchFacing(t.instance, facing == 'left' and 'right' or 'left')
        end }
    elseif t.kind == 'thing' and #fixtures.sfixtureData(t.thing.body, subtypes.SOFTBODY) == 0 then
        list[#list + 1] = { 'flip', function()
            state.selection.selectedObj = objectManager.flipThing(t.thing, 'x', true)
        end }
    end
    list[#list + 1] = { 'delete', function()
        if t.kind == 'mipo' then
            require('src.character-manager').removeCharacter(t.instance)
        else
            for _, body in ipairs(t.bodies) do
                if alive(body) then
                    snap.destroySnapJointAboutBody(body)
                    objectManager.destroyBody(body)
                end
            end
        end
        clearSelection()
    end }
    list[#list + 1] = { '•••', function() state.rightColumn.tab = 'properties' end }
    return list
end

local function buttonWidth(label)
    return math.max(BUTTON_H, ui.font:getWidth(label) + 16)
end

-- each frame, in the editor's UI pass (src/playtime-ui.lua)
function lib.draw()
    if not state.selectionBar then return end -- off for now, see the top
    if modes.get() ~= nil then return end -- a tool is busy with the stage
    local t = target()
    if not t or #t.bodies == 0 then return end
    local minX, minY, maxX, maxY = boundsOf(t.bodies)
    if not minX then return end
    local buttons = buttonsFor(t)

    local w = PAD
    for _, b in ipairs(buttons) do w = w + buttonWidth(b[1]) + GAP end
    w = w - GAP + PAD
    local h = BUTTON_H + 2 * PAD

    -- under the selection, centred; above it when there's no room below; always on the screen
    local sw, sh = ui.getDimensions()
    local left, top = ui.toUI(cam:getScreenCoordinates(minX, minY))
    local right, bottom = ui.toUI(cam:getScreenCoordinates(maxX, maxY))
    local x = (left + right) / 2 - w / 2
    local y = bottom + BELOW
    if y + h > sh - 12 then y = top - KNOB_ROOM - h end
    x = math.max(100, math.min(sw - w - 12, x)) -- clear of the tool rail on the left
    y = math.max(12, math.min(sh - h - 12, y))

    local pressed
    ui.panel(x, y, w, h, nil, function()
        local bx = x + PAD
        for _, b in ipairs(buttons) do
            local bw = buttonWidth(b[1])
            if ui.button(bx, y + PAD, bw, b[1], BUTTON_H) then pressed = b[2] end
            bx = bx + bw + GAP
        end
    end)
    if pressed then pressed() end -- after the panel: a delete or copy changes what's drawn
end

return lib
