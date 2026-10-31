-- Bent pictures (spine torsos, ears) laid in C (native/desound/grid.c via spineSkin.bentGridC)
-- come out where Lua's deform puts them (spineSkin.deform, earBend.deform): drawGrid draws
-- whichever is there.
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneLoader = require('src.scene-loader')
local spineSkin = require('src.spine-skin')
local earBend = require('src.ear-bend')
local subtypes = require('src.subtypes')

-- drawGrid's rest grid: bilinear over the picture's corners, row by row
local function restGrid(corners)
    local cols, rows = spineSkin.columns, spineSkin.rows
    local x1, y1, x2, y2, x3, y3, x4, y4 = unpack(corners)
    local rest = {}
    for r = 0, rows do
        local v = r / rows
        for c = 0, cols do
            local u = c / cols
            local tx, ty = x1 + (x2 - x1) * u, y1 + (y2 - y1) * u
            local bx, by = x4 + (x3 - x4) * u, y4 + (y3 - y4) * u
            rest[#rest + 1], rest[#rest + 2] = tx + (bx - tx) * v, ty + (by - ty) * v
        end
    end
    return rest
end

describe('grid-native', function()
    it('bends spine torsos and ears where Lua does', function()
        if not spineSkin.bentGridC({ 0, 0, 1, 0, 1, 1, 0, 1 }, { bodies = {}, middles = {} }) then
            pending('no native library (native/desound/build.sh)')
            return
        end
        love.math.setRandomSeed(1)
        math.randomseed(1)
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        registry.reset()
        mipoRegistry.reset()
        sceneLoader.loadScriptAndScene('spine-test')
        local world = state.physicsWorld
        for _ = 1, 60 do world:update(1 / 84) end -- let the spines and ears bend a little

        local seen = { spine = 0, ear = 0 }
        for _, fixture in pairs(registry.sfixtures) do
            local ud = fixture:getUserData()
            local corners = ud and ud.extra and ud.extra.vertices
            if subtypes.is(ud, subtypes.TEXFIXTURE) and corners and #corners == 8 then
                local body = fixture:getBody()
                local bones = spineSkin.bonesOf(body) or earBend.bonesOf(body, corners)
                if bones then
                    local kind = bones.ear and 'ear' or 'spine'
                    seen[kind] = seen[kind] + 1
                    local lua = (bones.deform or spineSkin.deform)(restGrid(corners), bones, {})
                    local c = spineSkin.bentGridC(corners, bones)
                    assert.are.equal(#lua, #c)
                    for i = 1, #lua do
                        assert.is_true(math.abs(lua[i] - c[i]) < 1e-2,
                            kind .. ' point ' .. i .. ': ' .. lua[i] .. ' vs ' .. c[i])
                    end
                end
            end
        end
        assert.is_true(seen.spine > 0, 'no spine torso in the spine-test room')
        assert.is_true(seen.ear > 0, 'no ear in the spine-test room')
        world:destroy()
    end)
end)
