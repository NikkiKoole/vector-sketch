-- src/mipo-dna.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local appearance = require('src.mipo-appearance')
local utils = require('src.utils')
local ST = require('src.shape-types')
local JT = require('src.joint-types')
local D = require('src.dna-defaults')

-- Ears hang on a soft weld: the angle springs back to the stanceAngle, the root stays
-- put. On a hinge (+-11 deg) they lay on a limit all the time, drooping, one up and one
-- down when the head tilted. frequency is Hz at the reference meter (physics-units).
lib.earSpring = { frequency = 3, dampingRatio = 0.25 }
local function earJoint()
    return { type = JT.WELD, frequency = lib.earSpring.frequency, dampingRatio = lib.earSpring.dampingRatio }
end

-- Torso layers: above the ears (190), below the head (200) with its bodyhair too. Both
-- used to be 200 (bodyhair 210), and same-z layers draw in fixture-id order: P4re5's
-- torso bodyhair covered its head. Saved Mipos are moved over by migrateDNA.
local TORSO_SKIN_Z = 192
local TORSO_HAIR_ABOVE_SKIN = 5

local add, initBlock = appearance.add, appearance.initBlock
local createDefaultTextureDNABlock = appearance.createDefaultTextureDNABlock


local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = true,
            neckSegments = 0,
            torsoSegments = 1,
            noseSegments = 1, -- 0 = no nose; >0 = segmented nose/trunk
        },
        positioners = {
            leg = { x = 0.5 },
            ear = { y = 0.5 },
            nose = { t = 0.35 },
        },
        faceMagnitude = 1,


        -- in the apppearance below we have a few options for types:
        -- skin = a skin that assumes a shape8 url to be present.
        -- bodyhair, = an overlay that assumes the shape8 url to be present, it will follow that
        -- connected-skin = a texture that will be drawn over a few connectd bodyparts
        -- connected-hair = an overlay that assumes a few parts to be there too.
        -- todo trace-hair, a texture that follows a few vertex indicises within 1 shape.
        parts = {
            ['nose-segment-template'] = {
                dims = { w = 40, h = 40, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 32, up = math.pi / 32 } }
            },
            ['nose-single-template'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 350, -- physics nose: in front of body/legs, behind arms (402) and hands (500)
                        main = initBlock('shapeA2'),
                    },
                },
                dims = { w = 40, h = 40, w2 = 4, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 32, up = math.pi / 32 } }
            },
            ['torso-segment-template'] = {
                appearance = {
                    -- this will do the neck texturing (connecting torso and head)
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), {}),
                        endNode = 'head',
                        zOffset = 100,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'head',
                        zOffset = 101,
                    },
                    ['skin'] = {
                        zOffset = 192, -- TORSO_SKIN_Z
                        main = initBlock(),
                        patch1 = add(initBlock('patch2'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = add(initBlock('borsthaar4'), {}) },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 3,
                        main = initBlock('hair7'),
                    },
                    ['face'] = utils.deepCopy(D.face),
                },
                dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 },
                shape8URL = 'shapeA1.png',
                shape = ST.SHAPE8,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 },
            --    shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = {

                dims = { w = 80, w2 = 4, h = 150 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = ST.CAPSULE,
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 200,
                        main = initBlock(),
                        patch1 = add(initBlock('patch1'), { tx = -0.33, ty = 0 }),
                        patch2 = add(initBlock('patch1'), { tx = 0.33, ty = 0 }),
                        patch3 = add(initBlock('patch1'), { tx = 0, ty = 0.83, sx = 2 })
                    },
                    ['bodyhair'] = { main = initBlock('borsthaar4') },
                    ['haircut'] = {
                        startIndex = 6,
                        endIndex = 3,
                        main = add(initBlock('hair6'), { fgURL = '' }),
                    },
                    ['face'] = utils.deepCopy(D.face),
                },
                dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'shapeA2.png',
                behaviors = { { name = 'KEEP_ANGLE', angle = 0 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 4, up = math.pi / 4 } }
            },
            ['luleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lfoot',
                        zOffset = 300,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot',
                        zOffset = 301,
                    }
                },
                dims = { w = 80, h = 400, w2 = 4 },
                shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } }
            },
            ['ruleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rfoot',
                        zOffset = 300,
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rfoot',
                        zOffset = 301,
                    }
                },
                dims = { w = 80, h = 400, w2 = 4 },
                shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 400, w2 = 4 }, shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 400, w2 = 4 }, shape = ST.CAPSULE,
                behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } },
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 402,
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lhand',
                        zOffset = 403,
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = 0, up = math.pi } }
            },
            ['ruarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 402,
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rhand',
                        zOffset = 403,
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE,
                j = { type = JT.REVOLUTE, limits = { low = -math.pi, up = 0 } }
            },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 },
                shape = ST.CAPSULE, j = { type = JT.REVOLUTE, limits = {} } },
            ['lfoot'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 399,
                        main = add(initBlock(), { dir = -1 }),
                    },

                },
                dims = { w = 80, h = 150, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rfoot'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 399,
                        main = add(initBlock(), { dir = 1 }),
                    },
                },
                dims = { w = 80, h = 150, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'feet6r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            --['lfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            --['rfoot'] = { dims = { w = 80, h = 250 }, shape = ST.CAPSULE,
            --    j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 500,
                        main = add(initBlock(), { dir = -1 }),
                    },
                },
                dims = { w = 40, h = 40, sx = 1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rhand'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 500,
                        main = add(initBlock(), {}),
                    },
                },
                dims = { w = 40, h = 40, sx = -1, sy = 1 },
                shape = ST.SHAPE8,
                shape8URL = 'hand3r.png',
                j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle',
            --     j = { type = JT.REVOLUTE, limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 190,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 100, h = 300, sx = .5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = earJoint(),
                stanceAngle = -math.pi / 2 + math.pi / 5
            },
            ['rear'] = {
                appearance = {
                    ['skin'] = {
                        zOffset = 190,
                        main = add(initBlock(), {}),
                        --patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        --patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    }
                },
                dims = { w = 100, h = 300, sx = -.5, sy = 1 },

                shape = ST.SHAPE8,
                shape8URL = 'earx1r.png',
                j = earJoint(),
                stanceAngle = math.pi / 2 - math.pi / 5
            }
        },

    }
}




lib.dna = dna
lib.earJoint = earJoint
lib.TORSO_SKIN_Z = TORSO_SKIN_Z
lib.TORSO_HAIR_ABOVE_SKIN = TORSO_HAIR_ABOVE_SKIN

return lib
