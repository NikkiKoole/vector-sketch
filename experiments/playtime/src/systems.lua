-- Engine systems: things that run every frame in every scene, without a scene script calling them
-- (docs/LANDING-2026-11.md L1). main.lua and the textured world call these hooks; each system says which it needs:
--   update(m, dt)  after the physics step and the scene script's update, only while the world runs
--   drawBelow(m)   after the scene script's drawBelow (its ground), before the bodies
--   splits(m, add) in among the textured world's pictures: add(z, fn, arg, mipoId) draws fn(arg) just
--                  before the first picture at z or higher; a Mipo's places are src/mipo-layers.lua.
--                  Skipped with its Mipo when that's off screen (mipoId), and in the shadow passes
--   draw(m)        after the textured world, before the scene script's draw (so a script can draw over)
--   unload(m)      when a scene's data loads, before the old bodies are destroyed
-- `m` is the system's module, looked up in package.loaded on every call, so a lurker hot swap of
-- that module is used straight away. Its state lives on the instances or on `state`, not here.
-- A new system: one entry below, and its scene scripts stop calling it themselves (else it runs twice).

local lib = {}

lib.list = {
    {
        name = 'sky', -- the scene's clock: the hour goes round while the day runs (src/scene-sky.lua, SKY.md)
        module = 'src.scene-sky',
        update = function(m, dt) m.update(dt) end,
    },
    {
        name = 'walk', -- Mipos turn, and walk when dragged along the floor (src/mipo-walk.lua, MIPO-FACING MF6)
        module = 'src.mipo-walk',
        update = function(m, dt) m.update(dt) end,
    },
    {
        name = 'stance', -- soft ankles and firm knees: Mipos stand on their soles (src/mipo-stance.lua)
        module = 'src.mipo-stance',
        update = function(m) m.update() end,
    },
    {
        name = 'hair', -- hair locks on Mipos and on bodies (src/hair-locks.lua, docs/HAIR-LOCKS.md)
        module = 'src.hair-locks',
        update = function(m, dt) m.update(dt) end,
        splits = function(m, add) m.splits(add) end, -- behind its Mipo, and the bangs over its face
        unload = function(m) m.detachBodies() end,  -- a Mipo's own hair goes with its body
    },
}

local function run(hook, ...)
    for _, system in ipairs(lib.list) do
        local fn = system[hook]
        if fn then fn(package.loaded[system.module] or require(system.module), ...) end
    end
end

function lib.update(dt) run('update', dt) end
function lib.drawBelow() run('drawBelow') end
function lib.draw() run('draw') end
function lib.splits(add) run('splits', add) end
function lib.unload() run('unload') end

return lib
