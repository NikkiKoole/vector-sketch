-- dollhouse: the doll-play test room (docs/DOLL-PLAY.md, foundation F1).
-- Every doll-play menu item gets tried here first.
local s = {}

function s.onStart()
    worldState.paused = false
end

return s
