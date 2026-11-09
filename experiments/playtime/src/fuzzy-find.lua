-- fuzzy-find.lua: quick fuzzy matching for search boxes (the scenes tab's, src/ui/scenes-tab.lua).
-- A query is words; each word must be found in the text, its letters in order (case ignored).
-- Found as one piece scores most (at the start of a word more, at the very start most); else
-- letter by letter, more for letters in a row and for ones that start a word. Pure Lua, no LÖVE.
local lib = {}

lib.MAX_SPREAD = 3 -- a word's letters found within this many times its length

local function isWordStart(text, i)
    if i == 1 then return true end
    local prev, here = text:sub(i - 1, i - 1), text:sub(i, i)
    if not prev:match('%w') then return true end
    return prev:match('%l') ~= nil and here:match('%u') ~= nil -- camelCase
end

-- one word against one text: a score, or nil when its letters aren't all there in order
function lib.scoreWord(word, text)
    if word == '' then return 0 end
    local lowWord, lowText = word:lower(), text:lower()
    local at = lowText:find(lowWord, 1, true)
    if at then
        -- the whole word as one piece; a later piece that starts a word beats an earlier one that doesn't
        local best = nil
        while at do
            local s = 100 + #word * 10 - math.min(at, 40) * 0.5
            if isWordStart(text, at) then s = s + 50 end
            if at == 1 then s = s + 30 end
            best = math.max(best or s, s)
            at = lowText:find(lowWord, at + 1, true)
        end
        return best
    end
    -- letter by letter, close together: from each place its first letter is, greedy forward; the
    -- tightest that fits in MAX_SPREAD times the word's length ('water' scattered over a long
    -- description found nearly every scene)
    local best = nil
    local start = lowText:find(lowWord:sub(1, 1), 1, true)
    while start do
        local score, last, ok = 0, nil, true
        for k = 1, #lowWord do
            local i = k == 1 and start or lowText:find(lowWord:sub(k, k), last + 1, true)
            if not i or i - start + 1 > #lowWord * lib.MAX_SPREAD then
                ok = false
                break
            end
            score = score + 10
            if last and i == last + 1 then score = score + 15 end
            if isWordStart(text, i) then score = score + 20 end
            if last then score = score - (i - last - 1) * 2 end
            last = i
        end
        if ok then best = math.max(best or score, score) end
        start = lowText:find(lowWord:sub(1, 1), start + 1, true)
    end
    return best
end

local function words(query)
    local out = {}
    for w in query:gmatch('%S+') do out[#out + 1] = w end
    return out
end

-- a query against several texts (fields[i] weighs weights[i], default 1): each word scores its
-- best field; nil when a word is found in none of them
function lib.score(query, fields, weights)
    local total = 0
    for _, word in ipairs(words(query)) do
        local best = nil
        for i, text in ipairs(fields) do
            local s = text and lib.scoreWord(word, text)
            if s then
                s = s * (weights and weights[i] or 1)
                best = math.max(best or s, s)
            end
        end
        if not best then return nil end
        total = total + best
    end
    return total
end

-- the items that match, best first (ties keep their order); fieldsOf(item) -> texts, weights
function lib.rank(query, items, fieldsOf)
    if not query:match('%S') then return {} end
    local scored = {}
    for i, item in ipairs(items) do
        local fields, weights = fieldsOf(item)
        local s = lib.score(query, fields, weights)
        if s then scored[#scored + 1] = { item = item, score = s, order = i } end
    end
    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.order < b.order
    end)
    local out = {}
    for i, entry in ipairs(scored) do out[i] = entry.item end
    return out
end

return lib
