local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'



-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in lib.drawTexturedWorld(world)
-- the torso images, or maybe everyt texfixture also needs a growvalue that describes how much the w, h values will be grown.
-- next the chesthair has a grow too, the torso too, i also have afoot offset value that should be parametrized.


local shape8Dict = {
    ['shapeA1.png'] = {
        v = {
            1.61, -272.46, 112.13, -133.04, 154.81, 76.67, 123.57, 229.44, 1.21, 273.51, -134.54, 225.43, -145.28, 73.64, -91.99, -132.77
        }
    },
    ['shapeA2.png'] = {
        v = {
            11.62, -224.06, 60.89, -144.08, 59.89, -20.57, 133.96, 135.02, 4.30, 224.06, -133.96, 131.49, -51.71, -20.97, -39.30, -147.16,

        }
    },
    ['shapeA3.png'] = {
        v = {
            -6.62, -189.25, 135.88, -69.67, 160.54, 45.82, 123.85, 154.90, -6.37, 189.25, -92.40, 153.92, -164.61, 53.37, -155.10, -67.94
        }
    },
    ['shapeA4.png'] = {
        v = {
            7.91, -194.17, 133.01, -56.57, 126.54, 45.82, 101.32, 190.94, -6.99, 195.81, -129.67, 185.05, -134.73, 40.26, -110.48, -66.30

        }
    },


    ['shapes1.png'] = {
        v = {
            10.53, -244.02, 133.00, -56.57, 135.72, 48.44, 124.93, 221.11, -0.43, 231.23, -128.36, 215.22, -138.66, 41.58, -134.09, -62.36

        }
    },
    ['shapes2.png'] = {
        v = {
            -3.37, -223.15, 74.58, -78.83, 89.81, 51.22, 104.06, 196.07, -0.43, 231.23, -92.19, 202.70, -94.15, 54.10, -61.75, -80.45
        }
    },
    ['shapes3.png'] = {
        v = {
            -3.37, -206.98, 132.81, -137.06, 148.04, 12.40, 110.53, 186.37, -6.90, 216.67, -97.04, 192.99, -149.14, 7.194, -141.01, -141.91
        }
    },
    ['shapes4.png'] = {
        v = {
            0.52, -123.04, 164.04, -98.02, 148.04, 12.40, 157.384, 112.19, -1.05, 117.121, -149.75, 105.159, -149.14, 7.19, -168.33, -87.25
        }
    },
    ['shapes5.png'] = {
        v = {
            0.52, -162.14, 74.68, -132.92, 78.23, -4.34, 73.61, 148.49, -2.44, 156.21, -81.33, 142.85, -84.921, 1.609, -87.35, -126.353,

        }
    },
    ['shapes6.png'] = {
        v = {
            3.17, -178.04, 77.33, -118.34, 92.815, -0.36, 93.491, 143.19, -2.44, 160.19, -85.314, 141.53, -92.87, 0.28, -67.478, -119.727
        }
    },
    ['shapes7.png'] = {
        v = {
            -3.26, -452.74, 127.787, -245.570, 305.58, 19.37, 247.03, 384.48, -2.448, 451.92, -276.14, 378.42, -283.70, 15.63, -207.86, -238.17

        }
    },
    ['shapes8.png'] = {
        v = {
            3.90, -154.02, 271.18, -307.71, 341.43, 26.54, 89.31, 298.45, -9.62, 332.43, -166.22, 299.56, -302.83, 34.76, -238.93, -319.43

        }
    },
    ['shapes9.png'] = {
        v = {
            -0.56, -236.64, 233.22, -191.59, 198.53, 24.31, 174.16, 206.90, -18.55, 216.32, -226.51, 205.78, -233.61, 19.13, -234.46, -198.85


        }
    },
    ['shapes10.png'] = {
        v = {
            4.96, -407.86, 166.94, -232.10, 231.67, 24.31, 141.02, 344.99, -16.71, 418.85, -186.00, 332.82, -233.61, 19.13, -182.91, -233.83
        }
    },
    ['shapes11.png'] = {
        v = {
            4.96, -451.24, 110.80, -405.62, 195.94, 6.45, 306.89, 408.78, 13.91, 436.71, -277.86, 417.03, -205.54, -3.84, -114.01, -417.56
        }
    },
    ['shapes12.png'] = {
        v = {
            17.22, -129.91, 208.91, -76.93, 249.91, 11.35, 191.60, 109.52, 9.01, 142.36, -228.81, 103.06, -247.24, -1.39, -175.34, -91.32
        }
    },
    ['shapes13.png'] = {
        v = {
            22.72, -239.92, 175.91, -101.68, 197.65, 11.35, 177.85, 219.53, 14.51, 260.62, -168.30, 210.32, -156.48, 12.37, -125.83, -105.07
        }
    },


    ['feet2.png'] = {
        v = {

            -- 197.92951957406, -17.817718028013, 170.28347402696, 84.883981989375, 104.3382073697, 106.29365560207, -139.66342189896, 114.08328408959, -165.65174171676, -8.6379557618171, -123.63314042073, -45.112484801676, 86.784081767721, -100.15140769724, 155.71079120581, -103.47476376929


            22.724588666593, -239.91966159884, 175.91013654, -101.67978777203, 197.65083381201, 11.351997784339, 177.84539019051, 219.53355732218, 14.507790801039, 260.6223497519, -168.29987466902, 210.31594772675, -156.47637293323, 12.365272224268, -125.83138609296, -105.07368014657

        }
    },

    ['feet2r.png'] = {
        v = {

            -- 197.92951957406, -17.817718028013, 170.28347402696, 84.883981989375, 104.3382073697, 106.29365560207, -139.66342189896, 114.08328408959, -165.65174171676, -8.6379557618171, -123.63314042073, -45.112484801676, 86.784081767721, -100.15140769724, 155.71079120581, -103.47476376929

            46.990907603994, -189.52773689109, 96.489192783945, -184.68643013375, 131.34012844459, 48.508703705155, 109.48859096573, 180.93295171947, 45.027594164554, 234.39907734869, -15.618229361652, 176.92515604219, -70.173442070241, 53.300130131955, -87.304763540911, -193.80518221938


        }
    },




}
local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = false,
            neckSegments = 5,
            torsoSegments = 1
        },
        parts = {
            ['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 }, shape8URL = 'shapeA3.png', shape = 'shape8', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = { dims = { w = 80, w2 = 4, h = 150 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = { dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 }, shape = 'shape8', shape8URL = 'shapeA2.png', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['luleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['ruleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi } } },
            ['ruarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi, up = 0 } } },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['lfoot'] = { dims = { w = 80, h = 150, sx = 1, sy = 1 }, shape = 'shape8', shape8URL = 'feet2r.png', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['rfoot'] = { dims = { w = 80, h = 150, sx = -1, sy = 1 }, shape = 'shape8', shape8URL = 'feet2r.png', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            -- ['lfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = { dims = { w = 40, h = 40, sx = .5, sy = .9 }, shape = 'shape8', shape8URL = 'feet2r.png', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['rhand'] = { dims = { w = 40, h = 40, sx = -.5, sy = .9 }, shape = 'shape8', shape8URL = 'feet2r.png', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = -math.pi / 2 },
            ['rear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = math.pi / 2 }
        },
    }
}

local function randomHexColor()
    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)
    local a = 255 -- fully opaque, or adjust if you want random alpha

    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

function defaultSetupTextures(instance)
    -- take note: right leg has flippedX.

    -- torso
    if false then
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = true,
            group = 'torso1Skin',
            main = {
                bgURL = 'shapeA3.png',
                fgURL = 'shapeA3-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            attachTo = 'torso1',
        })
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = false,
            group = 'torso1Hair',
            zOffset = 40,
            followShape8 = 'shapeA3.png',
            main = {
                bgURL = 'borsthaar3.png',
                fgURL = '',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            attachTo = 'torso1',
        })
    end

    -- legs
    if false then
        table.insert(instance.textures, {
            label = 'connected-texture',
            type = 'sfixture',
            OMP = true,
            group = 'leftLegSkin',
            main = {
                bgURL = 'leg5.png',
                fgURL = 'leg5-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" },
            attachTo = 'luleg',
        })
        table.insert(instance.textures, {
            label = 'connected-texture',
            type = 'sfixture',
            OMP = false,
            zOffset = 40,
            group = 'leftLegHair',
            main = {
                bgURL = 'hair10.png',
                fgURL = '',
                pURL = '',
                bgHex = '020202ff',

            },
            jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" },
            attachTo = 'luleg',
        })
        table.insert(instance.textures, {
            label = 'connected-texture',
            type = 'sfixture',
            OMP = true,
            group = 'rightLegSkin',
            main = {
                bgURL = 'leg5.png',
                fgURL = 'leg5-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor(),
                fx = -1
            },
            jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" },
            attachTo = 'ruleg',
        })
        table.insert(instance.textures, {
            label = 'connected-texture',
            type = 'sfixture',
            OMP = false,
            zOffset = 40,
            group = 'rightLegHair',
            main = {
                bgURL = 'hair10.png',
                fgURL = '',
                pURL = '',
                bgHex = '000000ff',
                fx = -1

            },
            jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" },
            attachTo = 'ruleg',
        })
    end

    --feet
    if true then
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = true,
            group = 'lfootSkin',
            main = {
                bgURL = 'feet2r.png',
                fgURL = 'feet2r-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            attachTo = 'lfoot',
        })
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = true,
            group = 'rfootSkin',
            main = {
                bgURL = 'feet2r.png',
                fgURL = 'feet2r-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor(),
                fx = -1,
            },
            attachTo = 'rfoot',
        })
    end


    --hand
    if true then
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = true,
            group = 'lhandSkin',
            main = {
                bgURL = 'feet2r.png',
                fgURL = 'feet2r-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            attachTo = 'lhand',
        })
        table.insert(instance.textures, {
            label = 'texfixture',
            type = 'sfixture',
            OMP = true,
            group = 'rhandSkin',
            main = {
                bgURL = 'feet2r.png',
                fgURL = 'feet2r-mask.png',
                pURL = '',
                bgHex = '020202ff',
                fgHex = randomHexColor(),
                pHex = randomHexColor()
            },
            attachTo = 'rhand',
        })
    end
    -- neck
    if true then
        -- Assume neckSegments and torsoSegments are available
        local creation = instance.dna.creation
        local neckSegments = creation.neckSegments or 0
        local torsoSegments = creation.torsoSegments or 1

        local jointLabels = {}
        local previous = 'torso' .. torsoSegments

        for i = 1, neckSegments do
            local current = 'neck' .. i
            table.insert(jointLabels, previous .. '->' .. current)
            previous = current
        end

        -- Final connection to head
        table.insert(jointLabels, previous .. '->head')

        logger:inspect(jointLabels)
        if neckSegments > 0 and not creation.isPotatoHead then
            table.insert(instance.textures, {
                label = 'connected-texture',
                type = 'sfixture',
                OMP = true,
                group = 'neckSkin',
                main = {
                    bgURL = 'leg5.png',
                    fgURL = 'leg5-mask.png',
                    pURL = '',
                    bgHex = '020202ff',
                    fgHex = randomHexColor(),
                    pHex = randomHexColor()
                },
                jointLabels = jointLabels,
                attachTo = 'neck1',
            })
            table.insert(instance.textures, {
                label = 'connected-texture',
                type = 'sfixture',
                OMP = false,
                zOffset = 40,
                group = 'neckHair',
                main = {
                    bgURL = 'hair10.png',
                    fgURL = '',
                    pURL = '',
                    bgHex = '000000ff',
                    fx = -1

                },
                jointLabels = jointLabels,
                attachTo = 'neck1',
            })
        end
    end

    -- head
    if true then
        local creation = instance.dna.creation
        if not creation.isPotatoHead then
            table.insert(instance.textures, {
                label = 'texfixture',
                type = 'sfixture',
                OMP = true,
                group = 'headSkin',
                main = {
                    bgURL = 'shapeA2.png',
                    fgURL = 'shapeA2-mask.png',
                    pURL = '',
                    bgHex = '020202ff',
                    fgHex = randomHexColor(),
                    pHex = randomHexColor()
                },
                attachTo = 'head',
            })
            -- table.insert(instance.textures, {
            --     label = 'texfixture',
            --     type = 'sfixture',
            --     OMP = false,
            --     group = 'headHair',
            --     zOffset = 40,
            --     followShape8 = 'shapeA2.png',
            --     main = {
            --         bgURL = 'borsthaar3.png',
            --         fgURL = '',
            --         pURL = '',
            --         bgHex = '020202ff',
            --         fgHex = randomHexColor(),
            --         pHex = randomHexColor()
            --     },
            --     attachTo = 'head',
            -- })
        end
    end
