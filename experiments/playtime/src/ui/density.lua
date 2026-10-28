-- density.lua
-- How padded the editor UI is. 'roomy' is the old spacing, 'compact' keeps the
-- same font and row height but takes out padding (Nikki likes the 25 px font,
-- the padding felt too much). A keep/revert experiment:
-- the choice is saved in editor-density.txt in the save directory, and the
-- 'compact' checkbox in settings switches it live.
local lib = {}

lib.presets = {
    roomy = {
        fontSize = 25, lineHeight = 25, lineWidth = 3, spacing = 10, panelWidth = 300, rowWidth = 160,
        columnTop = 70, toolbarScale = 1,
        -- panel title band, and where hand-placed panel content starts (below panelY)
        panelHeader = 40, contentTop = 80,
        -- inspector rows (src/ui/inspector.lua)
        rowHeight = 45, fieldHeight = 40, widgetDY = 7, labelWidth = 90,
    },
    compact = {
        fontSize = 25, lineHeight = 25, lineWidth = 3, spacing = 6, panelWidth = 300, rowWidth = 160,
        columnTop = 52, toolbarScale = 0.7,
        panelHeader = 32, contentTop = 36,
        rowHeight = 31, fieldHeight = 29, widgetDY = 3, labelWidth = 90,
    },
}

local FILE = 'editor-density.txt'
local current

function lib.name()
    if not current then
        local saved = love.filesystem.getInfo(FILE) and love.filesystem.read(FILE)
        current = (saved and lib.presets[saved]) and saved or 'roomy'
    end
    return current
end

function lib.sizes()
    return lib.presets[lib.name()]
end

-- Put the current sizes into a ui theme table (src/ui/all.lua does this at load).
function lib.applyTheme(theme)
    local s = lib.sizes()
    theme.lineHeight = s.lineHeight
    theme.button.height = s.lineHeight
    theme.slider.height = s.lineHeight
    theme.lineWidth = s.lineWidth
    theme.spacing = s.spacing
    theme.panelWidth = s.panelWidth
    theme.rowWidth = s.rowWidth
    theme.columnTop = s.columnTop
    theme.toolbarScale = s.toolbarScale
    theme.panelHeader = s.panelHeader
    theme.contentTop = s.contentTop
end

function lib.makeFont()
    return love.graphics.newFont('assets/Arial Narrow.ttf', lib.sizes().fontSize)
end

-- Modules that copy sizes into locals when they load; switching re-runs them.
lib.MODULES = {
    'src.ui.inspector', 'src.ui.world-settings', 'src.ui.recording-panel', 'src.ui.shape-panel',
    'src.ui.joint-update', 'src.ui.body-editor', 'src.ui.mipo-editor', 'src.ui.sfixture-editor',
    'src.ui.on-stage', 'src.ui.library-tab', 'src.ui.right-column', 'src.playtime-ui',
}

-- Switch to another density: save it, resize the theme and the font, and re-run
-- the UI modules. Call it between frames, not from inside a panel.
function lib.set(name)
    if not lib.presets[name] then return end
    current = name
    love.filesystem.write(FILE, name)
    local ui = require('src.ui.all')
    lib.applyTheme(ui.theme)
    local font = lib.makeFont()
    love.graphics.setFont(font)
    ui.init(font, lib.sizes().fontSize)
    local lume = require('vendor.lume')
    for _, modname in ipairs(lib.MODULES) do
        if package.loaded[modname] then lume.hotswap(modname) end
    end
end

return lib
