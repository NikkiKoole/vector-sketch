package.path = package.path .. ";../../?.lua"


local ui = require 'lib.ui'

local function hex2rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255
end

local palette = {
    dark0_hard     = "#1d2021", -- 29-32-33
    dark0          = "#282828", -- 40-40-40
    dark0_soft     = "#32302f", -- 50-48-47
    dark1          = "#3c3836", -- 60-56-54
    dark2          = "#504945", -- 80-73-69
    dark3          = "#665c54", -- 102-92-84
    dark4          = "#7c6f64", -- 124-111-100
    gray_245       = "#928374", -- 146-131-116
    light0_hard    = "#f9f5d7", -- 249-245-215
    light0         = "#fbf1c7", -- 253-244-193
    light0_soft    = "#f2e5bc", -- 242-229-188
    light1         = "#ebdbb2", -- 235-219-178
    light2         = "#d5c4a1", -- 213-196-161
    light3         = "#bdae93", -- 189-174-147
    light4         = "#a89984", -- 168-153-132
    bright_red     = "#fb4934", -- 251-73-52
    bright_green   = "#b8bb26", -- 184-187-38
    bright_yellow  = "#fabd2f", -- 250-189-47
    bright_blue    = "#83a598", -- 131-165-152
    bright_purple  = "#d3869b", -- 211-134-155
    bright_aqua    = "#8ec07c", -- 142-192-124
    bright_orange  = "#fe8019", -- 254-128-25
    neutral_red    = "#cc241d", -- 204-36-29
    neutral_green  = "#98971a", -- 152-151-26
    neutral_yellow = "#d79921", -- 215-153-33
    neutral_blue   = "#458588", -- 69-133-136
    neutral_purple = "#b16286", -- 177-98-134
    neutral_aqua   = "#689d6a", -- 104-157-106
    neutral_orange = "#d65d0e", -- 214-93-14
    faded_red      = "#9d0006", -- 157-0-6
    faded_green    = "#79740e", -- 121-116-14
    faded_yellow   = "#b57614", -- 181-118-20
    faded_blue     = "#076678", -- 7-102-120
    faded_purple   = "#8f3f71", -- 143-63-113
    faded_aqua     = "#427b58", -- 66-123-88
    faded_orange   = "#af3a03", -- 175-58-3
}

for k, v in pairs(palette) do
    palette[k] = { hex2rgb(v) }
end


function love.load()
    helvetica = love.graphics.newFont('helvetica-light-587ebe5a59211.ttf', 64)
    helveticasmall = love.graphics.newFont('helvetica-light-587ebe5a59211.ttf', 48)
    vag = love.graphics.newFont('VAG Rounded Regular.otf', 64)
    bg = love.graphics.newImage('mathhead2.png')
    newCalculation()
    answer = ''

    last = nil
end

function newCalculation()
    local a, operation, b = makeCalculation()
    calculation = {}
    calculation.a = a
    calculation.b = b
    calculation.operation = operation
end

