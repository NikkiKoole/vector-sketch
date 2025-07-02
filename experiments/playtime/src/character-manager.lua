local lib = {}

local ObjectManager = require 'src.object-manager' -- To create the physical parts
local Joints = require 'src.joints'
local uuid = require 'src.uuid'
local utils = require 'src.utils'
local mathutils = require 'src.math-utils'
local fixtures = require 'src.fixtures'

-- todo,
-- the curves for the limbs need a grow parameter, now its just some hardcoded value in lib.drawTexturedWorld(world)
-- the torso images, or maybe every tex-fixture also needs a growvalue that describes how much the w, h values will be grown.
-- next the chesthair has a grow too, the torso too and I also have a foot offset value that should be parametrized.
-- the shape98 values in the dict describe a shape, (made in meta file) but it doesntdescribe
-- how that is offsetted from the texture.

local function getBoundingBox(poly)
    assert(#poly % 2 == 0, "Polygon must have even number of coordinates")

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, #poly, 2 do
        local x, y = poly[i], poly[i + 1]
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    return {
        x = minX,
        y = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX,
        height = maxY - minY
    }
end
local function randomHexColor()
    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)
    local a = 255 -- fully opaque, or adjust if you want random alpha
    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

function createDefaultTextureDNABlock(shape, skipFG)
    return {
        bgURL = shape .. '.png',
        fgURL = skipFG and '' or shape .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = skipFG and '' or 'ff0000ff',
        pHex = 'ffff00ff',
    }
end

function initBlock(url)
    return {
        bgURL = (url or '') .. '.png',
        fgURL = (url or '') .. '-mask.png',
        pURL = '',
        bgHex = '020202ff',
        fgHex = randomHexColor(),
        pHex = randomHexColor(),
    }
end

function add(block, values)
    for k, v in pairs(values) do
        block[k] = v
    end
    return block
end

function lib.updateSkinOfPart(instance, partName, values, optionalPatchName)
    local p = instance.dna.parts[partName]
    if p then
        if p.appearance and p.appearance['skin'] then
            local patch = optionalPatchName or 'main'
            if p.appearance['skin'][patch] then
                for k, v in pairs(values) do
                    p.appearance['skin'][patch][k] = v
                end
            end
        end
    end
end

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
    ['feet2r.png'] = { v = { 46, -189, 96, -184, 131, 48, 109, 180, 45, 234, -15, 176, -70, 53, -87, -193 } },
    ['feet6r.png'] = { d = { 293, 612 }, v = { -28, -264, 46, -180, 110, 42, 117, 167, -7, 274, -109, 268, -110, 47, -102, -182 } },
    ['feet5xr.png'] = { v = { -4, -243, 25, -216, 46, 31, 66, 244, 3, 275, -69, 245, -71, 29, -41, -233 } },
    ['feet3xr.png'] = { v = { 8, -199, 56, -154, 46, 31, 61, 196, 5, 245, -54, 191, -71, 29, -38, -150 } },
    ['feet7r.png'] = { v = { -4, -243, 57, -227, 111, 6, 87, 218, 3, 256, -69, 213, -96, 10, -50, -223 } },
    ['feet8r.png'] = { v = { -11, -200, 37, -151, 87, 6, 110, 180, -7, 203, -100, 176, -96, 10, -74, -149 } },
    ['hand3r.png'] = { d = { 294, 489 }, v = { -57, -210, 21, -158, 26, -71, 37, 188, -57, 233, -117, 188, -138, -74, -130, -155 } },
    ['feet7xr.png'] = { v = { 4, -170, 71, -143, 77, -47, 45, 165, -11, 182, -71, 163, -67, -51, -42, -144 } },
}

