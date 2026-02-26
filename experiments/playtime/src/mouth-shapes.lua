-- Mouth shape presets ported from mipomi-lang.
-- 15 phoneme shapes, each with 8 control points (16 floats).
-- Points 1-4 = upper lip (left to right), points 5-8 = lower lip (right to left).
-- Normalized so upper lip center is at (0,0).

local lib = {}

local raw = {
    { name = 'A_I',              data = { upperteeth = true },
      points = { 46, 111, 70, 68, 153, 111, 224, 68, 254, 110, 223, 172, 156, 205, 70, 153 } },
    { name = 'closed',
      points = { 615, 657, 631, 651, 739, 649, 852, 645, 862, 665, 841, 670, 739, 670, 628, 674 } },
    { name = 'open_tween_happy',
      points = { 758, 300, 790, 277, 848, 316, 899, 268, 932, 296, 926, 333, 847, 355, 762, 338 } },
    { name = 'M_B_P',
      points = { 529, 484, 545, 476, 601, 530, 666, 478, 688, 490, 669, 522, 605, 531, 533, 520 } },
    { name = 'ugh',
      points = { 508, 313, 570, 256, 610, 249, 669, 262, 715, 315, 697, 365, 615, 329, 541, 370 } },
    { name = 'O_U_agh',
      points = { 540, 98, 561, 59, 601, 47, 643, 65, 661, 93, 639, 126, 597, 139, 564, 130 } },
    { name = 'O_U_W_Q',
      points = { 355, 122, 363, 98, 388, 85, 411, 96, 421, 122, 411, 146, 388, 160, 366, 145 } },
    { name = 'open_tween',
      points = { 762, 104, 772, 68, 835, 76, 914, 72, 930, 101, 915, 138, 827, 144, 770, 140 } },
    { name = 'mmm',
      points = { 770, 506, 794, 486, 853, 491, 906, 486, 927, 512, 908, 521, 846, 515, 792, 521 } },
    { name = 'C_D_E_G_K_N_R_S', data = { upperteeth = true },
      points = { 265, 315, 285, 285, 348, 271, 420, 289, 429, 320, 413, 368, 341, 367, 281, 345 } },
    { name = 'L_OU',             data = { upperteeth = true },
      points = { 323, 583, 334, 546, 385, 519, 435, 543, 443, 580, 424, 608, 384, 638, 337, 614 } },
    { name = 'TH_L',             data = { upperteeth = true },
      points = { 80, 444, 101, 408, 165, 391, 231, 404, 248, 450, 231, 478, 163, 500, 84, 478 } },
    { name = 'F_V',              data = { upperteeth = true },
      points = { 86, 643, 113, 611, 177, 647, 239, 616, 265, 659, 231, 701, 162, 702, 96, 692 } },
    { name = 'frown',
      points = { 1036, 556, 1056, 534, 1129, 496, 1226, 538, 1218, 566, 1204, 573, 1128, 518, 1051, 576 } },
    { name = 'smile',
      points = { 1038, 546, 1051, 536, 1124, 652, 1208, 532, 1221, 547, 1208, 568, 1124, 663, 1053, 570 } },
}

local phonemeKeys = {
    a = 'A_I',
    i = 'A_I',
    o = 'O_U_W_Q',
    m = 'M_B_P',
    b = 'M_B_P',
    p = 'M_B_P',
    f = 'F_V',
    k = 'C_D_E_G_K_N_R_S',
    l = 'L_OU',
    t = 'TH_L',
    j = 'open_tween',
    n = 'C_D_E_G_K_N_R_S',
    d = 'C_D_E_G_K_N_R_S',
    s = 'C_D_E_G_K_N_R_S',
    h = 'O_U_agh',
    w = 'O_U_W_Q',
    closed = 'frown',
    smile2 = 'open_tween_happy',
    smile = 'smile',
    mmm = 'mmm',
    frown = 'frown',
}

-- Build phoneme-to-index lookup
local phonemeIndex = {}
for k, v in pairs(phonemeKeys) do
    for i = 1, #raw do
        if raw[i].name == v then
            phonemeIndex[k] = i
        end
    end
end

-- Normalize shapes so upper lip center is at (0,0)
local function normalizeShapesByUpperLip(shapes)
    local normalized = {}
    for _, shape in ipairs(shapes) do
        local pts = shape.points
        -- Upper lip = first 4 points (indices 1-8)
        local upX, upY = 0, 0
        for i = 1, 8, 2 do
            upX = upX + pts[i]
            upY = upY + pts[i + 1]
        end
        upX = upX / 4
        upY = upY / 4

        local newPts = {}
        for i = 1, #pts, 2 do
            newPts[#newPts + 1] = pts[i] - upX
            newPts[#newPts + 1] = pts[i + 1] - upY
        end

        local entry = { name = shape.name, points = newPts }
        if shape.data then
            local d = {}
            for dk, dv in pairs(shape.data) do d[dk] = dv end
            entry.data = d
        end
        normalized[#normalized + 1] = entry
    end
    return normalized
end

lib.raw = raw
lib.normalized = normalizeShapesByUpperLip(raw)
lib.phonemeIndex = phonemeIndex
lib.phonemeKeys = phonemeKeys

return lib
