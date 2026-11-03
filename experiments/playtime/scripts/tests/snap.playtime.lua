-- snap test scene: bodies labelled 'havesnap' get a snap point on their left and
-- right edge, so they click together end to end. The snapping itself is the
-- engine's (src/physics/snap.lua); this script only adds the points, once.
local s = {}

local function ensureSnapPoints()
    for _, it in ipairs(getObjectsByLabel('havesnap')) do
        if not snap.hasPoints(it.body) then
            it.body:setBullet(true)
            snap.addPoint(it.body, it.width / 2, 0)
            snap.addPoint(it.body, -it.width / 2, 0)
        end
    end
end

s.onStart = ensureSnapPoints
s.onSceneLoaded = ensureSnapPoints

return s