local dna = {
    ['humanoid'] = {
        creation = {
            isPotatoHead = false,
            neckSegments = 5,
            torsoSegments = 1
        },


        -- in the pppearance belwo we have a few options for types:
        -- skin = a skin that assumes a shape8 url to be present.
        -- bodyhair, = an overlay that assumes the shape8 url to be present, it will follow that
        -- connected-skin = a texture that will be drawn over a few connectd bodyparts
        -- connected-hair = an overlay that assumes a few parts to be there too.

        parts = {
            ['torso-segment-template'] = {
                appearance = {
                    -- this will do the neck texturing (connecting torso and head)
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), {}),
                        endNode = 'head'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'head'
                    },
                    ['skin'] = {
                        main = initBlock(),
                        patch1 = add(initBlock('patch2'), { tx = 0.3, ty = 0.3 }),
                        patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    },
                    ['bodyhair'] = { main = add(initBlock('borsthaar4'), {}) }
                },
                dims = { w = 280, w2 = 5, h = 300, sx = 1, sy = 1 },
                shape8URL = 'shapeA1.png',
                shape = 'shape8',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },

            --['torso-segment-template'] = { dims = { w = 280, w2 = 5, h = 80 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } } },
            -- ['torso1'] = { dims = { w = 300, w2 = 4, h = 300 }, shape = 'trapezium' },
            ['neck-segment-template'] = {

                dims = { w = 80, w2 = 4, h = 150 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- ['head'] = { dims = { w = 100, w2 = 4, h = 180 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } } },
            ['head'] = {
                appearance = {
                    ['skin'] = {
                        main = initBlock(),
                        patch1 = add(initBlock('patch1'), { tx = 0.3, ty = 0.3 }),
                        patch2 = add(initBlock('patch1'), { tx = -0.3, ty = 0.3 })
                    },
                    ['bodyhair'] = { main = initBlock('borsthaar4') }
                },
                dims = { w = 100, w2 = 4, h = 180, sx = 1, sy = 1 },
                shape = 'shape8',
                shape8URL = 'shapeA2.png',
                j = { type = 'revolute', limits = { low = -math.pi / 4, up = math.pi / 4 } }
            },
            ['luleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } }
            },
            ['ruleg'] = {
                appearance = {
                    ['connected-skin'] = {
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rfoot'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'rfoot'
                    }
                },
                dims = { w = 80, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } }
            },
            ['llleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 2, up = 0 } } },
            ['rlleg'] = { dims = { w = 80, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = { low = 0, up = math.pi / 2 } } },
            ['luarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = -1 }),
                        endNode = 'lhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = -1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = 0, up = math.pi } }
            },
            ['ruarm'] = {
                appearance = {
                    ['connected-skin'] = {
                        zOffset = 1,
                        main = add(initBlock('leg5'), { dir = 1 }),
                        endNode = 'rhand'
                    },
                    ['connected-hair'] = {
                        main = add(createDefaultTextureDNABlock('hair10', true), { dir = 1 }),
                        endNode = 'lfoot'
                    }
                },
                dims = { w = 40, h = 200, w2 = 4 },
                shape = 'capsule',
                j = { type = 'revolute', limits = { low = -math.pi, up = 0 } }
            },
            ['llarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['rlarm'] = { dims = { w = 40, h = 200, w2 = 4 }, shape = 'capsule', j = { type = 'revolute', limits = {} } },
            ['lfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },

                },
                dims = { w = 80, h = 150, sx = 1, sy = 1 },
                shape = 'shape8',
                shape8URL = 'feet6r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rfoot'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = 1 }),
                    },
                },
                dims = { w = 80, h = 150, sx = -1, sy = 1 },
                shape = 'shape8',
                shape8URL = 'feet6r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODO THIS IS SO WEIRD, BUT WHEN I DONT USE A SHAPE8 for THE FOOT THE ANGLE IS FLIPPED?!
            --['lfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            --['rfoot'] = { dims = { w = 80, h = 250 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), { dir = -1 }),
                    },
                },
                dims = { w = 40, h = 40, sx = .5, sy = .9 },
                shape = 'shape8',
                shape8URL = 'hand3r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            ['rhand'] = {
                appearance = {
                    ['skin'] = {
                        main = add(initBlock(), {}),
                    },
                },
                dims = { w = 40, h = 40, sx = -.5, sy = .9 },
                shape = 'shape8',
                shape8URL = 'hand3r.png',
                j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } }
            },
            -- TODo same kind of weirdness for the hands!
            -- ['lhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            -- ['rhand'] = { dims = { w = 40, h = 400 }, shape = 'rectangle', j = { type = 'revolute', limits = { low = -math.pi / 8, up = math.pi / 8 } } },
            ['lear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = -math.pi / 2 },
            ['rear'] = { dims = { w = 10, h = 100 }, shape = 'capsule', j = { type = 'revolute', limits = { low = -math.pi / 16, up = math.pi / 16 } }, stanceAngle = math.pi / 2 }
        },

    }
}



