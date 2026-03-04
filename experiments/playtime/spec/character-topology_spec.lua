-- spec/character-topology_spec.lua
-- Unit tests for the character topology module.
-- Run with: busted spec/character-topology_spec.lua

local topology = require('src.character-topology')

-- ─── Helpers ───

local function names(topo)
    local result = {}
    for _, entry in ipairs(topo) do
        result[#result + 1] = entry.name
    end
    return result
end

local function findEntry(topo, name)
    for _, entry in ipairs(topo) do
        if entry.name == name then return entry end
    end
    return nil
end

local function indexOf(topo, name)
    for i, entry in ipairs(topo) do
        if entry.name == name then return i end
    end
    return nil
end

-- ─── Tests ───

describe("character-topology", function()

    describe("resolve", function()

        -- ─── Default creation (1 torso, 0 neck, 0 nose, not potato) ───

        describe("default creation", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces correct part count", function()
                -- 1 torso + 0 neck + 1 head + 0 nose + 14 limbs = 16
                assert.are.equal(16, #topo)
            end)

            it("includes torso1", function()
                assert.is_not_nil(findEntry(topo, 'torso1'))
            end)

            it("includes head", function()
                assert.is_not_nil(findEntry(topo, 'head'))
            end)

            it("torso1 has no parent", function()
                assert.is_nil(findEntry(topo, 'torso1').parent)
            end)

            it("head parent is torso1 (no neck)", function()
                assert.are.equal('torso1', findEntry(topo, 'head').parent)
            end)

            it("arms attach to highest torso", function()
                assert.are.equal('torso1', findEntry(topo, 'luarm').parent)
                assert.are.equal('torso1', findEntry(topo, 'ruarm').parent)
            end)

            it("legs attach to torso1", function()
                assert.are.equal('torso1', findEntry(topo, 'luleg').parent)
                assert.are.equal('torso1', findEntry(topo, 'ruleg').parent)
            end)

            it("ears attach to head", function()
                assert.are.equal('head', findEntry(topo, 'lear').parent)
                assert.are.equal('head', findEntry(topo, 'rear').parent)
            end)

            it("limb chains are correct", function()
                assert.are.equal('luarm', findEntry(topo, 'llarm').parent)
                assert.are.equal('llarm', findEntry(topo, 'lhand').parent)
                assert.are.equal('ruarm', findEntry(topo, 'rlarm').parent)
                assert.are.equal('rlarm', findEntry(topo, 'rhand').parent)
                assert.are.equal('luleg', findEntry(topo, 'llleg').parent)
                assert.are.equal('llleg', findEntry(topo, 'lfoot').parent)
                assert.are.equal('ruleg', findEntry(topo, 'rlleg').parent)
                assert.are.equal('rlleg', findEntry(topo, 'rfoot').parent)
            end)

            it("parent always before child in ordering", function()
                for _, entry in ipairs(topo) do
                    if entry.parent then
                        local parentIdx = indexOf(topo, entry.parent)
                        local childIdx = indexOf(topo, entry.name)
                        assert.is_truthy(parentIdx,
                            "parent '" .. entry.parent .. "' of '" .. entry.name .. "' not found in topology")
                        assert.is_true(parentIdx < childIdx,
                            "parent '" .. entry.parent .. "' (idx " .. parentIdx ..
                            ") should come before child '" .. entry.name .. "' (idx " .. childIdx .. ")")
                    end
                end
            end)
        end)

        -- ─── Multi-torso ───

        describe("multi-torso (3 segments)", function()
            local creation = { torsoSegments = 3, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces correct part count", function()
                -- 3 torso + 0 neck + 1 head + 0 nose + 14 limbs = 18
                assert.are.equal(18, #topo)
            end)

            it("torso chain is correct", function()
                assert.is_nil(findEntry(topo, 'torso1').parent)
                assert.are.equal('torso1', findEntry(topo, 'torso2').parent)
                assert.are.equal('torso2', findEntry(topo, 'torso3').parent)
            end)

            it("head attaches to highest torso", function()
                assert.are.equal('torso3', findEntry(topo, 'head').parent)
            end)

            it("arms attach to highest torso", function()
                assert.are.equal('torso3', findEntry(topo, 'luarm').parent)
                assert.are.equal('torso3', findEntry(topo, 'ruarm').parent)
            end)

            it("legs attach to torso1", function()
                assert.are.equal('torso1', findEntry(topo, 'luleg').parent)
            end)
        end)

        -- ─── With neck ───

        describe("with neck (2 segments)", function()
            local creation = { torsoSegments = 1, neckSegments = 2, noseSegments = 0, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces correct part count", function()
                -- 1 torso + 2 neck + 1 head + 14 limbs = 18
                assert.are.equal(18, #topo)
            end)

            it("neck1 attaches to highest torso", function()
                assert.are.equal('torso1', findEntry(topo, 'neck1').parent)
            end)

            it("neck2 attaches to neck1", function()
                assert.are.equal('neck1', findEntry(topo, 'neck2').parent)
            end)

            it("head attaches to last neck", function()
                assert.are.equal('neck2', findEntry(topo, 'head').parent)
            end)

            it("neck1 uses chainTop strategy", function()
                assert.are.equal('chainTop', findEntry(topo, 'neck1').parentAttach.strategy)
            end)

            it("neck2 uses parentTop strategy", function()
                assert.are.equal('parentTop', findEntry(topo, 'neck2').parentAttach.strategy)
            end)

            it("head uses parentTop strategy (has neck)", function()
                assert.are.equal('parentTop', findEntry(topo, 'head').parentAttach.strategy)
            end)
        end)

        -- ─── With nose ───

        describe("with nose (2 segments)", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 2, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces correct part count", function()
                -- 1 torso + 1 head + 2 nose + 14 limbs = 18
                assert.are.equal(18, #topo)
            end)

            it("nose1 attaches to head", function()
                assert.are.equal('head', findEntry(topo, 'nose1').parent)
            end)

            it("nose2 attaches to nose1", function()
                assert.are.equal('nose1', findEntry(topo, 'nose2').parent)
            end)

            it("nose1 uses midlineLerp", function()
                assert.are.equal('midlineLerp', findEntry(topo, 'nose1').parentAttach.strategy)
            end)

            it("nose2 uses parentBottom", function()
                assert.are.equal('parentBottom', findEntry(topo, 'nose2').parentAttach.strategy)
            end)
        end)

        -- ─── Potato head ───

        describe("potato head", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = true }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("does not include head", function()
                assert.is_nil(findEntry(topo, 'head'))
            end)

            it("produces correct part count", function()
                -- 1 torso + 14 limbs = 15 (no head, no neck, no nose)
                assert.are.equal(15, #topo)
            end)

            it("ears attach to highest torso", function()
                assert.are.equal('torso1', findEntry(topo, 'lear').parent)
                assert.are.equal('torso1', findEntry(topo, 'rear').parent)
            end)

            it("arms use potato vertex indices", function()
                assert.are.equal(7, findEntry(topo, 'luarm').parentAttach.vertex)
                assert.are.equal(3, findEntry(topo, 'ruarm').parentAttach.vertex)
            end)
        end)

        -- ─── Potato + nose ───

        describe("potato head with nose", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 1, noseMode = 'physics', isPotatoHead = true }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("nose1 attaches to highest torso (not head)", function()
                assert.are.equal('torso1', findEntry(topo, 'nose1').parent)
            end)

            it("produces correct part count", function()
                -- 1 torso + 1 nose + 14 limbs = 16 (no head)
                assert.are.equal(16, #topo)
            end)
        end)

        -- ─── Potato + multi-torso + nose ───

        describe("potato + multi-torso + nose", function()
            local creation = { torsoSegments = 2, neckSegments = 0, noseSegments = 2, isPotatoHead = true }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("ears attach to torso2 (highest)", function()
                assert.are.equal('torso2', findEntry(topo, 'lear').parent)
                assert.are.equal('torso2', findEntry(topo, 'rear').parent)
            end)

            it("nose1 attaches to torso2 (highest)", function()
                assert.are.equal('torso2', findEntry(topo, 'nose1').parent)
            end)

            it("arms attach to torso2 (highest)", function()
                assert.are.equal('torso2', findEntry(topo, 'luarm').parent)
                assert.are.equal('torso2', findEntry(topo, 'ruarm').parent)
            end)
        end)

        -- ─── Non-potato arms use standard vertex indices ───

        describe("non-potato arm vertices", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("luarm uses vertex 8", function()
                assert.are.equal(8, findEntry(topo, 'luarm').parentAttach.vertex)
            end)

            it("ruarm uses vertex 2", function()
                assert.are.equal(2, findEntry(topo, 'ruarm').parentAttach.vertex)
            end)
        end)

        -- ─── Angle offsets ───

        describe("angle offsets", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("lfoot has pi/2", function()
                assert.are.equal(math.pi / 2, findEntry(topo, 'lfoot').angleOffset)
            end)

            it("rfoot has -pi/2", function()
                assert.are.equal(-math.pi / 2, findEntry(topo, 'rfoot').angleOffset)
            end)

            it("ears use stanceAngle", function()
                assert.are.equal('stanceAngle', findEntry(topo, 'lear').angleOffset)
                assert.are.equal('stanceAngle', findEntry(topo, 'rear').angleOffset)
            end)

            it("torso has 0", function()
                assert.are.equal(0, findEntry(topo, 'torso1').angleOffset)
            end)
        end)

        -- ─── Neck ignored in potato mode ───

        describe("potato ignores neck setting", function()
            local creation = { torsoSegments = 1, neckSegments = 3, noseSegments = 0, isPotatoHead = true }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("no neck parts despite neckSegments > 0", function()
                assert.is_nil(findEntry(topo, 'neck1'))
                assert.is_nil(findEntry(topo, 'neck2'))
                assert.is_nil(findEntry(topo, 'neck3'))
            end)

            it("no head in potato mode", function()
                assert.is_nil(findEntry(topo, 'head'))
            end)
        end)

        -- ─── Ordering matches original ───

        describe("ordering", function()
            local creation = { torsoSegments = 2, neckSegments = 1, noseSegments = 1, noseMode = 'physics', isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("torsos come first", function()
                assert.are.equal(1, indexOf(topo, 'torso1'))
                assert.are.equal(2, indexOf(topo, 'torso2'))
            end)

            it("neck follows torsos", function()
                assert.are.equal(3, indexOf(topo, 'neck1'))
            end)

            it("head follows neck", function()
                assert.are.equal(4, indexOf(topo, 'head'))
            end)

            it("nose follows head", function()
                assert.are.equal(5, indexOf(topo, 'nose1'))
            end)

            it("limbs come after nose", function()
                assert.is_true(indexOf(topo, 'luleg') > indexOf(topo, 'nose1'))
            end)
        end)
    end)

    -- ─── noseMode variants ───

    describe("noseMode variants", function()

        describe("noseMode='overlay' with noseSegments=1", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 1, noseMode = 'overlay', isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces no nose entries", function()
                assert.is_nil(findEntry(topo, 'nose1'))
            end)

            it("has same part count as noseSegments=0", function()
                local topo0 = topology.resolve({ torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false })
                assert.are.equal(#topo0, #topo)
            end)
        end)

        describe("noseMode='physics' with noseSegments=1", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 1, noseMode = 'physics', isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces one nose entry", function()
                assert.is_not_nil(findEntry(topo, 'nose1'))
                assert.is_nil(findEntry(topo, 'nose2'))
            end)

            it("nose1 has shape8=1 in ownAttach", function()
                assert.are.equal(1, findEntry(topo, 'nose1').ownAttach.shape8)
            end)

            it("nose1 attaches to head", function()
                assert.are.equal('head', findEntry(topo, 'nose1').parent)
            end)
        end)

        describe("noseSegments=2 (segmented, no shape8)", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 2, isPotatoHead = false }
            local topo

            before_each(function()
                topo = topology.resolve(creation)
            end)

            it("produces two nose entries without shape8", function()
                local n1 = findEntry(topo, 'nose1')
                local n2 = findEntry(topo, 'nose2')
                assert.is_not_nil(n1)
                assert.is_not_nil(n2)
                assert.is_nil(n1.ownAttach.shape8)
                assert.is_nil(n2.ownAttach.shape8)
            end)

            it("nose2 uses parentBottom strategy", function()
                assert.are.equal('parentBottom', findEntry(topo, 'nose2').parentAttach.strategy)
            end)
        end)

        describe("noseMode defaults to overlay when omitted", function()
            it("noseSegments=1 without noseMode produces no nose entries", function()
                local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 1, isPotatoHead = false }
                local topo = topology.resolve(creation)
                assert.is_nil(findEntry(topo, 'nose1'))
            end)
        end)
    end)

    -- ─── buildChildrenMap ───

    describe("buildChildrenMap", function()
        it("maps parents to their children", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo = topology.resolve(creation)
            local children = topology.buildChildrenMap(topo)

            -- torso1 should have many children
            assert.is_truthy(children['torso1'])
            -- head should have ears
            local headChildren = children['head']
            assert.is_truthy(headChildren)
            local hasLear, hasRear = false, false
            for _, name in ipairs(headChildren) do
                if name == 'lear' then hasLear = true end
                if name == 'rear' then hasRear = true end
            end
            assert.is_true(hasLear)
            assert.is_true(hasRear)
        end)

        it("leaf parts have no children", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo = topology.resolve(creation)
            local children = topology.buildChildrenMap(topo)
            assert.is_nil(children['lfoot'])
            assert.is_nil(children['rfoot'])
            assert.is_nil(children['lhand'])
            assert.is_nil(children['rhand'])
            assert.is_nil(children['lear'])
            assert.is_nil(children['rear'])
        end)
    end)

    -- ─── buildEntryMap ───

    describe("buildEntryMap", function()
        it("maps names to entries", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo = topology.resolve(creation)
            local map = topology.buildEntryMap(topo)

            assert.is_truthy(map['torso1'])
            assert.are.equal('torso1', map['torso1'].name)
            assert.is_truthy(map['head'])
            assert.are.equal('head', map['head'].name)
        end)
    end)

    -- ─── buildOrderedNames ───

    describe("buildOrderedNames", function()
        it("returns names in topology order", function()
            local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 0, isPotatoHead = false }
            local topo = topology.resolve(creation)
            local ordered = topology.buildOrderedNames(topo)

            assert.are.equal(#topo, #ordered)
            assert.are.equal('torso1', ordered[1])
        end)
    end)

    -- ─── ownAttach strategies ───

    describe("ownAttach entries", function()
        local creation = { torsoSegments = 1, neckSegments = 0, noseSegments = 1, noseMode = 'physics', isPotatoHead = false }
        local topo, map

        before_each(function()
            topo = topology.resolve(creation)
            map = topology.buildEntryMap(topo)
        end)

        it("torso uses topEdge shape8", function()
            assert.are.equal('top', map['torso1'].ownAttach.strategy)
            assert.are.equal('topEdge', map['torso1'].ownAttach.shape8)
        end)

        it("head uses topEdge shape8", function()
            assert.are.equal('top', map['head'].ownAttach.strategy)
            assert.are.equal('topEdge', map['head'].ownAttach.shape8)
        end)

        it("ears use shape8 vertex 5", function()
            assert.are.equal('top', map['lear'].ownAttach.strategy)
            assert.are.equal(5, map['lear'].ownAttach.shape8)
        end)

        it("feet use shape8 vertex 1", function()
            assert.are.equal('bottom', map['lfoot'].ownAttach.strategy)
            assert.are.equal(1, map['lfoot'].ownAttach.shape8)
        end)

        it("hands use shape8 vertex 1", function()
            assert.are.equal('bottom', map['lhand'].ownAttach.strategy)
            assert.are.equal(1, map['lhand'].ownAttach.shape8)
        end)

        it("single physics nose uses bottom with shape8 vertex 1", function()
            assert.are.equal('bottom', map['nose1'].ownAttach.strategy)
            assert.are.equal(1, map['nose1'].ownAttach.shape8)
        end)

        it("upper legs use bottom (no shape8)", function()
            assert.are.equal('bottom', map['luleg'].ownAttach.strategy)
            assert.is_nil(map['luleg'].ownAttach.shape8)
        end)
    end)
end)