end

-- copy pasted form playtime-ui.lua
local function getCenterAndDimensions(body)
    local ud = body:getUserData()
    local cx, cy, w, h
    if ud.thing.vertices then
        local verts = ud.thing.vertices
        cx, cy, w, h = mathutils.getCenterOfPoints(verts)
    else -- this is a circle shape..
        cx, cy = body:getPosition()

        w, h = ud.thing.radius * 2, ud.thing.radius * 2
    end
    return cx, cy, w, h
end


local function makeTransformedVertices(vertices, scaleX, scaleY)
    -- Initialize result array
    local transformedVertices = {}
    -- Loop through input vertices (stepping by 2)
    for i = 1, #vertices, 2 do
        -- Get original x, y
        local x = vertices[i]
        local y = vertices[i + 1]
        -- Calculate transformed x, y (scaling handles flipping)
        local newX = x * scaleX
        local newY = y * scaleY
        -- Add transformed pair to result array
        table.insert(transformedVertices, newX)
        table.insert(transformedVertices, newY)
    end
    -- Return the new array
    return transformedVertices
end

local function getTransformedIndex(index, flipX, flipY)
    if flipY == -1 and flipX == 1 then
        local values = { 5, 4, 3, 2, 1, 8, 7, 6 }
        return values[index]
    end
    if flipX == -1 and flipY == 1 then
        local values = { 1, 8, 7, 6, 5, 4, 3, 2 }
        return values[index]
    end
    if flipX == -1 and flipY == -1 then
        local values = { 5, 6, 7, 8, 1, 2, 3, 4 }
        return values[index]
    end
    if flipX == 1 and flipY == 1 then
        local values = { 1, 2, 3, 4, 5, 6, 7, 8 }
        return values[index]
    end
    -- print(index, flipX, flipY)
    -- logger:warn('why are we getting here?')
