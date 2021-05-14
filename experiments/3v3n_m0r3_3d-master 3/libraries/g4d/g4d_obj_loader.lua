return function(path)
	local verts   = {}
	local faces   = {}
	local uvs     = {}
	local normals = {}

	for line in love.filesystem.lines(path) do
		local words = {}
		
		for word in line:gmatch('([^'..'%s'..']+)') do table.insert(words, word) end

		if words[1] == 'v'  then table.insert(verts  , {tonumber(words[2]), tonumber(words[3]), tonumber(words[4])}) end
		if words[1] == 'vn' then table.insert(normals, {tonumber(words[2]), tonumber(words[3]), tonumber(words[4])}) end
		if words[1] == 'vt' then table.insert(uvs    , {tonumber(words[2]), tonumber(words[3])})                     end

		-- if the first word in this line is a 'f', then this is a face
		-- a face takes three arguments which refer to points, each of those points take three arguments
		-- the arguments a point takes is v,vt,vn
		if words[1] == 'f' then
			local store = {}

			-- TODO allow models with untriangulated faces
			assert(#words == 4, 'Faces in '..path..' must be triangulated before they can be used in g4d!')

			for i=2, #words do
				local num  = ''
				local word = words[i]
				local ii   = 1
				local char = word:sub(ii,ii)

				while true do
					char = word:sub(ii,ii)
					if char ~= '/' then num = num .. char  else break end
					ii = ii + 1
				end
				table.insert(store, tonumber(num))

				local num = ''
				ii = ii + 1
				while true do
					char = word:sub(ii,ii)
					if ii <= #word and char ~= '/' then num = num .. char else break end
					ii = ii + 1
				end
				table.insert(store, tonumber(num))

				local num = ''
				ii = ii + 1
				while true do
					char = word:sub(ii,ii)
					if ii <= #word and char ~= '/' then num = num .. char else break end
					ii = ii + 1
				end
				table.insert(store, tonumber(num))
			end

			table.insert(faces, store)
		end
	end

	local concat = function(t1,t2,t3)
		local tbl = {}
		for _, v in ipairs(t1) do table.insert(tbl, v) end
		for _, v in ipairs(t2) do table.insert(tbl, v) end
		for _, v in ipairs(t3) do table.insert(tbl, v) end
		return tbl
	end
    -- put it all together in the right order
	local compiled = {}

	for i,face in pairs(faces) do
		table.insert(compiled, concat(verts[face[1]], uvs[face[2]], normals[face[3]]))
		table.insert(compiled, concat(verts[face[4]], uvs[face[5]], normals[face[6]]))
		table.insert(compiled, concat(verts[face[7]], uvs[face[8]], normals[face[9]]))
	end

	return compiled
end
