-- Specs for src/spine-mesh.lua — spine-bind mesh deformation math.
-- bind/evaluate go through love.math.newBezierCurve, so LÖVE is required.

if not love then return end

local spine = require('src.spine-mesh')

-- Flat-array closeness helper: every coord within eps of expected.
local function assertCoordsNear(expected, actual, eps, label)
    eps = eps or 1e-3
    assert.equal(#expected, #actual, (label or '') .. ' length mismatch')
    for i = 1, #expected do
        local d = math.abs(expected[i] - actual[i])
        assert.is_true(d <= eps, string.format(
            '%s coord %d: expected %.4f got %.4f (diff %.5f > eps %.5f)',
            label or 'coords', i, expected[i], actual[i], d, eps))
    end
end

describe('spine-mesh', function()
    -- A straight horizontal chain and a rectangle straddling it.
    local chain = { 0, 0, 100, 0, 200, 0 }
    local polygon = {
        20, -30, -- above the chain (negative y = left of +x direction... sign checked below)
        180, -30,
        180, 30,
        20, 30,
    }

    describe('bind()', function()
        it('rejects a polygon with fewer than 3 points', function()
            local bind, err = spine.bind({ 0, 0, 1, 1 }, chain)
            assert.is_nil(bind)
            assert.is_string(err)
        end)

        it('rejects a chain with fewer than 2 points', function()
            local bind, err = spine.bind(polygon, { 0, 0 })
            assert.is_nil(bind)
            assert.is_string(err)
        end)

        it('rejects a zero-length chain', function()
            local bind, err = spine.bind(polygon, { 50, 50, 50, 50, 50, 50 })
            assert.is_nil(bind)
            assert.is_string(err)
        end)

        it('records one (t, s) pair per vertex and captures bendiness', function()
            local bind = spine.bind(polygon, chain, 3)
            assert.is_not_nil(bind)
            assert.equal(#polygon, #bind.tsPerVert) -- (t,s) per (x,y)
            assert.equal(3, bind.bendiness)
        end)
    end)

    describe('rest-pose round-trip', function()
        it('evaluate(bind, same chain) returns the original polygon', function()
            local bind = spine.bind(polygon, chain)
            local out = spine.evaluate(bind, chain)
            assertCoordsNear(polygon, out, 1e-3, 'round-trip')
        end)

        it('round-trips verts that overshoot the chain ends', function()
            -- x = -40 and x = 240 sit past the chain's endpoints; bind
            -- records t < 0 / t > 1 and evaluate extrapolates tangentially.
            local poly = { -40, -10, 240, -10, 240, 10, -40, 10 }
            local bind = spine.bind(poly, chain)
            local out = spine.evaluate(bind, chain)
            assertCoordsNear(poly, out, 1e-3, 'overshoot round-trip')
        end)

        it('round-trips against a bent chain too', function()
            local bent = { 0, 0, 100, 60, 200, 0 }
            local poly = { 40, 20, 160, 20, 100, 80 }
            local bind = spine.bind(poly, bent)
            local out = spine.evaluate(bind, bent)
            assertCoordsNear(poly, out, 1e-3, 'bent round-trip')
        end)

        it('uses the captured bendiness by default (no drift)', function()
            local bind = spine.bind(polygon, chain, 4)
            local out = spine.evaluate(bind, chain) -- no bendiness arg
            assertCoordsNear(polygon, out, 1e-3, 'default-bendiness round-trip')
        end)
    end)

    describe('evaluate()', function()
        it('translates all verts when the whole chain translates', function()
            local bind = spine.bind(polygon, chain)
            local moved = {}
            for i = 1, #chain, 2 do
                moved[i] = chain[i] + 50
                moved[i + 1] = chain[i + 1] + 25
            end
            local out = spine.evaluate(bind, moved)
            local expected = {}
            for i = 1, #polygon, 2 do
                expected[i] = polygon[i] + 50
                expected[i + 1] = polygon[i + 1] + 25
            end
            assertCoordsNear(expected, out, 1e-3, 'translation')
        end)

        it('returns nil for a nil/invalid bind or a too-short chain', function()
            assert.is_nil(spine.evaluate(nil, chain))
            assert.is_nil(spine.evaluate({}, chain))
            local bind = spine.bind(polygon, chain)
            assert.is_nil(spine.evaluate(bind, { 0, 0 }))
        end)
    end)

    describe('splitChainsByRootRepeat()', function()
        it('wraps a list with no repeats in a single chain', function()
            local nodes = { { id = 'a' }, { id = 'b' }, { id = 'c' } }
            local chains = spine.splitChainsByRootRepeat(nodes)
            assert.equal(1, #chains)
            assert.equal(3, #chains[1])
        end)

        it('splits at a repeated root id and shares the root node', function()
            local root = { id = 'root' }
            local nodes = { root, { id = 'l1' }, { id = 'l2' },
                { id = 'root' }, { id = 'r1' }, { id = 'r2' } }
            local chains = spine.splitChainsByRootRepeat(nodes)
            assert.equal(2, #chains)
            assert.same({ 'root', 'l1', 'l2' },
                { chains[1][1].id, chains[1][2].id, chains[1][3].id })
            assert.same({ 'root', 'r1', 'r2' },
                { chains[2][1].id, chains[2][2].id, chains[2][3].id })
        end)

        it('passes tiny lists through untouched', function()
            local nodes = { { id = 'only' } }
            local chains = spine.splitChainsByRootRepeat(nodes)
            assert.equal(1, #chains)
            assert.equal(nodes, chains[1])
        end)
    end)

    describe('multi-chain bind/evaluate', function()
        -- Two parallel horizontal chains, far apart.
        local chainA = { 0, 0, 100, 0, 200, 0 }
        local chainB = { 0, 300, 100, 300, 200, 300 }
        -- Two verts hugging chain A, two hugging chain B.
        local poly = { 50, 10, 150, 10, 50, 290, 150, 290 }

        it('assigns each vertex to the closest chain', function()
            local bind = spine.bindMultiChain(poly, { chainA, chainB })
            assert.is_not_nil(bind)
            assert.is_true(bind.multi)
            assert.equal(1, bind.perVert[1].chain)
            assert.equal(1, bind.perVert[2].chain)
            assert.equal(2, bind.perVert[3].chain)
            assert.equal(2, bind.perVert[4].chain)
        end)

        it('round-trips at rest and moves only the assigned chain\'s verts', function()
            local bind = spine.bindMultiChain(poly, { chainA, chainB })
            local rest = spine.evaluateMultiChain(bind, { chainA, chainB })
            assertCoordsNear(poly, rest, 1e-3, 'multi rest')

            -- Move chain B down by 40: verts 3 and 4 follow, 1 and 2 stay.
            local movedB = { 0, 340, 100, 340, 200, 340 }
            local out = spine.evaluateMultiChain(bind, { chainA, movedB })
            assertCoordsNear({ poly[1], poly[2], poly[3], poly[4] },
                { out[1], out[2], out[3], out[4] }, 1e-3, 'chain A verts')
            assertCoordsNear({ poly[5], poly[6] + 40, poly[7], poly[8] + 40 },
                { out[5], out[6], out[7], out[8] }, 1e-3, 'chain B verts')
        end)

        it('falls back to (0, 0) for verts whose chain went missing', function()
            local bind = spine.bindMultiChain(poly, { chainA, chainB })
            local out = spine.evaluateMultiChain(bind, { chainA }) -- chain 2 gone
            -- verts 1-2 still round-trip, verts 3-4 collapse to origin
            assertCoordsNear({ poly[1], poly[2], poly[3], poly[4] },
                { out[1], out[2], out[3], out[4] }, 1e-3, 'surviving chain')
            assert.equal(0, out[5])
            assert.equal(0, out[6])
            assert.equal(0, out[7])
            assert.equal(0, out[8])
        end)

        it('rejects when no chain is valid', function()
            local bind, err = spine.bindMultiChain(poly, { { 0, 0 } })
            assert.is_nil(bind)
            assert.is_string(err)
        end)
    end)
end)
