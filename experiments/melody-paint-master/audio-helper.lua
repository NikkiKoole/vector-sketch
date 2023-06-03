
local lib = {}

local scales     = {
    { name = 'koalaMinor',   notes = { 0, 2, 3, 5, 7, 8, 11 } },
    { name = 'koalaHexa',    notes = { 0, 3, 4, 7, 8, 11 } },
    { name = 'minorBlues',   notes = { 0, 3, 5, 6, 7, 10, 11 } },
    { name = 'naturalMinor', notes = { 0, 2, 3, 5, 7, 8, 10, 11 } },
    { name = 'whole',        notes = { 0, 2, 4, 6, 8, 10 } },
    { name = 'bebop',        notes = { 0, 2, 4, 5, 7, 9, 10, 11 } },
    { name = 'soundforest',  notes = { 0, 2, 5, 9, 11, 16 } },
    { name = 'koalaPenta',   notes = { 0, 3, 5, 7, 10, 11 } },
    { name = 'chromatic',    notes = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
    { name = 'pentaMinor ',  notes = { 0, 2, 3, 4, 6 } },
    { name = 'gypsy',        notes = { 0, 2, 3, 6, 7, 8, 10 } },
    { name = 'dorian',       notes = { 0, 2, 3, 5, 7, 9, 10 } },
    { name = 'augmented',    notes = { 0, 3, 4, 7, 8, 11 } },
    { name = 'tritone',      notes = { 0, 1, 4, 6, 7, 10 } },
    -- { name = 'debug',        notes = { 0, 11, 23, 35, 47 } },
}

lib.findScaleByName = function(name)
    for i = 1, #scales do
       if scales[i].name == name then
          return scales[i], i
       end
    end
    return nil, -1
 end

 lib.getNextScale = function(current) 
    local name, index =   lib.findScaleByName(current.name)
    local nextIndex = (index % #scales) + 1
    return scales[nextIndex]
end


--function gatherSamplesFromFiles(files) end



return lib