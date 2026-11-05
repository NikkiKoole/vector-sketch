-- Snapshot: skinning.meshusertVertices on the hoop scene's MESHUSERT (the one scene with a bound
-- mesh) in every way it can be set up: no bind, bone weights (DQS), painted bones over them, a
-- spine bind (one chain, several), triangle groups to re-order, no stored triangles, no UVs,
-- moved / scaled / turned, selected, a bind left stale by a changed polygon. Each in three poses
-- of its bones; every number it returns and what it changes on extra / data. claudetools/snapshot.sh.
-- Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local meshusertBind = require('src.meshusert-bind')
local resourceLink = require('src.resource-link')
local skinning = require('src.render.skinning')

local function num(v) return string.format('%.4f', v) end

local function flat(t, depth)
    depth = depth or 0
    if type(t) == 'number' then return num(t) end
    if type(t) ~= 'table' then return tostring(t) end
    if depth > 3 then return '<deep>' end
    local parts = {}
    for i = 1, #t do parts[i] = flat(t[i], depth + 1) end
    return '{' .. table.concat(parts, ',') .. '}'
end

-- the node bodies' indices in extra.nodes, for painting triangles with bones
local function boneIndices(extra)
    local list = {}
    for i, node in ipairs(extra.nodes or {}) do
        if node.type then list[#list + 1] = i end
    end
    return list
end

local CASES = {
    { 'none', function(ud) meshusertBind.unbind(ud.extra) end },
    { 'dqs', function(ud, body) meshusertBind.bindInfluences(ud, body) end },
    { 'dqs+painted', function(ud, body, data)
        meshusertBind.bindInfluences(ud, body)
        local bones = boneIndices(ud.extra)
        ud.extra.triangleBones = {}
        for t = 1, math.floor(#(data.triangles or {}) / 3) do
            if t % 4 ~= 0 then ud.extra.triangleBones[t] = bones[(t % #bones) + 1] end
        end
    end },
    { 'dqs+painted, no rigidLookup', function(ud, body, data)
        meshusertBind.bindInfluences(ud, body)
        local bones = boneIndices(ud.extra)
        ud.extra.rigidLookup = nil
        ud.extra.triangleBones = {}
        for t = 1, math.floor(#(data.triangles or {}) / 3) do ud.extra.triangleBones[t] = bones[(t % #bones) + 1] end
    end },
    { 'spine', function(ud, body) meshusertBind.bindSpine(ud, body, false) end },
    { 'spine multi', function(ud, body) meshusertBind.bindSpine(ud, body, true) end },
    { 'groups', function(ud, body, data)
        meshusertBind.bindInfluences(ud, body)
        local bones = boneIndices(ud.extra)
        data.triangleGroups, ud.extra.triangleBones = {}, {}
        for t = 1, math.floor(#(data.triangles or {}) / 3) do
            data.triangleGroups[t] = (t * 7) % 3
            ud.extra.triangleBones[t] = bones[(t % #bones) + 1]
        end
        data.triangleOrderDirty = true
    end },
    { 'groups, no bones', function(ud, _, data)
        meshusertBind.unbind(ud.extra)
        data.triangleGroups = {}
        for t = 1, math.floor(#(data.triangles or {}) / 3) do data.triangleGroups[t] = (t * 5) % 4 end
        data.triangleOrderDirty = true
    end },
    { 'no triangles', function(ud, body, data)
        meshusertBind.bindInfluences(ud, body)
        data.triangles = nil
    end },
    { 'no triangles, no uvs', function(ud, _, data)
        meshusertBind.unbind(ud.extra)
        data.triangles, data.uvs = nil, nil
    end },
    { 'no uvs', function(ud, body, data)
        meshusertBind.bindInfluences(ud, body)
        data.uvs = nil
    end },
    { 'moved scaled turned', function(ud, body)
        meshusertBind.bindInfluences(ud, body)
        ud.extra.meshX, ud.extra.meshY, ud.extra.scaleX, ud.extra.scaleY, ud.extra.meshRot = 12, -7, 1.3, 0.8, 0.4
    end },
    { 'selected', function(ud, body, _, flags)
        meshusertBind.bindInfluences(ud, body)
        flags.selected = true
    end },
    { 'stale weights', function(ud, body)
        meshusertBind.bindInfluences(ud, body)
        table.remove(ud.extra.influences)
    end },
    { 'stale spine', function(ud, body)
        meshusertBind.bindSpine(ud, body, false)
        local sb = ud.extra.spineBind
        if sb and sb.tsPerVert then sb.tsPerVert[#sb.tsPerVert + 1] = 0; sb.tsPerVert[#sb.tsPerVert + 1] = 0 end
        if sb and sb.perVert then sb.perVert[#sb.perVert + 1] = sb.perVert[1] end
    end },
}

-- rest, then the bones bent, then bent further and the whole lot moved
local function pose(world, meshBody, k)
    if k == 1 then return end
    for i, body in ipairs(world:getBodies()) do
        if body ~= meshBody then
            body:setAngle(body:getAngle() + 0.15 * (k - 1) * ((i % 3) - 1))
            if k == 3 then body:setPosition(body:getX() + 5 * i, body:getY() - 3 * i) end
        end
    end
end

describe('skinning snapshot', function()
    it('records meshusertVertices', function()
        local lines = {}
        for _, case in ipairs(CASES) do
            for k = 1, 3 do
                registry.reset()
                local world = love.physics.newWorld(0, 0, true)
                state.physicsWorld = world
                sceneIO.load(love.filesystem.read('scripts/tech/hoop.playtime.json'), world, camera.getInstance())
                local mesh
                for _, fixture in pairs(registry.sfixtures) do
                    if fixture:getUserData().subtype == 'meshusert' then mesh = fixture end
                end
                local ud, body = mesh:getUserData(), mesh:getBody()
                local mappert = resourceLink.find(ud)
                local data = mappert:getUserData().extra
                local verts = data.meshVertices or mappert:getBody():getUserData().thing.vertices
                local flags = {}
                local ok, err = pcall(case[2], ud, body, data, flags)
                pose(world, body, k)
                local ok2, format, meshVertices, outVerts, triIdx, tris = pcall(skinning.meshusertVertices,
                    ud.extra, body, data, verts, flags.selected or false)
                lines[#lines + 1] = string.format('## %s pose %d setup %s %s run %s', case[1], k, tostring(ok),
                    tostring(err), tostring(ok2))
                if ok2 then
                    local names = {}
                    for i, f in ipairs(format) do names[i] = f[1] end
                    lines[#lines + 1] = 'format ' .. table.concat(names, ',')
                    lines[#lines + 1] = 'vertices ' .. #meshVertices
                    for i, v in ipairs(meshVertices) do lines[#lines + 1] = i .. ' ' .. flat(v) end
                    lines[#lines + 1] = 'verts ' .. flat(outVerts)
                    lines[#lines + 1] = 'triIdx ' .. flat(triIdx)
                    lines[#lines + 1] = 'tris ' .. flat(tris)
                    lines[#lines + 1] = 'after influences=' .. tostring(ud.extra.influences and #ud.extra.influences)
                        .. ' spineBind=' .. tostring(ud.extra.spineBind ~= nil)
                        .. ' triangleBones=' .. flat(ud.extra.triangleBones)
                        .. ' groups=' .. flat(data.triangleGroups) .. ' dirty=' .. tostring(data.triangleOrderDirty)
                        .. ' triangles=' .. flat(data.triangles)
                else
                    lines[#lines + 1] = 'error ' .. tostring(format)
                end
                world:destroy()
            end
        end
        state.physicsWorld = nil
        registry.reset()
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
