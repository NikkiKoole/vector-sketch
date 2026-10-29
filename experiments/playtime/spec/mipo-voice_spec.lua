-- spec/mipo-voice_spec.lua

describe("src.mipo-voice", function()
    package.loaded['src.mipo-voice'] = nil
    local mipoVoice = require('src.mipo-voice')

    describe("voiceFor", function()
        it("is stable for the same id", function()
            local a = mipoVoice.voiceFor({ id = 'abc-123' })
            local b = mipoVoice.voiceFor({ id = 'abc-123' })
            assert.are.same(a, b)
        end)

        it("picks a known voice set and a pitch in range", function()
            for i = 1, 50 do
                local voice = mipoVoice.voiceFor({ id = 'mipo-' .. i })
                local known = false
                for _, name in ipairs(mipoVoice.voiceSets) do
                    if name == voice.set then known = true end
                end
                assert.is_true(known, 'unknown set ' .. tostring(voice.set))
                assert.is_true(voice.pitch >= mipoVoice.pitchRange[1] and voice.pitch <= mipoVoice.pitchRange[2])
                assert.is_true(voice.tone >= mipoVoice.toneRange[1] and voice.tone <= mipoVoice.toneRange[2])
            end
        end)

        it("spreads ids over more than one voice", function()
            local seen = {}
            for i = 1, 30 do seen[mipoVoice.voiceFor({ id = 'mipo-' .. i }).set] = true end
            local count = 0
            for _ in pairs(seen) do count = count + 1 end
            assert.is_true(count > 1)
        end)

        it("has deep, dark Mipos and high, bright ones", function()
            local deep, high = 0, 0
            for i = 1, 60 do
                local voice = mipoVoice.voiceFor({ id = 'mipo-' .. i })
                if voice.pitch < 0.8 then deep = deep + 1 end
                if voice.pitch > 1.3 then high = high + 1 end
            end
            assert.is_true(deep >= 10, 'deep voices: ' .. deep)
            assert.is_true(high >= 10, 'high voices: ' .. high)
        end)

        it("prefers dna.voice when present", function()
            local voice = mipoVoice.voiceFor({ id = 'x', dna = { voice = { set = 'theo', pitch = 1.1 } } })
            assert.are.equal('theo', voice.set)
            assert.are.equal(1.1, voice.pitch)
        end)
    end)

    describe("candidates", function()
        it("lists the fx names of an fx emotion", function()
            local options = mipoVoice.candidates('nikki', 'annoyed')
            local keys = {}
            for _, o in ipairs(options) do keys[#keys + 1] = o.set .. '/' .. o.key end
            assert.are.same({ 'fx/tsk', 'fx/tsk2' }, keys)
        end)
    end)

    describe("flapEnvelope", function()
        it("is closed at both ends", function()
            assert.are.equal(0, mipoVoice.flapEnvelope(0))
            assert.are.equal(0, mipoVoice.flapEnvelope(1))
        end)

        it("is fully open in the middle third", function()
            assert.are.equal(1, mipoVoice.flapEnvelope(0.5))
        end)

        it("rises then falls", function()
            assert.is_true(mipoVoice.flapEnvelope(0.1) < mipoVoice.flapEnvelope(0.3))
            assert.is_true(mipoVoice.flapEnvelope(0.75) > mipoVoice.flapEnvelope(0.95))
        end)
    end)

    describe("isSquishy", function()
        local function fakeBody(behaviors)
            return { getUserData = function() return { thing = { behaviors = behaviors } } end }
        end

        it("is true for a body with the SQUISHY behavior", function()
            assert.is_true(mipoVoice.isSquishy(fakeBody({ { name = 'KEEP_ANGLE' }, { name = 'SQUISHY' } })))
        end)

        it("is false without it", function()
            assert.is_false(mipoVoice.isSquishy(fakeBody({ { name = 'KEEP_ANGLE' } })))
            assert.is_false(mipoVoice.isSquishy(fakeBody(nil)))
        end)
    end)

    describe("squeak", function()
        it("is a no-op without an instance", function()
            assert.is_nil(mipoVoice.squeak(nil, 'poke'))
        end)
    end)

    describe("edited", function()
        it("is a no-op without an instance", function()
            assert.is_nil(mipoVoice.edited(nil, 0.5))
            assert.is_false(mipoVoice.isTalking(nil))
        end)

        if not (love and love.audio) then return end

        it("talks higher for bigger values and waits until the last hmpf is done", function()
            local low = mipoVoice.edited({ id = 'edit-low', parts = {} }, 0)
            local high = mipoVoice.edited({ id = 'edit-high', parts = {} }, 1)
            assert.is_not_nil(low)
            assert.is_not_nil(high)
            assert.is_true(high:getPitch() > low:getPitch() * 2)

            local instance = { id = 'edit-busy', parts = {} }
            assert.is_not_nil(mipoVoice.edited(instance, 0.5))
            assert.is_true(mipoVoice.isTalking(instance))
            assert.is_nil(mipoVoice.edited(instance, 0.5))
            low:stop(); high:stop()
        end)
    end)
end)
