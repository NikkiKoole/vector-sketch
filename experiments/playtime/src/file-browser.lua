-- this thing needs to be able to show files visually, lets start with just showing the filetype im after given a subdir.

local lib = {}


function lib:loadFiles(path, filterrules)
    local all_items = love.filesystem.getDirectoryItems(path)
    local filtered = {}
    for _, item in ipairs(all_items) do

        local info = love.filesystem.getInfo(path..'/'..item)
        if info and (info.type == "file") then
            local ok = true
            if filterrules then
                if filterrules.includes then
                    local str = item
                    local index = string.find(str, filterrules.includes)
                    if not index  then
                        ok = false
                    end
                end
                if filterrules.excludes then
                    local str = item
                    local index = string.find(str, filterrules.excludes)
                    if index then
                        ok = false
                    end
                end
            end

            if ok then
                table.insert(filtered, {info=info, path=path, item=item})
            end

        end
       -- count = count + 1
    end

    for i= 1, #filtered do
        print(filtered[i].item)
    end

    logger:info('count:',#filtered)
    -- Apply current search_query to filter files
    --self:filterFiles()

    -- Adjust scroll_offset and selected_index if necessary
    --if self.scroll_offset > 0 and (self.scroll_offset + self.max_display_items) > #self.filtered_files then
    --    self.scroll_offset = math.max(0, #self.filtered_files - self.max_display_items)
    --    self.selected_index = math.min(self.selected_index, #self.filtered_files)
    --end
end

return lib
