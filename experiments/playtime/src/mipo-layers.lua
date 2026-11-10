-- mipo-layers.lua — the named places between a Mipo's own pictures where something drawn on it goes
-- (docs/LANDING-2026-11.md L2). Each Mipo draws in its own z range, zGroupOffset * 1000 + a part's
-- zOffset (src/mipo-dna.lua): neck 100, ears 190, torso 192 (+ its hair 197), head 200, the drawn
-- haircut 220, face patches 205, the face 250..254 (eyes .. nose, src/mipo-textures.lua FACE_Z),
-- legs 300, the physics nose 350, feet 399, arms 402, hands 500. Something drawn at one of these is
-- a split in the textured list (src/physics/box2d-draw-textured.lua): before the first picture at
-- that z or higher, so between this Mipo's parts and under the Mipos in front of it.
-- One table, so the hair and the wearables (scripts/spikes/wearables.playtime.lua) don't take the
-- same place by accident.
local lib = {}

lib.Z = {
    hairBack  = 50,  -- hair locks behind the whole Mipo (long hair over its back)
    headscarf = 230, -- over the drawn haircut (220) and the ears, under the face
    hairFront = 255, -- bangs, front locks, a coat on the face: over the face (..254), under the arms and hands
    mask      = 256, -- over the face and the bangs
    pants     = 302, -- over the legs (300, 301), under the physics nose, feet and arms
    shirt     = 305, -- over the torso and the pants (worn untucked)
    hat       = 380, -- over the face and the hair, under the arms
    scarf     = 390, -- over the chin and the pants, under the feet and arms
    sleeve    = 404, -- over the arms (402, 403), under the hands
}

-- The z of `slot` in this Mipo's own range.
function lib.z(instance, slot)
    return (instance.zGroupOffset or 0) * 1000 + lib.Z[slot]
end

-- The z range of what a body draws (its sfixtures' pictures): lowest, highest; nil without any.
function lib.bodyRange(body)
    local lo, hi
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        local extra = type(ud) == 'table' and ud.extra
        if extra and (extra.zOffset or extra.zGroupOffset) then
            local z = (extra.zGroupOffset or 0) * 1000 + (extra.zOffset or 0)
            if not lo or z < lo then lo = z end
            if not hi or z > hi then hi = z end
        end
    end
    return lo, hi
end

return lib
