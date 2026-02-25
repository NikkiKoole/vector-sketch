-- subtypes.lua — sfixture subtype constants and helpers
local lib = {}

lib.SNAP              = 'snap'
lib.ANCHOR            = 'anchor'
lib.TEXFIXTURE        = 'texfixture'
lib.CONNECTED_TEXTURE = 'connected-texture'
lib.TRACE_VERTICES    = 'trace-vertices'
lib.TILE_REPEAT       = 'tile-repeat'
lib.RESOURCE          = 'resource'
lib.UVUSERT           = 'uvusert'
lib.MESHUSERT         = 'meshusert'

-- All known subtypes (current era) — used by migration
lib.ALL = {
    [lib.SNAP]              = true,
    [lib.ANCHOR]            = true,
    [lib.TEXFIXTURE]        = true,
    [lib.CONNECTED_TEXTURE] = true,
    [lib.TRACE_VERTICES]    = true,
    [lib.TILE_REPEAT]       = true,
    [lib.RESOURCE]          = true,
    [lib.UVUSERT]           = true,
    [lib.MESHUSERT]         = true,
}

--- Check whether a fixture userData has a given subtype.
-- @param ud  table  fixture:getUserData()
-- @param subtype  string  one of the constants above
-- @return boolean
function lib.is(ud, subtype)
    return ud ~= nil and ud.subtype == subtype
end

--- Migrate a fixture's userData from old/middle era to current era.
-- Mutates ud in-place. Call once per sfixture at load time.
-- Returns ud for convenience.
function lib.migrate(ud)
    if not ud then return ud end

    -- 1) Sanitize existing subtype (strip trailing whitespace/control chars)
    if ud.subtype then
        ud.subtype = ud.subtype:gsub("[%c%s]+$", "")
    end

    -- 2) Middle era: extra.type → subtype
    if ud.extra and ud.extra.type and lib.ALL[ud.extra.type] then
        if not ud.subtype or ud.subtype == '' then
            ud.subtype = ud.extra.type
        end
        ud.extra.type = nil
    end

    -- 3) Old era: label is a known subtype name → move to subtype
    if ud.label and ud.label ~= '' then
        local sanitized = ud.label:gsub("[%c%s]+$", "")
        if lib.ALL[sanitized] then
            if not ud.subtype or ud.subtype == '' then
                ud.subtype = sanitized
            end
            ud.label = ''
        end
    end

    -- 4) Dead subtype rename: uvmappert → uvusert
    if ud.subtype == 'uvmappert' then
        ud.subtype = lib.UVUSERT
    end

    return ud
end

return lib
