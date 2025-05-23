return function(moonshine)
    local shader = love.graphics.newShader [[
    extern vec4 background_color;
    extern vec4 shadow_color;
    extern vec2 offset_in_pixels;
    extern vec2 screen_size;

    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
      vec4 current_color = Texel(texture, uv);

      // If the current color matches background_color
      if (distance(current_color, background_color) < 0.01) {
        vec2 offset_uv = uv - offset_in_pixels / screen_size;
        vec4 offset_color = Texel(texture, offset_uv);

        // If offset color is not background, apply shadow
        if (distance(offset_color, background_color) > 0.01) {
          return shadow_color;
        }
      }
      return current_color;
    }
  ]]

    local background = { 0.0, 0.0, 0.0, 1.0 }
    local shadow = { 0.0, 0.0, 0.0, 0.5 }
    local offset = { 2.0, 2.0 }

    local setters = {}
    setters.background_color = function(c) background = c end
    setters.shadow_color = function(c) shadow = c end
    setters.offset_in_pixels = function(v) offset = v end

    local draw = function(buffer)
        shader:send("screen_size", { love.graphics.getWidth(), love.graphics.getHeight() })
        shader:send("background_color", background)
        shader:send("shadow_color", shadow)
        shader:send("offset_in_pixels", offset)
        moonshine.draw_shader(buffer, shader)
    end

    return moonshine.Effect {
        name = "shadow",
        draw = draw,
        setters = setters,
        defaults = {
            background_color = { 0.0, 0.0, 0.0, 1.0 },
            shadow_color = { 0.0, 0.0, 0.0, 0.5 },
            offset_in_pixels = { 20.0, 20.0 }
        }
    }
end
