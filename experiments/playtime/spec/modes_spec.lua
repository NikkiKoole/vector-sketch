describe('modes', function()
    local modes

    before_each(function()
        -- Fresh state for each test
        package.loaded['src.modes'] = nil
        package.loaded['src.state'] = nil
        modes = require('src.modes')
    end)

    describe('constants', function()
        it('has 11 mode constants', function()
            local count = 0
            for k, v in pairs(modes) do
                if type(v) == 'string' and k == k:upper() then
                    count = count + 1
                end
            end
            assert.are.equal(11, count)
        end)

        it('has expected mode values', function()
            assert.are.equal('drawClickMode', modes.DRAW_CLICK)
            assert.are.equal('drawFreePath', modes.DRAW_FREE_PATH)
            assert.are.equal('drawFreePoly', modes.DRAW_FREE_POLY)
            assert.are.equal('pickAutoRopifyMode', modes.PICK_AUTO_ROPIFY)
            assert.are.equal('editMeshVertices', modes.EDIT_MESH_VERTS)
            assert.are.equal('jointCreationMode', modes.JOINT_CREATION)
            assert.are.equal('setOffsetA', modes.SET_OFFSET_A)
            assert.are.equal('setOffsetB', modes.SET_OFFSET_B)
            assert.are.equal('positioningSFixture', modes.POSITIONING_SFIXTURE)
            assert.are.equal('addNodeToMeshUsert', modes.ADD_NODE_MESHUSERT)
            assert.are.equal('addNodeToConnectedTexture', modes.ADD_NODE_CONNECTED_TEX)
        end)

        it('has unique values for all constants', function()
            local seen = {}
            for k, v in pairs(modes) do
                if type(v) == 'string' and k == k:upper() then
                    assert.is_nil(seen[v], 'duplicate value: ' .. v)
                    seen[v] = k
                end
            end
        end)
    end)

    describe('set()', function()
        it('sets currentMode on state', function()
            local state = require('src.state')
            modes.set(modes.DRAW_CLICK)
            assert.are.equal('drawClickMode', state.currentMode)
        end)

        it('still sets unknown mode (warns but does not throw)', function()
            local state = require('src.state')
            -- Should not error, just warn
            assert.has_no.errors(function()
                modes.set('bogusMode')
            end)
            assert.are.equal('bogusMode', state.currentMode)
        end)
    end)

    describe('clear()', function()
        it('sets currentMode to nil', function()
            local state = require('src.state')
            state.currentMode = 'drawClickMode'
            modes.clear()
            assert.is_nil(state.currentMode)
        end)
    end)

    describe('is()', function()
        it('returns true when mode matches', function()
            local state = require('src.state')
            state.currentMode = 'drawClickMode'
            assert.is_true(modes.is(modes.DRAW_CLICK))
        end)

        it('returns false when mode does not match', function()
            local state = require('src.state')
            state.currentMode = 'drawClickMode'
            assert.is_false(modes.is(modes.DRAW_FREE_POLY))
        end)

        it('returns false when currentMode is nil', function()
            local state = require('src.state')
            state.currentMode = nil
            assert.is_false(modes.is(modes.DRAW_CLICK))
        end)
    end)

    describe('get()', function()
        it('returns current mode value', function()
            local state = require('src.state')
            state.currentMode = 'jointCreationMode'
            assert.are.equal('jointCreationMode', modes.get())
        end)

        it('returns nil when no mode set', function()
            local state = require('src.state')
            state.currentMode = nil
            assert.is_nil(modes.get())
        end)
    end)
end)
