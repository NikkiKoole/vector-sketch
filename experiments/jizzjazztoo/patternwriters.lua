local data2 = require 'pocket2'
function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function split_and_remove_whitespace(str)
    local result = {}
    for word in str:gmatch("%S+") do
        table.insert(result, word:gsub("%s+", ""))
    end
    return result
end

function stringSplit(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

function parse(str)
    local parts = {}
    local currentPart = nil
    local currentTitle = nil
    local currentSection = nil
    local currentSectionTitle = nil
    local writingGrid = false
    local result = {};
    for line in string.gmatch(str .. "\n", "(.-)\n") do
        table.insert(result, line);
    end
    for i = 1, #result do
        local token = result[i]
        if token == '' then
            -- end current part
            -- begin new part
            if currentPart then
                print('}')
                print('},')
                -- print('try to close currentpart')
                currentPart = nil
                currentTitle = nil
                currentSectionTitle = nil
            end
            if not currentPart then
                currentPart = {}
                print('{')
                --print(' new currentpart')
            end
        else
            --[[
        BD Bass Drum SN Snare
        LT Low Tom RS Rimshot
        MT Medium Tom CB Cowbell
        HT High Tom CY Cymbal
        CL Hand Clap OH Open High Hat
        SH Shaker CH Closed High Hat
        ]]
            --

            if string.starts(token, 'BD') or
                string.starts(token, 'SN') or -- SD
                --   string.starts(token, 'CN') or -- ?
                string.starts(token, 'SH') or -- ?
                string.starts(token, 'HC') or -- ?
                string.starts(token, 'CH') or
                string.starts(token, 'CL') or --CPS
                string.starts(token, 'RS') or
                string.starts(token, 'CB') or
                string.starts(token, 'MT') or
                string.starts(token, 'AC') or
                string.starts(token, 'CY') or
                string.starts(token, 'OH')
            then
                local mapping = {

                    ["BD"] = "BD",
                    ["SN"] = "SD",
                    ["SH"] = "TB",
                    --  ["HC"] = "HT",
                    ["CH"] = "CH",
                    ["HC"] = "HT",
                    ["HT"] = "HT",
                    ["MT"] = "MT",
                    --["LowTom"] = "LT",
                    ["AC"] = "AC",
                    --  ["accent"] = "AC",
                    -- ["Cymbal"] = "CY",
                    ["CB"] = "CB",
                    ["CL"] = "CPS",
                    ["RS"] = "RS"
                }
                local r = stringSplit(token, " ")
                print(inspect(r) .. ',')
                writingGrid = true
                --print('grid data')
            else
                if currentTitle == nil then
                    currentTitle = token
                    -- name = "Afro Cuban",
                    print('name= "' .. token .. '",')

                    print('sections={{')
                    --   print('new part', token)
                elseif currentSectionTitle == nil then
                    currentSectionTitle = token

                    writingGrid = false

                    print('{name="' .. currentSectionTitle .. '",')
                    --  print('grid={')
                    --  print('new section 1', currentSectionTitle)
                else
                    if writingGrid then
                        print("},")
                        print('{name="' .. token .. '",')
                        --print('new section', token)
                    end
                end
                -- print('?', token)
            end
        end
        -- print(token)
        --print(result[i])
        --if result[]
    end
end

--parse(data)
local mapping = {

    ["BD"] = "BD",
    ["SN"] = "SD",
    ["SH"] = "TB",
    --  ["HC"] = "HT",
    ["CH"] = "CH",
    ["OH"] = "OH",
    ["HC"] = "HT",
    ["HT"] = "HT",
    ["MT"] = "MT",
    ["LT"] = "LT",
    --["LowTom"] = "LT",
    ["AC"] = "AC",
    --  ["accent"] = "AC",
    -- ["Cymbal"] = "CY",
    ["CB"] = "CB",
    ["CY"] = "CY",
    ["CL"] = "CPS",
    ["RS"] = "RS"
}
function makePatternString(data)
    local result = ''
    for i = 1, 16 do
        local hit = false
        for j = 2, #data do
            if data[j] == i .. '' then
                hit = true
            end
        end
        result = result .. (hit and 'x' or '.')
    end

    return result
end

function parseAgain(data)
    local result = {}
    for i = 1, #data do
        local chapter = nil
        if result[data[i].name] then
            chapter = result[data[i].name]
        else
            chapter = { name = data[i].name, sections = {} }
            result[data[i].name] = chapter
        end
        for j = 1, #data[i].sections do
            local newSection = {
                name = data[i].sections[j].name,
                grid = {

                }
            }
            -- print(data[i].sections[j].name)
            local sectionName = data[i].sections[j].name
            -- print(sectionName, data[i].sections[j])
            for l = 1, #data[i].sections[j] do
                local r = makePatternString(data[i].sections[j][l])
                local ab = data[i].sections[j][l][1]
                -- print(ab)
                ab = mapping[ab]
                if ab then
                    newSection.grid[ab] = r
                    --print(ab .. r)
                else
                    -- print(data[i].sections[j].name)
                    -- print(chapter.name, j)
                    -- print(l)
                    print('issue', inspect(data[i].sections[j][l]))
                end
                --print(inspect(data[i].sections[j][l]))
            end
            table.insert(chapter.sections, newSection)
            --   print(inspect(newSection))
            --for k, v in pairs(data[i].sections[j]) do
            --    print(k, v)
            --end
        end
        --print(chapter)
        --print(data[i].name)
    end

    for k, v in pairs(result) do
        print(inspect(v, { newline = ' ', indent = " " }))
    end
    --print(inspect(result, { newline = ' ', indent = " " }))
end

parseAgain(data2)
