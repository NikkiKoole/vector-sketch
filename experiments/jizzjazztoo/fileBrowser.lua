function createFilePath(root, subdirs)
    local path = root
    for i = 1, #subdirs do
        if subdirs[i] then
            path = path .. '/' .. subdirs[i]
        end
    end
    return path
end

function TableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

local verticalCount = 0
function handleFileBrowserWheelMoved(browser, a, b)
    browser.scrollTop = browser.scrollTop + b
    if browser.scrollTop < 0 then browser.scrollTop = 0 end
    print(verticalCount, #browser.all)
    local maxScrollTop = math.max(#browser.all - verticalCount, 0)
    print(maxScrollTop)
    if browser.scrollTop > maxScrollTop then browser.scrollTop = maxScrollTop end
    browser.scrollTop = math.floor(browser.scrollTop)
    print(browser.scrollTop)
end

function fileBrowser(rootPath, subdirs, allowedExtensions)
    local path = createFilePath(rootPath, subdirs)
    local all = love.filesystem.getDirectoryItems(path);
    local files = {}
    local directories = {}

    if #subdirs > 0 then
        table.insert(directories, { path = '..', type = 'directory' })
    end

    for i = 1, #all do
        local t = love.filesystem.getInfo(path .. '/' .. all[i]).type

        if t == 'file' then
            if allowedExtensions then
                for j = 1, #allowedExtensions do
                    if ends_with(all[i], allowedExtensions[j]) then
                        table.insert(files, { path = all[i], type = 'file' })
                    end
                end
            else
                table.insert(files, { path = all[i], type = 'file' })
            end
        end

        if t == 'directory' then
            table.insert(directories, { path = all[i], type = 'directory' })
        end
    end

    return {
        root = rootPath,
        subdirs = subdirs,
        files = files,
        directories = directories,
        all = TableConcat(directories, files),
        allowedExtensions = allowedExtensions,
        -- allowedToUseFolders = allowedToUseFolders,
        scrollTop = 0
    }
end

function renderBrowser(browser, x, y, w, h, font)
    --if not browser then return end

    local runningX, runningY

    browser.x = x
    browser.y = y
    --browser.h = h
    --runningX = 20
    runningY = browser.y
    local buttonWidth = w
    local buttonHeight = font:getHeight()
    local amount = h / buttonHeight
    browser.amount = amount
    verticalCount = math.floor(h / buttonHeight)
    h = math.min(h, buttonHeight * #browser.all)
    love.graphics.setScissor(x, y, w, h)
    love.graphics.setColor(palette.bg0)
    love.graphics.rectangle('fill', x, y, w, h)

    local mx, my = love.mouse.getPosition()

    for i = 1 + browser.scrollTop, math.min(#browser.all, browser.scrollTop + amount) do
        local thing = browser.all[i]
        --if thing then
        if mx > x and mx < x + w and my > runningY and my < runningY + buttonHeight then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle('fill', x, runningY, w, buttonHeight)
        end
        if thing.type == 'directory' then
            --love.graphics.setColor(palette.red)
            --love.graphics.rectangle('fill', x, runningY, buttonWidth, buttonHeight)

            love.graphics.setColor(palette.yellow)
            love.graphics.print(' ' .. thing.path, x, runningY)
        else
            local filename = thing.path
            if browser.allowedExtensions then
                for j = 1, #browser.allowedExtensions do
                    filename = string.gsub(filename, '.' .. browser.allowedExtensions[j], '')
                end
            end
            if (browser.lastClickedFile and browser.lastClickedFile == thing.path) then
                love.graphics.setColor(palette.orange)
            else
                love.graphics.setColor(1, 1, 0)
                love.graphics.setColor(palette.fg2)
            end

            love.graphics.print(' ' .. filename, x, runningY)
        end
        --end
        runningY = runningY + buttonHeight
    end
    love.graphics.setScissor()
end

function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

function handleBrowserClick(browser, x, y, font)
    --if not browser.x or not browser.y then return end
    local result = false
    local buttonHeight = font:getHeight()
    if x > browser.x and x < browser.x + 200 and y > browser.y then
        local index = math.floor((y - browser.y) / buttonHeight) + 1
        index = index + browser.scrollTop

        local thing = browser.all[index]
        if index > #browser.all then return end
        if not thing then return end
        if thing.type == 'directory' then
            if thing.path == '..' then
                table.remove(browser.subdirs)
            else
                table.insert(browser.subdirs, thing.path)
            end
            result = true
            print('clicked a folder')
        elseif thing.type == 'file' then
            local path = createFilePath(browser.root, browser.subdirs)
            if thing.path then
                browser.lastClickedFile = thing.path
                if ends_with(thing.path, 'wav') or ends_with(thing.path, 'WAV') then
                    --channel.main2audio:push({ osc = { path = thing.path, fullPath = path .. '/' .. thing.path } })
                end
                if ends_with(thing.path, 'lua') then
                    contents, size = love.filesystem.read(path .. '/' .. thing.path)
                    local instr = (loadstring(contents)())
                    --channel.main2audio:push({ loadInstrument = { instrument = instr, path = thing.path } })
                end
                print('clicked a file')
            end
        end
    end

    return result
end
