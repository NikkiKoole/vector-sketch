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

Concord.component('mouth',
    function(c, parts)
        c.head = parts.head
        c.upperlip = parts.upperlip
        c.lowerlip = parts.lowerlip
        c.teeth = parts.teeth
        c.values = parts.values
    end
)

Concord.component('biped',
    function(c, parts)
        c.guy = parts.guy

        c.body = parts.body
        c.head = parts.head
        c.neck = parts.neck

        c.leg1 = parts.leg1
        c.leg2 = parts.leg2
        c.leghair1 = parts.leghair1
        c.leghair2 = parts.leghair2
        c.feet1 = parts.feet1
        c.feet2 = parts.feet2
        c.arm1 = parts.arm1
        c.arm2 = parts.arm2
        c.armhair1 = parts.armhair1
        c.armhair2 = parts.armhair2

        c.hand1 = parts.hand1
        c.hand2 = parts.hand2

        c.potatoHead = parts.potatoHead --boolean
        c.values = parts.values -- numbers

        --c.bodyTimer = nil
    end
)

Concord.component('potato', function(c, parts)
    c.head = parts.head
    c.values = parts.values
    c.nose = parts.nose

    c.eye1 = parts.eye1
    c.eye2 = parts.eye2
    c.pupil1 = parts.pupil1
    c.pupil2 = parts.pupil2
    c.brow1 = parts.brow1
    c.brow2 = parts.brow2
    c.ear1 = parts.ear1
    c.ear2 = parts.ear2

    c.eyeBlink = 1
    c.eyeTimer = nil
    c.lookAtTimerEye1 = nil
    c.lookAtTimerEye2 = nil

    c.blinkCounter = love.math.random() * 5.0

    -- c.mouthOpenNess = parts.mouthOpenNess or 0
end)
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
