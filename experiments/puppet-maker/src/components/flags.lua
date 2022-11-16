Concord.component("basic")
Concord.component(
    'texturedBody',
    function(c, lineart, mask, texture1, color1, texture2, color2)
        c.lineart = lineart
        c.mask = mask
        c.texture1 = texture1
        c.color1 = color1
        c.texture2 = texture2
        c.color2 = color2

    end
)
