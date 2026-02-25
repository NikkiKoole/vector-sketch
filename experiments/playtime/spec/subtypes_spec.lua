-- spec/subtypes_spec.lua

describe("src.subtypes", function()
    package.loaded['src.subtypes'] = nil
    local subtypes = require('src.subtypes')

    describe("constants", function()
        it("defines all 9 active subtypes", function()
            assert.are.equal('snap', subtypes.SNAP)
            assert.are.equal('anchor', subtypes.ANCHOR)
            assert.are.equal('texfixture', subtypes.TEXFIXTURE)
            assert.are.equal('connected-texture', subtypes.CONNECTED_TEXTURE)
            assert.are.equal('trace-vertices', subtypes.TRACE_VERTICES)
            assert.are.equal('tile-repeat', subtypes.TILE_REPEAT)
            assert.are.equal('resource', subtypes.RESOURCE)
            assert.are.equal('uvusert', subtypes.UVUSERT)
            assert.are.equal('meshusert', subtypes.MESHUSERT)
        end)

        it("has ALL lookup table for all active subtypes", function()
            assert.is_true(subtypes.ALL['snap'])
            assert.is_true(subtypes.ALL['anchor'])
            assert.is_true(subtypes.ALL['texfixture'])
            assert.is_true(subtypes.ALL['connected-texture'])
            assert.is_true(subtypes.ALL['trace-vertices'])
            assert.is_true(subtypes.ALL['tile-repeat'])
            assert.is_true(subtypes.ALL['resource'])
            assert.is_true(subtypes.ALL['uvusert'])
            assert.is_true(subtypes.ALL['meshusert'])
        end)

        it("ALL does not contain legacy subtypes", function()
            assert.is_nil(subtypes.ALL['uvmappert'])
        end)
    end)

    describe("is()", function()
        it("returns true for matching subtype", function()
            local ud = { subtype = 'snap' }
            assert.is_true(subtypes.is(ud, subtypes.SNAP))
        end)

        it("returns false for non-matching subtype", function()
            local ud = { subtype = 'snap' }
            assert.is_false(subtypes.is(ud, subtypes.ANCHOR))
        end)

        it("returns false for nil ud", function()
            assert.is_false(subtypes.is(nil, subtypes.SNAP))
        end)

        it("returns false when ud has no subtype", function()
            local ud = { label = 'snap' }
            assert.is_false(subtypes.is(ud, subtypes.SNAP))
        end)
    end)

    describe("migrate()", function()
        it("returns nil for nil input", function()
            assert.is_nil(subtypes.migrate(nil))
        end)

        it("passes through already-migrated ud unchanged", function()
            local ud = { subtype = 'snap', label = 'my-label', extra = {} }
            subtypes.migrate(ud)
            assert.are.equal('snap', ud.subtype)
            assert.are.equal('my-label', ud.label)
        end)

        -- Old era: label holds the subtype
        describe("old era (label-based)", function()
            it("migrates label='snap' to subtype", function()
                local ud = { label = 'snap', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('snap', ud.subtype)
                assert.are.equal('', ud.label)
            end)

            it("migrates label='anchor' to subtype", function()
                local ud = { label = 'anchor', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('anchor', ud.subtype)
                assert.are.equal('', ud.label)
            end)

            it("migrates label='connected-texture' to subtype", function()
                local ud = { label = 'connected-texture', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('connected-texture', ud.subtype)
                assert.are.equal('', ud.label)
            end)

            it("migrates label with trailing newline", function()
                local ud = { label = 'snap\n', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('snap', ud.subtype)
                assert.are.equal('', ud.label)
            end)

            it("migrates label with trailing whitespace", function()
                local ud = { label = 'anchor  \t', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('anchor', ud.subtype)
                assert.are.equal('', ud.label)
            end)

            it("does not clobber existing subtype from label", function()
                local ud = { subtype = 'texfixture', label = 'snap', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('texfixture', ud.subtype)
                -- label is still cleared because it matches a known subtype
                assert.are.equal('', ud.label)
            end)

            it("preserves non-subtype labels", function()
                local ud = { label = 'my-custom-name', extra = {} }
                subtypes.migrate(ud)
                assert.is_nil(ud.subtype)
                assert.are.equal('my-custom-name', ud.label)
            end)
        end)

        -- Middle era: extra.type holds the subtype
        describe("middle era (extra.type-based)", function()
            it("migrates extra.type='texfixture' to subtype", function()
                local ud = { label = 'meta8', extra = { type = 'texfixture' } }
                subtypes.migrate(ud)
                assert.are.equal('texfixture', ud.subtype)
                assert.is_nil(ud.extra.type)
                assert.are.equal('meta8', ud.label) -- real label preserved
            end)

            it("does not clobber existing subtype from extra.type", function()
                local ud = { subtype = 'snap', label = '', extra = { type = 'texfixture' } }
                subtypes.migrate(ud)
                assert.are.equal('snap', ud.subtype)
                assert.is_nil(ud.extra.type) -- still cleaned up
            end)

            it("ignores unknown extra.type values", function()
                local ud = { label = '', extra = { type = 'unknown-thing' } }
                subtypes.migrate(ud)
                assert.is_nil(ud.subtype)
                assert.are.equal('unknown-thing', ud.extra.type) -- not touched
            end)
        end)

        -- Dead subtype rename
        describe("dead subtype rename", function()
            it("renames uvmappert to uvusert", function()
                local ud = { subtype = 'uvmappert', label = '', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('uvusert', ud.subtype)
            end)
        end)

        -- Sanitize
        describe("subtype sanitization", function()
            it("strips trailing newline from subtype", function()
                local ud = { subtype = 'snap\n', label = '', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('snap', ud.subtype)
            end)

            it("strips trailing whitespace from subtype", function()
                local ud = { subtype = 'anchor  ', label = '', extra = {} }
                subtypes.migrate(ud)
                assert.are.equal('anchor', ud.subtype)
            end)
        end)

        -- Combined scenarios
        describe("combined old+middle era", function()
            it("prefers existing subtype over both label and extra.type", function()
                local ud = { subtype = 'resource', label = 'snap', extra = { type = 'texfixture' } }
                subtypes.migrate(ud)
                assert.are.equal('resource', ud.subtype)
                assert.are.equal('', ud.label) -- cleared because 'snap' is a known subtype
                assert.is_nil(ud.extra.type) -- cleared
            end)

            it("migrates extra.type when subtype is empty string", function()
                local ud = { subtype = '', label = 'meta8', extra = { type = 'texfixture' } }
                subtypes.migrate(ud)
                assert.are.equal('texfixture', ud.subtype)
                assert.are.equal('meta8', ud.label)
            end)
        end)
    end)
end)
