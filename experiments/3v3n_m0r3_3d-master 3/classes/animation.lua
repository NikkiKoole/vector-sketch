Animation =  Class:extend('Animation')

function Animation:new(delay, frames, mode, actions)
  	@.delay         = delay
  	@.anim_frames   = frames
  	@.size          = #frames.frames
  	@.mode          = mode or 'loop'
  	@.actions       = actions
	@.pause         = false
  	@.timer         = 0
  	@.current_frame = 1
  	@.dir           = 1
end

function Animation:update(dt)
	if @.pause then return end
	@.timer += dt
	
  local delay = @.delay
	if type(@.delay) == 'table' then delay = @.delay[@.current_frame] end
	
	if @.timer > delay then
		local action = get(@, {'actions', @.current_frame})

    @.current_frame += @.dir
		if @.current_frame > @.size || @.current_frame < 1 then
      if   @.mode == 'once' then
        @.current_frame = @.size
				@.pause = true

      elif @.mode == 'loop' then
				@.current_frame = 1

      elif @.mode == 'bounce' then
        @.dir = -@.dir
        @.current_frame += (2 * @.dir)
			end
		end
		if action then action() end
		
		@.timer -= delay
  end
end

function Animation:draw(x, y, r, sx, sy, ox, oy)
	@.anim_frames:draw(@.current_frame, x, y, r, sx, sy, ox, oy)
end

function Animation:reset()
	@.current_frame = 1
	@.timer         = 0
	@.dir           = 1
	@.pause         = false
end

function Animation:set_frame(frame)
	@.current_frame = frame
	@.timer         = 0
end

function Animation:set_actions(actions)
	@.actions = actions
end

function Animation:set_delay(delay)
	@.delay = delay
end

function Animation:clone()
	return Animation(@.delay, @.frames, @.mode, @.actions)
end
