local function parse(s)
	local str = s
	local integer    = "([%d]+)"
	local simple_var = "([%w_]+)" -- var
	local var        = "([%w%.:_'\"%[%]]+)" -- var['key']
	local expression = "([%w%.:_'\"%[%]%(%){}]+)" -- var['key'](p1, p2)
	local wl         = "[%s]+"
	local _wl        = "[%s]-"

	local patterns = {
		{ patt = '@'                  , repl = 'self'},
		{ patt = var .. _wl .. '%+='  , repl = '%1 = %1 + '},
		{ patt = var .. _wl .. '%-='  , repl = '%1 = %1 - '},
		{ patt = var .. _wl .. '%*='  , repl = '%1 = %1 * '},
		{ patt = var .. _wl .. '/='   , repl = '%1 = %1 / '},
		{ patt = var .. _wl .. '^='   , repl = '%1 = %1 ^ '},
		{ patt = var .. _wl .. '%%='  , repl = '%1 = %1 %% '},
		{ patt = var .. _wl .. '%.%.=', repl = '%1 = %1 .. '},
		{ patt = '(' .. wl .. ')' ..'elif' .. '(' .. wl .. ')', repl = '%1elseif%2'},
		{ patt = '&&'                 , repl = ' and '},
		{ patt = '||'                 , repl = ' or '},
		{ patt = '!='                 , repl = ' ~= '},
		{ patt = '!'                  , repl = ' not '},
		{ patt = 'fn%('               , repl = 'function('},
		{ patt = 'ifor' .. wl .. integer    .. wl .. 'do', repl = 'for it = 1, %1 do'},
		{ patt = 'ifor' .. wl .. expression .. wl .. 'do', repl = 'for key, it in ipairs(%1) do'},
		{ patt = 'ifor' .. wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for key, %1 in ipairs(%2) do'},
		{ patt = 'ifor' .. wl .. simple_var .. ',' .. _wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for %1, %2 in ipairs(%3) do'},
		{ patt = 'rfor' .. wl .. integer    .. wl .. 'do', repl = 'for it = %1, 1, -1 do'},
		{ patt = 'rfor' .. wl .. expression .. wl .. 'do', repl = 'for key = #%1, 1, -1 do local it = %1[key] '},
		{ patt = 'rfor' .. wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for key = #%2, 1, -1 do local %1 = %2[key] '},
		{ patt = 'rfor' .. wl .. simple_var .. ',' .. _wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for %1 = #%3, 1, -1 do local %2 = %3[%1] '},
		{ patt = 'for'  .. wl .. integer    .. wl .. 'do', repl = 'for it = 1, %1 do'},
		{ patt = 'for'  .. wl .. expression .. wl .. 'do', repl = 'for key, it in pairs(%1) do'},
		{ patt = 'for'  .. wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for key, %1 in pairs(%2) do'},
		{ patt = 'for'  .. wl .. simple_var .. ',' .. _wl .. simple_var .. wl .. 'in' .. wl .. var .. wl .. 'do', repl = 'for %1, %2 in pairs(%3) do'},
	}

	for _, v in ipairs(patterns) do str = str:gsub(v.patt, v.repl) end
	return str
end

table.insert(package.loaders, 2, function(name)
	local name        = name:gsub('%.', '/') .. '.lua'
	local file        = love.filesystem.read(name)
	local parsed_file = parse(file)

	return assert(loadstring(parsed_file, name))
end)
