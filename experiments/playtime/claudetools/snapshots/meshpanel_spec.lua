-- Snapshot: the MESHUSERT panel (src/ui/meshusert-panel.lua lib.draw) on the hoop scene's mesh in
-- 11 states (unbound, weights, spine, spine multi, the triangle painter in bones / groups, with
-- triangles selected, hovering a bone or group, splits to clear, transforms shown): every ui call
-- and line drawn, then every button / slider "clicked" once in turn on a fresh load, with what that
-- changed (the mesh's extra, the RESOURCE's triangles and groups, splits, the painter's state, the
-- mode). claudetools/snapshot.sh. Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local ui = require('src.ui.all')
local modes = require('src.modes')
local utils = require('src.utils')
local resourceLink = require('src.resource-link')
local meshusertBind = require('src.meshusert-bind')
local panel = require('src.ui.meshusert-panel')

local function num(v) return string.format('%.3f', v) end

local function dump(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == 'number' then return num(v) end
    if t == 'string' then return string.format('%q', v) end
    if t == 'boolean' or t == 'nil' then return tostring(v) end
    if t ~= 'table' then return '<' .. t .. '>' end
    if depth > 3 then return '<deep>' end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. dump(v[k], depth + 1) end
    return '{' .. table.concat(parts, ',') .. '}'
end

-- the influences as a count and a weight sum per bone (they hold bodies)
local function influencesSummary(list)
    if not list then return 'nil' end
    local perBone = {}
    for _, vert in ipairs(list) do
        for _, infl in ipairs(vert) do perBone[infl.nodeIndex] = (perBone[infl.nodeIndex] or 0) + infl.w end
    end
    return #list .. ' ' .. dump(perBone)
end

local function load()
    registry.reset()
    local world = love.physics.newWorld(0, 0, true)
    state.physicsWorld = world
    sceneIO.load(love.filesystem.read('scripts/tech/hoop.playtime.json'), world, camera.getInstance())
    local mesh
    for _, fixture in pairs(registry.sfixtures) do
        if fixture:getUserData().subtype == 'meshusert' then mesh = fixture end
    end
    state.selection.selectedSFixture = mesh
    modes.clear()
    state.triangleEditor = { selectedTriangles = {}, selectedGroup = 1, selectedBone = 1, brushSize = 20 }
    return world, mesh
end

local function painter(paintMode, extra)
    return function(ud, body)
        modes.set(modes.EDIT_MESH_TRIS)
        state.triangleEditor.paintMode = paintMode
        for k, v in pairs(extra or {}) do state.triangleEditor[k] = v end
        if extra and extra.bind then meshusertBind.bindInfluences(ud, body) end
    end
end

-- the panel's rows start at y 0, 30 apart: with triangles selected the bone buttons are on y 420
-- (the mouse on bone 1), the group buttons on y 450 (the mouse on group 2)
local STATES = {
    { 'unbound', function(ud) meshusertBind.unbind(ud.extra) end },
    { 'weights', function(ud, body) meshusertBind.bindInfluences(ud, body) end },
    { 'spine', function(ud, body) meshusertBind.bindSpine(ud, body, false) end },
    { 'spine multi', function(ud, body) meshusertBind.bindSpine(ud, body, true) end },
    { 'painter bones', painter('bones') },
    { 'painter bones, bound, selected, hover', painter('bones',
        { bind = true, selectedTriangles = { 1, 2, 5 }, selectedBone = 2, mouse = { 20, 430 } }) },
    { 'painter groups', painter('groups', { selectedGroup = 1 }) },
    { 'painter groups, selected, hover', painter('groups',
        { selectedTriangles = { 3, 4 }, selectedGroup = 3, mouse = { 45, 460 } }) },
    { 'painter, splits', function(ud, body)
        painter('bones', { bind = true })(ud, body)
        local rv = resourceLink.find(ud)
        utils.thingOf(rv:getBody()).extraSteiner = { 1, 2, 3, 4 }
    end },
    { 'painter no mode yet', function()
        modes.set(modes.EDIT_MESH_TRIS)
    end },
    { 'weights, transforms shown', function(ud, body)
        meshusertBind.bindInfluences(ud, body)
        panel._test.showTransformSliders[ud.id] = true
    end },
}

describe('meshusert panel snapshot', function()
    it('records the panel', function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        local lines, log = {}, nil
        local forceAt, interactive = nil, 0
        local wrapped = {}
        local function logCall(name, args)
            if not log then return end
            local shown = {}
            for i, a in ipairs(args) do shown[i] = type(a) == 'function' and 'fn' or a end
            log[#log + 1] = name .. dump(shown)
        end
        for _, name in ipairs({ 'alignedLabel', 'label' }) do
            local f = ui[name]
            wrapped[name] = f
            ui[name] = function(...) logCall(name, { ... }); return f(...) end
        end
        for _, name in ipairs({ 'button', 'sliderWithInput', 'createSliderWithId' }) do
            local f = ui[name]
            wrapped[name] = f
            ui[name] = function(...)
                local args = { ... }
                logCall(name, args)
                interactive = interactive + 1
                if forceAt and interactive == forceAt then
                    if name == 'button' then return true end
                    if name == 'sliderWithInput' then return (args[5] + args[6]) / 2 end
                    args[9]((args[6] + args[7]) / 2) -- createSliderWithId: id, label, x, y, w, min, max, value, cb
                    return
                end
                local r1, r2 = f(...)
                if name == 'sliderWithInput' then return nil end -- no drags in a spec
                return r1, r2
            end
        end
        local line, circle = love.graphics.line, love.graphics.circle
        love.graphics.line = function(...) if log then log[#log + 1] = 'line' .. dump({ ... }) end return line(...) end
        love.graphics.circle = function(...) if log then log[#log + 1] = 'circle' .. dump({ ... }) end return circle(...) end

        local canvas = love.graphics.newCanvas(1200, 768)
        local function drawPanel(setup)
            local world, mesh = load()
            local ud, body = mesh:getUserData(), mesh:getBody()
            setup(ud, body)
            local mouse = state.triangleEditor.mouse or { 0, 0 }
            state.triangleEditor.mouse = nil
            love.graphics.setCanvas({ canvas, stencil = true })
            ui.startFrame()
            ui.mouseX, ui.mouseY = mouse[1], mouse[2]
            local y = 0
            local ok, err = pcall(panel.draw, ud, 'm', 10, y, function() y = y + 30; return 10, y end)
            love.graphics.setCanvas()
            love.graphics.present()
            local rv = resourceLink.find(ud)
            local rextra = rv and rv:getUserData().extra
            local after = 'mode=' .. tostring(modes.get())
                .. ' painter=' .. dump(state.triangleEditor)
                .. ' nodes=' .. tostring(ud.extra.nodes and #ud.extra.nodes)
                .. ' bindRadius=' .. dump(ud.extra.bindRadius) .. ' bindFalloff=' .. dump(ud.extra.bindFalloff)
                .. ' influences=' .. influencesSummary(ud.extra.influences)
                .. ' spineBind=' .. tostring(ud.extra.spineBind ~= nil)
                .. ' multi=' .. tostring(ud.extra.spineBind and ud.extra.spineBind.multi)
                .. ' bendiness=' .. dump(ud.extra.spineBendiness)
                .. ' triangleBones=' .. dump(ud.extra.triangleBones)
                .. ' mesh=' .. dump({ ud.extra.meshX, ud.extra.meshY, ud.extra.scaleX, ud.extra.scaleY,
                    ud.extra.meshRot, ud.extra.zOffset })
                .. ' shown=' .. tostring(panel._test.showTransformSliders[ud.id])
                .. ' groups=' .. dump(rextra and rextra.triangleGroups) .. ' dirty=' .. tostring(rextra and rextra.triangleOrderDirty)
                .. ' triangles=' .. tostring(rextra and rextra.triangles and #rextra.triangles)
                .. ' splits=' .. dump(rv and utils.thingOf(rv:getBody()).extraSteiner)
            panel._test.showTransformSliders[ud.id] = nil
            modes.clear()
            world:destroy()
            return ok, err, after
        end

        for _, st in ipairs(STATES) do
            log, interactive, forceAt = {}, 0, nil
            local ok, err, after = drawPanel(st[2])
            lines[#lines + 1] = '## ' .. st[1] .. ' ' .. tostring(ok) .. ' ' .. tostring(err)
            for _, l in ipairs(log) do lines[#lines + 1] = l end
            lines[#lines + 1] = 'state ' .. after
            local total = interactive
            log = nil
            for k = 1, total do
                interactive, forceAt = 0, k
                local ok2, err2, after2 = drawPanel(st[2])
                forceAt = nil
                lines[#lines + 1] = '# click ' .. k .. ' ' .. tostring(ok2) .. ' ' .. tostring(err2) .. ' ' .. after2
            end
        end
        canvas:release()
        love.graphics.line, love.graphics.circle = line, circle
        for name, f in pairs(wrapped) do ui[name] = f end
        state.selection.selectedSFixture = nil
        state.triangleEditor = { selectedTriangles = {}, selectedGroup = 1, selectedBone = 1, brushSize = 20 }
        state.physicsWorld = nil
        registry.reset()
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
