function love.load()
    keys = { 'mi', 'po' }
    sounds = {}
    for _, key in ipairs(keys) do
        sounds[key] = love.audio.newSource("sounds/" .. key .. ".ogg", "static")
    end
end

function play()

end

function love.load()
    keys = { 'mi', 'po' }
    sounds = {}
    play()
    for _, key in ipairs(keys) do
        sounds[key] = love.audio.newSource('sounds' .. key .. '.ogg', 'static')
    end
end

function love.load()
    keys = { 'mi', 'po' }
    sounds = {}
    for _, key in pairs(keys) do
        sounds[key] = love.audio.newSource('sounds/' .. key .. '.ogg', 'static')
    end
end
