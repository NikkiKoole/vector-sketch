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
                assert.is_true(voice.pitch >= 0.85 and voice.pitch <= 1.25)
            end
        end)

        it("spreads ids over more than one voice", function()
            local seen = {}
            for i = 1, 30 do seen[mipoVoice.voiceFor({ id = 'mipo-' .. i }).set] = true end
            local count = 0
            for _ in pairs(seen) do count = count + 1 end
            assert.is_true(count > 1)
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

    describe("squeak", function()
        it("is a no-op without an instance", function()
            assert.is_nil(mipoVoice.squeak(nil, 'poke'))
        end)
    end)
end)
