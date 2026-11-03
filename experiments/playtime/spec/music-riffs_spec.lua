local riffs = require('src.music-riffs')

describe('music-riffs', function()
    local riff = { phrase = 'R...', vars = { B = '            8.7A' }, form = 'AAAB' }

    it('fills a short phrase to a bar', function()
        assert.are.equal('R...R...R...R...', riffs.barWith(riff, 'A'))
    end)

    it('lays a variation over the phrase, spaces keep the phrase', function()
        assert.are.equal('R...R...R...8.7A', riffs.barWith(riff, 'B'))
    end)

    it('lines the form up with the end of the root step', function()
        assert.are.equal('B', riffs.letter(riff, 1)) -- the bar before the root moves
        assert.are.equal('A', riffs.letter(riff, 2))
        assert.are.equal('A', riffs.letter(riff, 4))
        assert.are.equal('A', riffs.letter(riff, 8)) -- a longer step plays the first letter until the form fits
    end)

    it('plays the tail of the form on a short step', function()
        local abac = { phrase = 'R', vars = { B = '8', C = '5' }, form = 'ABAC' }
        assert.are.equal('A', riffs.letter(abac, 2))
        assert.are.equal('C', riffs.letter(abac, 1))
    end)

    it('is pentatonic unless it says otherwise', function()
        assert.are.same(riffs.SCALES.pentatonic, riffs.scaleOf(riff))
        assert.are.same(riffs.SCALES.blues, riffs.scaleOf({ phrase = 'R', scale = 'blues' }))
    end)

    it('finds notes outside the scale on strong steps, not on off-16ths or approaches', function()
        assert.are.same({}, riffs.check({ phrase = 'R..3......A.....' })) -- an off-16th, an approach
        local bad = riffs.check({ phrase = 'R.3.............' })
        assert.are.equal(1, #bad)
        assert.are.same({ 'A', 3, '3' }, bad[1])
        assert.are.same({}, riffs.check({ phrase = 'R.3.', scale = 'mixolydian' }))
    end)

    it('keeps every built-in riff in its scale', function()
        for _, r in ipairs(riffs.RIFFS) do
            assert.are.same({}, riffs.check(r), r.name)
            for letter in r.form:gmatch('.') do
                assert.is_true(letter == 'A' or r.vars[letter] ~= nil, r.name .. ' ' .. letter)
            end
        end
    end)

    it('follows the chord: the minor pentatonic in place on the chord\'s own', function()
        local r = { phrase = 'R' }
        local function notes(kind)
            local d = riffs.degrees(r, kind)
            return { d.R, d.m, d['4'], d['5'], d['7'], d['8'], d.L }
        end
        assert.are.same({ 0, 3, 5, 7, 10, 12, -5 }, notes('m'))
        assert.are.same({ 0, 2, 4, 7, 9, 12, -5 }, notes('M'))
        assert.are.same({ 0, 2, 4, 7, 10, 12, -5 }, notes('7'))
    end)

    it('keeps its own notes when it has its own scale or says follow = false', function()
        assert.are.equal(3, riffs.degrees({ phrase = 'R', scale = 'blues' }, 'M').m)
        assert.are.equal(3, riffs.degrees({ phrase = 'R', follow = false }, 'M').m)
    end)
end)