function lib.updateShape8(instance, partName, newShape8Name)
    -- Update the physics part
    lib.updatePart(partName, { shape8URL = newShape8Name .. '.png' }, instance)

    -- Trigger a rebuild
    lib.rebuildFromCreation(instance, {})

    -- Update all visuals linked to that shape
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'bgURL', newShape8Name .. '.png')
    --lib.updateTextureGroupValue(instance, partName .. 'Skin', 'fgURL', newShape8Name .. '-mask.png')
    --lib.updateTextureGroupValueInRoot(instance, partName .. 'Hair', 'followShape8', newShape8Name .. '.png')

    -- Recreate the actual texture fixtures
    --   lib.addTextureFixturesFromInstance(instance)
end

-- copy pasted from playtime-ui.lua
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
    local result = {}

    for i = 1, #vertices, 2 do
        local x = vertices[i]
        local y = vertices[i + 1]
        local newX = x * scaleX
        local newY = y * scaleY
        table.insert(result, newX)
        table.insert(result, newY)
    end

    return result
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

    local torsoIndex = extractTorsoIndex(partName)

    if torsoIndex then
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
            print(parts[partName].shape8URL)
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
        if parts[partName].shape == 'shape8' then
            local raw = shape8Dict[parts[partName].shape8URL].v
            local vertices = makeTransformedVertices(raw, parts[partName].dims.sx or 1, parts[partName].dims.sy or 1)
            local topIndex = getTransformedIndex(1, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
            local bottomIndex = getTransformedIndex(5, sign(parts[partName].dims.sx), sign(parts[partName].dims.sy))
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
        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            logger:info(part.shape8URL)
            -- todo like the grow offsets this too should be parametrized
            local footOffset = 0
            local d = shape8Dict[part.shape8URL].d
            --logger:inspect(d)
            local bbox = getBoundingBox(raw)
            logger:inspect(bbox)
            local dx, dy = 0, 0
            local xoff, yoff = 0, 0
            if bbox and d then
                dx = d[1] - bbox.width
                dy = d[2] - bbox.height
                xoff = -(d[1] / 2) - bbox.x
                yoff = -(d[2] / 2) - bbox.y
            end
            --   -1*(293/2)
            --logger:inspect(d)

            --logger:info(xoff, yoff)
            --print(xoff, yoff)
            local sxSign = sign(part.dims.sx)
            --print(sign(part.dims.sx), sign(part.dims.sy))
            --return 100, 0
            --print(dx, dy)
            --
            -- return vertices[(index * 2) - 1], -vertices[(index * 2)]
            return vertices[(index * 2) - 1] - (yoff * part.dims.sx), -vertices[(index * 2)] + (xoff * part.dims.sy)
        else
            return 0, part.dims.h / 2
        end
    end
    if partName == 'rlleg' then
        return 0, parts.rlleg.dims.h / 2
    end

    if partName == 'luarm' then
        return 0, parts.luarm.dims.h / 2
    end
    if partName == 'ruarm' then
        return 0, parts.ruarm.dims.h / 2
    end
    if partName == 'rhand' or partName == 'lhand' then
        local part = parts[partName]
        if part.shape == 'shape8' then
            local raw = shape8Dict[part.shape8URL].v

            local vertices = makeTransformedVertices(raw, part.dims.sx or 1, part.dims.sy or 1)
            --logger:info(part.dims.sx, part.dims.sy)
            local index = getTransformedIndex(1, sign(part.dims.sx), sign(part.dims.sy)) -- or pick 5 or another

            local handOffset = 50
            return vertices[(index * 2) - 1] + handOffset * sign(part.dims.sx), -vertices[(index * 2)]
            -- return vertices[(index * 2) - 1], -vertices[(index * 2)]
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
                return getTorsoPart8FromSpecificTorso(1, index - 1)
            else
                return 0, -parts['torso' .. (index - 1)].dims.h / 2
            end
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

    local ownOffsetX, ownOffsetY = getOwnOffset(partName, instance)
    local xangle = getAngleOffset(partName, instance)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

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

        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]
        local partB_thing = instance.parts[partName]

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
            -- logger:info('joint:', parent, partName)
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
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local newAngle = instance.parts['torso1'].body:getAngle()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end

