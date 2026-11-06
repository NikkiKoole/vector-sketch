-- materials.lua — a material instead of clay on a drawn part (docs/MATERIALS.md, MT6): the part's own
-- colours and pattern stay, the material is how they take the light. Set by name on a texfixture's,
-- ribbon's or skin's extra: `extra.material = 'brass'`; the plasticine shader draws it
-- (src/render/shaders.lua, setSurfaceShader). From the material-check scene's palette, the ones that
-- need no grain (grains cost on the phone: MATERIALS MT18).
--   kind: 1 metal, 2 velvet, 5 a surface
--   spec = { shine strength, size (higher: smaller), tint by its colour, clear coat }
--   surf = { light wrap, sheen at the edges, edges darkened, rough (metal) }
--   tint = { r, g, b, how much }: a metal's own colour over the part's
local lib = {}

lib.PRESETS = {
    metal = { kind = 1, spec = { 1.5, 70 } },
    brass = { kind = 1, spec = { 1.5, 70 }, tint = { 0.95, 0.72, 0.3, 1 } },
    gold = { kind = 1, spec = { 1.8, 90 }, tint = { 1.0, 0.8, 0.28, 1 } },
    copper = { kind = 1, spec = { 1.5, 70 }, surf = { 0, 0, 0, 0.2 }, tint = { 0.93, 0.5, 0.32, 1 } },
    tin = { kind = 1, spec = { 1.2, 50 }, tint = { 0.78, 0.8, 0.85, 1 } },
    velvet = { kind = 2 },
    satin = { kind = 5, spec = { 0.5, 10 }, surf = { 0.3, 0.6 } },
    felt = { kind = 5, surf = { 0.5, 0.25 } },
    leather = { kind = 5, spec = { 0.35, 16, 0.2 }, surf = { 0.15, 0, 0.45 } },
    rubber = { kind = 5, spec = { 0.18, 4 }, surf = { 0.2, 0.25 } },
    wax = { kind = 5, spec = { 0.2, 12 }, surf = { 0.7 } },
    plastic = { kind = 5, spec = { 1.0, 70 }, surf = { 0.15 } },
    glaze = { kind = 5, spec = { 0.3, 20, 0.5, 1.0 }, surf = { 0.1, 0, 0.45 } },
    candy = { kind = 5, spec = { 0.2, 30, 0, 1.0 }, surf = { 0.4 } },
}

-- in the order a panel steps through them; nil (clay) first
lib.NAMES = { 'metal', 'brass', 'gold', 'copper', 'tin', 'velvet', 'satin', 'felt', 'leather', 'rubber', 'wax',
    'plastic', 'glaze', 'candy' }

local ZERO = { 0, 0, 0, 0 }
local function four(t)
    t = t or ZERO
    return { t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 0 }
end

-- per preset, the shader's numbers, made once
local sent = {}
function lib.uniforms(name)
    local preset = name and lib.PRESETS[name]
    if not preset then return nil end
    if not sent[name] then
        sent[name] = { kind = preset.kind, spec = four(preset.spec), surf = four(preset.surf),
            tint = four(preset.tint) }
    end
    return sent[name]
end

return lib
