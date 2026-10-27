-- resource-link.lua
-- MESHUSERT and UVUSERT sfixtures draw with the mesh (vertices, UVs, triangles)
-- of a RESOURCE sfixture, the "mappert". They used to find it by equal sfixture
-- label, so a copy found the original's RESOURCE as easily as its own. Now
-- `extra.resourceId` links them: an sfixture id, renewed on clone and library
-- place like every id. Label match stays as the fallback for scenes saved
-- before the link, and fills in the link the first time.
--
-- The RESOURCE's picture is `extra.imageURL`, its own. A backdrop is only the
-- tracing aid while UVs are made (src/cdt.lua computeResourceMesh needs its
-- world rect); after that the mesh draws without it, so prefabs and clones
-- carry their texture and the backdrop can move or go.
local lib = {}

local registry = require('src.registry')
local subtypes = require('src.subtypes')
local state = require('src.state')

-- The image file a RESOURCE userData draws with, or nil. Scenes from before
-- imageURL fall back to the backdrop URL saved next to the index, then to the
-- backdrop at that index, and keep the answer.
function lib.imageURL(ud)
    local extra = ud and ud.extra
    if not extra then return nil end
    if not extra.imageURL then
        local bd = extra.selectedBGIndex and state.backdrops and state.backdrops[extra.selectedBGIndex]
        extra.imageURL = extra.selectedBGURL or (bd and bd.url)
    end
    return extra.imageURL
end

-- The backdrop a RESOURCE traces its UVs from: the one showing its image, at
-- any index. nil when it isn't on stage; never another picture's backdrop,
-- which would remap the UVs onto the wrong image. (Only a RESOURCE with no
-- image at all falls back to its stored index.)
function lib.backdrop(ud)
    local extra = ud and ud.extra
    if not extra or not state.backdrops then return nil end
    local url = lib.imageURL(ud)
    if not url then return extra.selectedBGIndex and state.backdrops[extra.selectedBGIndex] end
    for i, bd in ipairs(state.backdrops) do
        if bd.url == url then
            extra.selectedBGIndex = i
            return bd
        end
    end
    return nil
end

local function byLabel(label, fixtures)
    for _, v in pairs(fixtures) do
        if not v:isDestroyed() then
            local vud = v:getUserData()
            if type(vud) == 'table' and vud.label == label and subtypes.is(vud, subtypes.RESOURCE) then
                return v
            end
        end
    end
end

function lib.isUser(ud)
    return type(ud) == 'table' and (subtypes.is(ud, subtypes.MESHUSERT) or subtypes.is(ud, subtypes.UVUSERT))
end

-- The RESOURCE fixture this MESHUSERT/UVUSERT userData draws with, or nil.
-- preferAmong: fixtures to search first when falling back to the label (a
-- freshly placed prefab prefers its own RESOURCE over the original's).
function lib.find(ud, preferAmong)
    local extra = ud.extra
    local linked = extra and extra.resourceId and registry.getSFixtureByID(extra.resourceId)
    if linked and not linked:isDestroyed() then return linked end
    if not ud.label or #ud.label == 0 then return nil end
    local found = (preferAmong and byLabel(ud.label, preferAmong)) or byLabel(ud.label, registry.sfixtures)
    if found and extra then extra.resourceId = found:getUserData().id end
    return found
end

-- Fill in the link for every MESHUSERT/UVUSERT on these bodies, so a copy
-- made next carries it (and doesn't fall back to an ambiguous label).
function lib.linkBodies(bodies)
    for _, body in ipairs(bodies) do
        if not body:isDestroyed() then
            for _, fixture in ipairs(body:getFixtures()) do
                local ud = fixture:getUserData()
                if lib.isUser(ud) then lib.find(ud) end
            end
        end
    end
end

return lib