end

local function clamp(x, min, max)
    return x < min and min or (x > max and max or x)
end

local function lerp(a, b, amount)
    return a + (b - a) * clamp(amount, 0, 1)
end

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end

local function getParentAndChildrenFromPartName(partName, guy)
    local creation      = guy.dna.creation
    local neckSegments  = creation.neckSegments or 0
    local torsoSegments = creation.torsoSegments or 1

    local highestTorso  = 'torso' .. torsoSegments
    local lowestTorso   = 'torso1'

    local map           = {

        head = { p = (neckSegments > 0) and ('neck' .. neckSegments) or highestTorso, c = { 'lear', 'rear' } },
        lear = { p = 'head' },
        rear = { p = 'head' },
        luarm = { p = highestTorso, c = 'llarm' },
        llarm = { p = 'luarm', c = 'lhand' },
        lhand = { p = 'llarm' },
        ruarm = { p = highestTorso, c = 'rlarm' },
        rlarm = { p = 'ruarm', c = 'rhand' },
        rhand = { p = 'rlarm' },
        luleg = { p = lowestTorso, c = 'llleg' },
        llleg = { p = 'luleg', c = 'lfoot' },
        lfoot = { p = 'llleg' },
        ruleg = { p = lowestTorso, c = 'rlleg' },
        rlleg = { p = 'ruleg', c = 'rfoot' },
        rfoot = { p = 'rlleg' },

    }

    local neckIndex     = extractNeckIndex(partName)
    if neckIndex then
        if neckIndex == 1 then
            map[partName] = { p = highestTorso, c = (neckIndex == neckSegments) and 'head' or 'neck2' }
        else
            map[partName] = {
                p = 'neck' .. (neckIndex - 1),
                c = (neckIndex == neckSegments) and 'head' or
                    'neck' .. neckIndex + 1
            }
        end
    end
    --print(partName)
    local torsoIndex = extractTorsoIndex(partName)
    --logger:info('torsoIndex', torsoIndex)
    if torsoIndex then
        -- logger:info('torsoIndex', torsoIndex)
        if torsoIndex then
            local children = {}
            -- Middle segments connect only to the next torso segment
            if torsoIndex < torsoSegments then
                table.insert(children, 'torso' .. (torsoIndex + 1))
            end

            -- Highest segment connects to arms and neck/head
            if torsoIndex == torsoSegments then
                if not creation.isPotatoHead then
                    table.insert(children, (neckSegments > 0) and 'neck1' or 'head')
                end
                table.insert(children, 'luarm')
                table.insert(children, 'ruarm')
                if creation.isPotatoHead then -- Potato ears attach to highest torso
                    table.insert(children, 'lear')
                    table.insert(children, 'rear')
                end
            end

            -- Lowest segment connects to legs
            if torsoIndex == 1 then
                table.insert(children, 'luleg')
                table.insert(children, 'ruleg')
            end



            if torsoIndex == 1 then
                map[partName] = { c = children } -- Torso1 has no parent
            else
                map[partName] = { p = 'torso' .. (torsoIndex - 1), c = children }
            end
        end
    end

    -- Overrides for special cases

    -- Head connects directly to highest torso if no neck
    if partName == 'head' and neckSegments == 0 then
        map[partName] = { p = highestTorso, c = { 'lear', 'rear' } }
    end

    -- If Potato Head, ears parent is highest torso (head doesn't exist as parent)
    if creation.isPotatoHead then
        map['lear'] = { p = highestTorso }
        map['rear'] = { p = highestTorso }
        -- Remove head connection if it exists from map
        map['head'] = nil -- No head part in potato mode
    end

    -- If only one torso segment, it has all children directly
    if torsoSegments == 1 and partName == 'torso1' then
        local children = {}
        if creation.isPotatoHead then
            children = { 'luarm', 'ruarm', 'luleg', 'ruleg', 'lear', 'rear' }
        else
            children = { (neckSegments > 0) and 'neck1' or 'head', 'luarm', 'ruarm', 'luleg', 'ruleg' }
        end

        map[partName] = { c = children }
    end


    local result = map[partName]



    return result or {} -- Return empty table if partName not found
end

local function sign(value)
    if value < 0 or value == nil then return -1 else return 1 end
end

local function getOwnOffset(partName, guy)
    local parts = guy.dna.parts


    -- upward
    if extractNeckIndex(partName) then
        return 0, -parts[partName].dims.h / 2
    end
    if extractTorsoIndex(partName) then
        if parts[partName].shape == 'shape8' then
            -- local vertices = shape8Dict[parts[partName].shape8URL].v

            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)

            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))

            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end
    if partName == 'head' then
        -- return 0, -parts.head.dims.h / 2
        if parts[partName].shape == 'shape8' then
            --local vertices = shape8Dict[parts[partName].shape8URL].v


            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)

            --local topIndex = 1
            --local bottomIndex = 5
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))


            --return vertices[(index * 2) - 1], vertices[(index * 2)]
            return -vertices[(bottomIndex * 2) - 1], vertices[(topIndex * 2)]
        else
            return 0, -parts[partName].dims.h / 2
        end
    end
    if partName == 'lear' then
        return 0, -parts.lear.dims.h / 2
    end
    if partName == 'rear' then
        return 0, -parts.rear.dims.h / 2
    end


    -- downward
    if partName == 'luleg' then
        return 0, parts.luleg.dims.h / 2
    end
    if partName == 'ruleg' then
        return 0, parts.ruleg.dims.h / 2
    end
    if partName == 'llleg' then
        return 0, parts.llleg.dims.h / 2
    end
    if partName == 'lfoot' or partName == 'rfoot' then
        -- return 0, parts.lfoot.dims.h / 2


        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            --logger:info(part.dims.sx, part.dims.sy)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            -- todo like the grow offsets this too should be parametrized
            local footOffset = 0
            return vertices[(index * 2) - 1], -vertices[(index * 2)] + footOffset
        else
            return 0, part.dims.h / 2
        end
    end
    if partName == 'rlleg' then
        return 0, parts.rlleg.dims.h / 2
    end
    -- if partName == 'rfoot' then
    --     return 0, parts.rfoot.dims.h / 2
    -- end
    if partName == 'luarm' then
        return 0, parts.luarm.dims.h / 2
    end
    if partName == 'ruarm' then
        return 0, parts.ruarm.dims.h / 2
    end
    if partName == 'rhand' or partName == 'lhand' then
        --return 0, parts.rhand.dims.h / 2
        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            --logger:info(part.dims.sx, part.dims.sy)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another
            return vertices[(index * 2) - 1], -vertices[(index * 2)]
        else
            return 0, part.dims.h / 2
        end
    end
    if partName == 'llarm' then
        return 0, parts.llarm.dims.h / 2
    end
    if partName == 'rlarm' then
        return 0, parts.rlarm.dims.h / 2
    end
    --if partName == 'lhand' then
    --    return 0, parts.lhand.dims.h / 2
    --end
    return 0, 0
