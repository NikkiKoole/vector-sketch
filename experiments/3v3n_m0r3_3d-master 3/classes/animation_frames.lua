AnimationFrames = Class:extend('AnimationFrames')

function AnimationFrames:new(image, frame_w, frame_h, ox, oy, frames_list)
	if type(image) == 'string' then 
		image = lg.newImage(image)
	end

	if type(frames_list) == 'string' then 
		frames_list = @:convert_frames_string(frames_list)
	end

  	@.image    = image
	@.frame_w  = frame_w
	@.frame_h  = frame_h
	@.ox       = ox or 0
	@.oy       = oy or 0

	@.frames   = map(frames_list, fn(frame)
		return lg.newQuad(
			(frame[1]-1) * @.frame_w + @.ox, 
			(frame[2]-1) * @.frame_h + @.oy, 
			@.frame_w, @.frame_h, 
			@.image:getWidth(), @.image:getHeight()
		)
	end)
end

function AnimationFrames:draw(frame, x, y, r, sx, sy, ox, oy)
  lg.draw(
		@.image, 
		@.frames[frame], 
		x, y, r or 0, sx or 1, sy or sx or 1, 
		@.frame_w/2 + (ox or 0), 
		@.frame_h/2 + (oy or 0)
	)
end

function AnimationFrames:convert_frames_string(str)
	local tbl = {}

	str:gsub('([%d]+)-([%d]+)', fn(x, y) 
		insert(tbl, {tonumber(x), tonumber(y)}) 
	end)

	return tbl
end