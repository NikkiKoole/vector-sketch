-- tree-kinds: how each kind of tree grows, the data for tree-grow.lua (not a scene). Loaded with
-- love.filesystem.load('scripts/spikes/tree-kinds.lua')() -> { oak = {...}, elm = {...}, ... }.
-- From the bark spike (docs/BARK.md); tuning a kind is editing its numbers here.
-- How each kind grows (the L-system idea: every branch makes side branches by its kind's rules, those make
-- their own, down to twigs), seen from the side, in world units:
--   trunk     length, width at the foot, roots flaring (wider at the very bottom), how far it wanders
--   fork      the trunk ends in this many limbs (an oak, an elm's vase), spread between them, their length;
--             none: the trunk runs on to the top (a pine, a poplar, an aspen)
--   kids      side branches per branch (min, max), from how far along (the trunk's own: trunkKids, bare below
--             trunkStart: aspens and birches drop their lower branches, the eyes are where they were)
--   spread    angle from the parent (min, max, radians), len a child's length over its parent's, cone: shorter
--             toward the top (a pine), share how much of its parent's wood a side branch takes (its width is
--             the parent's times the square root: widths add up, da Vinci's rule)
--   depth     how many times branches branch; up: how much a branch turns toward the sky, droop: toward the
--             ground (more on thinner ones: weeping twigs), wander: slow crookedness
--   sag       how much a limb sags as it reaches out (its weight); recover: how much its tip turns back up
--             past recoverFrom (the elbow)
--   stretch   storybook size (BARK, 2026-11-08): the grown tree scaled up from its foot to about its height in
--             Mipos (a median Mipo stands 658): olive 2.5, birch and aspen 4, oak 4.5, beech plane elm 5,
--             pine and poplar 6 (real trees are 15-20 people; picture-book trees a handful of Mipos);
--             thicken: its trunk's width (oak ~520, wider than a Mipo; aspen ~240), twigs staying thin
--   zigzag    the kink at each year's growth where a side bud takes over from the tip (oak, elm, plane: a
--             zigzag twig); none where one leading bud goes on (pine, poplar: straight)
local KINDS = {
    oak = { trunk = 560, w = 250, flare = 0.7, trunkWander = 0.08, fork = { 3, 0.55, 0.85 },
        trunkKids = { 1, 2 }, trunkStart = 0.45, kids = { 2, 3 }, start = 0.25, spread = { 0.55, 1.05 },
        len = 0.62, share = 0.35, depth = 4, up = 0.03, droop = 0.03, wander = 0.32,
        sag = 0.05, recover = 0.07, recoverFrom = 0.5, zigzag = 0.35,
        stretch = 2.74, thicken = 2.08 },
    elm = { trunk = 480, w = 190, flare = 0.4, trunkWander = 0.05, fork = { 4, 0.2, 1.3 },
        trunkKids = { 0, 1 }, trunkStart = 0.5, kids = { 2, 2 }, start = 0.35, spread = { 0.35, 0.6 },
        len = 0.55, share = 0.3, depth = 4, up = 0.035, droop = 0.05, wander = 0.14,
        sag = 0.012, recover = 0.06, recoverFrom = 0.35, zigzag = 0.45,
        stretch = 2.67, thicken = 2.0 },
    beech = { trunk = 620, w = 190, flare = 0.55, trunkWander = 0.04, fork = { 2, 0.5, 0.95 },
        trunkKids = { 1, 2 }, trunkStart = 0.5, kids = { 3, 3 }, start = 0.25, spread = { 0.5, 0.85 },
        len = 0.55, share = 0.3, depth = 4, up = 0.06, droop = 0.02, wander = 0.12,
        sag = 0.03, recover = 0.05, recoverFrom = 0.5, zigzag = 0.3,
        stretch = 2.43, thicken = 1.9 },
    plane = { trunk = 580, w = 180, flare = 0.35, trunkWander = 0.1, fork = { 3, 0.65, 0.85 },
        trunkKids = { 1, 1 }, trunkStart = 0.55, kids = { 2, 3 }, start = 0.25, spread = { 0.6, 1.1 },
        len = 0.58, share = 0.33, depth = 4, up = 0.02, droop = 0.03, wander = 0.38,
        sag = 0.05, recover = 0.06, recoverFrom = 0.5, zigzag = 0.38,
        stretch = 3.54, thicken = 2.0 },
    olive = { trunk = 380, w = 260, flare = 0.5, trunkWander = 0.18, fork = { 3, 0.8, 0.95 },
        trunkKids = { 0, 1 }, trunkStart = 0.5, kids = { 2, 3 }, start = 0.25, spread = { 0.6, 1.15 },
        len = 0.52, share = 0.35, depth = 3, up = 0.02, droop = 0.05, wander = 0.42,
        sag = 0.06, recover = 0.04, recoverFrom = 0.55, zigzag = 0.2,
        stretch = 3.06, thicken = 1.54 },
    pine = { trunk = 1450, w = 170, flare = 0.3, trunkWander = 0.02, trunkKids = { 14, 16 }, trunkStart = 0.35,
        kids = { 4, 5 }, start = 0.15, spread = { 0.6, 0.9 }, firstSpread = { 1.3, 1.55 }, len = 0.4, cone = true,
        share = 0.1, depth = 2, up = 0.0, droop = 0.025, wander = 0.08,
        sag = 0.04, recover = 0.08, recoverFrom = 0.6, zigzag = 0,
        stretch = 2.74, thicken = 1.76 },
    poplar = { trunk = 1450, w = 140, flare = 0.2, trunkWander = 0.03, trunkKids = { 11, 13 }, trunkStart = 0.22,
        kids = { 1, 2 }, start = 0.3, spread = { 0.2, 0.35 }, len = 0.42, cone = true, coneTop = 0.55,
        share = 0.1, depth = 2, up = 0.1, droop = 0.0, wander = 0.08,
        sag = 0.01, recover = 0.02, recoverFrom = 0.5, zigzag = 0,
        stretch = 2.3, thicken = 1.86 },
    aspen = { trunk = 1400, w = 150, flare = 0.15, trunkWander = 0.03, trunkKids = { 8, 10 }, trunkStart = 0.55,
        kids = { 2, 3 }, start = 0.3, spread = { 0.45, 0.8 }, len = 0.5, cone = true, coneTop = 0.6,
        share = 0.13, depth = 3, up = 0.1, droop = 0.0, wander = 0.15,
        sag = 0.02, recover = 0.04, recoverFrom = 0.5, zigzag = 0.1,
        stretch = 1.54, thicken = 1.6 },
    birch = { trunk = 1350, w = 170, flare = 0.3, trunkWander = 0.04, trunkKids = { 7, 9 }, trunkStart = 0.45,
        kids = { 2, 3 }, start = 0.3, spread = { 0.55, 0.9 }, len = 0.42, cone = true, coneTop = 0.45,
        share = 0.15, depth = 3, up = 0.04, droop = 0.16, wander = 0.15,
        sag = 0.05, recover = 0.0, recoverFrom = 1, zigzag = 0.15,
        stretch = 1.96, thicken = 1.53 },
}

return KINDS
