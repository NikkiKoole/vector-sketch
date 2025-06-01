function love.load()
    keys = { 'a', 'b', 'm' }
    sounds = {}
    for _, key in ipairs(keys) do
        sounds[key] = love.audio.newSource("samples/" .. key .. ".wav", "static")
    end
end

function play(k)
    local source = sounds[k]:clone()
    source:play()
end

function love.keypressed(key)
    local keymap = {
        ['a'] = function() play('a') end,
        ['b'] = function() play('b') end,
        ['m'] = function() play('m') end,
        ['escape'] = function() love.event.quit() end,
    }
    if keymap[key] then keymap[key]() end
end
