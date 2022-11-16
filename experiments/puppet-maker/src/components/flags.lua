Concord.component("basic")
Concord.component('texturedBody',
    function(c, lineart, mask, texture1, color1, texture2, color2)
        c.lineart = lineart
        c.mask = mask
        c.texture1 = texture1
        c.color1 = color1
        c.texture2 = texture2
        c.color2 = color2
    end
)
Concord.component('biped',
    function(c, body, leg1, leg2, feet1, feet2)
        c.body = body
        c.leg1 = leg1
        c.leg2 = leg2
        c.feet1 = feet1
        c.feet2 = feet2
    end
)
Concord.component('draggingRopeEnd',
    function(c, rope, anchorName, attachedTo)
        c.rope = rope
        c.anchorName = anchorName
        c.attachedTo = attachedTo
    end
)
