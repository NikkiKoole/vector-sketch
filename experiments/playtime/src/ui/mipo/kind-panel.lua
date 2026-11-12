-- src/ui/mipo/kind-panel.lua: the Mipo panel's rows about the whole Mipo and the way to its parts
-- (docs/KINDS.md: a kind's own things first, the same whichever part was clicked):
--   the head: breed, roll, undo, the actions, copy and delete;
--   the part row: step to the previous / next part, or pick one from the list of all of them;
--   the workshop (folded): what it's made of, dissolve.
local lib = {}

local state = require('src.state')
local utils = require('src.utils')
local CharacterManager = require('src.character-manager')
local mipoBreeds = require('src.mipo-breeds')
local mipoRegistry = require('src.mipo-registry')
local mipoActions = require('src.mipo-actions')
local mipoVoice = require('src.mipo-voice')
local library = require('src.library')
local widgets = require('src.ui.mipo.widgets')
local partMap = require('src.ui.mipo.part-map')
local facePanel = require('src.ui.mipo.face-panel')
local ui = widgets.ui
local accordionStates = widgets.accordionStates

local SMALL = 30 -- the step buttons' width

local function usable(p) return p.panelWidth - 40 end
local function half(p) return math.floor(usable(p) / 2) - 2 end

-- === BREED, ROLL, UNDO ===
-- 'any' and 'any *' are the plain and the constrained random Mipo; the rest are mipo-breeds' breeds
local function breedChoices()
    local list = { 'any', 'any *' }
    for _, name in ipairs(mipoBreeds.order) do list[#list + 1] = name end
    return list
end

local function stepChoice(list, current, delta)
    local at = 1
    for i, name in ipairs(list) do if name == current then at = i end end
    return list[(at - 1 + delta) % #list + 1]
end

local function roll(instance, breed)
    mipoBreeds.remember(instance) -- every roll keeps the Mipo from before it: undo goes back a step at a time
    if breed == 'any' then
        CharacterManager.randomizeMipo(instance)
    elseif breed == 'any *' then
        CharacterManager.randomizeMipoConstrained(instance)
    else
        mipoBreeds.randomize(instance, breed)
    end
    mipoVoice.dice(instance)
end

local function selectThing(thing)
    local sel = state.selection
    sel.selectedObj, sel.selectedBodies, sel.selectedJoint, sel.selectedSFixture = thing, nil, nil, nil
end

-- the whole Mipo: breed, roll, undo, what it can do, copy and delete
function lib.drawHead(p, y)
    local instance, x, ROW = p.instance, p.x, p.ROW
    local W, hw = usable(p), half(p)

    -- the title, with copy and delete: copy brings the whole Mipo along (library.clone), the copy's
    -- same part gets selected
    ui.label(x, y, 'mipo')
    local bw = math.floor(W / 3)
    local thing = state.selection.selectedObj
    if thing and ui.button(x + W - 2 * bw - 4, y, bw, 'copy') then
        for _, copy in ipairs(library.clone({ thing })) do
            local _, name = mipoRegistry.getFromBody(copy.body)
            if name == p.partName then selectThing(copy) break end
        end
    end
    if ui.button(x + W - bw, y, bw, 'delete') then
        CharacterManager.removeCharacter(instance)
        selectThing(nil)
        return y + ROW, true
    end
    y = y + ROW

    local choices = breedChoices()
    local breed = accordionStates.breed
    if type(breed) ~= 'string' then breed = 'any' end -- the editor snapshot opens every state with true
    if ui.button(x, y, SMALL, '<') then breed = stepChoice(choices, breed, -1) end
    if ui.button(x + SMALL + 4, y, W - 2 * SMALL - 8, breed) then breed = stepChoice(choices, breed, 1) end
    if ui.button(x + W - SMALL, y, SMALL, '>') then breed = stepChoice(choices, breed, 1) end
    accordionStates.breed = breed
    y = y + ROW
    local third = math.floor((W - 8) / 3)
    if ui.button(x, y, third, 'roll') then roll(instance, breed) end
    if ui.button(x + third + 4, y, third, 'mutate') then -- the sizes only
        mipoBreeds.remember(instance)
        CharacterManager.mutateSizes(instance)
        mipoVoice.dice(instance)
    end
    if mipoBreeds.canUndo(instance) and ui.button(x + 2 * (third + 4), y, third, 'undo') then
        mipoBreeds.undo(instance)
    end
    y = y + ROW

    -- what it can do: one-shot actions as buttons, on/off states as checkboxes, two per row
    if ui.button(x, y, hw, 'breathe') then mipoActions.breathe(instance) end
    local grounded = mipoActions.isGrounded(instance)
    if ui.button(x + hw + 4, y, hw, grounded and 'jump' or 'jump (air)') then mipoActions.jump(instance) end
    y = y + ROW
    if ui.checkbox(x, y, mipoActions.isRagdoll(instance), 'ragdoll') then
        mipoActions.setRagdoll(instance, not mipoActions.isRagdoll(instance))
    end
    if ui.checkbox(x + hw + 4, y, mipoActions.isFlipped(instance), 'flip') then
        mipoActions.setFlipped(instance, not mipoActions.isFlipped(instance))
    end
    y = y + ROW
    local isPointing = mipoActions.isPointing(instance)
    if ui.checkbox(x, y, isPointing, 'point') then
        if isPointing then mipoActions.stopPointing(instance) else mipoActions.pointAt(instance, 'cursor') end
    end
    if ui.button(x + hw + 4, y, hw, 'raspberry') then require('src.mipo-raspberry').blow(instance) end
    y = y + ROW

    return y
end

-- === THE PARTS ===
-- the order the part row steps through: head to feet, the left side before the right
local RANK = { 'head', 'neck', 'nose', 'torso', 'lobe', 'lear', 'rear',
    'luarm', 'llarm', 'lhand', 'ruarm', 'rlarm', 'rhand', 'luleg', 'llleg', 'lfoot', 'ruleg', 'rlleg', 'rfoot' }
local function rankOf(name)
    for i, prefix in ipairs(RANK) do
        if name:sub(1, #prefix) == prefix then return i end
    end
    return #RANK + 1
end

function lib.partNames(instance)
    local names = {}
    for name, part in pairs(instance.parts or {}) do
        if part.body and not part.body:isDestroyed() then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        local ra, rb = rankOf(a), rankOf(b)
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    return names
end

-- a faint part was picked (part-map's ghosts: the neck or nose of a Mipo without them as bodies): the
-- panel shows its settings while the same part stays selected (it has no body to select); any other pick
-- ends it. Returns 'neck', 'nose' or nil.
function lib.ghostView(p)
    local ghost = accordionStates.ghostPick
    if ghost == nil then return nil end
    if accordionStates.ghostFrom ~= (p.partName or '') then
        accordionStates.ghostPick, accordionStates.ghostFrom = nil, nil
        return nil
    end
    return ghost
end

local function selectPart(instance, name)
    accordionStates.ghostPick, accordionStates.ghostFrom = nil, nil
    local part = instance.parts[name]
    local thing = part and part.body and utils.thingOf(part.body)
    if thing then selectThing(thing) end
end

-- the part being edited: < name > steps through every part; under it, always, a skeleton to pick any part
-- on and a face to pick a feature on (part-map.lua): a feature selects the part with the face and opens
-- that feature's rows
function lib.drawPartRow(p, y)
    local instance, partName, x, ROW = p.instance, p.partName, p.x, p.ROW
    local W = usable(p)
    y = y + ui.theme.spacing
    love.graphics.line(x, y, x + W, y)
    y = y + ui.theme.spacing

    local names = lib.partNames(instance)
    if #names == 0 then return y end
    if ui.button(x, y, SMALL, '<') then selectPart(instance, stepChoice(names, partName, -1)) end
    local ghost = lib.ghostView(p)
    ui.button(x + SMALL + 4, y, W - 2 * SMALL - 8, ghost or partName or 'parts')
    if ui.button(x + W - SMALL, y, SMALL, '>') then selectPart(instance, stepChoice(names, partName, 1)) end
    y = y + ROW

    -- the skeleton on the left, the face on the right
    local hw = half(p)
    local picked, bodyH = partMap.drawBody('mipo_parts', x, y, hw, names, partName, { isLit = function(name)
        if ghost then return name == ghost end
        return name == partName
    end })
    if picked and not instance.parts[picked] then -- a ghost
        accordionStates.ghostPick, accordionStates.ghostFrom = picked, partName or ''
    elseif picked then
        selectPart(instance, picked)
    end

    -- the face's keys belong to the selected part when it carries the face, else to the face's own part
    local faceKeys = facePanel.featureKeys(instance, partName)
    local facePart = faceKeys and partName or (instance.dna.creation.isPotatoHead and 'torso1' or 'head')
    faceKeys = faceKeys or facePanel.featureKeys(instance, facePart)
    if faceKeys then
        local feature = partMap.drawFace('mipo_face', x + hw + 4, y, hw, faceKeys, function(name)
            return facePart == partName and widgets.isOpen(faceKeys.face) and widgets.isOpen(faceKeys[name])
        end)
        if feature then
            local wasOpen = facePart == partName and widgets.isOpen(faceKeys.face) and widgets.isOpen(faceKeys[feature])
            for _, name in ipairs({ 'brows', 'eyes', 'nose', 'mouth' }) do accordionStates[faceKeys[name]] = false end
            for _, key in ipairs(widgets.tabsOf(facePart)) do accordionStates[key] = false end -- one section open
            accordionStates[faceKeys.face] = true
            accordionStates[faceKeys[feature]] = not wasOpen
            if facePart ~= partName then selectPart(instance, facePart) end
        end
    end
    y = y + bodyH + ui.theme.spacing

    local symClicked, symChecked = ui.checkbox(x, y, accordionStates.symmetricEditing, 'symmetric')
    if symClicked then accordionStates.symmetricEditing = symChecked end
    y = y + ROW
    return y
end

-- the part's sections as a row of small buttons (the sections' keys noted on the frame before,
-- widgets.beginTabs), one open at a time; the open one orange
local function tabLabel(key)
    if key:find(' > ', 1, true) then return 'limb ' .. key:match('(%S+)$') end
    if key:match('connected skin$') then return 'limb skin' end
    if key:match('connected hair$') then return 'limb hair' end
    return key:match('(%S+)$')
end

function lib.drawTabs(p, y)
    local x, ROW = p.x, p.ROW
    local W = usable(p)
    local keys = widgets.tabsOf(p.partName)
    if #keys == 0 then return y end
    local font = love.graphics.getFont()
    local h = ui.theme.button.height
    local cx = x
    for _, key in ipairs(keys) do
        local label = tabLabel(key)
        local bw = font:getWidth(label) + 18
        if cx > x and cx + bw > x + W then
            cx, y = x, y + h + 4
        end
        local open = widgets.isOpen(key)
        if ui.button(cx, y, bw, label, h, open and ui.theme.header.active or nil) then
            for _, other in ipairs(keys) do accordionStates[other] = false end
            accordionStates[key] = not open
        end
        cx = cx + bw + 4
    end
    return y + ROW + ui.theme.spacing
end

-- the part's own randomize, at the end of its sections (a side part rolls both sides)
function lib.drawPartRandomize(p, y)
    local instance, partName, x, ROW = p.instance, p.partName, p.x, p.ROW
    if not partName then return y end
    local label = partName
    if partName == 'lear' or partName == 'rear' then label = 'ears'
    elseif partName == 'lfoot' or partName == 'rfoot' then label = 'feet'
    elseif partName == 'lhand' or partName == 'rhand' then label = 'hands'
    elseif partName:match('arm') then label = 'arms'
    elseif partName:match('leg') then label = 'legs'
    end
    if ui.button(x, y, usable(p), 'randomize ' .. label) then
        mipoBreeds.remember(instance)
        CharacterManager.randomizePart(instance, partName)
        mipoVoice.dice(instance)
    end
    return y + ROW
end

-- === THE WORKSHOP ===
-- folded at the bottom: what the Mipo is made of, and dissolve (its parts become plain bodies)
function lib.drawWorkshop(p, y)
    local instance, x, ROW = p.instance, p.x, p.ROW
    y = y + 4
    y = widgets.accordionHeader(p, y, 'workshop')
    if widgets.isOpen('workshop') then
        local partCount = 0
        for _ in pairs(instance.parts) do partCount = partCount + 1 end
        ui.label(x, y, 'parts: ' .. partCount .. '  scale: ' .. string.format('%.2f', instance.scale or 1))
        y = y + ROW
        if ui.button(x, y, half(p), 'dissolve') then
            for _, part in pairs(instance.parts) do
                if part and part.body and not part.body:isDestroyed() then
                    local thing = utils.thingOf(part.body)
                    if thing then
                        thing.mipoId = nil
                        thing.mipoPartName = nil
                    end
                end
            end
            mipoRegistry.unregister(instance.id)
        end
        y = y + ROW
    end
    return y
end

return lib
