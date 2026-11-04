-- drum-machines: the drum jam's drum machine kits (docs/DRUM-JAM.md J4), voice by voice as their
-- dreamengine carts fire them. The sounds are patches in src/synth.lua (tr808*, slots 48-61); here is
-- how a hit plays them: a voice is a few notes on those patches (an 808 snare = two body tones and the
-- snappy noise, a clap = three quick retriggers and a tail).
--
-- The TR-808 is runtime/tr808.h's tr808_fire, at the cart's neutral knobs (tune, decay, colour all 0.5),
-- its numbers copied as they work out there: a hit's volume is the cart's base + boost, clamped 0..7
-- (boost 0 plain, 1 played by hand, 2 accented); a hard hit tips the snare from body to noise (§J9).
-- Hits that come out at volume 0 are left out (silent in the engine, but each would take a voice): at
-- boost 0 that's the cymbal's two upper bands, which only an accent brings in.

local lib = {}

-- role (the jam's: BD SD CPS CH OH CY RS CB TB LT MT HT) -> the 808's hits:
-- { patch, midi, base volume (before boost), length ms, delay ms, tilt = -1 body / 1 noise }
lib.tr808 = {
    BD = { { 'tr808Kick', 31, 6, 391 } },
    SD = { { 'tr808SnareBody', 54, 3, 110, tilt = -1 },        -- 180 Hz
           { 'tr808SnareBody', 64, 1, 110, tilt = -1 },        -- 330 Hz, ~10 dB under
           { 'tr808Snappy', 60, 3, 140, tilt = 1 } },
    CPS = { { 'tr808Clap', 60, 6, 12 }, { 'tr808Clap', 60, 6, 12, 10 }, { 'tr808Clap', 60, 6, 12, 20 },
            { 'tr808Clap', 60, 5, 140, 28 } },
    CH = { { 'tr808HatClosed', 60, 2, 50 } },
    OH = { { 'tr808HatOpen', 60, 2, 403 } },
    CY = { { 'tr808Cymbal', 79, 5, 642 }, { 'tr808Cymbal', 72, 4, 642 }, { 'tr808Cymbal', 66, 5, 642 },
           -- the upper bands, 3 steps under (tr808_cym3_vel): heard only on an accent
           { 'tr808CymbalMid', 72, -1, 450 }, { 'tr808CymbalHigh', 72, -1, 170 },
           { 'tr808CymbalMid', 79, 0, 450 }, { 'tr808CymbalMid', 66, 0, 450 },
           { 'tr808CymbalHigh', 79, 0, 170 }, { 'tr808CymbalHigh', 66, 0, 170 } },
    RS = { { 'tr808Rim', 92, 1, 15 }, { 'tr808Rim', 70, 4, 15 } },
    CB = { { 'tr808Cowbell', 73, 1, 70 }, { 'tr808Cowbell', 80, 7, 70 } },
    TB = { { 'tr808Maracas', 90, 4, 30 } }, -- the 808 has no tambourine: its maracas
    LT = { { 'tr808Tom', 40, 5, 280 }, { 'tr808TomThud', 60, 3, 30 } },
    MT = { { 'tr808Tom', 48, 5, 110 }, { 'tr808TomThud', 60, 3, 30 } },
    HT = { { 'tr808Tom', 54, 5, 80 }, { 'tr808TomThud', 60, 3, 30 } },
}

-- the jam's accent (0..1) as the cart's boost
function lib.boost(accent)
    if not accent or accent <= 0 then return 0 end
    return accent >= 0.5 and 2 or 1
end

-- The notes one hit of `role` plays on `kit`: a list of { patch, midi, vol, ms, delay ms }, nil if the
-- kit has no such voice. quieter = volume steps off every note (the jam's ghosts and run-ups).
function lib.notes(kit, role, accent, quieter)
    local voice = lib[kit] and lib[kit][role]
    if not voice then return nil end
    local boost, out = lib.boost(accent), {}
    local tilt = kit == 'tr808' and boost or 0 -- tr808__snare_tilt: boost x tr808_snare_dyn (1)
    for _, h in ipairs(voice) do
        local vol = h[3] + (h.tilt or 0) * tilt + boost
        vol = math.max(0, math.min(7, vol)) - (quieter or 0)
        if vol > 0 then out[#out + 1] = { h[1], h[2], vol, h[4], h[5] or 0 } end
    end
    return out
end

return lib
