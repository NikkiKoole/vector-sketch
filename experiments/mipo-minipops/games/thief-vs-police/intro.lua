local scene = {}
function scene:load(args)
    success = love.window.setMode(1400, 1000)
    love.keyboard.setKeyRepeat(true)

    gras = love.graphics.newImage('games/thief-vs-police/img/gras.png')
    sky = love.graphics.newImage('games/thief-vs-police/img/sky.png')
    muur = love.graphics.newImage('games/thief-vs-police/img/muur.png')
    dief = love.graphics.newImage('games/thief-vs-police/img/thief2.png')
    geldzak = love.graphics.newImage('games/thief-vs-police/img/geldzak.png')
    pin = love.graphics.newImage('games/thief-vs-police/img/pin3.png')

    screenData = {
       columns = 10,
       rows = 10
   }

   map = [[
ssssssssss
ssssssssss
ssssssssss
ssssssssss
ssssssssss
ssssssssss
mmmmmmmmmm
mmmmmmmmmm
gggggggggg
gggggggggg
]]

  print(map)

end




function scene:draw()
    love.graphics.clear(.1, .1, .1)

    local w, h = love.graphics.getDimensions()
    local columns = screenData.columns
    local rows = screenData.rows
    local size = math.min(math.floor(w / columns), math.floor(h / rows)) * 0.9

    local offsetX = (w - (size * columns)) / 2
    local offsetY = (h - (size * rows)) / 2  + size/2

    -- Loop through all rows and columns
   --  if true then

    for row = 1, rows  do
        for col = 1, columns  do
            local index =1+ ((row-1) * (columns)) + (col-1)

            local char = string.sub(map, index, index)
            print(index, char)
        end
    end
end


return scene
