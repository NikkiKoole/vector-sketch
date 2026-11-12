-- cloud-air: the air a cloud grows in, and the thermals it's made of (CLOUDS.md CG1, CG2).
-- Pure Lua (no LÖVE), so the physics has its own spec (spec/cloud-air_spec.lua).
--
-- The air: a profile of temperature and humidity with height (the ground's, how fast it cools
-- going up, a warm lid that stops clouds). A thermal: a bubble of air with its own temperature,
-- vapour and cloud water. Lifted, it cools ~9.8 °C a km; when its vapour is more than the air can
-- hold at that cold it condenses into cloud water and the heat that gives off warms it (so a
-- cloud cools only ~5-6 °C a km). Warmer (lighter) than the air around it, it rises; its cloud
-- water weighs it down; it mixes with the air it passes through (entrainment), smaller ones
-- faster. After Harris 2003 (the thermodynamics) and Goswami & Neyret 2017 (thermals as parcels).
--
-- Units: heights z in metres (the scene: 1 unit = 1 m, y up negative), temperatures in °C,
-- humidity as mixing ratios in g/kg, time in seconds of the sky's own time (the scene speeds it up).

local lib = {}

local G = 9.81
local LV_CP = 2.49     -- K per g/kg condensed: latent heat 2.5e6 J/kg over cp 1004 J/kg/K, / 1000
local DRY = 0.0098     -- K per m: dry adiabatic cooling
local SCALE_H = 8000   -- m: pressure scale height

lib.DEFAULTS = {
    groundT = 22,      -- °C
    groundRH = 70,     -- % at the ground
    aloftRH = 45,      -- % above 2 km (in between it goes over)
    lapse = 7.5,       -- K per km: how fast the air cools with height
    lidZ = 3500,       -- m: the bottom of the warm lid
    lidK = 4,          -- K: how much warmer the air gets through the lid (300 m thick)
}
local LID_DEPTH = 300

-- pressure in hPa at height z
function lib.pressure(z)
    return 1000 * math.exp(-z / SCALE_H)
end

