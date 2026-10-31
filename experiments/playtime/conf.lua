function love.conf(t)
    t.identity = 'playtime'                -- The name of the save directory (string)
    t.appendidentity = false               -- Search files in source directory before save directory (boolean)
    t.version = "11.3"                     -- The LÖVE version this game was made for (string)
    t.console = false                      -- Attach a console (boolean, Windows only)
    t.accelerometerjoystick = true         -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
    t.externalstorage = false              -- True to save files (and read from the save directory) in external storage on Android (boolean)
    t.gammacorrect = false                 -- Enable gamma-correct rendering, when supported by the system (boolean)

    t.audio.mic = false                    -- Request and use microphone capabilities in Android (boolean)
    t.audio.mixwithsystem = true           -- Keep background music playing when opening LOVE (boolean, iOS and Android only)

    t.window.title = "playtime"            -- The window title (string)
    t.window.icon = 'assets/iconagain.png' -- Filepath to an image to use as the window's icon (string)
    t.window.width = 1000                  -- The window width (number)
    t.window.height = 800                  -- The window height (number)
    t.window.borderless = false            -- Remove all border visuals from the window (boolean)
    t.window.resizable = true              -- Let the window be user-resizable (boolean)
    t.window.minwidth = 1                  -- Minimum window width if the window is resizable (number)
    t.window.minheight = 1                 -- Minimum window height if the window is resizable (number)
    t.window.fullscreen = false            -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop"    -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    -- adaptive vsync: a late frame is shown at once (may tear) instead of waiting a whole
    -- refresh. With 1 the crowd scene got stuck at 30 fps: at 30 a frame runs 3 physics
    -- steps (~10 ms) + drawing (~10 ms), too long for 60, so it stayed at 30; with -1 it
    -- climbs to 60 where a frame runs 1-2 steps (~15 ms). LOVE falls back to 1 where
    -- adaptive isn't supported.
    t.window.vsync = -1
    t.window.msaa = 4                      -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.depth = 16                    -- The number of bits per sample in the depth buffer
    t.window.stencil = nil                 -- The number of bits per sample in the stencil buffer
    t.window.display = 1                   -- Index of the monitor to show the window in (number)
    t.window.highdpi = false               -- Enable high-dpi mode for the window on a Retina display (boolean)
    t.window.usedpiscale = false           -- Enable automatic DPI scaling when highdpi is set to true as well (boolean)
    -- Phones draw at their full resolution, in points: the game sees 667x375 on an iPhone SE,
    -- LÖVE draws it at 2x (love._os: love.system isn't loaded yet here).
    -- Fullscreen: no status bar, and SDL defers the system swipes from the edges (Control
    -- Center, notifications, home): a first swipe only shows a tab. Not resizable, so the
    -- window keeps to landscape (the orientations themselves: native/ios/device.sh).
    if love._os == 'iOS' or love._os == 'Android' then
        t.window.highdpi = true
        t.window.usedpiscale = true
        t.window.fullscreen = true
        t.window.resizable = false
    end
    t.window.x = nil                       -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil                       -- The y-coordinate of the window's position in the specified display (number)

    t.modules.audio = true                 -- Enable the audio module (boolean)
    -- Specs open no audio device unless given --audio: a spec run next to the game stopped
    -- the game's synth source when it opened and closed its own (a drop), and played its
    -- sounds out loud. The few specs that play sound are pending without it.
    local specs, audio = false, false
    for _, a in ipairs(arg or {}) do
        if a == '--specs' then specs = true end
        if a == '--audio' then audio = true end
    end
    if specs and not audio then t.modules.audio = false end
    -- Specs need a window for graphics (images, meshes, the UI: without one ~110 fail) and
    -- some read its size; so the normal one, but borderless and far off-screen, so a spec
    -- run doesn't pop up over the game.
    if specs then
        t.window.borderless = true
        t.window.x, t.window.y = -20000, -20000
    end
    t.modules.data = true                  -- Enable the data module (boolean)
    t.modules.event = true                 -- Enable the event module (boolean)
    t.modules.font = true                  -- Enable the font module (boolean)
    t.modules.graphics = true              -- Enable the graphics module (boolean)
    t.modules.image = true                 -- Enable the image module (boolean)
    t.modules.joystick = true              -- Enable the joystick module (boolean)
    t.modules.keyboard = true              -- Enable the keyboard module (boolean)
    t.modules.math = true                  -- Enable the math module (boolean)
    t.modules.mouse = true                 -- Enable the mouse module (boolean)
    t.modules.physics = true               -- Enable the physics module (boolean)
    t.modules.sound = true                 -- Enable the sound module (boolean)
    t.modules.system = true                -- Enable the system module (boolean)
    t.modules.thread = true                -- Enable the thread module (boolean)
    t.modules.timer = true                 -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
    t.modules.touch = true                 -- Enable the touch module (boolean)
    t.modules.video = true                 -- Enable the video module (boolean)
    t.modules.window = true                -- Enable the window module (boolean)
end
