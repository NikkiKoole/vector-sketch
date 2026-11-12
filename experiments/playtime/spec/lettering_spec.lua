-- src/lettering.lua: which of a letter's three drawings it gets, still and boiling (docs/HANDDRAWN-FONT.md).
-- LETTERING_PNG=<path> love . --specs spec/lettering_spec.lua also writes a picture of some text there.
if not love then return end

local lettering = require('src.lettering')

-- the drawings a text gets: one quad per drawn letter, in order
local function drawn(text, opts)
    local quads = {}
    local real = love.graphics.draw
    love.graphics.draw = function(_, quad) quads[#quads + 1] = quad end
    local ok, err = pcall(lettering.draw, text, 0, 0, opts)
    love.graphics.draw = real
    assert(ok, err)
    return quads
end

describe('lettering', function()
    it('loads the comic letters, three drawings each', function()
        local f = lettering.font()
        assert.are.equal(3, #f.letters.a.versions)
        assert.are.equal(0, #f.letters[' '].versions)
    end)

    it('has windsor and cooper too', function()
        for _, name in ipairs(lettering.FONTS) do
            assert.are.equal(3, #lettering.font(name).letters.M.versions)
        end
    end)

    it('draws every letter but spaces', function()
        assert.are.equal(8, #drawn('Hola Mipo', {}))
    end)

    it('the same letter twice in a row never gets the same drawing', function()
        for seed = 1, 30 do
            for tick = 0, 5 do
                local q = drawn('llaaammm', { seed = seed, boil = 1, time = tick })
                for i = 2, #q do
                    if i ~= 3 and i ~= 6 then assert.are_not.equal(q[i - 1], q[i]) end
                end
            end
        end
    end)

    it('still text is the same every frame', function()
        local a = drawn('Mipo', { time = 1 })
        local b = drawn('Mipo', { time = 99 })
        for i = 1, #a do assert.are.equal(a[i], b[i]) end
    end)

    it('boiling: each tick every letter goes to another of its drawings', function()
        for tick = 0, 8 do
            local a = drawn('Mipo shop', { boil = 12, time = tick / 12 + 0.01 })
            local b = drawn('Mipo shop', { boil = 12, time = (tick + 1) / 12 + 0.01 })
            for i = 1, #a do assert.are_not.equal(a[i], b[i]) end
        end
    end)

    it('measures lines, the widest one and all their height', function()
        local w1, h1 = lettering.measure('Mipo', { size = 48 })
        local w2, h2 = lettering.measure('Mipo\nMi', { size = 48 })
        assert.is_true(w1 > 0)
        assert.are.equal(w1, w2)
        assert.is_true(math.abs(h2 - 2 * h1) < 1e-6)
    end)

    it('draws every look, plain and tweaked', function()
        local looks = love.filesystem.load('scripts/spikes/lettering-looks.lua')()(lettering)
        local canvas = love.graphics.newCanvas(64, 64)
        love.graphics.setCanvas(canvas)
        for _, name in ipairs(looks.NAMES) do
            local t = looks.defaults(name)
            t.hue, t.angle = 120, -30
            looks.draw('Mipo', 0, 0, { size = 40 }, looks.tweaked(name, t))
        end
        love.graphics.setCanvas()
        local path = os.getenv('LETTERING_PNG')
        if not path then return end
        local sheet = love.graphics.newCanvas(1200, 900)
        love.graphics.push('all')
        love.graphics.setCanvas(sheet)
        love.graphics.clear(0.96, 0.93, 0.87, 1)
        for i, name in ipairs(looks.NAMES) do
            local fonts = { 'comic', 'comicbold', 'windsor', 'cooper', 'comicbold', 'cooper' }
            looks.draw(name, 40 + ((i - 1) % 2) * 580, 30 + math.floor((i - 1) / 2) * 280,
                { size = 96, font = fonts[i] }, name)
        end
        love.graphics.setCanvas()
        love.graphics.pop()
        local file = io.open(path:gsub('%.png$', '-looks.png'), 'wb')
        file:write(sheet:newImageData():encode('png'):getString())
        file:close()
    end)

    it('writes a picture when asked', function()
        local path = os.getenv('LETTERING_PNG')
        if not path then return end
        local canvas = love.graphics.newCanvas(1100, 520)
        love.graphics.push('all')
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.96, 0.93, 0.87, 1)
        love.graphics.setColor(0.17, 0.14, 0.12)
        lettering.draw('Hola Mipo! llama aaa', 30, 20, { size = 72 })
        lettering.draw('Hola Mipo! llama aaa', 30, 120, { size = 72, seed = 2 })
        lettering.draw('MIPO SHOP\nopen 9 - 5', 30, 240, { size = 48, align = 'center', jiggle = 1 })
        lettering.draw('tiny text for a label, 24 px', 500, 260, { size = 24 })
        lettering.draw('fourteen px: Mipo walks', 500, 300, { size = 14 })
        lettering.draw('Windsor: The Bathhouse', 30, 380, { size = 56, font = 'windsor' })
        lettering.draw('Cooper: MIPO fridge', 30, 450, { size = 56, font = 'cooper' })
        lettering.draw('Comic bold: Hola Mipo!', 640, 160, { size = 40, font = 'comicbold' })
        love.graphics.setCanvas()
        love.graphics.pop()
        local file = io.open(path, 'wb')
        file:write(canvas:newImageData():encode('png'):getString())
        file:close()
    end)
end)
