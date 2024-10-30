-- commander.lua

local utf8 = require("utf8")

local Commander = {}
Commander.__index = Commander

-- === Commander Class ===

function Commander:new()
    local obj = {
        -- File Management Variables
        all_files = {},      -- Complete list of files in the current directory
        filtered_files = {}, -- List of files filtered based on search_query
        selected_index = 1,
        root_path = '',      -- THIS WILL LIMIT MOVING UP WITH ..
        current_path = "",
        scroll_offset = 0,
        max_display_items = 20,
        line_height = 24,

        -- Font
        retro_font = nil,

        -- Layout Constants
        TEXT_PADDING = 4,
        TEXT_SIZE = 24,
        SEARCH_BAR_Y = 0,
        SEARCH_BAR_HEIGHT = 0, -- To be calculated based on TEXT_SIZE and TEXT_PADDING
        CURRENT_PATH_Y = 0,
        FRAME_X = 5,
        FRAME_Y = 0,
        FRAME_WIDTH = 610,
        FRAME_PADDING = 5,
        FILE_START_X = 15,
        FILE_START_Y = 0,

        -- Search Bar Variables
        search_query = "",

        -- Popup Variables
        popup = {
            active = false,
            input = "",
            placeholder = "Enter new file name...",
            prompt = "Create New File:",
            x = 0, -- To be set dynamically based on window size
            y = 0, -- To be set dynamically based on window size
            width = 600,
            height = 100,
            bgColor = { 0.1, 0.1, 0.1, 0.9 }, -- Semi-transparent dark background
            borderColor = { 1, 1, 1, 1 },     -- White border
            textColor = { 1, 1, 1, 1 },       -- White text
            instructions = "Enter to create, Esc to cancel.",
        },

        -- Double-Click Detection Variables
        last_clicked_index = nil,
        last_click_time = 0,
        double_click_threshold = 0.3, -- seconds

        -- Confirmation Dialog (Placeholder for future use)
        show_confirm = false,
    }
    setmetatable(obj, Commander)
    return obj
end

-- === Helper Functions ===

-- Function to sanitize the filename
function Commander:sanitizeFilename(name)
    -- Remove any path separators to prevent directory traversal
    name = name:gsub("[/\\]", "")
    -- Remove other unwanted characters
    name = name:gsub("[<>:%*%?\"|]", "")
    return name
end

-- Function to create a new file
function Commander:createNewFile(filename)
    -- Sanitize filename
    local sanitized_filename = self:sanitizeFilename(filename)

    if sanitized_filename == "" then
        print("Invalid filename. Please enter a valid name.")
        return
    end

    local path = self.current_path ~= "" and (self.current_path .. "/" .. sanitized_filename) or sanitized_filename

    -- Check if the file already exists
    if love.filesystem.getInfo(path) then
        print("File already exists: " .. path)
        return
    end

    -- Create an empty file
    local success, message = love.filesystem.write(path, "")
    if success then
        print("Created new file: " .. path)
        -- Refresh the file list
        self:loadFiles()
    else
        print("Failed to create file: " .. message)
    end
end

-- Function to filter files based on search_query
function Commander:filterFiles()
    if self.search_query == "" then
        self.filtered_files = {}
        for _, file in ipairs(self.all_files) do
            table.insert(self.filtered_files, file)
        end
    else
        self.filtered_files = {}
        local lower_query = string.lower(self.search_query)
        for _, file in ipairs(self.all_files) do
            if string.find(string.lower(file), lower_query, 1, true) then
                table.insert(self.filtered_files, file)
            end
        end
    end

    -- Reset selection and scroll
    self.selected_index = 1
    self.scroll_offset = 0
end