local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end


    for k, v in pairs(data) do
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end

    local oldBody = nil
    local oldPosX, oldPosY = 0, 0
    local oldAngle = 0

    -- Remove old body
    local extras = {}
    if instance.parts[partName] then
        oldBody = instance.parts[partName].body
        oldPosX, oldPosY = oldBody:getPosition()
        oldAngle = oldBody:getAngle()
        local body = instance.parts[partName].body
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
    if type(children) == 'string' then
        children = { children }
    end
    makePart(partName, instance, settings)

    -- after making a part set it to its angle so the children will be using that angle in their calculations.
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
    local positionTorso = nil
    local oldAngle = 0
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)
    updateSinglePart(partName, data, instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
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

function lib.addTexturesFromInstance2(instance)
    -- for k, v in pairs(instance.parts) do
    --     local part = v
    --     print(inspect(v))
    --     if part.appearance then
    --         print(k)
    --     end
    -- end
    for k, v in pairs(instance.dna.parts) do
        if v.appearance then
            --logger:info(k .. ' has appearance')
            local relevant = instance.parts[k]
            if (relevant) then
                --logger:info('relevant real thing found ' .. k)
                --logger:inspect(v.appearance)
                --
                --
                -- maybe i can jst remove all texture fixtures from the body right now?
                -- and then reattahc new ones below.

                local allFixtures = relevant.body:getFixtures()
                for fi = #allFixtures, 1, -1 do -- backwards to safely remove
                    local f = allFixtures[fi]
                    local ud = f:getUserData()
                    if ud then
                        if (ud.subtype == 'connected-texture' or ud.subtype == 'texfixture') then
                            fixtures.destroyFixture(f)
                        end
                    end
                end

                for k2, v2 in pairs(v.appearance) do
                    --print(k2)
                    if k2 == 'skin' then
                        local body = relevant.body


                        local cx, cy, w, h = getCenterAndDimensions(body)

                        local inDocumentOffset = nil
                        -- if v.shape8URL then
                        --     if shape8Dict[v.shape8URL] then
                        --         if shape8Dict[v.shape8URL].d then
                        --             inDocumentOffset = {}

                        --             inDocumentOffset.w = shape8Dict[v.shape8URL].d[1] * math.abs(v.dims.sx)
                        --             inDocumentOffset.h = shape8Dict[v.shape8URL].d[2] * math.abs(v.dims.sy)
                        --             inDocumentOffset.x = (inDocumentOffset.w - w) * (v.dims.sx < 0 and -1 or 1)
                        --             inDocumentOffset.y = (inDocumentOffset.h - h) --* (v.dims.sx < 0 and -1 or 1)
                        --         end
                        --     end
                        -- end
                        logger:inspect(inDocumentOffset)
                        --print(w, h)
                        local growfactor = 1.0
                        -- here we can offset the texture (needed for some shapes..)
                        local fixture
                        if (inDocumentOffset) then
                            fixture = fixtures.createSFixture(body, inDocumentOffset.x, inDocumentOffset.y,
                                'texfixture',
                                { width = inDocumentOffset.w, height = inDocumentOffset.h })
                        else
                            fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
                                { width = w * growfactor, height = h * growfactor })
                        end
                        local ud = fixture:getUserData()
                        ud.extra.OMP = true --it.OMP
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)
                        ud.extra.main.bgURL = v.shape8URL
                        ud.extra.main.fgURL = v.shape8URL:gsub('.png', '-mask.png')

                        if v.dims.sy ~= nil and v.dims.sy < 0 then
                            ud.extra.main.fy = -1
                        end
                        if v.dims.sx ~= nil and v.dims.sx < 0 then
                            ud.extra.main.fx = -1
                        end

                        if v2.patch1 then
                            ud.extra.patch1 = utils.deepCopy(v2.patch1)
                        end
                        if v2.patch2 then
                            ud.extra.patch2 = utils.deepCopy(v2.patch2)
                        end
                        if v2.patch3 then
                            ud.extra.patch3 = utils.deepCopy(v2.patch3)
                        end
                    elseif k2 == 'bodyhair' then
                        local body = relevant.body
                        local cx, cy, w, h = getCenterAndDimensions(body)
                        local growfactor = 1.1
                        local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
                            { width = w * growfactor, height = h * growfactor })
                        local ud = fixture:getUserData()
                        ud.extra.OMP = false --it.OMP
                        ud.extra.zOffset = 40
                        ud.extra.dirty = true
                        ud.extra.main = utils.deepCopy(v2.main)

                        local raw = shape8Dict[v.shape8URL].v
                        local growfactor = 1.5
                        local vertices = makeTransformedVertices(raw, (v.dims.sx or 1) * growfactor,
                            (v.dims.sy or 1) * growfactor)

                        ud.extra.vertices = vertices
                        ud.extra.vertexCount = #vertices / 2
                    elseif k2 == 'connected-skin' or k2 == 'connected-hair' then
                        local body = relevant.body
                        print(k)
                        --print(k, v2.endNode)
                        -- depending on the start and end node. build the jointlabels
                        local torsoSegments = instance.dna.creation.torsoSegments or 1
                        local jointLabels = {}

                        local fixture = fixtures.createSFixture(body, 0, 0, 'connected-texture',
                            { radius = 30 })

                        local ud = fixture:getUserData()

                        ud.extra = {
                            attachTo = k,
                            OMP = (k2 == 'connected-skin'),
                            dirty = true,
                            main = utils.deepCopy(v2.main),
                            zOffset = v2.zOffset or 0,
                            nodes = {}
                        }
                        if k:find('uleg') then
                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luleg' then
                                jointLabels = { "torso1->luleg", "luleg->llleg", "llleg->lfoot" }
                            elseif k == 'ruleg' then
                                jointLabels = { "torso1->ruleg", "ruleg->rlleg", "rlleg->rfoot" }
                            end
                        end
                        if k:find('uarm') then
                            local top = 'torso' .. torsoSegments

                            --print('this is an upper-leg, connect to torso1')
                            if k == 'luarm' then
                                jointLabels = { top .. "->luarm", "luarm->llarm", "llarm->lhand" }
                            elseif k == 'ruarm' then
                                jointLabels = { top .. "->ruarm", "ruarm->rlarm", "rlarm->rhand" }
                            end
                        end
                        -- we only do neck stuff from the top torso to the head. (other torso segments are ignored)
                        if k == ('torso' .. torsoSegments) and v2.endNode == 'head' then
                            local neckSegments = instance.dna.creation.neckSegments or 0
                            local previous = 'torso' .. torsoSegments

                            for i = 1, neckSegments do
                                local current = 'neck' .. i
                                table.insert(jointLabels, previous .. '->' .. current)
                                previous = current
                            end
                            -- Final connection to head
                            table.insert(jointLabels, previous .. '->head')
                            --logger:inspect(jointLabels)

                            print('this is about texturing the neck')
                        end
                        for j = 1, #jointLabels do
                            local jointID = jointLabels[j]
                            ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
                        end
                    end
                end
                -- here we do stuff.
                -- i think we should haev some kind of helper function that know depending on what the body tye is how we will add
                -- sfiuxture or connected fixture etc..
            end
        end
    end
