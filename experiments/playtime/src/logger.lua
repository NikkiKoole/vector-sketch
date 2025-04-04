-- src/logger.lua
local Logger = {}
Logger.__index = Logger

-- Store original print function safely
local _old_print = print

function Logger:new()
    local instance = setmetatable({}, Logger)
    -- You could add log levels, file output etc. here later
    return instance
end

-- Generic log function
function Logger:_log(level, ...)
    local info = debug.getinfo(3, "Sl") -- 3 levels up: _log -> info/warn/error -> caller
    local source = info.short_src or "unknown"
    local line = info.currentline > 0 and info.currentline or "?"
    -- Basic formatting
    local prefix = string.format("[%s] %s:%s:", level, source, line)
    -- Use the original print function for output
    _old_print(prefix, ...)
end

-- Specific level methods
function Logger:info(...)
    self:_log("INFO", ...)
end

function Logger:warn(...)
    self:_log("WARN", ...)
end

function Logger:error(...)
    self:_log("ERROR", ...)
end

function Logger:debug(...)
    -- Add a flag check if you only want debug logs sometimes
    -- if DEBUG_ENABLED then
    self:_log("DEBUG", ...)
    -- end
end

return Logger
