local screenshotRequested = false
local screenshotFilename = ""


function love.load(arg)
    love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
    -- Check for command line arguments and navigate to the appropriate screen
    for i, v in ipairs(arg) do
        if v == "--screenshot-main" then
            navigateToMainScreen()
            screenshotRequested = true
            screenshotFilename = "screenshot_main.png"
        elseif v == "--screenshot-settings" then
            navigateToSettingsScreen()
            screenshotRequested = true
            screenshotFilename = "screenshot_settings.png"
        elseif v == "--screenshot-profile" then
            navigateToProfileScreen()
            screenshotRequested = true
            screenshotFilename = "screenshot_profile.png"
        elseif v == "--screenshot-game" then
            navigateToGameScreen()
            screenshotRequested = true
            screenshotFilename = "screenshot_game.png"
        elseif v == "--screenshot-summary" then
            navigateToSummaryScreen()
            screenshotRequested = true
            screenshotFilename = "screenshot_summary.png"
        end
    end
end

function navigateToMainScreen()
    -- Replace with logic to navigate to the main screen
    print("Navigating to Main Screen")
    -- Simulate screen rendering
    love.graphics.setBackgroundColor(1, 0, 0)
end

function navigateToSettingsScreen()
    -- Replace with logic to navigate to the settings screen
    print("Navigating to Settings Screen")
    -- Simulate screen rendering
    love.graphics.setBackgroundColor(0, 1, 0)
end

function navigateToProfileScreen()
    -- Replace with logic to navigate to the profile screen
    print("Navigating to Profile Screen")
    -- Simulate screen rendering
    love.graphics.setBackgroundColor(0, 0, 1)
end

function navigateToGameScreen()
    -- Replace with logic to navigate to the game screen
    print("Navigating to Game Screen")
    -- Simulate screen rendering
    love.graphics.setBackgroundColor(1, 1, 0)
end

function navigateToSummaryScreen()
    -- Replace with logic to navigate to the summary screen
    print("Navigating to Summary Screen")
    -- Simulate screen rendering
    love.graphics.setBackgroundColor(1, 0, 1)
end

function love.draw()
    -- Ensure something is drawn on the screen
    love.graphics.print("Screen Content", 400, 300)

    -- Check if a screenshot has been requested
    if screenshotRequested then
        -- Capture the screenshot
        love.graphics.print(screenshotFilename, 400, 350)
        love.graphics.captureScreenshot(screenshotFilename)

        screenshotRequested = false
        -- Quit the app after taking the screenshot
        love.event.quit()
    end
end