end

-- function lib.addTextureFixturesFromInstance(instance)
--     function removeSimilarFixture(body, it)
--         local allFixtures = body:getFixtures()
--         for fi = #allFixtures, 1, -1 do -- backwards to safely remove
--             local f = allFixtures[fi]
--             local ud = f:getUserData()
--             --  logger:inspect(ud)
--             --if ud then
--             --    print(ud.label, it.label, ud and ud.label == it.label, ud.extra.OMP == it.OMP)
--             --end
--             if ud and ud.extra.OMP == it.OMP then
--                 --logger:info('destroying fixture')
--                 fixtures.destroyFixture(f)
--             end
--         end
--     end

--     for i = 1, #instance.textures do
--         local it = instance.textures[i]
--         --print(it.type, it.subtype)
--         if it.type == 'sfixture' then
--             if it.subtype == 'texfixture' then
--                 local body = instance.parts[it.attachTo].body
--                 removeSimilarFixture(body, it)
--                 --print("body angle at texture creation:", body:getAngle())
--                 local cx, cy, w, h = getCenterAndDimensions(body)
--                 -- local localX, localY = body:getLocalPoint(wx, wy)
--                 local growfactor = 1.1
--                 local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture',
--                     { width = w * growfactor, height = h * growfactor })
--                 local ud = fixture:getUserData()
--                 ud.extra.OMP = it.OMP
--                 ud.extra.dirty = true
--                 ud.extra.main = utils.deepCopy(it.main)

