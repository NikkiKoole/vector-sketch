-- lettering: text in hand-drawn letters, three drawings of each (docs/HANDDRAWN-FONT.md). The drawings come
-- from claudetools/lettering-forge.py (a font's letters redrawn three times with a wobbling line) as one
-- atlas + metrics in textures/lettering/.
--
--   lettering.draw(text, x, y, opts) -> width, height   (x, y: the top left, like love.graphics.print)
--   lettering.measure(text, opts) -> width, height
-- opts (all optional): size (px of the em, 48), font ('comic'), seed (which drawings a text gets, 1),
--   boil (drawings per second, 0 = still), jiggle (0..1, each drawing's own tilt and bounce, 0.5),
--   align ('left' | 'center' | 'right', per line), spacing (extra px between letters), time (for boil),
--   straight (true: the font's own letters, no wobble, no jiggle, no boil)
--
-- Which drawing: each letter gets one of its three by its place in the text, so it stays the same frame to
-- frame, and a letter never has the same drawing as the same letter right before it ("ll", "aaa"). Boil:
-- every tick each letter goes on to another of its three, round in its own order, out of step with its
-- neighbours (a run of one letter keeps step, so its drawings stay different). The tilt and bounce belong to
-- the drawing (a letter and its drawing), so a boiling letter jumps between three poses, not every frame.
local utf8 = require('utf8')

local lib = {}

-- both names in full: claudetools/ship-list.py packs what the code names
local FONTS = {
    comic = { metrics = 'textures/lettering/comic.lua', image = 'textures/lettering/comic.png' },
    comicbold = { metrics = 'textures/lettering/comicbold.lua', image = 'textures/lettering/comicbold.png' },
    windsor = { metrics = 'textures/lettering/windsor.lua', image = 'textures/lettering/windsor.png' },
    cooper = { metrics = 'textures/lettering/cooper.lua', image = 'textures/lettering/cooper.png' },
}
lib.FONTS = { 'comic', 'comicbold', 'windsor', 'cooper' }

local loaded = {}

local function font(name)
    name = name or 'comic'
    local f = loaded[name]
    if f then return f end
    local paths = FONTS[name]
    if not paths then error('lettering: no font ' .. tostring(name)) end
    local m = love.filesystem.load(paths.metrics)()
    local image = love.graphics.newImage(paths.image, { mipmaps = true })
    image:setFilter('linear', 'linear')
    image:setMipmapFilter('linear')
    local letters = {}
    for ch, e in pairs(m.letters) do
        local versions = {}
        for i, v in ipairs(e) do
            versions[i] = { quad = love.graphics.newQuad(v[1], v[2], v[3], v[4], m.width, m.height),
                w = v[3], h = v[4], ox = v[5], oy = v[6] }
        end
        local c = e.clean
        local clean = c and { quad = love.graphics.newQuad(c[1], c[2], c[3], c[4], m.width, m.height),
            w = c[3], h = c[4], ox = c[5], oy = c[6] }
        letters[ch] = { advance = e.advance, versions = versions, clean = clean }
    end
    f = { image = image, letters = letters, em = m.em, ascent = m.ascent, lineHeight = m.lineHeight }
    loaded[name] = f
    return f
end
lib.font = font

-- a number 0..1 from a few integers, the same every time (no math.random: the text must not change)
local function hash(a, b, c)
    local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
    return v - math.floor(v)
end

local function chars(text)
    local out = {}
    for _, code in utf8.codes(text) do out[#out + 1] = utf8.char(code) end
    return out
end

local function lines(text)
    local out = {}
    for line in (text .. '\n'):gmatch('(.-)\n') do out[#out + 1] = chars(line) end
    return out
end

local function lineWidth(f, line, spacing)
    local w = 0
    for i, ch in ipairs(line) do
        local e = f.letters[ch] or f.letters['?']
        w = w + (e and e.advance or 0) + (i < #line and spacing or 0)
    end
    return w
end

function lib.measure(text, opts)
    opts = opts or {}
    local f = font(opts.font)
    local s = (opts.size or 48) / f.em
    local spacing = (opts.spacing or 0) / s
    local w, all = 0, lines(text)
    for _, line in ipairs(all) do w = math.max(w, lineWidth(f, line, spacing)) end
    return w * s, #all * f.lineHeight * s
end

-- the drawing (1..3) of the letter at place n, at boil tick `tick`; `run` carries the last letter's choice
local function pick(ch, n, count, seed, tick, run)
    local base, step
    if run.ch == ch then
        base, step = (run.base + 1) % count, run.step
    else
        base = math.floor(hash(seed, n, 1) * count)
        step = hash(seed, n, 2) < 0.5 and 1 or count - 1
    end
    run.ch, run.base, run.step = ch, base, step
    return (base + tick * step) % count + 1
end

function lib.draw(text, x, y, opts)
    opts = opts or {}
    local f = font(opts.font)
    local size = opts.size or 48
    local s = size / f.em
    local seed = opts.seed or 1
    local straight = opts.straight
    local boil = straight and 0 or opts.boil or 0
    local jiggle = straight and 0 or opts.jiggle or 0.5
    local spacing = (opts.spacing or 0) / s
    local align = opts.align or 'left'
    local tick = 0
    if boil > 0 then tick = math.floor((opts.time or love.timer.getTime()) * boil) end
    local all = lines(text)
    local maxW = 0
    local widths = {}
    for i, line in ipairs(all) do
        widths[i] = lineWidth(f, line, spacing)
        maxW = math.max(maxW, widths[i])
    end
    local n = 0
    for li, line in ipairs(all) do
        local pen = 0
        if align == 'center' then pen = (maxW - widths[li]) / 2
        elseif align == 'right' then pen = maxW - widths[li] end
        local base = (li - 1) * f.lineHeight + f.ascent
        local run = {}
        for _, ch in ipairs(line) do
            n = n + 1
            local e = f.letters[ch] or f.letters['?']
            if e then
                local count = #e.versions
                if count > 0 then
                    local vi = pick(ch, n, count, seed, tick, run)
                    local v = straight and e.clean or e.versions[vi]
                    local tilt = (hash(seed + vi, n, 3) - 0.5) * 0.12 * jiggle
                    local bounce = (hash(seed + vi, n, 4) - 0.5) * 0.06 * f.em * jiggle
                    local cx, cy = pen + v.ox + v.w / 2, base + v.oy + v.h / 2 + bounce
                    love.graphics.draw(f.image, v.quad, x + cx * s, y + cy * s, tilt, s, s, v.w / 2, v.h / 2)
                else
                    run.ch = nil
                end
                pen = pen + e.advance + spacing
            end
        end
    end
    return maxW * s, #all * f.lineHeight * s
end

return lib
