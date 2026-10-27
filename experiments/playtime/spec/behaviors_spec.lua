-- spec/behaviors_spec.lua
-- The inspector (src/ui/inspector.lua) draws whatever `params` a behavior
-- declares; a malformed row would only show up as a broken panel. Pure spec.

local behaviors = require('src.behaviors')

local kinds = { text = true, numberText = true, number = true, bool = true, choice = true, action = true,
    buttons = true, note = true, color = true, file = true }

describe('behavior params (inspector schema)', function()
    for _, behavior in ipairs(behaviors.allBehaviors) do
        it(behavior.name .. ' declares valid rows', function()
            for i, row in ipairs(behavior.params or {}) do
                local where = behavior.name .. ' row ' .. i
                assert.is_true(kinds[row.kind] == true, where .. ': unknown kind ' .. tostring(row.kind))
                if row.kind == 'action' then
                    assert.are.equal('function', type(row.run), where)
                    assert.is_not_nil(row.label, where)
                else
                    assert.are.equal('string', type(row.key), where)
                end
                if row.kind == 'number' then
                    assert.is_true(row.min < row.max, where)
                    assert.is_true(row.default >= row.min and row.default <= row.max, where)
                end
                if row.kind == 'choice' then
                    assert.is_true(#row.options >= 2, where)
                end
            end
        end)
    end
end)
