-- spec/web-bridge_spec.lua
-- The browser build's eval bridge (src/web-bridge.lua) and the serializer it shares with the
-- desktop bridge (vendor/bridge-serialize.lua). The page side is in webtest/index.template.html.
-- Run with: love . --specs spec/web-bridge_spec.lua

if not love then return end

local json = require('vendor.dkjson')
local serialize = require('vendor.bridge-serialize').serialize
local webBridge = require('src.web-bridge')

describe('bridge serializer', function()
    it('keeps plain values, cuts cycles and depth, drops NaN', function()
        local t = { a = 1, list = { 1, 2, 3 }, nan = 0 / 0, fn = print }
        t.self = t
        local out = serialize(t, 0, 4)
        assert.are.equal(1, out.a)
        assert.are.same({ 1, 2, 3 }, out.list)
        assert.is_nil(out.nan)
        assert.are.equal('<function>', out.fn)
        assert.are.equal('<circular ref>', out.self)
        assert.are.equal('<max depth>', serialize({ { { 1 } } }, 0, 2)[1][1])
    end)

    it('turns a Box2D body into a small table', function()
        local world = love.physics.newWorld(0, 0, true)
        local body = love.physics.newBody(world, 10, 20, 'dynamic')
        local out = serialize(body, 0, 4)
        assert.are.equal('Body', out._type)
        assert.are.equal(10, out.x)
        assert.are.equal(20, out.y)
        world:destroy()
    end)

    it('the desktop bridge still loads with it', function()
        assert.is_table(require('vendor.claude-bridge'))
    end)
end)

describe('web bridge', function()
    local printed
    local realPrint = _G.print

    -- Runs one frame of the bridge with these requests in its inbox; returns the answers by id.
    local function frame(requests)
        for id, code in pairs(requests) do
            assert.is_true(love.filesystem.write(webBridge.dir .. '/' .. id .. '.lua', code))
        end
        printed = {}
        _G.print = function(line) printed[#printed + 1] = line end -- busted runs specs in their own env
        local ok, err = pcall(webBridge.update)
        _G.print = realPrint
        assert.is_true(ok, tostring(err))
        local answers = {}
        for _, line in ipairs(printed) do
            local id, body = line:match('^@bridge\t([^\t]+)\t(.*)$')
            if id then answers[id] = json.decode(body) end
        end
        return answers
    end

    it('says where its inbox is, runs requests in order and empties the inbox', function()
        local first = frame({})
        assert.is_truthy(first.ready and first.ready.dir:match('web%-bridge$'))

        local answers = frame({ ['00000002'] = 'order = order .. "b"; return order',
                                ['00000001'] = 'order = "a"; return order' })
        assert.are.same({ ok = true, data = 'a' }, answers['00000001'])
        assert.are.same({ ok = true, data = 'ab' }, answers['00000002'])
        assert.are.same({}, love.filesystem.getDirectoryItems(webBridge.dir))
        order = nil -- luacheck: ignore 111
    end)

    it('has the desktop /eval locals, and reports errors with the sent line numbers', function()
        local answers = frame({
            a = 'return type(state) == "table" and type(registry) == "table" and type(sceneIO) == "table"',
            b = 'local x = 1\nerror("boom")',
            c = 'return +',
        })
        assert.are.same({ ok = true, data = true }, answers.a)
        assert.is_false(answers.b.ok)
        assert.is_truthy(answers.b.error:match(':2: boom'))
        assert.is_false(answers.c.ok)
        assert.is_truthy(answers.c.error:match('^compile error: .*:1:'))
    end)
end)