end

local function getOffsetFromParent(partName, guy)
    local parts         = guy.dna.parts
    local creation      = guy.dna.creation
    local positioners   = guy.dna.positioners
    local data          = getParentAndChildrenFromPartName(partName, guy)
    -- Define the name of the highest torso segment
    local torsoSegments = creation.torsoSegments or 1
    local highestTorso  = 'torso' .. torsoSegments
    -- Define the name of the lowest torso segment (always torso1)
    local lowestTorso   = 'torso1'


    local function getTorsoPart8FromSpecificTorso(index, torsoIndex)
        --local vertices = shape8Dict[parts[highestTorso].shape8URL].v

        local torso = 'torso' .. torsoIndex

        local raw = shape8Dict[parts[torso].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts[torso].dims.sx or 1, parts[torso].dims.sy or 1)
        local newIndex = getTransformedIndex(index, sign(parts[torso].dims.sx), sign(parts[torso].dims.sy))
        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    local function getTorsoPart8FromHighest(index)
        return getTorsoPart8FromSpecificTorso(index, torsoSegments)
    end

    local function getTorsoPart8FromLowest(index)
        return getTorsoPart8FromSpecificTorso(index, 1)
    end



    local function hasTorso8()
        if parts[highestTorso].shape == 'shape8' then
            return true
        end
        return false
    end

    local function hasHead8()
        if parts['head'].shape == 'shape8' then
            return true
        end
        return false
    end

    local function getHeadPart8(index)
        local raw = shape8Dict[parts['head'].shape8URL].v
        local vertices = makeTransformedVertices(raw, parts['head'].dims.sx or 1, parts['head'].dims.sy or 1)

        local newIndex = getTransformedIndex(index, sign(parts['head'].dims.sx), sign(parts['head'].dims.sy))

        -- local vertices = shape8Dict[parts['head'].shape8URL].v
        return vertices[(newIndex * 2) - 1], vertices[(newIndex * 2)]
    end

    if extractNeckIndex(partName) then
        local index = extractNeckIndex(partName)
        if index == 1 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            return 0, -parts['neck' .. (index - 1)].dims.h / 2
        end
    elseif extractTorsoIndex(partName) then
        local index = extractTorsoIndex(partName)
        if index == 1 then
            return 0, 0
        else
            if hasTorso8() then
                --print('getting here')
                return getTorsoPart8FromSpecificTorso(1, index - 1)
                -- return getTorsoPart8(1)
            else
                -- return 0, -parts[highestTorso].dims.h / 2
                return 0, -parts['torso' .. (index - 1)].dims.h / 2
            end


            --return 0, -parts['torso' .. (index - 1)].dims.h / 2
        end
    elseif partName == 'llarm' then
        return 0, parts.luarm.dims.h / 2
    elseif partName == 'rlarm' then
        return 0, parts.ruarm.dims.h / 2
    elseif partName == 'llleg' then
        return 0, parts.luleg.dims.h / 2
    elseif partName == 'lfoot' then
        return 0, parts.llleg.dims.h / 2
    elseif partName == 'rlleg' then
        return 0, parts.ruleg.dims.h / 2
    elseif partName == 'rfoot' then
        return 0, parts.rlleg.dims.h / 2
    elseif partName == 'rhand' then
        return 0, parts.rlarm.dims.h / 2
    elseif partName == 'lhand' then
        return 0, parts.llarm.dims.h / 2
    elseif partName == 'luarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(7)
            else
                return getTorsoPart8FromHighest(8)
            end
        else
            return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'ruarm' then
        if hasTorso8() then
            if creation.isPotatoHead then
                return getTorsoPart8FromHighest(3)
            else
                return getTorsoPart8FromHighest(2)
            end
        else
            return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
        end
    elseif partName == 'luleg' then
        local t = 0.5 --positioners.leg.x
        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(6)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (-parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'ruleg' then
        local t = 0.5 -- positioners.leg.x

        if hasTorso8() then
            local ax, ay = getTorsoPart8FromLowest(4)
            local bx, by = getTorsoPart8FromLowest(5)
            local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
            return rx, ry
        else
            return (parts[lowestTorso].dims.w / 2) * (1 - t), parts[lowestTorso].dims.h / 2
        end
    elseif partName == 'lear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(8)
                local bx, by = getTorsoPart8FromHighest(7)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(7)
                local bx, by = getHeadPart8(8)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return -parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif partName == 'rear' then
        if creation.isPotatoHead then
            if hasTorso8() then
                local t = 0.5
                local ax, ay = getTorsoPart8FromHighest(2)
                local bx, by = getTorsoPart8FromHighest(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts[highestTorso].dims.w / 2, -parts[highestTorso].dims.h / 2
            end
        else
            if hasHead8() then
                local t = 0.5
                local ax, ay = getHeadPart8(2)
                local bx, by = getHeadPart8(3)
                local rx, ry = lerp(ax, bx, t), lerp(ay, by, t)
                return rx, ry
            else
                return parts.head.dims.w / 2, -parts.head.dims.h / 2
            end
        end
    elseif (partName == 'head') then
        if creation.neckSegments == 0 then
            if hasTorso8() then
                return getTorsoPart8FromHighest(1)
            else
                return 0, -parts[highestTorso].dims.h / 2
            end
        else
            local last = 'neck' .. creation.neckSegments
            return 0, -parts[last].dims.h / 2
        end
    else
        return 0, 0
    end
end

local function getAngleOffset(partName, guy)
    local parts = guy.dna.parts
    if partName == 'lfoot' then
        return math.pi / 2
    elseif partName == 'rfoot' then
        return -math.pi / 2
    elseif partName == 'lear' then
        return parts.lear.stanceAngle
    elseif partName == 'rear' then
        return parts.rear.stanceAngle
    else
        return 0
    end
end


local function makePart(partName, instance, settings)
    local values = getParentAndChildrenFromPartName(partName, instance)
    local parent = values.p
    -- logger:info(partName, parent)

    local prevA = 0


    if parent then
        if instance.parts[parent] then
            local parentPosX, parentPosY = instance.parts[parent].body:getPosition()

            prevA = instance.parts[parent].body:getAngle()

            local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)


            settings.x = px
            settings.y = py
        end
    end


    --local parentOffsetX, parentOffsetY = getOffsetFromParent(partName, instance)
    local ownOffsetX, ownOffsetY = getOwnOffset(partName, instance)
    local xangle = getAngleOffset(partName, instance)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    -- logger:info(partName, prevA, xangle)


    local thing = ObjectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)

        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end
        --  logger:info('setting', partName)
        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]   --instance.parts[jointData.a]
        local partB_thing = instance.parts[partName] --instance.parts[jointData.b]
        -- logger:info(partA_thing, partB_thing)

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
            }
            --logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = getOffsetFromParent(partName, instance)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = Joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body
        local groupIndex = body:getFixtures()[1]:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end
    return poseCache
