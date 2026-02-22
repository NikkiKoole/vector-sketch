-- Find forward-reference issues in local functions
-- Usage: lua claudetools/find-forward-refs.lua [dir]
-- Default dir: src/
--
-- Detects local functions that are called before their definition line,
-- which breaks lurker hot-reload (file re-executes top-to-bottom, local is nil).

local scan_dir = arg[1] or "src"

local files = {}
for line in io.popen("find " .. scan_dir .. " -name '*.lua' -maxdepth 1"):lines() do
    files[#files+1] = line
end
files[#files+1] = "main.lua"

local issues = {}

for _, filepath in ipairs(files) do
    local lines = {}
    local f = io.open(filepath)
    if not f then goto continue end
    for line in f:lines() do
        lines[#lines+1] = line
    end
    f:close()

    -- Compute nesting depth before each line
    local depth_before = {}
    local d = 0
    local in_mc = false

    for i, line in ipairs(lines) do
        if not in_mc and line:match("%-%-%[%[") and not line:match("%]%].-$") then
            in_mc = true
            depth_before[i] = d
            goto next1
        end
        if not in_mc and line:match("%-%-%[%[.*%]%]") then
            depth_before[i] = d
            goto next1
        end
        if in_mc then
            depth_before[i] = d
            if line:match("%]%]") then in_mc = false end
            goto next1
        end

        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed:sub(1,2) == "--" then
            depth_before[i] = d
            goto next1
        end

        depth_before[i] = d

        local s = line:gsub('"[^"]*"', '""'):gsub("'[^']*'", "''"):gsub("%-%-.*$", "")

        for _ in s:gmatch("%f[%w]function[%s%(]") do d = d + 1 end
        if s:match("%f[%w]function$") then d = d + 1 end
        for _ in s:gmatch("%f[%w]do%f[^%w]") do d = d + 1 end
        for _ in s:gmatch("%f[%w]then%f[^%w]") do d = d + 1 end
        for _ in s:gmatch("%f[%w]end%f[^%w]") do d = d - 1 end

        ::next1::
    end

    -- Find all local function definitions
    local local_func_defs = {}
    in_mc = false
    for i, line in ipairs(lines) do
        if not in_mc and line:match("%-%-%[%[") and not line:match("%]%]") then in_mc = true; goto next2 end
        if in_mc then
            if line:match("%]%]") then in_mc = false end
            goto next2
        end
        if line:match("^%s*%-%-") then goto next2 end

        local fname = line:match("^%s*local%s+function%s+([%w_]+)%s*%(")
        if fname then
            local_func_defs[#local_func_defs+1] = {name=fname, line=i, depth=depth_before[i]}
        end
        ::next2::
    end

    -- Find forward declarations and function assignments
    local fwd_decls = {}
    local func_assigns = {}
    in_mc = false
    for i, line in ipairs(lines) do
        if not in_mc and line:match("%-%-%[%[") and not line:match("%]%]") then in_mc = true; goto next2b end
        if in_mc then
            if line:match("%]%]") then in_mc = false end
            goto next2b
        end
        if line:match("^%s*%-%-") then goto next2b end

        local decl_part = line:match("^%s*local%s+(.+)")
        if decl_part and not decl_part:match("^function%s") then
            local before_eq = decl_part:match("^(.-)%s*=") or decl_part
            for varname in before_eq:gmatch("([%w_]+)") do
                if not fwd_decls[varname] then
                    fwd_decls[varname] = {line=i, depth=depth_before[i]}
                end
            end
        end

        if not line:match("^%s*local%s") then
            local aname = line:match("^%s*([%w_]+)%s*=%s*function%s*%(")
            if aname then
                func_assigns[aname] = {line=i, depth=depth_before[i]}
            end
        end
        ::next2b::
    end

    -- Check each local function for references before its definition
    for _, def in ipairs(local_func_defs) do
        local name = def.name
        local def_line = def.line
        local def_depth = def.depth

        in_mc = false
        for i = 1, def_line - 1 do
            local line = lines[i]
            if not in_mc and line:match("%-%-%[%[") and not line:match("%]%]") then in_mc = true; goto next3 end
            if in_mc then
                if line:match("%]%]") then in_mc = false end
                goto next3
            end
            if line:match("^%s*%-%-") then goto next3 end
            if line:match("^%s*local%s+function%s+" .. name .. "%s*%(") then goto next3 end
            if line:match("^%s*local%s.*%f[%w]" .. name .. "%f[^%w]") then goto next3 end

            local cleaned = line:gsub('"[^"]*"', '""'):gsub("'[^']*'", "''"):gsub("%-%-.*$", "")

            if cleaned:match("%f[%w]" .. name .. "%f[^%w]") then
                local covered = false

                local fd = fwd_decls[name]
                if fd and fd.line < i and fd.depth == def_depth then
                    local fa = func_assigns[name]
                    if fa and fa.line < i then
                        covered = true
                    end
                    if not covered and depth_before[i] > def_depth then
                        covered = true
                    end
                end

                for _, other_def in ipairs(local_func_defs) do
                    if other_def.name == name and other_def.line < i and other_def.depth <= depth_before[i] then
                        covered = true
                        break
                    end
                end

                if not covered then
                    local sev
                    if depth_before[i] == 0 then
                        sev = "CRITICAL: referenced at module-load level"
                    else
                        sev = "BUG: referenced inside function body before local is in scope"
                    end

                    issues[#issues+1] = {
                        file = filepath,
                        name = name,
                        ref_line = i,
                        def_line = def_line,
                        severity = sev,
                        ref_text = lines[i],
                        def_text = lines[def_line],
                        ref_depth = depth_before[i],
                    }
                end
            end

            ::next3::
        end
    end

    ::continue::
end

table.sort(issues, function(a,b)
    if a.file == b.file then return a.ref_line < b.ref_line end
    return a.file < b.file
end)

if #issues == 0 then
    print("No forward-reference issues found.")
else
    print(string.format("Found %d forward-reference issues:\n", #issues))
    local seen = {}
    for _, iss in ipairs(issues) do
        local key = iss.file .. ":" .. iss.name .. ":" .. iss.ref_line
        if not seen[key] then
            seen[key] = true
            print(string.format("FILE: %s", iss.file))
            print(string.format("  Function: %s()", iss.name))
            print(string.format("  Severity: %s", iss.severity))
            print(string.format("  Referenced at line %d (depth %d): %s", iss.ref_line, iss.ref_depth, iss.ref_text:match("^%s*(.-)%s*$")))
            print(string.format("  Defined at line %d: %s", iss.def_line, iss.def_text:match("^%s*(.-)%s*$")))
            print()
        end
    end
end