-- Function to load files from the current directory
function Commander:loadFiles()
    local all_items = love.filesystem.getDirectoryItems(self.current_path)
    self.all_files = {}

    -- Insert '..' to allow navigating to the parent directory if not at root
    if self.current_path ~= self.root_path then
        table.insert(self.all_files, "..")
    end

    for _, item in ipairs(all_items) do
        local path = self.current_path ~= "" and (self.current_path .. "/" .. item) or item
        local info = love.filesystem.getInfo(path)
        if info and (info.type == "directory" or true) then -- Modify 'true' to add specific file filters if needed
            table.insert(self.all_files, item)
        end
    end

    -- Apply current search_query to filter files
    self:filterFiles()

    -- Adjust scroll_offset and selected_index if necessary
    if self.scroll_offset > 0 and (self.scroll_offset + self.max_display_items) > #self.filtered_files then
        self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
        self.selected_index = math.min(self.selected_index, #self.filtered_files)
    end
end

-- Function to list all files in the save directory
function Commander:listSaveDirectoryFiles()
    local saveDir = love.filesystem.getSaveDirectory()
    print("Listing files in Save Directory:", saveDir)

    local files = love.filesystem.getDirectoryItems(saveDir)
    for _, file in ipairs(files) do
        print(file)
    end
end

-- Function to load a file (Placeholder for actual loading logic)
function Commander:loadFile(path)
    local content, size = love.filesystem.read(path)
    if content then
        -- Process the content (e.g., load save state)
        print("Loaded file: " .. path .. " (" .. size .. " bytes)")
    else
        print("Failed to load file: " .. path)
    end
end

-- Function to handle item selection (single or double-click)
function Commander:handleItemSelection(clicked_index, is_double_click)
    if is_double_click then
        local selected_item = self.filtered_files[clicked_index]
        local path = self.current_path ~= "" and (self.current_path .. "/" .. selected_item) or selected_item
        local info = love.filesystem.getInfo(path)

        if selected_item == ".." then
            -- Navigate to parent directory
            if self.current_path ~= "" then
                self.current_path = self.current_path:match("^(.*)/") or ""
                self:loadFiles()
                self.selected_index = 1
                self.scroll_offset = 0
            end
        elseif info and info.type == "directory" then
            -- Navigate into the selected directory
            self.current_path = path
            self:loadFiles()
            self.selected_index = 1
            self.scroll_offset = 0
        elseif info and info.type == "file" then
            -- Load the selected file
            self:loadFile(path)
        end
    else
        -- Single click: select the item
        self.selected_index = clicked_index

        -- Adjust scroll_offset if necessary
        if self.selected_index > self.scroll_offset + self.max_display_items then
            self.scroll_offset = self.scroll_offset + 1
        elseif self.selected_index < self.scroll_offset + 1 and self.scroll_offset > 0 then
            self.scroll_offset = self.scroll_offset - 1
        end
    end
end

-- Function to draw the popup
function Commander:drawPopup()
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Draw popup background
    love.graphics.setColor(self.popup.bgColor)
    love.graphics.rectangle("fill", self.popup.x, self.popup.y, self.popup.width, self.popup.height)

    -- Draw popup border
    love.graphics.setColor(self.popup.borderColor)
    love.graphics.rectangle("line", self.popup.x, self.popup.y, self.popup.width, self.popup.height)

    -- Draw prompt text
    love.graphics.setColor(self.popup.textColor)
    love.graphics.print(self.popup.prompt, self.popup.x + 10, self.popup.y + 10)

    -- Draw input field
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.popup.x + 10, self.popup.y + 40, self.popup.width - 20, self.line_height)

    -- Draw input text or placeholder
    if self.popup.input == "" then
        love.graphics.setColor(0.7, 0.7, 0.7) -- Gray color for placeholder
        love.graphics.print(self.popup.placeholder, self.popup.x + 15, self.popup.y + 45)
    else
        love.graphics.setColor(self.popup.textColor)
        love.graphics.print(self.popup.input, self.popup.x + 15, self.popup.y + 45)
    end

    -- Draw instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.popup.instructions, self.popup.x + 10, self.popup.y + self.popup.height - 25)
end

-- Function to open the popup
function Commander:openPopup()
    self.popup.active = true
    self.popup.input = ""
end

-- Function to close the popup
function Commander:closePopup()
    self.popup.active = false
    self.popup.input = ""