end
local function applyPoseCache(instance, poseCache)
    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            --body:setPosition(pose.pos[1], pose.pos[2])
            body:setAngle(pose.angle)
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local fixtures = body:getFixtures()
            for j = 1, #fixtures do
                fixtures[j]:setGroupIndex(pose.groupIndex)
            end
        end
    end
end

local function fixDrift(positionTorso, instance)
    -- this routine is to fix the drift we get .
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local newAngle = instance.parts['torso1'].body:getAngle()

        --local dx = oldPosX - newPosX

        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY
        --local da = oldAngle - newAngle

        --local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -newAngle)

        for _, part in pairs(instance.parts) do
            -- local px, py = part.body:getPosition()
            --local cx, cy = mathutils.rotatePoint(px, py, newPosX, newPosY, da)
            --   part.body:setPosition(cx + dx, cy + dy)
            --  part.body:setAngle(part.body:getAngle() + da)

            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end




local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end

    -- Apply dimension updates
    -- logger:inspect(data)
    for k, v in pairs(data) do
        --logger:info(k, v)
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end

    -- print(partName, instance.parts[partName], inspect(instance.dna.creation))
    local oldBody = instance.parts[partName].body
    local oldPosX, oldPosY = oldBody:getPosition()
    local oldAngle = oldBody:getAngle()

    -- Remove old body

    local extras = {}
    if instance.parts[partName] then
        local body = instance.parts[partName].body
        --extras = safeAllExtras(body)
        ObjectManager.destroyBody(body)
        instance.parts[partName] = nil
    end

    -- Recreate the part
    local settings = {
        x = oldPosX,
        y = oldPosY,
        bodyType = 'dynamic',
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        radius = partData.dims.r,
        width = partData.dims.w,
        width2 = partData.dims.w2,
        width3 = partData.dims.w2,
        height = partData.dims.h,
        height2 = partData.dims.h,
        height3 = partData.dims.h,
        height4 = partData.dims.h,
    }

    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = shape8Dict[partData.shape8URL].v
        settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
    end

    local children = getParentAndChildrenFromPartName(partName, instance).c or {}
    --logger:inspect(children)
    if type(children) == 'string' then
        children = { children }
    end
    makePart(partName, instance, settings)


    -- after making a part set it to its angle so the children will be using that angle in tehir calculations.
    instance.parts[partName].body:setAngle(oldAngle)


    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

