local lib = {}
-- Utility function to concatenate two tables.

-- Define the map function
function lib.map(tbl, func)
    local new_tbl = {}
    for i, v in ipairs(tbl) do
        new_tbl[i] = func(v)
    end
    return new_tbl
end

function lib.trace(...)
    local info = debug.getinfo(2, "Sl")
    local t = { info.short_src .. ":" .. info.currentline .. ":" }
    for i = 1, select("#", ...) do
        local x = select(i, ...)
        if type(x) == "number" then
            x = string.format("%g", lib.round_to_decimals(x, 2))
        end
        t[#t + 1] = tostring(x)
    end
    print(table.concat(t, " "))
end

function lib.insertNewlines(str, interval)
    local result = {}
    local length = #str
    for i = 1, length, interval do
        table.insert(result, str:sub(i, i + interval - 1))
    end
    return table.concat(result, "\n")
end

-- Utility function to get the difference between two paths
function lib.getPathDifference(base, full)
    -- Ensure both inputs are strings
    if type(base) ~= "string" or type(full) ~= "string" then
        error("Both base and full paths must be strings")
    end

    -- If the paths are identical, return an empty string
    if full == base then
        return ""
    end

    -- Check if the base path is a prefix of the full path
    if full:sub(1, #base) == base then
        -- Ensure that the base path ends at a directory boundary
        -- i.e., the next character should be '/' or the full path should end here
        local nextChar = full:sub(#base + 1, #base + 1)
        if nextChar == "/" then
            -- Extract the remaining part of the path
            return full:sub(#base + 1)
        end
    end

    -- If base is not a proper prefix, return nil or handle accordingly
    return nil
end

function lib.sanitizeString(input)
    if not input then return "" end   -- Handle nil or empty strings
    return input:gsub("[%c%s]+$", "") -- Remove control characters and trailing spaces
end

function lib.round_to_decimals(num, dec)
    local multiplier = 10 ^ dec -- 10^4 for 4 decimal places
    return math.floor(num * multiplier + 0.5) / multiplier
end

function lib.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function lib.printTableKeys(tbl)
    for key, _ in pairs(tbl) do
        print(key)
    end
end

function lib.tableConcat(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

function lib.shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

-- Function to compare two tables for equality (assuming they are arrays of numbers)
function lib.tablesEqualNumbers(t1, t2)
    -- Check if both tables have the same number of elements
    if #t1 ~= #t2 then
        return false
    end

    -- Compare each corresponding element
    for i = 1, #t1 do
        if t1[i] ~= t2[i] then
            return false
        end
    end

    return true
end

return lib