end

-- === Love2D Callbacks ===

-- Load function
function Commander:load()
    love.keyboard.setKeyRepeat(true)
    love.graphics.setLineWidth(3)
    -- Load a retro font (ensure the path is correct)
    self.retro_font = love.graphics.newFont("SMW.Whole-Pixel.Spacing.ttf", self.TEXT_SIZE) -- Adjust font size as needed
    love.graphics.setFont(self.retro_font)

    -- Dynamically set line height based on font metrics
    self.line_height = self.retro_font:getHeight() + self.TEXT_PADDING -- Adjust padding as needed

    -- Dynamically calculate max_display_items based on window height
    self.max_display_items = math.max(1,
        math.floor((love.graphics.getHeight() - self.FILE_START_Y - 10) / self.line_height))

    -- Calculate layout positions
    self.SEARCH_BAR_HEIGHT = self.TEXT_SIZE + self.TEXT_PADDING * 2 + 5
    self.CURRENT_PATH_Y = self.SEARCH_BAR_Y + self.SEARCH_BAR_HEIGHT + 5
    self.FRAME_Y = self.CURRENT_PATH_Y + self.line_height + 10
    self.FILE_START_Y = self.FRAME_Y + self.FRAME_PADDING + 5

    -- Set popup position to center
    self.popup.x = (love.graphics.getWidth() - self.popup.width) / 2
    self.popup.y = (love.graphics.getHeight() - self.popup.height) / 2

    love.window.setTitle("=== Nikki Commander 1.0 ===")
    self:loadFiles()
    self:listSaveDirectoryFiles()
end

-- Resize function
function Commander:resize(w, h)
    -- Recalculate max_display_items based on new window size
    self.max_display_items = math.max(1, math.floor((h - self.FILE_START_Y - 10) / self.line_height))

    -- Adjust scroll_offset and selected_index if necessary
    if self.scroll_offset + self.max_display_items > #self.filtered_files then
        self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
        self.selected_index = math.min(self.selected_index, #self.filtered_files)
    end

    -- Recalculate layout positions
    self.SEARCH_BAR_HEIGHT = self.TEXT_SIZE + self.TEXT_PADDING * 2 + 5
    self.CURRENT_PATH_Y = self.SEARCH_BAR_Y + self.SEARCH_BAR_HEIGHT + 5
    self.FRAME_Y = self.CURRENT_PATH_Y + self.line_height + 10
    self.FILE_START_Y = self.FRAME_Y + self.FRAME_PADDING + 5

    -- Reposition popup to remain centered
    if self.popup.active then
        self.popup.x = (w - self.popup.width) / 2
        self.popup.y = (h - self.popup.height) / 2
    end
end

-- Draw function
function Commander:draw()
    -- Clear the screen with a dark blue background
    love.graphics.clear(0, 0, 0.5)

    -- Draw search bar background
    love.graphics.setColor(0.2, 0.2, 0.2) -- Dark background for search bar
    love.graphics.rectangle("fill", self.FRAME_X, self.SEARCH_BAR_Y, self.FRAME_WIDTH, self.SEARCH_BAR_HEIGHT)

    -- Draw search bar border
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.FRAME_X, self.SEARCH_BAR_Y, self.FRAME_WIDTH, self.SEARCH_BAR_HEIGHT)

    -- Draw search query with placeholder
    if self.search_query == "" then
        love.graphics.setColor(0.7, 0.7, 0.7) -- Gray color for placeholder
        love.graphics.print("Search...", self.FRAME_X + 5, self.SEARCH_BAR_Y + 5)
    else
        love.graphics.setColor(1, 1, 1) -- White color for user input
        love.graphics.print("Search: " .. self.search_query, self.FRAME_X + 5, self.SEARCH_BAR_Y + 5)
    end

    -- Draw current path
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current Path: /" .. self.current_path, self.FRAME_X, self.CURRENT_PATH_Y)

    -- Draw frame for file list
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.FRAME_X, self.FRAME_Y, self.FRAME_WIDTH,
        (self.max_display_items * self.line_height) + 10)

    -- Draw file list
    for i = self.scroll_offset + 1, math.min(self.scroll_offset + self.max_display_items, #self.filtered_files) do
        local display_name = self.filtered_files[i]
        local path = self.current_path ~= "" and (self.current_path .. "/" .. self.filtered_files[i]) or
            self.filtered_files[i]
        local y_position = self.FILE_START_Y + ((i - self.scroll_offset - 1) * self.line_height)

        -- Append '/' to directories, including '..'
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            display_name = display_name .. "/"
        end

        if i == self.selected_index then
            love.graphics.setColor(1, 1, 0) -- Yellow background
            love.graphics.rectangle("fill", 10, y_position, 600, self.line_height)
            love.graphics.setColor(0, 0, 0) -- Black text

            -- Calculate vertical offset for centering
            local text_offset = (self.line_height - self.retro_font:getHeight()) / 2
            love.graphics.print(display_name, self.FILE_START_X, y_position + text_offset)
        else
            love.graphics.setColor(1, 1, 1)                                      -- White text
            love.graphics.print(display_name, self.FILE_START_X, y_position + 4) -- Adjust as needed
        end
    end

    -- Draw scroll indicators
    if self.scroll_offset > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("^", self.FRAME_X + self.FRAME_WIDTH - 10, self.FRAME_Y - 20)
    end

    if self.scroll_offset + self.max_display_items < #self.filtered_files then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("v", self.FRAME_X + self.FRAME_WIDTH - 10,
            self.FRAME_Y + (self.max_display_items * self.line_height) + 5)
    end

    -- Draw the popup if active
    if self.popup.active then
        self:drawPopup()
    end
