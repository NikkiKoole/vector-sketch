-- plant-kinds: how each kind of plant grows, the data for plant-grow.lua (not a scene). Loaded with
-- love.filesystem.load('scripts/spikes/plant-kinds.lua')() -> { ORDER = {...}, daisy = {...}, ... }.
-- docs/FLORA.md. Tuning a kind is editing its numbers here. World units (a median Mipo stands 658); storybook
-- sizes, as the trees: flowers knee to shoulder, a sunflower over a Mipo's head.
--   axiom, rules, iter, final   the L-system (rules: { {replacement, weight}, ... }, chosen at random);
--               symbols: F internode, f a short one, + - turn by angle (degrees), [ ] a branch,
--               L a leaf, O an opposite pair, and the letters in heads
--   stems       { min, max, spread }: stems out of the foot, fanned over +-spread radians; footSpread apart
--   len         an internode's length; profile { foot, middle, top } its length along a stem;
--               branchLen a branch's internodes over its parent's (per depth)
--   width, tip  a stem's width at the foot (carrying everything) and its thinnest; widths in between go
--               with what each part carries (pipe model)
--   up          how much a stem turns to the light; sag how much it bends under what it carries;
--               wander slow crookedness; lean a tilt at the foot; sunny how much it leans to the sun;
--               curl a fern's crozier (the tip rolled up while young)
--   phyllo      'spiral' (137.5 degrees round), 'alternate' (two rows, seen round), 'flat' (two rows in the
--               picture's plane: a fern's pinnae, Solomon's seal), opposite pairs (O) cross at 90 degrees
--   leaf        { shapes (textures/plants names), len, wk (width), angle (from the stem, radians), droop
--               (the blade's bend down), petiole (stalk, of its length), ageOpen (older lower ones stand out
--               further), level (blades turned flat to the light), lie (a rosette leaf on the ground) };
--               leafProfile { foot, middle, top } its size along the stem; leafMass, leafMissing
--   rosette     { count, angle, size, leaf, closing (inner leaves more upright), pups { min, max, distance,
--               size }: small rosettes round it }: a ring of leaves at the foot. A leaf's droop below 0 cups it
--               upward (fat succulent leaves); oldColor its outer leaves' colour; leaflets = 3 a clover leaf
--   heads       letter -> { style, size, mass, ... } (plant-look.lua draws the styles): ray (petals round a
--               heart, face: how much it turns to you), cup (tulip, poppy), bell (pendant: hangs off the stem),
--               dots (a ball or flat umbel of crayon rings), spike (dots up a spike), whorl (a ring round the
--               stem), tail (a foxtail), catkin (a nettle's hanging tassels), panicle (a grass's plume);
--               budNod the stalk bowed under the bud, oldNod when it goes to seed
local K = {}

K.daisy = { -- margriet (Leucanthemum vulgare): spoon-leaved rosette, a few stems, a white head each
    name = 'margriet', stems = { 1, 3, 0.22 }, axiom = 'FLX', iter = 7,
    rules = { X = { { 'FLX', 1 }, { 'FX', 0.4 }, { 'F[+FLFH]X', 0.12 } } }, final = { X = 'FH' },
    angle = 30, len = 42, profile = { 0.6, 1, 1.3 }, width = 9, tip = 3, up = 0.05, sag = 0.02, wander = 0.25,
    phyllo = 'spiral', leaf = { shapes = { 'oval-03', 'oval-04' }, len = 70, wk = 0.4, angle = 0.6, droop = 0.25 },
    leafProfile = { 1, 0.7, 0.3 },
    rosette = { count = 8, angle = 1.25, size = 1.6, leaf = { shapes = { 'oval-01', 'oval-02', 'oval-05' },
        len = 80, wk = 0.55, droop = 0.5, petiole = 0.4, lie = true } },
    heads = { H = { style = 'ray', size = 95, mass = 2, face = 0.75, petals = 18, petal = 'petal',
        colors = { { 0.98, 0.97, 0.93 } }, heart = { 0.98, 0.8, 0.2 }, heartK = 0.3, budNod = 0.3 } },
    stemColor = { 0.4, 0.56, 0.26 }, leafColor = { 0.33, 0.52, 0.24 },
}

K.poppy = { -- klaproos (Papaver rhoeas): branching hairy stems, the buds hang, open red, a pepperpot
    name = 'klaproos', stems = { 2, 4, 0.35 }, axiom = 'FLFLX', iter = 3,
    rules = { X = { { 'F[+FLX]FX', 0.5 }, { 'F[-FLX]FX', 0.5 }, { 'FFX', 0.4 } } }, final = { X = 'FFH' },
    angle = 28, len = 40, profile = { 0.7, 1, 1.2 }, branchLen = 0.95, width = 8, tip = 3, up = 0.06, sag = 0.02,
    wander = 0.35, phyllo = 'alternate',
    leaf = { shapes = { 'frond-01' }, len = 95, wk = 0.5, angle = 0.8, droop = 0.35 }, leafProfile = { 1.2, 0.7, 0.4 },
    heads = { H = { style = 'cup', size = 85, mass = 1.6, petals = 4, budNod = 3.2,
        colors = { { 0.9, 0.15, 0.12 }, { 0.95, 0.25, 0.12 } }, heart = { 0.15, 0.12, 0.12 } } },
    stemColor = { 0.42, 0.56, 0.3 }, leafColor = { 0.38, 0.55, 0.3 },
}

K.dandelion = { -- paardenbloem (Taraxacum): a flat rosette of toothed leaves, bare hollow stalks, clocks
    name = 'paardenbloem', stems = { 2, 5, 0.5 }, axiom = 'FFFX', iter = 1,
    rules = { X = { { 'FH', 1 }, { 'FFH', 0.6 } } }, final = {},
    angle = 20, len = 50, profile = { 1, 1, 1 }, width = 8, tip = 5, up = 0.08, sag = 0.01, wander = 0.2,
    footSpread = 6, sunny = 0.5,
    rosette = { count = 9, angle = 1.35, size = 1, vary = 2, leaf = { shapes = { 'frond-01', 'frond-02' },
        len = 160, wk = 0.42, droop = 0.4, lie = true } },
    heads = { H = { style = 'ray', size = 80, mass = 1, face = 0.55, petals = 26, petal = 'petal', petalWk = 0.35,
        colors = { { 0.99, 0.8, 0.1 } }, heart = { 0.98, 0.72, 0.08 }, heartK = 0.25, clock = true, budNod = 0.5 } },
    stemColor = { 0.5, 0.6, 0.38 }, leafColor = { 0.34, 0.55, 0.24 },
}

K.tulip = { -- tulip: two broad leaves clasping the foot, one stalk, a cup
    name = 'tulp', stems = { 1, 1, 0 }, axiom = 'FFFFX', iter = 1, rules = { X = { { 'FFT', 1 } } }, final = {},
    angle = 10, len = 58, profile = { 1, 1, 1 }, width = 10, tip = 7, up = 0.08, sag = 0.008, wander = 0.12,
    rosette = { count = 3, angle = 0.45, size = 1, vary = 0, leaf = { shapes = { 'oval-02', 'oval-04' },
        len = 290, wk = 0.36, droop = 0.55 } },
    heads = { T = { style = 'cup', size = 120, mass = 2, petals = 3, tulip = true,
        colors = { { 0.9, 0.2, 0.24 }, { 0.98, 0.52, 0.2 }, { 0.92, 0.45, 0.66 }, { 0.98, 0.86, 0.32 } } } },
    stemColor = { 0.42, 0.6, 0.32 }, leafColor = { 0.42, 0.6, 0.38 },
}

K.mint = { -- watermunt (Mentha aquatica): square stems, opposite crossing pairs, lilac whorls, a top ball
    name = 'watermunt', stems = { 2, 3, 0.25 }, axiom = 'FOFOFOFOFwFwFW', iter = 0, rules = {}, final = {},
    angle = 20, len = 50, profile = { 0.7, 1, 0.8 }, width = 8, tip = 4, up = 0.06, sag = 0.015, wander = 0.3,
    lean = 0.12, phyllo = 'decussate',
    leaf = { shapes = { 'oval-01', 'oval-03', 'oval-05' }, len = 75, wk = 0.65, angle = 1.0, droop = 0.3,
        petiole = 0.15 }, leafProfile = { 1, 1, 0.6 },
    heads = { w = { style = 'whorl', size = 55, mass = 0.4, colors = { { 0.78, 0.6, 0.85 }, { 0.7, 0.52, 0.8 } } },
        W = { style = 'dots', size = 85, mass = 0.8, colors = { { 0.8, 0.62, 0.88 }, { 0.72, 0.55, 0.82 } } } },
    stemColor = { 0.48, 0.38, 0.32 }, leafColor = { 0.3, 0.48, 0.24 },
}

K.grass = { -- a grass tuft: arching blades, a few culms with nodding seed spikes
    name = 'gras', stems = { 2, 4, 0.3 }, axiom = 'FFFFX', iter = 2,
    rules = { X = { { 'FX', 1 } } }, final = { X = 'S' },
    angle = 10, len = 55, profile = { 1, 1, 1 }, width = 5, tip = 2.5, up = 0.04, sag = 0.06, wander = 0.25,
    footSpread = 10,
    rosette = { count = 14, angle = 0.55, size = 1, vary = 3, leaf = { shapes = { 'oval-02', 'oval-04' },
        len = 260, wk = 0.11, droop = 1.0 } },
    heads = { S = { style = 'spike', size = 110, mass = 1.4, colors = { { 0.75, 0.68, 0.45 }, { 0.62, 0.6, 0.4 } },
        oldNod = 0.5 } },
    stemColor = { 0.5, 0.62, 0.32 }, leafColor = { 0.4, 0.6, 0.28 },
}

K.sunflower = { -- zonnebloem: a thick stem, big leaves round it, one heavy head that bows as it seeds
    name = 'zonnebloem', stems = { 1, 1, 0 }, axiom = 'FLX', iter = 11,
    rules = { X = { { 'FLX', 1 } } }, final = { X = 'FH' },
    angle = 20, len = 85, profile = { 0.6, 1, 0.7 }, width = 30, tip = 12, up = 0.06, sag = 0.006, wander = 0.08,
    sunny = 0.6, phyllo = 'spiral',
    leaf = { shapes = { 'oval-01', 'oval-05' }, len = 330, wk = 0.9, angle = 1.0, droop = 0.7, petiole = 0.3,
        ageOpen = 0.4 }, leafProfile = { 0.9, 1.1, 0.5 }, leafMass = 0.25,
    heads = { H = { style = 'ray', size = 300, mass = 10, face = 0.85, petals = 22, petal = 'petal', petalWk = 0.6,
        colors = { { 0.98, 0.78, 0.12 }, { 0.98, 0.68, 0.1 } }, heart = { 0.42, 0.26, 0.12 }, heartK = 0.55,
        budNod = 0.3, oldNod = 2.5 } },
    stemColor = { 0.42, 0.56, 0.24 }, leafColor = { 0.34, 0.54, 0.2 },
}

K.foxglove = { -- vingerhoedskruid (Digitalis): a rosette, one tall stem, bells to one side opening upward
    name = 'vingerhoedskruid', stems = { 1, 1, 0 }, axiom = 'FLFLFLFLX', iter = 10,
    rules = { X = { { 'FbX', 1 } } }, final = { X = 'fbfbf' },
    angle = 15, len = 52, profile = { 1, 0.85, 0.55 }, width = 14, tip = 4, up = 0.06, sag = 0.006, wander = 0.12,
    phyllo = 'spiral', leaf = { shapes = { 'oval-01', 'oval-03' }, len = 140, wk = 0.5, angle = 0.8, droop = 0.4 },
    leafProfile = { 1, 0.5, 0.3 },
    rosette = { count = 9, angle = 1.3, size = 1.7, leaf = { shapes = { 'oval-01', 'oval-02', 'oval-05' },
        len = 140, wk = 0.5, droop = 0.6, lie = true } },
    heads = { b = { style = 'bell', pendant = true, oneSided = true, angle = 1.35, hang = 0.4, size = 95, mass = 0.6,
        colors = { { 0.82, 0.4, 0.68 }, { 0.88, 0.5, 0.75 } }, white = 0.15 } },
    stemColor = { 0.4, 0.52, 0.3 }, leafColor = { 0.36, 0.52, 0.3 },
}

K.solomon = { -- salomonszegel (Polygonatum): an arching stem, leaves in two rows, bells hanging in pairs
    name = 'salomonszegel', stems = { 1, 2, 0.3 }, axiom = 'FFX', iter = 9,
    rules = { X = { { 'FLbX', 1 } } }, final = { X = 'FL' },
    angle = 10, len = 52, profile = { 1.2, 1, 0.7 }, width = 9, tip = 3, up = 0.01, sag = 0.085, wander = 0.1,
    lean = 0.35, phyllo = 'flat',
    leaf = { shapes = { 'oval-02', 'oval-03' }, len = 125, wk = 0.55, angle = 0.75, droop = 0.35, ageOpen = 0,
        level = 0.55 },
    leafProfile = { 0.8, 1.1, 0.7 }, leafMass = 0.35, leafMissing = 0,
    heads = { b = { style = 'bell', pendant = true, angle = 0.4, hang = 1, size = 80, mass = 0.35, slim = true,
        pair = true,
        colors = { { 0.96, 0.97, 0.92 } } } },
    stemColor = { 0.45, 0.58, 0.32 }, leafColor = { 0.32, 0.5, 0.26 },
}

K.fern = { -- mannetjesvaren (Dryopteris): a shuttlecock of fronds, pinnae in pairs, unrolling croziers
    name = 'mannetjesvaren', stems = { 5, 8, 0.9 }, axiom = 'FFX', iter = 13,
    rules = { X = { { 'FOX', 1 } } }, final = { X = 'FO' },
    angle = 10, len = 30, profile = { 1.4, 1, 0.6 }, width = 7, tip = 2, up = 0.02, sag = 0.04, wander = 0.15,
    curl = 0.9, phyllo = 'flat', footSpread = 8,
    leaf = { shapes = { 'oval-03', 'oval-04', 'petal-02' }, len = 90, wk = 0.42, angle = 1.25, droop = 0.15,
        ageOpen = 0 }, leafProfile = { 0.6, 1, 0.25 }, leafMass = 0.4, leafMissing = 0.02,
    stemColor = { 0.4, 0.5, 0.28 }, leafColor = { 0.3, 0.52, 0.24 },
}

K.cowparsley = { -- fluitenkruid (Anthriscus): fern-like leaves, branching, flat white umbels on rays
    name = 'fluitenkruid', stems = { 1, 2, 0.2 }, axiom = 'FLFLF[+FLFX]FLFX', iter = 1,
    rules = { X = { { '[++fU][+fU][fU][-fU][--fU]', 1 }, { '[+++fU][+fU][-fU][---fU]', 0.7 } } }, final = {},
    angle = 14, len = 115, profile = { 1, 1, 0.8 }, branchLen = 0.8, width = 16, tip = 3, up = 0.05,
    sag = 0.012, wander = 0.2, phyllo = 'alternate',
    leaf = { shapes = { 'frond-01', 'frond-02' }, len = 230, wk = 0.7, angle = 0.9, droop = 0.4, petiole = 0.25 },
    leafProfile = { 1.3, 0.8, 0.4 },
    heads = { U = { style = 'umbel', size = 110, mass = 0.5, colors = { { 0.98, 0.97, 0.92 }, { 0.93, 0.93, 0.86 } } } },
    stemColor = { 0.42, 0.52, 0.3 }, leafColor = { 0.36, 0.56, 0.26 },
}

K.nettle = { -- grote brandnetel (Urtica dioica): a clump of square upright stems, crossing pairs of heart-shaped
    -- leaves, green flower tassels hanging from the upper leaves' feet
    name = 'brandnetel', stems = { 3, 6, 0.22 }, axiom = 'FOFOFOFOFcOFcOFcOFcOFO', iter = 0, rules = {}, final = {},
    angle = 15, len = 62, profile = { 0.7, 1, 0.65 }, width = 11, tip = 3, up = 0.06, sag = 0.012, wander = 0.2,
    footSpread = 30, phyllo = 'decussate',
    leaf = { shapes = { 'oval-01', 'oval-05' }, len = 130, wk = 0.62, angle = 1.0, droop = 0.65, petiole = 0.2 },
    leafProfile = { 0.8, 1.1, 0.55 }, leafMass = 0.35,
    heads = { c = { style = 'catkin', pendant = true, angle = 0.9, hang = 0.7, size = 110, mass = 0.2,
        colors = { { 0.6, 0.66, 0.4 }, { 0.66, 0.6, 0.42 } } } },
    stemColor = { 0.36, 0.42, 0.26 }, leafColor = { 0.25, 0.42, 0.2 },
}

K.whiteclover = { -- witte klaver (Trifolium repens): low, three-part leaves on long stalks from the ground, white
    -- balls on bare stalks a little above them
    name = 'witte klaver', stems = { 2, 5, 0.6 }, axiom = 'FFX', iter = 1, rules = { X = { { 'FH', 1 }, { 'H', 0.6 } } },
    final = {}, angle = 10, len = 45, profile = { 1, 1, 1 }, width = 5, tip = 3.5, up = 0.1, sag = 0.01, wander = 0.25,
    footSpread = 40,
    rosette = { count = 9, angle = 0.95, size = 1, vary = 2, closing = 0.5, leaf = { shapes = { 'oval-03', 'oval-04' },
        len = 150, wk = 0.95, droop = 0.4, petiole = 0.55, leaflets = 3 } },
    heads = { H = { style = 'dots', size = 60, mass = 0.6, colors = { { 0.98, 0.97, 0.92 }, { 0.95, 0.9, 0.88 } } } },
    stemColor = { 0.48, 0.6, 0.34 }, leafColor = { 0.3, 0.52, 0.24 },
}

K.redclover = { -- rode klaver (Trifolium pratense): upright leafy stems, three-part leaves, pink-purple balls
    name = 'rode klaver', stems = { 2, 4, 0.35 }, axiom = 'FLFLX', iter = 2,
    rules = { X = { { 'FLX', 1 }, { 'F[+FLH]X', 0.4 } } }, final = { X = 'FLH' },
    angle = 30, len = 55, profile = { 0.8, 1, 0.6 }, width = 7, tip = 3, up = 0.07, sag = 0.015, wander = 0.3,
    lean = 0.15, phyllo = 'alternate',
    leaf = { shapes = { 'oval-03', 'oval-04' }, len = 150, wk = 0.85, angle = 0.9, droop = 0.35, petiole = 0.45,
        leaflets = 3 },
    leafProfile = { 1, 0.9, 0.6 },
    heads = { H = { style = 'dots', size = 80, mass = 0.8, colors = { { 0.85, 0.42, 0.62 }, { 0.78, 0.36, 0.58 } } } },
    stemColor = { 0.45, 0.55, 0.3 }, leafColor = { 0.32, 0.52, 0.26 },
}

K.houseleek = { -- huislook (Sempervivum): a tight rosette of fat pointed leaves curving in, red at the tips,
    -- small rosettes (offsets) round it
    name = 'huislook', stems = { 0, 0, 0 }, axiom = '', iter = 0, rules = {}, final = {},
    angle = 0, len = 0, width = 6, tip = 3,
    rosette = { count = 18, angle = 1.3, size = 1, vary = 2, closing = 0.75, pups = { 2, 4, 190, 0.5 },
        leaf = { shapes = { 'petal-01', 'petal-03', 'petal-05' }, len = 120, wk = 0.75, droop = -0.55,
            oldColor = { 0.7, 0.32, 0.35 } } },
    stemColor = { 0.5, 0.58, 0.45 }, leafColor = { 0.45, 0.6, 0.45 },
}

K.echeveria = { -- echeveria: a blue-grey rosette of thick spoon leaves cupped upward, pink-edged, an arching
    -- stalk with small orange bells
    name = 'echeveria', stems = { 1, 2, 0.6 }, axiom = 'FLFLFX', iter = 1, rules = { X = { { 'fbfbfbfbfb', 1 } } },
    final = {}, angle = 10, len = 48, profile = { 1, 1, 0.6 }, width = 7, tip = 3, up = 0.02, sag = 0.07, wander = 0.15,
    lean = 0.5, phyllo = 'spiral',
    leaf = { shapes = { 'petal-02', 'petal-04' }, len = 28, wk = 0.7, angle = 0.6, droop = 0 }, leafProfile = { 1, 0.8, 0.6 },
    rosette = { count = 20, angle = 1.35, size = 1, vary = 3, closing = 0.7,
        leaf = { shapes = { 'petal-01', 'petal-04', 'petal-06' }, len = 170, wk = 0.85, droop = -0.45,
            oldColor = { 0.78, 0.55, 0.62 } } },
    heads = { b = { style = 'bell', pendant = true, angle = 0.7, hang = 0.6, size = 42, mass = 0.4, slim = true,
        colors = { { 0.98, 0.55, 0.3 }, { 0.95, 0.65, 0.35 } } } },
    stemColor = { 0.62, 0.55, 0.5 }, leafColor = { 0.55, 0.66, 0.66 },
}

K.aloe = { -- aloë: a rosette of thick grey-green sword leaves, a tall stalk ending in hanging orange tubes
    name = 'aloë', stems = { 1, 1, 0 }, axiom = 'FFFFFFX', iter = 1, rules = { X = { { 'fbfbfbfbfbfbfbfbfb', 1 } } },
    final = {}, angle = 10, len = 80, profile = { 1, 1, 0.4 }, width = 13, tip = 5, up = 0.08, sag = 0.004, wander = 0.08,
    heads = { b = { style = 'bell', pendant = true, angle = 1.0, hang = 0.75, size = 55, mass = 0.3, slim = true,
        colors = { { 0.95, 0.45, 0.2 }, { 0.98, 0.6, 0.25 } } } },
    rosette = { count = 14, angle = 0.95, size = 1, vary = 2, closing = 0.6,
        leaf = { shapes = { 'oval-02', 'oval-04' }, len = 300, wk = 0.3, droop = 0.15, oldColor = { 0.6, 0.5, 0.42 } } },
    stemColor = { 0.5, 0.5, 0.36 }, leafColor = { 0.45, 0.58, 0.48 },
}

K.sedum = { -- hemelsleutel (Sedum telephium): upright fleshy stems, fat blue-green leaves round them, a flat pink
    -- head of tiny stars
    name = 'hemelsleutel', stems = { 3, 5, 0.28 }, axiom = 'FLFLFLFLFLFLFLX', iter = 1, rules = { X = { { 'fU', 1 } } },
    final = {}, angle = 10, len = 38, profile = { 0.8, 1, 0.7 }, width = 9, tip = 5, up = 0.06, sag = 0.02, wander = 0.15,
    footSpread = 25, phyllo = 'spiral',
    leaf = { shapes = { 'petal-01', 'petal-04', 'oval-03' }, len = 85, wk = 0.8, angle = 0.95, droop = 0.08,
        ageOpen = 0.2 },
    leafProfile = { 0.9, 1, 0.7 }, leafMass = 0.4, leafMissing = 0.02,
    heads = { U = { style = 'umbel', size = 130, mass = 1.5, colors = { { 0.88, 0.55, 0.65 }, { 0.82, 0.48, 0.6 } } } },
    stemColor = { 0.55, 0.62, 0.5 }, leafColor = { 0.48, 0.62, 0.52 },
}

K.reed = { -- riet (Phragmites): tall stiff canes, long blade leaves held out and drooping, a purple-brown plume
    name = 'riet', stems = { 4, 7, 0.18 }, axiom = 'FLFLFLFLFLFLFLFX', iter = 1, rules = { X = { { 'fH', 1 } } },
    final = {}, angle = 10, len = 95, profile = { 0.7, 1, 0.8 }, width = 11, tip = 5, up = 0.05, sag = 0.006,
    wander = 0.08, footSpread = 40, phyllo = 'alternate',
    leaf = { shapes = { 'oval-02', 'oval-04' }, len = 380, wk = 0.1, angle = 0.75, droop = 1.1, ageOpen = 0.1 },
    leafProfile = { 0.7, 1, 0.6 }, leafMass = 0.25, leafMissing = 0.04,
    heads = { H = { style = 'panicle', size = 300, mass = 3, branches = 13, spikelets = 6, spread = 0.45, reach = 0.4,
        droop = 0.12, dot = 0.04, oldNod = 0.8, colors = { { 0.52, 0.38, 0.42 }, { 0.6, 0.48, 0.42 } } } },
    stemColor = { 0.52, 0.6, 0.36 }, leafColor = { 0.4, 0.56, 0.3 },
}

K.foxtail = { -- grote vossenstaart (Alopecurus pratensis): a tuft, culms with a leaf or two, soft cylinder heads
    name = 'vossenstaart', stems = { 5, 9, 0.3 }, axiom = 'FFFLFFFX', iter = 1, rules = { X = { { 'FH', 1 } } }, final = {},
    angle = 10, len = 70, profile = { 1, 1, 0.9 }, width = 5, tip = 3, up = 0.05, sag = 0.015, wander = 0.2,
    footSpread = 14, phyllo = 'alternate',
    leaf = { shapes = { 'oval-02', 'oval-04' }, len = 200, wk = 0.1, angle = 0.6, droop = 0.7 }, leafMass = 0.1,
    rosette = { count = 12, angle = 0.5, size = 1, vary = 3, leaf = { shapes = { 'oval-02', 'oval-04' },
        len = 300, wk = 0.1, droop = 1.0 } },
    heads = { H = { style = 'tail', size = 130, mass = 1.2, dots = 26, thick = 0.15, oldNod = 0.4,
        colors = { { 0.62, 0.66, 0.48 }, { 0.58, 0.5, 0.55 } } } },
    stemColor = { 0.5, 0.62, 0.34 }, leafColor = { 0.4, 0.58, 0.28 },
}

K.bentgrass = { -- struisgras (Agrostis capillaris): many thin culms, airy reddish clouds of tiny spikelets
    name = 'struisgras', stems = { 6, 11, 0.4 }, axiom = 'FFFLFFFX', iter = 1, rules = { X = { { 'FH', 1 } } }, final = {},
    angle = 10, len = 62, profile = { 1, 1, 0.9 }, width = 4, tip = 2, up = 0.05, sag = 0.02, wander = 0.25,
    footSpread = 14, phyllo = 'alternate',
    leaf = { shapes = { 'oval-02' }, len = 140, wk = 0.09, angle = 0.6, droop = 0.6 }, leafMass = 0.08,
    rosette = { count = 10, angle = 0.6, size = 1, vary = 3, leaf = { shapes = { 'oval-02', 'oval-04' },
        len = 220, wk = 0.09, droop = 1.0 } },
    heads = { H = { style = 'panicle', size = 180, mass = 0.8, branches = 8, spikelets = 4, spread = 0.9, reach = 0.55,
        droop = 0.05, dot = 0.045, colors = { { 0.68, 0.42, 0.42 }, { 0.6, 0.5, 0.45 } } } },
    stemColor = { 0.52, 0.58, 0.36 }, leafColor = { 0.42, 0.58, 0.3 },
}

K.ORDER = { 'daisy', 'poppy', 'dandelion', 'tulip', 'mint', 'grass',
    'sunflower', 'foxglove', 'solomon', 'fern', 'cowparsley',
    'nettle', 'whiteclover', 'redclover', 'houseleek', 'echeveria', 'aloe', 'sedum',
    'reed', 'foxtail', 'bentgrass' }

return K
