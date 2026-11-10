-- Engine systems: things that run every frame in every scene, without a scene script calling them
-- (docs/LANDING-2026-11.md L1). main.lua calls the four hooks; each system says which it needs:
--   update(m, dt)  after the physics step and the scene script's update, only while the world runs
--   drawBelow(m)   after the scene script's drawBelow (its ground), before the bodies
--   draw(m)        after the textured world, before the scene script's draw (so a script can draw over)
--   unload(m)      when a scene's data loads, before the old bodies are destroyed
-- `m` is the system's module, looked up in package.loaded on every call, so a lurker hot swap of
-- that module is used straight away. Its state lives on the instances or on `state`, not here.
-- A new system: one entry below, and its scene scripts stop calling it themselves (else it runs twice).

local lib = {}

lib.list = {
    {
        name = 'hair', -- hair locks on Mipos and on bodies (src/hair-locks.lua, docs/HAIR-LOCKS.md)
        module = 'src.hair-locks',
        update = function(m, dt) m.update(dt) end,
        drawBelow = function(m) m.draw('back') end, -- behind the Mipos
        draw = function(m) m.draw('front') end,     -- bangs, front locks and coats, over the faces
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
function lib.unload() run('unload') end

return lib
