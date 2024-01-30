
local lib = {}


connectorCooldownList = {}
connectors = {}

-- will need the lisyts connector and connetorcooldown lisyt
-- function to add connection , breka connection

lib.resetConnectors = function() 

    connectors = {}
    connectorCooldownList = {}
end

return lib