function pickRandom(container)
    local index = math.ceil(math.random() * #container)
    return container[index]
end

function makeCalculation()
    local a = math.ceil(love.math.random() * 32)
    local b = math.ceil(love.math.random() * 16)
    local operation = pickRandom({ 'x', '-', '+' })
    if operation == '-' then
        if a < b then
            local c = a
            a = b
            b = c
        end
    end
    return a, operation, b
end

function addDigitToAnswer(digit)
    answer = answer .. digit
    if (#answer >= 3) then
        answerIsCorrect()
        answer = ''
        newCalculation()
    end
end

function button(x, y, w, h, color, labelfont, label, labelcolor)
    love.graphics.setFont(labelfont)
    local cornerRadius = math.min(w, h) / 10
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', x, y, w, h, cornerRadius, cornerRadius)
    love.graphics.setColor(labelcolor)
    local xoff = (w - labelfont:getWidth(label)) / 2
    local yoff = (h - labelfont:getHeight(label)) / 2
    love.graphics.print(label, x + xoff, y + yoff, 0)

    return ui.getUIRect(label, x, y, w, h)
end

local getAnswer = function(a, b, operator)
    if operator == 'x' then
        return a * b
    elseif operator == '+' then
        return a + b
    elseif operator == '-' then
        return a - b
    end
end
function answerIsCorrect()
    
    local correct = getAnswer(calculation.a, calculation.b, calculation.operation)
    local result = (tonumber(answer) == correct)
    last = { result = result, time = 100, answer = correct }
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    if k == 'space' then
        newCalculation()
    end
    local digits = {
        ["0"] = true,
        ["1"] = true,
        ["2"] = true,
        ["3"] = true,
        ["4"] = true,
        ["5"] = true,
        ["6"] = true,
        ["7"] = true,
        ["8"] = true,
        ["9"] = true
    }
    if digits[k] then
        -- print("Digit key pressed:", k)
        addDigitToAnswer(k)
    end
    if k == 'return' then
        --print('return ')
        answerIsCorrect()
        answer = ''
        newCalculation()
    end
end

function makeNumpad(tlx, tly)
    local margin = 16
    local size = 64
    local d = size + margin

    if button(tlx, tly, size, size, palette.neutral_orange, helvetica, '7', palette.light0) then addDigitToAnswer(7) end
    if button(tlx + d, tly, size, size, palette.neutral_orange, helvetica, '8', palette.light0) then addDigitToAnswer(8) end
    if button(tlx + d * 2, tly, size, size, palette.neutral_orange, helvetica, '9', palette.light0) then addDigitToAnswer(9) end

    if button(tlx, tly + d, size, size, palette.neutral_orange, helvetica, '4', palette.light0) then addDigitToAnswer(4) end
    if button(tlx + d, tly + d, size, size, palette.neutral_orange, helvetica, '5', palette.light0) then addDigitToAnswer(5) end
    if button(tlx + d * 2, tly + d, size, size, palette.neutral_orange, helvetica, '6', palette.light0) then
        addDigitToAnswer(6)
    end

    if button(tlx, tly + d * 2, size, size, palette.neutral_orange, helvetica, '1', palette.light0) then addDigitToAnswer(1) end
    if button(tlx + d, tly + d * 2, size, size, palette.neutral_orange, helvetica, '2', palette.light0) then
        addDigitToAnswer(2)
    end
    if button(tlx + d * 2, tly + d * 2, size, size, palette.neutral_orange, helvetica, '3', palette.light0) then
        addDigitToAnswer(3)
    end

    if button(tlx, tly + d * 3, size + d, size, palette.neutral_orange, helvetica, '0', palette.light0) then
        addDigitToAnswer(0)
    end
    if button(tlx + d * 2, tly + d * 3, size, size, palette.neutral_orange, helveticasmall, 'ok', palette.light0) then
        if answerIsCorrect() then 
        else 
            print(calculation.a .. ' '..calculation.operation..' ' .. calculation.b, getAnswer(calculation.a, calculation.b, calculation.operation)) 
        end

        answer = ''
        newCalculation()
    end
    --  button(tlx + d * 2, tly + d * 3, size, size, palette.neutral_orange, helvetica, 'C', palette.light0)
    -- button(tlx + d * 3, tly + d, size, size + d, palette.neutral_yellow, helvetica, '=', palette.light0)
end

function love.update()
    if last and last.time > 0 then
        last.time = last.time - 1
        if last.time <= 0 then last = nil end
    end
end

local function printCentered(text, centerX)
    local strWidth = vag:getWidth(text)
    love.graphics.print(text, centerX - strWidth / 2)
end


function love.draw()
    ui.handleMouseClickStart()
    love.graphics.clear(palette.dark1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg)
    love.graphics.setFont(vag)


    local widthXXX = vag:getWidth('XXX')
    local widthXX = vag:getWidth('XXXX')
    local widthXXXXXX = vag:getWidth('XXXXXXX')


    -- Print the first number centered
    local formattedA = string.format("%2d", calculation.a)
    printCentered(formattedA, widthXX / 2)

    -- Print the operation symbol
    printCentered(calculation.operation, widthXX)

    -- Print the second number centered
    local formattedB = string.format("%2d", calculation.b)
    printCentered(formattedB, widthXX + widthXX / 2)

    -- Print the equals sign
    love.graphics.print("=", widthXXXXXX)




    -- local strW = vag:getWidth(str)
    local strH = vag:getHeight()
    local totalW = vag:getWidth('XXX')
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', vag:getWidth('XXXXXXXX'), 0, totalW, strH, strH / 10, strH / 10)


    if last then
        local alpha = last.time / 100

        if last.result then
            love.graphics.setColor(palette.bright_green[1], palette.bright_green[2], palette.bright_green[3], alpha)
        else
            love.graphics.setColor(palette.bright_red[1], palette.bright_red[2], palette.bright_red[3], alpha)
        end
        love.graphics.rectangle('fill', vag:getWidth('XXXXXXXX'), 0, totalW, strH, strH / 10, strH / 10)

        if last.result then
            love.graphics.setColor(palette.bright_yellow[1], palette.bright_yellow[2], palette.bright_yellow[3], alpha)
            love.graphics.print(last.answer, vag:getWidth('XXXXXXXX'))
        end
        if not last.result then
            love.graphics.setColor(palette.dark0[1], palette.dark0[2], palette.dark0[3], alpha)
            love.graphics.print(last.answer, vag:getWidth('XXXXXXXX'))
        end
    end

    love.graphics.setColor(palette.light0)
    love.graphics.print(answer, vag:getWidth('XXXXXXXX'))

    love.graphics.setColor(palette.light0)
    love.graphics.setFont(helvetica)

    local w, h = love.graphics.getDimensions()
    makeNumpad(w / 2, 100)
end
