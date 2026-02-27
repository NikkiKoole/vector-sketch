-- spec/dna-defaults_spec.lua
-- Pure busted tests for dna-defaults module (no LÖVE needed)

describe('dna-defaults', function()
    local D = require('src.dna-defaults')

    describe('ensureDefaults', function()
        it('fills missing scalar fields', function()
            local target = { a = 10 }
            D.ensureDefaults(target, { a = 99, b = 20, c = 'hello' })
            assert.equal(10, target.a)  -- not overwritten
            assert.equal(20, target.b)  -- filled
            assert.equal('hello', target.c)  -- filled
        end)

        it('does not overwrite existing values', function()
            local target = { x = 5, y = 'yes' }
            D.ensureDefaults(target, { x = 100, y = 'no', z = 42 })
            assert.equal(5, target.x)
            assert.equal('yes', target.y)
            assert.equal(42, target.z)
        end)

        it('preserves false values (not treated as nil)', function()
            local target = { enabled = false }
            D.ensureDefaults(target, { enabled = true, other = true })
            assert.equal(false, target.enabled)  -- false preserved, not overwritten
            assert.equal(true, target.other)  -- missing key filled
        end)

        it('fills missing sub-tables with deep copies', function()
            local defaults = { nested = { a = 1, b = 2 } }
            local target = {}
            D.ensureDefaults(target, defaults)
            assert.same({ a = 1, b = 2 }, target.nested)
            -- Must be a deep copy, not the same reference
            assert.are_not.equal(defaults.nested, target.nested)
        end)

        it('recurses into existing sub-tables', function()
            local target = { sub = { x = 10 } }
            D.ensureDefaults(target, { sub = { x = 99, y = 20 } })
            assert.equal(10, target.sub.x)  -- not overwritten
            assert.equal(20, target.sub.y)  -- filled
        end)

        it('handles empty target', function()
            local target = {}
            D.ensureDefaults(target, { a = 1, b = { c = 2 } })
            assert.equal(1, target.a)
            assert.same({ c = 2 }, target.b)
        end)

        it('handles empty defaults', function()
            local target = { a = 1 }
            D.ensureDefaults(target, {})
            assert.equal(1, target.a)
        end)

        it('handles nested table recursion multiple levels deep', function()
            local target = { l1 = { l2 = { existing = 'keep' } } }
            D.ensureDefaults(target, { l1 = { l2 = { existing = 'ignore', new = 'added' }, extra = 5 } })
            assert.equal('keep', target.l1.l2.existing)
            assert.equal('added', target.l1.l2.new)
            assert.equal(5, target.l1.extra)
        end)

        it('returns the target table', function()
            local target = {}
            local result = D.ensureDefaults(target, { a = 1 })
            assert.equal(target, result)
        end)

        it('deep-copied defaults are independent (mutation isolation)', function()
            local defaults = { t = { val = 10 } }
            local target1 = {}
            local target2 = {}
            D.ensureDefaults(target1, defaults)
            D.ensureDefaults(target2, defaults)
            target1.t.val = 999
            assert.equal(10, target2.t.val)  -- not affected
            assert.equal(10, defaults.t.val)  -- original not affected
        end)
    end)

    describe('default tables', function()
        it('has eye defaults', function()
            assert.equal(1, D.eye.shape)
            assert.equal('000000ff', D.eye.bgHex)
            assert.equal(1, D.eye.wMul)
        end)

        it('has pupil defaults', function()
            assert.equal(1, D.pupil.shape)
            assert.equal(0.5, D.pupil.wMul)
        end)

        it('has brow defaults', function()
            assert.equal(1, D.brow.shape)
            assert.equal(1, D.brow.bend)
        end)

        it('has nose defaults', function()
            assert.equal(0, D.nose.shape)
            assert.equal('ffffffff', D.nose.fgHex)
        end)

        it('has teeth defaults', function()
            assert.equal(0, D.teeth.shape)
            assert.equal(false, D.teeth.stickOut)
        end)

        it('has mouth defaults', function()
            assert.equal(2, D.mouth.shape)
            assert.equal(0.25, D.mouth.lipScale)
            assert.equal('cc5555ff', D.mouth.lipHex)
        end)

        it('has face positioner defaults', function()
            assert.equal(0.2, D.facePositioners.eye.x)
            assert.equal(0.5, D.facePositioners.eye.y)
            assert.equal(0, D.facePositioners.eye.r)
            assert.equal(0.3, D.facePositioners.brow.y)
            assert.equal(0.35, D.facePositioners.nose.y)
            assert.equal(0.7, D.facePositioners.mouth.y)
        end)

        it('has combined face defaults with all sub-structures', function()
            assert.is_table(D.face.eye)
            assert.is_table(D.face.pupil)
            assert.is_table(D.face.brow)
            assert.is_table(D.face.nose)
            assert.is_table(D.face.teeth)
            assert.is_table(D.face.mouth)
            assert.is_table(D.face.positioners)
        end)

        it('has positioner defaults', function()
            assert.equal(0.5, D.positioners.leg.x)
            assert.equal(0.5, D.positioners.ear.y)
            assert.equal(0.35, D.positioners.nose.t)
        end)

        it('has creation defaults', function()
            assert.equal(false, D.creation.isPotatoHead)
            assert.equal(1, D.creation.torsoSegments)
            assert.equal(0, D.creation.neckSegments)
            assert.equal(0, D.creation.noseSegments)
        end)

        it('has faceMagnitude default', function()
            assert.equal(1, D.faceMagnitude)
        end)
    end)

    describe('validate', function()
        it('returns empty list for a complete face', function()
            -- Build a complete face from the defaults
            local face = {
                eye = { shape = 1, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1, lookAtMouse = false },
                pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
                brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 },
                nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                teeth = { shape = 0, bgHex = 'ffffffff', fgHex = 'eeeeeeff', hMul = 1, stickOut = false },
                mouth = { shape = 2, upperLipShape = 1, lowerLipShape = 1,
                          lipHex = 'cc5555ff', backdropHex = '00000033',
                          lipScale = 0.25, wMul = 1, hMul = 1 },
                positioners = {
                    eye = { x = 0.2, y = 0.5, r = 0 },
                    brow = { y = 0.3 },
                    nose = { y = 0.35 },
                    mouth = { y = 0.7 },
                },
            }
            local issues = D.validateFace(face)
            assert.same({}, issues)
        end)

        it('reports missing sub-table', function()
            local face = {
                pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
                brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 },
                nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                teeth = { shape = 0, bgHex = 'ffffffff', fgHex = 'eeeeeeff', hMul = 1, stickOut = false },
                mouth = { shape = 2, upperLipShape = 1, lowerLipShape = 1,
                          lipHex = 'cc5555ff', backdropHex = '00000033',
                          lipScale = 0.25, wMul = 1, hMul = 1 },
                positioners = {
                    eye = { x = 0.2, y = 0.5, r = 0 },
                    brow = { y = 0.3 }, nose = { y = 0.35 }, mouth = { y = 0.7 },
                },
            }
            -- eye is missing
            local issues = D.validateFace(face)
            assert.equal(1, #issues)
            assert.equal('face.eye', issues[1].path)
            assert.equal('missing', issues[1].issue)
        end)

        it('reports wrong type on a leaf field', function()
            local face = {
                eye = { shape = 'foo', bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1, lookAtMouse = false },
                pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
                brow = { shape = 1, bgHex = '000000ff', wMul = 1, hMul = 1, bend = 1 },
                nose = { shape = 0, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1 },
                teeth = { shape = 0, bgHex = 'ffffffff', fgHex = 'eeeeeeff', hMul = 1, stickOut = false },
                mouth = { shape = 2, upperLipShape = 1, lowerLipShape = 1,
                          lipHex = 'cc5555ff', backdropHex = '00000033',
                          lipScale = 0.25, wMul = 1, hMul = 1 },
                positioners = {
                    eye = { x = 0.2, y = 0.5, r = 0 },
                    brow = { y = 0.3 }, nose = { y = 0.35 }, mouth = { y = 0.7 },
                },
            }
            local issues = D.validateFace(face)
            assert.equal(1, #issues)
            assert.equal('face.eye.shape', issues[1].path)
            assert.matches('expected number, got string', issues[1].issue)
        end)

        it('reports missing key within sub-table', function()
            local issues = D.validate(
                { eye = { shape = 1 } },
                { eye = { shape = 'number', bgHex = 'string' } },
                'face'
            )
            assert.equal(1, #issues)
            assert.equal('face.eye.bgHex', issues[1].path)
            assert.equal('missing', issues[1].issue)
        end)

        it('reports only missing sub-tables in partial face', function()
            -- Only eye and pupil present, rest missing
            local face = {
                eye = { shape = 1, bgHex = '000000ff', fgHex = 'ffffffff', wMul = 1, hMul = 1, lookAtMouse = false },
                pupil = { shape = 1, bgHex = '000000ff', fgHex = '', wMul = 0.5, hMul = 0.5 },
            }
            local issues = D.validateFace(face)
            -- Should report brow, nose, teeth, mouth, positioners as missing
            local missing_paths = {}
            for _, issue in ipairs(issues) do
                if issue.issue == 'missing' then
                    missing_paths[issue.path] = true
                end
            end
            assert.is_true(missing_paths['face.brow'])
            assert.is_true(missing_paths['face.nose'])
            assert.is_true(missing_paths['face.teeth'])
            assert.is_true(missing_paths['face.mouth'])
            assert.is_true(missing_paths['face.positioners'])
            -- eye and pupil should NOT be missing
            assert.is_nil(missing_paths['face.eye'])
            assert.is_nil(missing_paths['face.pupil'])
        end)

        it('validatePositioners catches missing leg, ear, nose', function()
            local issues = D.validatePositioners({})
            assert.equal(3, #issues)
            local paths = {}
            for _, issue in ipairs(issues) do paths[issue.path] = true end
            assert.is_true(paths['positioners.leg'])
            assert.is_true(paths['positioners.ear'])
            assert.is_true(paths['positioners.nose'])
        end)

        it('validatePositioners passes for complete positioners', function()
            local pos = { leg = { x = 0.5 }, ear = { y = 0.5 }, nose = { t = 0.35 } }
            local issues = D.validatePositioners(pos)
            assert.same({}, issues)
        end)

        it('reports type mismatch in nested positioner field', function()
            local pos = { leg = { x = 'bad' }, ear = { y = 0.5 }, nose = { t = 0.35 } }
            local issues = D.validatePositioners(pos)
            assert.equal(1, #issues)
            assert.equal('positioners.leg.x', issues[1].path)
            assert.matches('expected number, got string', issues[1].issue)
        end)

        it('validateCreation passes for complete creation', function()
            local creation = { isPotatoHead = false, torsoSegments = 1, neckSegments = 0, noseSegments = 0 }
            local issues = D.validateCreation(creation)
            assert.same({}, issues)
        end)

        it('validateCreation catches missing fields', function()
            local issues = D.validateCreation({})
            assert.equal(4, #issues)
            local paths = {}
            for _, issue in ipairs(issues) do paths[issue.path] = true end
            assert.is_true(paths['creation.isPotatoHead'])
            assert.is_true(paths['creation.torsoSegments'])
            assert.is_true(paths['creation.neckSegments'])
            assert.is_true(paths['creation.noseSegments'])
        end)

        it('validateCreation catches type mismatches', function()
            local creation = { isPotatoHead = 'yes', torsoSegments = 1, neckSegments = 0, noseSegments = 0 }
            local issues = D.validateCreation(creation)
            assert.equal(1, #issues)
            assert.equal('creation.isPotatoHead', issues[1].path)
            assert.matches('expected boolean, got string', issues[1].issue)
        end)
    end)

    describe('randomRanges', function()
        it('has all expected range keys', function()
            local expectedKeys = {
                'bodyScale', 'earScale', 'feetScale', 'handScale', 'haircutWidth',
                'eyeY', 'eyeX', 'eyeWMul', 'eyeHMul', 'pupilWMul', 'pupilHMul',
                'mouthYOffset', 'mouthLipScale', 'mouthWMul', 'mouthHMul',
                'browWMul', 'browHMul', 'browBend', 'browY',
                'noseWMul', 'noseHMul', 'noseY', 'teethHMul',
            }
            for _, key in ipairs(expectedKeys) do
                local r = D.randomRanges[key]
                assert.is_table(r, 'missing randomRange: ' .. key)
                assert.is_number(r.min, key .. '.min should be number')
                assert.is_number(r.max, key .. '.max should be number')
                assert.is_true(r.min <= r.max, key .. ': min should be <= max')
            end
        end)

        it('has scalar chance values', function()
            assert.is_number(D.randomRanges.teethChance)
            assert.is_number(D.randomRanges.teethStickOut)
        end)
    end)

    describe('randomInRange', function()
        it('returns value within [min, max] range', function()
            -- Run multiple times to check bounds
            for _ = 1, 100 do
                local val = D.randomInRange('bodyScale')
                assert.is_true(val >= 1, 'bodyScale should be >= 1, got ' .. val)
                assert.is_true(val <= 2, 'bodyScale should be <= 2, got ' .. val)
            end
        end)

        it('works for all range keys', function()
            local rangeKeys = {
                'bodyScale', 'earScale', 'eyeX', 'browBend', 'noseY',
            }
            for _, key in ipairs(rangeKeys) do
                local r = D.randomRanges[key]
                local val = D.randomInRange(key)
                assert.is_true(val >= r.min, key .. ': ' .. val .. ' < ' .. r.min)
                assert.is_true(val <= r.max, key .. ': ' .. val .. ' > ' .. r.max)
            end
        end)
    end)

    describe('randomIntInRange', function()
        it('returns integer within range', function()
            for _ = 1, 100 do
                local val = D.randomIntInRange('browBend')
                assert.is_true(val >= 1, 'browBend should be >= 1, got ' .. val)
                assert.is_true(val <= 10, 'browBend should be <= 10, got ' .. val)
                assert.equal(math.ceil(val), val, 'should be integer')
            end
        end)
    end)
end)
