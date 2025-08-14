--utils.lua

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
    logger:info(table.concat(t, " "))
end

function lib.getPathDifference(base, full)
    -- Ensure both inputs are strings
    if type(base) ~= "string" or type(full) ~= "string" then
        error("Both base and full paths must be strings")
    end

    -- Handle root path explicitly
    if base == "/" then
        if full:sub(1, 1) == "/" then
            return full:sub(2) -- Return path without leading slash
        else
            return full        -- Should not happen if full is absolute, but handle anyway
        end
    end

    -- If the paths are identical, return an empty string
    if full == base then
        return ""
    end

    -- Check if the base path is a prefix of the full path
    if full:sub(1, #base) == base then
        -- Ensure that the base path ends at a directory boundary
        local nextChar = full:sub(#base + 1, #base + 1)
        if nextChar == "/" then
            -- Extract the remaining part of the path
            return full:sub(#base + 1)
            -- Check if the base is the entire path except for the final segment without a leading slash
            -- This case seems less common for absolute paths but might occur.
        elseif nextChar == "" then
            return "" -- Or maybe nil depending on desired behavior? Empty seems reasonable.
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
        logger:info(key)
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

function lib.deepCopy(orig, copies)
    -- 'copies' table tracks already-copied tables to handle cyclic references.
    copies = copies or {}

    -- If the value is not a table, return it directly (base case).
    if type(orig) ~= "table" then
        return orig
    end

    -- If we've already copied this table, return the copy to avoid recursion loops.
    if copies[orig] then
        return copies[orig]
    end

    -- Create a new table for the copy and record it in 'copies'.
    local copy = {}
    copies[orig] = copy

    -- Recursively copy all keys and values from the original.
    for key, value in pairs(orig) do
        local copiedKey = lib.deepCopy(key, copies)
        local copiedValue = lib.deepCopy(value, copies)
        copy[copiedKey] = copiedValue
    end

    -- Preserve the metatable, if any.
    setmetatable(copy, getmetatable(orig))

    return copy
end

function lib.findByField(array, field, target)
    for _, element in ipairs(array) do
        local value = element[field]
        if type(value) == "string" and value == target then
            return element
        elseif type(value) == "table" then
            for _, v in ipairs(value) do
                if v == target then
                    return element
                end
            end
        end
    end
    return nil -- not found
end

function lib.tablesEqualNumbers(t1, t2, tolerance)
    tolerance = tolerance or 1e-9 -- Default tolerance for floating point

    -- Check if both tables have the same number of elements
    if #t1 ~= #t2 then
        return false
    end

    -- Compare each corresponding element
    for i = 1, #t1 do
        local v1 = t1[i]
        local v2 = t2[i]
        -- Use tolerance check for numbers
        if type(v1) == 'number' and type(v2) == 'number' then
            if math.abs(v1 - v2) > tolerance then
                return false
            end
        elseif v1 ~= v2 then -- Use standard comparison for non-numbers
            return false
        end
    end

    return true
end

return lib
