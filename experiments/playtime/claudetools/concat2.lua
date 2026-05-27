-- concat.lua

local lfs = require("lfs") -- LuaFileSystem is required for directory traversal

local outputFile = io.open("output.md", "w")
if not outputFile then
    io.stderr:write("Could not open output.md for writing.\n")
    os.exit(1)
end

-- Helper: add file contents to output
local function appendFile(filename)
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*a")
        file:close()

        outputFile:write(filename .. "\n")
        outputFile:write("```lua\n")
        outputFile:write(content .. "\n")
        outputFile:write("```\n\n")
    else
        io.stderr:write("Could not open file: " .. filename .. "\n")
    end
end

-- Helper: check if path is directory
local function isDirectory(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

-- Helper: get all .lua files in a directory
local function getLuaFilesInDir(dir)
    local files = {}
    for file in lfs.dir(dir) do
        if file:match("%.lua$") then
            table.insert(files, dir .. "/" .. file)
        end
    end
    table.sort(files)
    return files
end

-- Process all arguments
for i = 1, #arg do
    local path = arg[i]
    if isDirectory(path) then
        for _, luaFile in ipairs(getLuaFilesInDir(path)) do
            appendFile(luaFile)
        end
    elseif path:match("%.lua$") then
        appendFile(path)
    else
        io.stderr:write("Skipping unsupported file: " .. path .. "\n")
    end
end

outputFile:close()
print("Wrote concatenated output to output.md")