--                 ud.extra.zOffset = it.zOffset or 0
--                 ud.extra.attachTo = it.attachTo
--                 local partData = instance.dna.parts[it.attachTo]

--                 -- todo we probably also need to flip the other ones (patch1..3) but not sure..
--                 if partData.dims.sy ~= nil and partData.dims.sy < 0 then
--                     ud.extra.main.fy = -1
--                 end
--                 if partData.dims.sx ~= nil and partData.dims.sx < 0 then
--                     ud.extra.main.fx = -1
--                 end

--                 if it.patch1 then
--                     ud.extra.patch1 = utils.deepCopy(it.patch1)
--                 end
--                 if it.patch2 then
--                     ud.extra.patch2 = utils.deepCopy(it.patch2)
--                 end
--                 if it.patch3 then
--                     ud.extra.patch3 = utils.deepCopy(it.patch3)
--                 end
--                 if it.followShape8 then
--                     ud.extra.followShape8 = it.followShape8
--                     -- logger:inspect(ud.extra)
--                     --  logger:inspect(it.followShape8)
--                     --print(it.followShape8)
--                     local raw = shape8Dict[it.followShape8].v
--                     local partData = instance.dna.parts[it.attachTo]
--                     local growfactor = 1.5
--                     local vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * growfactor,
--                         (partData.dims.sy or 1) * growfactor)


--                     ud.extra.vertices = vertices
--                     ud.extra.vertexCount = #vertices / 2
--                     -- logger:info('found a follo8')
--                     --  logger:inspect(ud.extra)
--                 end
--                 -- followShape8 = 'shapeA3.png',


--                 --logger:info('texgisture to add:')
--             end

--             if it.subtype == 'connected-texture' then
--                 --print('got some stuff todo')
--                 -- print(it.attachTo)
--                 local body = instance.parts[it.attachTo].body

--                 -- REMOVE OLD CONNECTED-TEXTURE FIXTURES FIRST
--                 removeSimilarFixture(body, it)

--                 local fixture = fixtures.createSFixture(body, 0, 0, 'connected-texture',
--                     { radius = 30 })
--                 local ud = fixture:getUserData()
--                 ud.extra = {
--                     attachTo = it.attachTo,
--                     OMP = it.OMP,                   -- we will just alays use OUTLINE/ MASK / PATTERN TEXTURES for characters.
--                     dirty = true,                   -- because the rendered needs to pick this up.
--                     main = utils.deepCopy(it.main), -- this is still missing a lot but that will be defaulted
--                     zOffset = it.zOffset or 0,
--                     nodes = {

--                     }

--                 }
--                 for j = 1, #it.jointLabels do
--                     local jointID = it.jointLabels[j]
--                     -- print(jointID)
--                     ud.extra.nodes[j] = { id = instance.joints[jointID], type = 'joint' }
--                     --print(instance.joints[jointID])
--                 end
--             end
--         end
--     end
-- end

-- function lib.updateTextureGroupValue(instance, group, key, value)
--     for i = 1, #instance.textures do
--         local t = instance.textures[i]
--         if t.group == group and t.main then
--             t.main[key] = value
--             --logger:info('setting', key, value)
--         end
--     end
-- end

-- function lib.updateTextureGroupValueInRoot(instance, group, key, value)
--     for i = 1, #instance.textures do
--         local t = instance.textures[i]
--         if t.group == group then
--             t[key] = value
--             -- logger:info('setting', key, value)
--         end
--     end
-- end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.
    --
    local isPotato = instance.dna.creation.isPotatoHead
    local hasNeck = instance.dna.creation.neckSegments > 0
    local ordered = {}

    local torsoSegments = instance.dna.creation.torsoSegments or 1 -- Default to 1 torso segment
    -- 1. Add Torso Segments
    logger:info('createCharacterFromExistingDNA', torsoSegments)
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

            -- if we have multiple torso parts i want to remove the data that is about neck.
            -- only the topmost torso may have that data.

            -- if i ~= torsoSegments then
            --     instance.dna.parts[partName].appearance['connected-skin'] = nil
            --     print('removed unneeded nexk texture data from a torso segemnt')
            -- end

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
    --logger:info('calling defaultSetupTextures')


    lib.addTexturesFromInstance2(instance)
    --logger:info('calling addTextureFixturesFromInstance')
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