-- update part
function lib.updatePart(partName, data, instance)
    --  preserveAllSpecialFixtures(instance)
    local positionTorso = nil
    local oldAngle = 0
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)

    -- update the thing
    updateSinglePart(partName, data, instance)

    applyPoseCache(instance, poseCache)
    --addTextufeFixturesFromInstance(instance)
    if positionTorso then fixDrift(positionTorso, instance) end
    -- restoreAllSpecialFixtures()
end

-- given an instance with dna and a new creation, this function is made to change a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings
    for k, v in pairs(newCreation) do
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }


    -- Step 2: Remove all existing parts
    for _, part in pairs(instance.parts) do
        ObjectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    instance.textures = {}

    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

function lib.addTextureFixturesFromInstance(instance)
    function removeSimilarFixture(body, it)
        local allFixtures = body:getFixtures()
        for fi = #allFixtures, 1, -1 do -- backwards to safely remove
            local f = allFixtures[fi]
            local ud = f:getUserData()
            --  logger:inspect(ud)
            if ud and ud.label == it.label and ud.extra.OMP == it.OMP then
                -- logger:info('destroying fixture')
                fixtures.destroyFixture(f)
            end
        end
    end

    for i = 1, #instance.textures do
        local it = instance.textures[i]
        if it.type == 'sfixture' then
            if it.label == 'texfixture' then
                local body = instance.parts[it.attachTo].body
                removeSimilarFixture(body, it)
                --print("body angle at texture creation:", body:getAngle())
                local cx, cy, w, h = getCenterAndDimensions(body)
                -- local localX, localY = body:getLocalPoint(wx, wy)
                local growfactor = 1.1
                local fixture = fixtures.createSFixture(body, 0, 0,
                    { label = 'texfixture', width = w * growfactor, height = h * growfactor })
                local ud = fixture:getUserData()
                ud.extra.OMP = it.OMP
                ud.extra.dirty = true
                ud.extra.main = utils.deepCopy(it.main)
                ud.extra.zOffset = it.zOffset or 0
                ud.extra.attachTo = it.attachTo
                local partData = instance.dna.parts[it.attachTo]
                if partData.dims.sy < 0 then
                    -- logger:inspect(ud.extra.main)
                    ud.extra.main.fy = -1
                    -- logger:info('should flip texture')
                end
                if partData.dims.sx < 0 then
                    -- logger:inspect(ud.extra.main)
                    ud.extra.main.fx = -1
                    -- logger:info('should flip texture')
                end
                if it.followShape8 then
                    ud.extra.followShape8 = it.followShape8
                    -- logger:inspect(ud.extra)
                    local raw = shape8Dict[it.followShape8].v
                    local partData = instance.dna.parts[it.attachTo]
                    local growfactor = 1.5
                    local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor,
                        (partData.dims.sy or 1) * growfactor)


                    ud.extra.vertices = vertices
                    ud.extra.vertexCount = #vertices / 2
                    -- logger:info('found a follo8')
                    --  logger:inspect(ud.extra)
                end
                -- followShape8 = 'shapeA3.png',


                --logger:info('texgisture to add:')
            end

            if it.label == 'connected-texture' then
                --print('got some stuff todo')
                print(it.attachTo)
                local body = instance.parts[it.attachTo].body

                -- REMOVE OLD CONNECTED-TEXTURE FIXTURES FIRST
                removeSimilarFixture(body, it)

                local fixture = fixtures.createSFixture(body, 0, 0, { label = 'connected-texture', radius = 30 })
                local ud = fixture:getUserData()
                ud.extra = {
                    attachTo = it.attachTo,
                    OMP = it.OMP,                   -- we will just alays use OUTLINE/ MASK / PATTERN TEXTURES for characters.
                    dirty = true,                   -- because the rendered needs to pick this up.
                    main = utils.deepCopy(it.main), -- this is still missing a lot but that will be defaulted
                    zOffset = it.zOffset or 0,
                    nodes = {

                    }

                }
                for j = 1, #it.jointLabels do
                    local jointID = it.jointLabels[j]
                    ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
                    --print(instance.joints[jointID])
                end
            end
        end
    end
