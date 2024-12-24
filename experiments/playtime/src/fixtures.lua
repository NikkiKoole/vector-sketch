--fixtres.lua


local mathutils = require 'src.math-utils'

local lib = {}


function lib.hasFixturesWithUserDataAtBeginning(fixtures)
  -- first we will start looking from beginning untill we no longer find userdata on fixtures
  -- then we will start looking fom that index on and expect not to found any more userdata
    local found = true
    local index = 0
    for i =1, #fixtures do
        if found then
            if fixtures[i]:getUserData() then
                --print('expected')
                index = i
            else
                found = false
            end
        end
        if not found then
             if fixtures[i]:getUserData() then
                 --print('not ok!')
                 return false, -1
             else
                -- expected
             end
        end
    end
    return true, index
end
function lib.getCentroidOfFixture(body, fixture)
    return { mathutils.getCenterOfPoints({ fixture:getShape():getPoints() }) }
end

return lib
