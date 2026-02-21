--[[
    run-specs.lua - Run busted specs inside LÖVE

    Usage:
        love . --specs              (run all specs)
        love . --specs spec/io_spec.lua   (run one file)

    Requires busted installed for Lua 5.1:
        luarocks --lua-version 5.1 install busted
]]

-- Add luarocks 5.1 paths so busted can be found
local home = os.getenv('HOME')
package.path = home .. '/.luarocks/share/lua/5.1/?.lua;'
             .. home .. '/.luarocks/share/lua/5.1/?/init.lua;'
             .. package.path
package.cpath = home .. '/.luarocks/lib/lua/5.1/?.so;'
              .. package.cpath

-- Figure out what spec files to run
local specTarget = 'spec'  -- default: all specs
for i, v in ipairs(arg) do
    if arg[i - 1] == '--specs' and v:match('%.lua$') then
        specTarget = v
    end
end

-- Override arg to look like: busted <specTarget>
arg = { specTarget }
arg[0] = 'busted'
arg[-1] = 'luajit'

-- Intercept os.exit so busted doesn't leave LÖVE hanging
local realExit = os.exit
local exitCode = 0
os.exit = function(code)
    exitCode = code or 0
    -- Don't actually exit — we'll handle it after busted returns
end

-- Run busted
local ok, err = pcall(function()
    require('busted.runner')({ standalone = false })
end)

-- Restore os.exit
os.exit = realExit

if not ok then
    print('Error running busted: ' .. tostring(err))
    love.event.quit(1)
else
    love.event.quit(exitCode)
end