-- the most vapour air can hold (g/kg) at temperature t (°C) and pressure p (hPa) (Bolton's es)
function lib.qs(t, p)
    local es = 6.112 * math.exp(17.67 * t / (t + 243.5))
    return 622 * es / math.max(p - es, 1)
end

-- the air's temperature at height z
function lib.envT(air, z)
    local t = air.groundT - air.lapse * z / 1000
    if z > air.lidZ then
        -- through the lid it warms by lidK, above it cools on at the same rate
        local into = math.min(z - air.lidZ, LID_DEPTH)
        t = t + air.lapse * into / 1000 + air.lidK * into / LID_DEPTH
    end
    return t
end

-- relative humidity (0..1) of the air at height z: the ground's, going over to the aloft one by 2 km
function lib.envRH(air, z)
    local u = math.max(0, math.min(1, z / 2000))
    local rh = air.groundRH + (air.aloftRH - air.groundRH) * u
    if z > air.lidZ then rh = rh * 0.6 end -- above the lid it's dry
    return rh / 100
end

function lib.envQv(air, z)
    return lib.envRH(air, z) * lib.qs(lib.envT(air, z), lib.pressure(z))
end

-- virtual temperature (K): vapour makes air lighter, cloud water heavier
local function virtualK(t, qv, qc)
    return (t + 273.15) * (1 + 0.00061 * qv - 0.001 * (qc or 0))
end

-- condense or evaporate until the parcel is just saturated (or has no cloud water left);
-- a few Newton steps of the saturation adjustment
local function adjust(p, z)
    local pr = lib.pressure(z)
    for _ = 1, 3 do
        local qs = lib.qs(p.t, pr)
        local excess = p.qv - qs
        if excess <= 0 and p.qc <= 0 then break end
        -- d qs / d T, so the heat released is taken into account in one go
        local dqs = qs * 17.67 * 243.5 / (p.t + 243.5) ^ 2
        local dq = excess / (1 + LV_CP * dqs)
        if dq < -p.qc then dq = -p.qc end
        p.qv, p.qc, p.t = p.qv - dq, p.qc + dq, p.t + LV_CP * dq
        if math.abs(dq) < 1e-4 then break end
    end
end

-- a new thermal at (x, z), rh its relative humidity (1 = just saturated), warm how much warmer than
-- the air there, r its radius in m
function lib.newThermal(air, x, z, rh, warm, r)
    local t = lib.envT(air, z) + (warm or 0)
    local p = { x = x, z = z, w = 0, u = 0, t = t, qv = rh * lib.qs(t, lib.pressure(z)), qc = 0,
        r = r or 350, age = 0 }
    adjust(p, z)
    return p
end

-- a painted cloud: saturated, qc g/kg of cloud water, as heavy as the air around it, and it
-- floats: it stays where it's put and fades only very slowly (FLOAT_MIX), until it's let go
-- (p.floats = nil) and the air takes over (the friendly kind, Nikki 2026-11-12)
lib.FLOAT_MIX = 0.1
function lib.newCloud(air, x, z, qc, r)
    local p = lib.newThermal(air, x, z, 1, 0, r)
    p.qc = qc
    p.floats = true
    for _ = 1, 4 do
        p.t = p.t - lib.buoyancyK(air, p)
        p.qv = lib.qs(p.t, lib.pressure(z))
    end
    return p
end

-- how much warmer (K, virtual) than the air around it: > 0 it's pushed up
function lib.buoyancyK(air, p)
    local te = lib.envT(air, p.z)
    return virtualK(p.t, p.qv, p.qc) - virtualK(te, lib.envQv(air, p.z), 0)
end

-- move a thermal by dz (lifted or dropped): it cools or warms as it goes, condenses or evaporates
function lib.moveTo(p, z)
    p.t = p.t - DRY * (z - p.z)
    p.z = z
    adjust(p, z)
end

-- One step of dt sky seconds. held: a hand has it (it moves where it's put; only the air acts).
-- ENTRAIN: how much it mixes per metre risen, at r = 1 m (so a 350 m one mixes 1/10 of itself
-- every ~400 m); MIX: a little always, rising or not (a cloud left alone slowly evaporates).
lib.ENTRAIN = 0.25
lib.MIX = 0.0003
lib.DRAG = 0.004 -- per second: the air it pushes through
function lib.step(air, p, dt, held)
    p.age = p.age + dt
    if not held and not p.floats then
        local te = lib.envT(air, p.z)
        local tv = virtualK(te, lib.envQv(air, p.z), 0)
        local accel = G * (virtualK(p.t, p.qv, p.qc) - tv) / tv
        p.w = p.w + accel * dt
        -- drag: the air it pushes through, and the still air it takes in as it rises
        p.w = p.w / (1 + dt * (lib.DRAG + lib.ENTRAIN / p.r * math.abs(p.w)))
        local z = p.z + p.w * dt
        if z < 0 then z, p.w = 0, math.max(0, p.w) end
        lib.moveTo(p, z)
        p.x = p.x + p.u * dt
        if p.soot then
            -- a puff thrown sideways (a blast) is slowed by the air like one going up
            p.u = p.u / (1 + dt * (lib.DRAG + lib.ENTRAIN / p.r * math.abs(p.u)))
        else
            p.u = p.u * math.max(0, 1 - dt * 0.02)
        end
    end
    -- mixing with the air around: towards its temperature and vapour, cloud water towards none
    local k = math.min(1, dt * (lib.MIX + lib.ENTRAIN / p.r * math.abs(p.w)))
    if p.floats then k = k * lib.FLOAT_MIX end
    p.t = p.t + (lib.envT(air, p.z) - p.t) * k
    p.qv = p.qv + (lib.envQv(air, p.z) - p.qv) * k
    -- the cloud water mixed out goes into the mixed-in air as vapour, then evaporates if it can
    local out = p.qc * k
    p.qc, p.qv = p.qc - out, p.qv + out
    adjust(p, p.z)
    if p.soot then
        -- smoke: what it takes in makes it bigger and thinner, and a little fades all the time
        local kk = math.min(1, dt * (lib.MIX + lib.ENTRAIN / p.r * (math.abs(p.w) + math.abs(p.u))))
        p.r = math.min(lib.SMOKE_MAX_R, p.r * (1 + kk * 0.5))
        p.soot = p.soot * (1 - kk * 0.6) * math.max(0, 1 - dt * lib.SOOT_FADE)
    end
end

-- Smoke (2026-11-12, after the clouds; CAMPFIRE CF2): a puff of hot air with soot in it, from a
-- fire or a blast. The same air acts on it: much warmer than the air, it shoots up, takes in the
-- air it passes (growing, thinning, cooling), slows, and spreads where it's no warmer; burning
-- gives off water, so a big fire's smoke that reaches the cloud base grows a cloud cap
-- (pyrocumulus). warm: K over the air, wet: extra g/kg of vapour.
lib.SOOT_FADE = 0.0015
lib.SMOKE_MAX_R = 900
function lib.newSmoke(air, x, z, warm, r, wet)
    local p = lib.newThermal(air, x, z, 0, warm, r)
    p.qv = lib.envQv(air, z) + (wet or 0) -- the air's own vapour (not its humidity at the heat)
    adjust(p, z)
    p.soot = 1
    return p
end

-- how hot it is, to see (0 .. 1): a fireball glows
function lib.glow(air, p)
    return math.max(0, math.min(1, (p.t - lib.envT(air, p.z) - 25) / 120))
end

-- how close to cloud it is: relative humidity, 1 = saturated
function lib.rh(p)
    return p.qv / lib.qs(p.t, lib.pressure(p.z))
end

-- spent: no cloud left and too dry to be one soon (the scene's shimmer is gone by then); smoke:
-- no soot left to see either
lib.SPENT_RH = 0.8
function lib.spent(p)
    if p.soot then return p.soot < 0.03 and p.qc <= 0.005 end
    return p.qc <= 0.005 and lib.rh(p) < lib.SPENT_RH and p.w < 0.5
end

-- The lines for the panel: lift the ground's air (a little warm, as a sunny field makes it) and
-- see where it turns to cloud (the condensation level: the bases), where it gets warmer than the
-- air and goes on alone (the level of free convection), and where it stops being (the top).
-- Each nil when it doesn't happen below 12 km.
function lib.levels(air)
    local p = lib.newThermal(air, 0, 0, lib.envRH(air, 0), 0)
    local lcl, lfc, top
    local step = 20
    for z = step, 12000, step do
        lib.moveTo(p, z)
        if not lcl and p.qc > 0 then lcl = z end
        local warmer = lib.buoyancyK(air, p) > 0
        if lcl and not lfc and warmer then lfc = z end
        if lfc and not warmer then top = z; break end
    end
    return lcl, lfc, top
end

return lib
