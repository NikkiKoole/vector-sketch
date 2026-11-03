-- texture-names: where a texture lives, and the move list from the old names (docs/ASSETS-AND-BUILDS.md AB6).
-- Mipo parts are textures/mipo/<part>/<part>-<nn>.png, with <part>-<nn>-mask.png beside it; world art is in
-- world/, patterns in pat/. The old flat names (feet6r.png, shapes9.png, borsthaar4.png, ...) were moved
-- 2026-11-03; MOVES is the only place they live. A scene, prefab or setup is migrated when it is read
-- (scene-load, library), so old scenes, the save folder's copies and old DNA keep loading, and resolve()
-- catches any that slip past. The textures nothing named went to ~/Projects/mipo-art/archive/.

local lib = {}

-- 'eye', 3 -> 'mipo/eye/eye-03' (no extension: callers add '.png' or '-mask.png')
function lib.part(kind, n)
    return ('mipo/%s/%s-%02d'):format(kind, kind, n)
end

-- 'eye', 'mipo/eye/eye-03.png' -> 3 (nil when it isn't one)
function lib.number(kind, url)
    return url and tonumber(url:match('mipo/' .. kind .. '/' .. kind .. '%-(%d+)%.png$'))
end

-- old base name -> new base name (the same for its -mask)
lib.MOVES = {
    ['shapeA1'] = 'mipo/body/body-01', ['shapeA2'] = 'mipo/body/body-02',
    ['shapeA3'] = 'mipo/body/body-03', ['shapeA4'] = 'mipo/body/body-04',
    ['shapes1'] = 'mipo/body/body-05', ['shapes2'] = 'mipo/body/body-06',
    ['shapes3'] = 'mipo/body/body-07', ['shapes4'] = 'mipo/body/body-08',
    ['shapes5'] = 'mipo/body/body-09', ['shapes6'] = 'mipo/body/body-10',
    ['shapes7'] = 'mipo/body/body-11', ['shapes8'] = 'mipo/body/body-12',
    ['shapes9'] = 'mipo/body/body-13', ['shapes10'] = 'mipo/body/body-14',
    ['shapes11'] = 'mipo/body/body-15', ['shapes12'] = 'mipo/body/body-16',
    ['shapes13'] = 'mipo/body/body-17', ['romp1'] = 'mipo/body/body-18',
    ['earx1r'] = 'mipo/ear/ear-01', ['earx2r'] = 'mipo/ear/ear-02',
    ['earx3r'] = 'mipo/ear/ear-03', ['earx4r'] = 'mipo/ear/ear-04',
    ['earx5r'] = 'mipo/ear/ear-05', ['earx6r'] = 'mipo/ear/ear-06',
    ['earx7r'] = 'mipo/ear/ear-07', ['earx8r'] = 'mipo/ear/ear-08',
    ['earx9r'] = 'mipo/ear/ear-09', ['earx10r'] = 'mipo/ear/ear-10',
    ['earx11r'] = 'mipo/ear/ear-11', ['earx12r'] = 'mipo/ear/ear-12',
    ['earx13r'] = 'mipo/ear/ear-13', ['earx14r'] = 'mipo/ear/ear-14',
    ['earx15r'] = 'mipo/ear/ear-15', ['earx16r'] = 'mipo/ear/ear-16',
    ['feet2r'] = 'mipo/foot/foot-01', ['feet3xr'] = 'mipo/foot/foot-02',
    ['feet5xr'] = 'mipo/foot/foot-03', ['feet6r'] = 'mipo/foot/foot-04',
    ['feet7r'] = 'mipo/foot/foot-05', ['feet7xr'] = 'mipo/foot/foot-06',
    ['feet8r'] = 'mipo/foot/foot-07', ['hand3r'] = 'mipo/hand/hand-01',
    ['leg1'] = 'mipo/leg/leg-01', ['leg2'] = 'mipo/leg/leg-02',
    ['leg3'] = 'mipo/leg/leg-03', ['leg4'] = 'mipo/leg/leg-04',
    ['leg5'] = 'mipo/leg/leg-05', ['leg7'] = 'mipo/leg/leg-06',
    ['borsthaar1'] = 'mipo/chesthair/chesthair-01', ['borsthaar2'] = 'mipo/chesthair/chesthair-02',
    ['borsthaar3'] = 'mipo/chesthair/chesthair-03', ['borsthaar4'] = 'mipo/chesthair/chesthair-04',
    ['borsthaar5'] = 'mipo/chesthair/chesthair-05', ['borsthaar6'] = 'mipo/chesthair/chesthair-06',
    ['borsthaar7'] = 'mipo/chesthair/chesthair-07', ['hair1'] = 'mipo/hair/hair-01',
    ['hair2'] = 'mipo/hair/hair-02', ['hair3'] = 'mipo/hair/hair-03',
    ['hair4'] = 'mipo/hair/hair-04', ['hair5'] = 'mipo/hair/hair-05',
    ['hair6'] = 'mipo/hair/hair-06', ['hair7'] = 'mipo/hair/hair-07',
    ['hair8'] = 'mipo/hair/hair-08', ['hair9'] = 'mipo/hair/hair-09',
    ['hair10'] = 'mipo/hair/hair-10', ['hair11'] = 'mipo/hair/hair-11',
    ['eye1'] = 'mipo/eye/eye-01', ['eye2'] = 'mipo/eye/eye-02',
    ['eye3'] = 'mipo/eye/eye-03', ['eye4'] = 'mipo/eye/eye-04',
    ['eye5'] = 'mipo/eye/eye-05', ['eye6'] = 'mipo/eye/eye-06',
    ['eye7'] = 'mipo/eye/eye-07', ['pupil1'] = 'mipo/pupil/pupil-01',
    ['pupil2'] = 'mipo/pupil/pupil-02', ['pupil3'] = 'mipo/pupil/pupil-03',
    ['pupil4'] = 'mipo/pupil/pupil-04', ['pupil5'] = 'mipo/pupil/pupil-05',
    ['pupil6'] = 'mipo/pupil/pupil-06', ['pupil7'] = 'mipo/pupil/pupil-07',
    ['pupil8'] = 'mipo/pupil/pupil-08', ['pupil9'] = 'mipo/pupil/pupil-09',
    ['pupil10'] = 'mipo/pupil/pupil-10', ['pupil11'] = 'mipo/pupil/pupil-11',
    ['brow1'] = 'mipo/brow/brow-01', ['brow2'] = 'mipo/brow/brow-02',
    ['brow3'] = 'mipo/brow/brow-03', ['brow4'] = 'mipo/brow/brow-04',
    ['brow5'] = 'mipo/brow/brow-05', ['brow6'] = 'mipo/brow/brow-06',
    ['brow7'] = 'mipo/brow/brow-07', ['nose1'] = 'mipo/nose/nose-01',
    ['nose2'] = 'mipo/nose/nose-02', ['nose3'] = 'mipo/nose/nose-03',
    ['nose4'] = 'mipo/nose/nose-04', ['nose5'] = 'mipo/nose/nose-05',
    ['nose6'] = 'mipo/nose/nose-06', ['nose7'] = 'mipo/nose/nose-07',
    ['nose8'] = 'mipo/nose/nose-08', ['nose9'] = 'mipo/nose/nose-09',
    ['nose10'] = 'mipo/nose/nose-10', ['nose11'] = 'mipo/nose/nose-11',
    ['nose12'] = 'mipo/nose/nose-12', ['nose13'] = 'mipo/nose/nose-13',
    ['nose14'] = 'mipo/nose/nose-14', ['nose15'] = 'mipo/nose/nose-15',
    ['teeth1'] = 'mipo/teeth/teeth-01', ['teeth2'] = 'mipo/teeth/teeth-02',
    ['teeth3'] = 'mipo/teeth/teeth-03', ['teeth4'] = 'mipo/teeth/teeth-04',
    ['teeth5'] = 'mipo/teeth/teeth-05', ['teeth6'] = 'mipo/teeth/teeth-06',
    ['teeth7'] = 'mipo/teeth/teeth-07', ['upperlip1'] = 'mipo/upperlip/upperlip-01',
    ['upperlip2'] = 'mipo/upperlip/upperlip-02', ['upperlip3'] = 'mipo/upperlip/upperlip-03',
    ['upperlip4'] = 'mipo/upperlip/upperlip-04', ['lowerlip1'] = 'mipo/lowerlip/lowerlip-01',
    ['lowerlip2'] = 'mipo/lowerlip/lowerlip-02', ['lowerlip3'] = 'mipo/lowerlip/lowerlip-03',
    ['lowerlip4'] = 'mipo/lowerlip/lowerlip-04', ['patch1'] = 'mipo/patch/patch-01',
    ['patch2'] = 'mipo/patch/patch-02', ['patch3'] = 'mipo/patch/patch-03',
    ['patch4'] = 'mipo/patch/patch-04', ['line1'] = 'world/line-01',
}

-- whole paths that moved (backdrops, relative to the project; docs/ASSETS-AND-BUILDS.md AB8)
lib.PATHS = {
    ['knut-is-dead/gevaarland.jpg'] = 'backdrops/gevaarland.jpg',
    ['knut-is-dead/stapel-met.jpg'] = 'backdrops/stapel-met.jpg',
}

-- an old name ('feet6r.png', 'feet6r-mask.png', 'textures/feet6r.png') -> its new one; anything else as is
function lib.resolve(url)
    if type(url) ~= 'string' then return url end
    if lib.PATHS[url] then return lib.PATHS[url] end
    local prefix, base, suffix = url:match('^(textures/)(.-)(%-mask%.png)$')
    if not prefix then prefix, base, suffix = url:match('^(textures/)(.-)(%.png)$') end
    if not prefix then
        prefix = ''
        base, suffix = url:match('^(.-)(%-mask%.png)$')
        if not base then base, suffix = url:match('^(.-)(%.png)$') end
    end
    local new = base and lib.MOVES[base]
    return new and (prefix .. new .. suffix) or url
end

-- every old texture name in a decoded scene / prefab table, renamed in place; returns how many
function lib.migrate(data)
    local count, seen = 0, {}
    local function walk(t)
        if seen[t] then return end
        seen[t] = true
        for k, v in pairs(t) do
            if type(v) == 'string' then
                local new = lib.resolve(v)
                if new ~= v then t[k], count = new, count + 1 end
            elseif type(v) == 'table' then
                walk(v)
            end
        end
    end
    if type(data) == 'table' then walk(data) end
    return count
end

return lib
