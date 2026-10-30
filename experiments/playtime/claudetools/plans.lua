-- plans.lua — the work board, made from the docs themselves (docs/readme.md).
--
-- Each doc in docs/ (and docs/knut/) has one hand-kept line near the top:
--   status: active | idea | parked — why | done | reference
-- (idea: a notebook added to now and then, like KING-ROLLO; listed, never warned about)
-- Progress comes from the doc's `- [x]` / `- [ ]` boxes (`- [~]`: a step parked for now, left out);
-- nothing else is kept by hand.
-- Warnings point at drift: an active doc untouched for weeks, an active doc with every box
-- ticked, a commit that names a step (W2, P8, ...) the doc hasn't ticked, a doc without a status.
--
-- Run from experiments/playtime: lua claudetools/plans.lua [--all]   (or ./playtime.sh todo)

local STALE_DAYS = 21
local NEXT_ITEMS = 3
local showAll = arg[1] == '--all'

local function run(cmd)
    local p = io.popen(cmd)
    local out = p:read('*a')
    p:close()
    return out
end

local function listDocs()
    local docs = {}
    for path in run('ls docs/*.md docs/knut/*.md 2>/dev/null'):gmatch('[^\n]+') do
        docs[#docs + 1] = path
    end
    return docs
end

-- `- [ ] **W2. Persistence.** save/...` -> 'W2. Persistence.'; no bold: the first words.
local function itemLabel(text)
    local bold = text:match('^%*%*(.-)%*%*')
    local label = bold or text
    if #label > 90 then label = label:sub(1, 87) .. '...' end
    return label
end

local function readDoc(path)
    local doc = { path = path, open = {}, done = 0, ids = {} }
    local lineNo = 0
    for line in io.lines(path) do
        lineNo = lineNo + 1
        if not doc.title then doc.title = line:match('^#%s+(.+)') end
        if lineNo <= 12 and not doc.status then
            local status, rest = line:match('^status:%s*(%a+)%s*(.*)$')
            if status then
                doc.status = status
                doc.reason = rest:gsub('^[—%-:%s]+', '')
            end
        end
        local mark, text = line:match('^%s*[-*] %[([ xX~])%]%s*(.*)$')
        if mark and mark ~= '~' then
            local id = text:match('^%*%*(%u+%d+%a?)[%.%s:]')
            if mark == ' ' then
                doc.open[#doc.open + 1] = { label = itemLabel(text), id = id }
                if id then doc.ids[id] = 'open' end
            else
                doc.done = doc.done + 1
                if id then doc.ids[id] = 'done' end
            end
        end
    end
    doc.title = doc.title or path
    return doc
end

local function daysSinceCommit(path)
    local ts = tonumber(run('git log -1 --format=%ct -- "' .. path .. '" 2>/dev/null'):match('%d+'))
    if not ts then return 0 end
    return math.floor((os.time() - ts) / 86400)
end

-- Commits since the doc last changed that name one of its open steps.
local function untickedMentions(doc)
    local since = run('git log -1 --format=%cI -- "' .. doc.path .. '" 2>/dev/null'):match('%S+')
    if not since then return {} end
    local log = run('git log --since="' .. since .. '" --format="%h %s" -- . 2>/dev/null')
    local found = {}
    for line in log:gmatch('[^\n]+') do
        -- a range ('V1-V6', 'W2–W5', 'BUG1-18') names a group of steps, not one that got done
        line = line:gsub('%u+%d+%a?%s*%-%s*%u*%d+%a?', ''):gsub('%u+%d+%a?%s*–%s*%u*%d+%a?', '')
        for id, state in pairs(doc.ids) do
            if state == 'open' and line:find('%f[%w]' .. id .. '%f[%W]') then
                found[#found + 1] = id .. ' in ' .. line
            end
        end
    end
    return found
end

local docs = listDocs()
local byStatus = { active = {}, idea = {}, parked = {}, done = {}, reference = {} }
local warnings = {}

for _, path in ipairs(docs) do
    local doc = readDoc(path)
    local short = path:gsub('^docs/', '')
    doc.short = short
    if not doc.status then
        warnings[#warnings + 1] = short .. ': no status line (add `status: active|idea|parked|done|reference` under the title)'
    elseif not byStatus[doc.status] then
        warnings[#warnings + 1] = short .. ': unknown status "' .. doc.status .. '"'
    else
        table.insert(byStatus[doc.status], doc)
    end
    if doc.status == 'active' then
        local days = daysSinceCommit(path)
        if days >= STALE_DAYS then
            warnings[#warnings + 1] = short .. ': active but untouched for ' .. days .. ' days. Still active, or parked?'
        end
        if #doc.open == 0 and doc.done > 0 then
            warnings[#warnings + 1] = short .. ': active but every box is ticked. Done?'
        end
        for _, mention in ipairs(untickedMentions(doc)) do
            warnings[#warnings + 1] = short .. ': a commit names an unticked step: ' .. mention
        end
    end
end

print('ACTIVE')
for _, doc in ipairs(byStatus.active) do
    local total = doc.done + #doc.open
    local progress = total > 0 and (' [' .. doc.done .. '/' .. total .. ']') or ''
    print('  ' .. doc.title .. progress .. '  (' .. doc.short .. ')')
    for i = 1, math.min(NEXT_ITEMS, #doc.open) do
        print('    - ' .. doc.open[i].label)
    end
    if #doc.open > NEXT_ITEMS then print('    ... ' .. (#doc.open - NEXT_ITEMS) .. ' more') end
end

print('\nIDEAS')
for _, doc in ipairs(byStatus.idea) do
    print('  ' .. doc.short .. '  ' .. doc.title)
end

print('\nPARKED')
for _, doc in ipairs(byStatus.parked) do
    local reason = doc.reason ~= '' and (' — ' .. doc.reason) or ''
    print('  ' .. doc.short .. reason)
end

if showAll then
    for _, status in ipairs({ 'done', 'reference' }) do
        print('\n' .. status:upper())
        for _, doc in ipairs(byStatus[status]) do
            print('  ' .. doc.short .. '  ' .. doc.title)
        end
    end
else
    print('\n(' .. #byStatus.done .. ' done, ' .. #byStatus.reference .. ' reference: --all lists them)')
end

if #warnings > 0 then
    print('\nDRIFT')
    for _, warning in ipairs(warnings) do print('  ! ' .. warning) end
end