end

function lib.updateTextureGroupValue(instance, group, key, value)
    for i = 1, #instance.textures do
        local t = instance.textures[i]
        if t.group == group and t.main then
            t.main[key] = value
            logger:info('setting', key, value)
        end
    end
end

function lib.updateTextureGroupValueInRoot(instance, group, key, value)
    for i = 1, #instance.textures do
        local t = instance.textures[i]
        if t.group == group then
            t[key] = value
            logger:info('setting', key, value)
        end
    end
end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.
    --
    local isPotato = instance.dna.creation.isPotatoHead
    local hasNeck = instance.dna.creation.neckSegments > 0
    local ordered = {}

    local torsoSegments = instance.dna.creation.torsoSegments or 1 -- Default to 1 torso segment
    -- 1. Add Torso Segments
    for i = 1, torsoSegments do
        local partName = 'torso' .. i
        table.insert(ordered, partName)
        -- Copy template DNA for this segment if it doesn't exist (it shouldn't)
        if not instance.dna.parts[partName] then
            -- Ensure template exists
            if not instance.dna.parts['torso-segment-template'] then
                error("Missing 'torso-segment-template' in DNA for template: " .. template)
            end
            instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])
            -- Optional: Modify dimensions/properties of specific segments here if needed
            -- e.g., make torso1 wider (pelvis) or torsoN narrower (shoulders)
            --instance.dna.parts[partName].dims.w = i * 100
            --logger:inspect(instance.dna.parts[partName])
            --  instance.dna.parts[partName].dims.w = ((torsoSegments + 1) - i) * 100
        end
    end

    if hasNeck and not isPotato then
        for i = 1, (instance.dna.creation.neckSegments or 2) do
            table.insert(ordered, 'neck' .. i)
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
    end
    if not isPotato then
        table.insert(ordered, 'head')
    end
    -- Common limbs
    local limbs = {
        'luleg', 'ruleg', 'llleg', 'rlleg', 'lfoot', 'rfoot',
        'luarm', 'ruarm', 'llarm', 'rlarm', 'lhand', 'rhand',
        'lear', 'rear'
    }
    for _, part in ipairs(limbs) do table.insert(ordered, part) end


    for i = 1, #ordered do
        local partName = ordered[i]
        local partData = instance.dna.parts[partName]
        --logger:info(partName, partData.shapeName)
        local settings = {
            x = x,
            y = y,
            bodyType = 'dynamic',       -- Start as dynamic, will be adjusted later if inactive
            shapeType = partData.shape, -- Use shape defined in template
            shape8URL = partData.shape8URL,
            label = partName,           --partName,           -- Use part name as initial label
            density = partData.density or 1,
            radius = partData.dims.r,
            width = partData.dims.w,
            width2 = partData.dims.w2,
            width3 = partData.dims.w2,
            height = partData.dims.h,
            height2 = partData.dims.h,
            height3 = partData.dims.h,
            height4 = partData.dims.h,

            -- Add other physics properties if needed (friction, restitution?)
        }

        if (partData.shape8URL) then
            if (shape8Dict[partData.shape8URL]) then
                local raw = shape8Dict[partData.shape8URL].v
                settings.vertices = makeTransformedVertices(raw, partData.dims.sx or 1, partData.dims.sy or 1)
            end
        end
        --logger:info('getting offset for ', partName)



        makePart(partName, instance, settings)
        if optionalTorsoAngle and partName == 'torso1' then
            instance.parts['torso1'].body:setAngle(optionalTorsoAngle)
        end
    end


    -- here we will build up the sfixtures we need.

    defaultSetupTextures(instance)
    lib.addTextureFixturesFromInstance(instance)
    return instance
end

function lib.createCharacter(template, x, y)
    if dna[template] then
        local instance = {
            id = uuid.generateID(),
            templateName = template,
            dna = utils.deepCopy(dna[template]), -- Copy template data for potential instance modification
            parts = {},                          -- { [partName] = thingObject, ... }
            joints = {},                         -- unused...{ [connectionName] = jointObject, ... }
            --appearanceValues = {},               -- Will hold visual overrides (implement later)
            -- Add other instance-specific state if needed
            textures = {},   -- here we will keep the data about what texture will go where (simple textures and connected textures)
            positioners = {} -- here we will have some lerp values describing how things are positioned..
        }



        return lib.createCharacterFromExistingDNA(instance, x, y)
    end
end

return lib
