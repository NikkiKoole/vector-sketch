-- kitchen: the water test room (docs/WATER.md). Cups on the table, a bath on the
-- floor, one Mipo. W1: the water stays level when you swing a cup around.
local s = {}

function s.onStart()
    worldState.paused = false
end

return s
