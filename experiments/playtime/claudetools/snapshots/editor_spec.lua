-- Snapshot: the Mipo editor with every accordion open, for 9 parts (potato head and not): every
-- ui call and rectangle drawn, then every button / checkbox / slider "clicked" once in turn, with
-- the Mipo's DNA after each (~20 s). claudetools/snapshot.sh. Runs only when $SNAPSHOT_OUT is set.
if not love then return end
local out = os.getenv('SNAPSHOT_OUT')
if not out or out == '' then return end

local state = require('src.state')
local registry = require('src.registry')
local ui = require('src.ui.all')
local CM = require('src.character-manager')
local mipoEditor = require('src.ui.mipo-editor')

local function dump(v, seen, depth)
    local t = type(v)
    if t == 'number' then return string.format('%.3f', v) end
    if t == 'string' then return string.format('%q', v) end
    if t == 'boolean' or t == 'nil' then return tostring(v) end
    if t ~= 'table' then return '<' .. t .. '>' end
    if seen[v] or depth > 6 then return '<seen>' end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do if k ~= 'id' and k ~= 'mipoId' then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. '=' .. dump(v[k], seen, depth + 1) end
    seen[v] = nil
    return '{' .. table.concat(parts, ',') .. '}'
end

describe('editor snapshot', function()
    it('records the editor', function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        local lines = {}
        local log
        local forceAt, interactive = nil, 0
        local wrapped = {}
        for _, name in ipairs({ 'alignedLabel', 'label', 'header_button', 'textinput', 'slider' }) do
            local f = ui[name]
            wrapped[name] = f
            ui[name] = function(...)
                if log then
                    local args = { ... }
                    for i, a in ipairs(args) do args[i] = type(a) == 'function' and 'fn' or a end
                    log[#log + 1] = name .. dump(args, {}, 0)
                end
                return f(...)
            end
        end
        for _, name in ipairs({ 'button', 'checkbox', 'sliderWithInput' }) do
            local f = ui[name]
            wrapped[name] = f
            ui[name] = function(...)
                local args = { ... }
                if log then
                    local shown = {}
                    for i, a in ipairs(args) do shown[i] = type(a) == 'function' and 'fn' or a end
                    log[#log + 1] = name .. dump(shown, {}, 0)
                end
                interactive = interactive + 1
                if forceAt and interactive == forceAt then
                    if name == 'button' then return true end
                    if name == 'checkbox' then return true, not args[3] end
                    local min, max = args[5], args[6]
                    return (min + max) / 2
                end
                local r1, r2 = f(...)
                if name == 'sliderWithInput' then return nil end -- no drags in a spec
                return r1, r2
            end
        end
        local rect = love.graphics.rectangle
        love.graphics.rectangle = function(...)
            if log then log[#log + 1] = 'rect' .. dump({ ... }, {}, 0) end
            return rect(...)
        end

        local states = mipoEditor._test.accordionStates
        local saved = {}
        for k, v in pairs(states) do saved[k] = v end
        setmetatable(states, { __index = function() return true end })

        local canvas = love.graphics.newCanvas(1200, 768)
        for _, potato in ipairs({ false, true }) do
            for _, part in ipairs({ 'head', 'torso1', 'torso2', 'luarm', 'llarm', 'lhand', 'luleg', 'lfoot', 'lear' }) do
                local world = love.physics.newWorld(0, 0, true)
                state.physicsWorld = world
                registry.reset()
                require('src.mipo-registry').reset()
                math.randomseed(7); love.math.setRandomSeed(7)
                local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
                if potato then CM.rebuildFromCreation(instance, { isPotatoHead = true, torsoSegments = 2 }) end
                if instance.dna.parts[part] then
                    love.graphics.setCanvas({ canvas, stencil = true })
                    ui.startFrame()
                    log, interactive = {}, 0
                    local ok, err = pcall(mipoEditor.drawMipoEditor, instance, part, 800, 0, 380, 768)
                    lines[#lines + 1] = '## draw ' .. tostring(potato) .. ' ' .. part .. ' ' .. tostring(ok) .. ' ' .. tostring(err)
                    for _, l in ipairs(log) do lines[#lines + 1] = l end
                    local total = interactive
                    log = nil
                    for k = 1, total do
                        ui.startFrame()
                        interactive, forceAt = 0, k
                        local ok2, err2 = pcall(mipoEditor.drawMipoEditor, instance, part, 800, 0, 380, 768)
                        forceAt = nil
                        lines[#lines + 1] = '# click ' .. part .. ' ' .. k .. ' ' .. tostring(ok2) .. ' ' .. tostring(err2)
                            .. ' ' .. dump(instance.dna, {}, 0)
                    end
                    love.graphics.setCanvas()
                end
                for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
                world:setCallbacks()
                world:destroy()
            end
        end
        canvas:release()
        love.graphics.rectangle = rect
        for name, f in pairs(wrapped) do ui[name] = f end
        setmetatable(states, nil)
        for k in pairs(states) do states[k] = nil end
        for k, v in pairs(saved) do states[k] = v end
        local f = assert(io.open(out, 'w'))
        f:write(table.concat(lines, '\n'), '\n')
        f:close()
    end)
end)
