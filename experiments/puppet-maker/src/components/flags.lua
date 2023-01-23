Concord.component("basic")
--[[

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
--]]
-- 1 means the bipeds' right, 2 means the bipeds' left.
-- when facing me, 1 == left and 2 == right (for me)
Concord.component('biped',
    function(c, parts)
        c.guy = parts.guy

        c.body = parts.body
        c.head = parts.head
        c.neck = parts.neck

        c.leg1 = parts.leg1
        c.leg2 = parts.leg2
        c.feet1 = parts.feet1
        c.feet2 = parts.feet2
        c.arm1 = parts.arm1
        c.arm2 = parts.arm2
        c.hand1 = parts.hand1
        c.hand2 = parts.hand2

        print('making the component again')
        c.potatoHead = parts.potatoHead

    end
)
--[[
Concord.component('head',
    function(c, parts)
        c.eye1 = parts.eye1
        c.eye2 = parts.eye2
    end
)
Concord.component('draggingRopeEnd',
    function(c, rope, anchorName, attachedTo)
        c.rope = rope
        c.anchorName = anchorName
        c.attachedTo = attachedTo
    end
)
--]]