end

-- Handle text input for the search bar and popup
function Commander:textinput(t)
    if self.popup.active then
        -- Append text to popup input
        self.popup.input = self.popup.input .. t
    else
        -- Append text to search_query
        self.search_query = self.search_query .. t
        self:filterFiles()
    end
end

-- Handle keypresses for the search bar and popup
function Commander:keypressed(key)
    if self.popup.active then
        -- Handle popup input
        if key == "return" then
            -- Confirm creation of the new file
            if self.popup.input ~= "" then
                self:createNewFile(self.popup.input)
                self:closePopup()
            end
        elseif key == "escape" then
            -- Cancel file creation
            self:closePopup()
        elseif key == "backspace" then
            -- Remove last character from popup input
            local byteoffset = utf8.offset(self.popup.input, -1)
            if byteoffset then
                self.popup.input = string.sub(self.popup.input, 1, byteoffset - 1)
            end
        end
    else
        -- Handle normal input (search bar and navigation)

        -- Handle search input keys
        if key == "backspace" then
            -- Remove last character from search_query
            local byteoffset = utf8.offset(self.search_query, -1)
            if byteoffset then
                self.search_query = string.sub(self.search_query, 1, byteoffset - 1)
                self:filterFiles()
            end
        elseif key == "escape" then
            -- Clear search query or quit if already cleared
            if self.search_query ~= "" then
                self.search_query = ""
                self:filterFiles()
            else
                love.event.quit()
            end
        end

        -- Handle navigation keys
        if key == "up" then
            if self.selected_index > 1 then
                self.selected_index = self.selected_index - 1
                if self.selected_index < self.scroll_offset + 1 then
                    self.scroll_offset = self.scroll_offset - 1
                end
            end
        elseif key == "down" then
            if self.selected_index < #self.filtered_files then
                self.selected_index = self.selected_index + 1
                if self.selected_index > self.scroll_offset + self.max_display_items then
                    self.scroll_offset = self.scroll_offset + 1
                end
            end
        elseif key == "pageup" then
            if self.scroll_offset > 0 then
                -- Calculate new scroll_offset
                self.scroll_offset = math.max(0, self.scroll_offset - self.max_display_items)
                -- Calculate new selected_index
                self.selected_index = math.max(1, self.selected_index - self.max_display_items)
            else
                -- If already at the top, jump to the first item
                self.selected_index = 1
            end
        elseif key == "pagedown" then
            if self.scroll_offset + self.max_display_items < #self.filtered_files then
                -- Calculate new scroll_offset
                self.scroll_offset = self.scroll_offset + self.max_display_items
                -- Calculate new selected_index
                self.selected_index = math.min(#self.filtered_files, self.selected_index + self.max_display_items)
            else
                -- If near the bottom, jump to the last visible item
                self.selected_index = #self.filtered_files
                self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
            end
        elseif key == "return" or key == "right" then
            local selected_item = self.filtered_files[self.selected_index]
            local path = self.current_path ~= "" and (self.current_path .. "/" .. selected_item) or selected_item
            local info = love.filesystem.getInfo(path)

            if selected_item == ".." then
                -- Navigate to parent directory
                if self.current_path ~= "" then
                    self.current_path = self.current_path:match("^(.*)/") or ""
                    self:loadFiles()
                    self.selected_index = 1
                    self.scroll_offset = 0
                end
            elseif info and info.type == "directory" then
                -- Navigate into the selected directory
                self.current_path = path
                self:loadFiles()
                self.selected_index = 1
                self.scroll_offset = 0
            elseif info and info.type == "file" then
                -- Load the selected file
                self:loadFile(path)
            end
        elseif key == "n" and self.search_query == "" then
            -- Press 'n' to open the popup for creating a new file
            self:openPopup()
        elseif key == "left" then
            -- Optionally, allow left arrow to act like backspace for navigation
            if self.current_path ~= "" then
                self.current_path = self.current_path:match("^(.*)/") or ""
                self:loadFiles()
                self.selected_index = 1
                self.scroll_offset = 0
            end
        elseif key == "home" then
            self.selected_index = 1
            self.scroll_offset = 0
        elseif key == "end" then
            self.selected_index = #self.filtered_files
            self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
        end

        -- Add debug prints (optional)
        print("Key Pressed:", key)
        print("Selected Index:", self.selected_index)
        print("Scroll Offset:", self.scroll_offset)
    end
end

-- Handle mouse presses for selecting and double-clicking items
function Commander:mousepressed(x, y, button)
    if self.popup.active then
        -- Optional: Handle clicks within the popup if needed
        return
    end

    if button == 1 then
        local item_height = self.line_height
        local clicked_index = math.floor((y - self.FILE_START_Y) / item_height) + self.scroll_offset + 1
        if clicked_index >= 1 and clicked_index <= #self.filtered_files then
            local current_time = love.timer.getTime()
            if self.last_clicked_index == clicked_index and (current_time - self.last_click_time) < self.double_click_threshold then
                -- Double-click detected
                self:handleItemSelection(clicked_index, true)
                self.last_clicked_index = nil
                self.last_click_time = 0
            else
                -- Single click
                self:handleItemSelection(clicked_index, false)
                self.last_clicked_index = clicked_index
                self.last_click_time = current_time
            end
        end
    end
end

function Commander:mousereleased(x, y, button)
    -- No action needed here for double-click logic
end

-- Handle mouse wheel for scrolling
function Commander:wheelmoved(x, y)
    if self.popup.active then
        -- Optional: Handle scrolling within the popup if needed
        return
    end

    if y > 0 then
        -- Scroll up
        if self.scroll_offset > 0 then
            self.scroll_offset = self.scroll_offset - 1
            if self.selected_index > 1 then
                self.selected_index = self.selected_index - 1
            end
        end
    elseif y < 0 then
        -- Scroll down
        if self.scroll_offset + self.max_display_items < #self.filtered_files then
            self.scroll_offset = self.scroll_offset + 1
            if self.selected_index < #self.filtered_files then
                self.selected_index = self.selected_index + 1
            end
        end
    end

    -- Add debug prints (optional)
    print("Wheel Moved:", y)
    print("Selected Index:", self.selected_index)
    print("Scroll Offset:", self.scroll_offset)
end

-- === Module Return ===

return Commander
