package.path = package.path .. ";../../?.lua"

local lurker = require 'vendor.lurker'
lurker.quiet = true

lurker.postswap = function(f)
   print("File " .. f .. " was swapped")
   grabDevelopmentScreenshot()
end


function grabDevelopmentScreenshot()


    print(os.date())

    love.graphics.captureScreenshot('ScreenShot-'..os.date("%Y-%m-%d-[%H-%M-%S]")..'.png' )
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end


function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end

function love.load()
    grabDevelopmentScreenshot()
end

function love.update()

    lurker.update()
end