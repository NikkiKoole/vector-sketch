local base1 = '/Users/nikkikoole/Projects/love/vector-sketch'
local base2 = '/Users/nikkikoole/Projects/vector-sketch'

local function mountZip(filename, mountpoint)
    --print(filename)
    local f = io.open(filename, 'r')
    if f then
        local filedata = love.filesystem.newFileData(f:read("*all"), filename)
        f:close()
        local result = love.filesystem.mount(filedata, mountpoint or 'zip')
        --print(inspect(result))
        printC({ fg = 'black', bg = 'magenta' }, "loaded resources file :" .. filename)
        return result
    else
        printC({ fg = 'black', bg = 'red' }, "could not load resources file :" .. filename)
    end
end

if false then
    mountZip(base1 .. '/resources.zip', '')
    mountZip(base2 .. '/resources.zip', '')
end
