local raw = {
    [1] = {
        data = { upperteeth = true },
        points = { 46, 111, 70, 68, 153, 111, 224, 68, 254, 110, 223, 172, 156, 205, 70, 153 }
    },
    [2] = {
        points = { 615, 657, 631, 651, 739, 649, 852, 645, 862, 665, 841, 670, 739, 670, 628, 674 }
    },
    [3] = {
        points = { 758, 300, 790, 277, 848, 316, 899, 268, 932, 296, 926, 333, 847, 355, 762, 338 }
    },
    [4] = {
        points = { 529, 484, 545, 476, 601, 530, 666, 478, 688, 490, 669, 522, 605, 531, 533, 520 }
    },
    [5] = {
        points = { 508, 313, 570, 256, 610, 249, 669, 262, 715, 315, 697, 365, 615, 329, 541, 370 }
    },
    [6] = {
        points = { 540, 98, 561, 59, 601, 47, 643, 65, 661, 93, 639, 126, 597, 139, 564, 130 }
    },
    [7] = {
        points = { 355, 122, 363, 98, 388, 85, 411, 96, 421, 122, 411, 146, 388, 160, 366, 145 }
    },
    [8] = {
        points = { 762, 104, 772, 68, 835, 76, 914, 72, 930, 101, 915, 138, 827, 144, 770, 140 }
    },
    [9] = {
        points = { 770, 506, 794, 486, 853, 491, 906, 486, 927, 512, 908, 521, 846, 515, 792, 521 }
    },
    [10] = {
        data = { upperteeth = true },
        points = { 265, 315, 285, 285, 348, 271, 420, 289, 429, 320, 413, 368, 341, 367, 281, 345 }
    },
    [11] = {
        data = { upperteeth = true },
        points = { 323, 583, 334, 546, 385, 519, 435, 543, 443, 580, 424, 608, 384, 638, 337, 614 }
    },
    [12] =
    {
        data = { upperteeth = true },
        points = { 80, 444, 101, 408, 165, 391, 231, 404, 248, 450, 231, 478, 163, 500, 84, 478 }
    },
    [13] =
    {
        data = { upperteeth = true },
        points = { 86, 643, 113, 611, 177, 647, 239, 616, 265, 659, 231, 701, 162, 702, 96, 692 }
    },
    [14] = {

        points = { 1036, 556, 1056, 534, 1129, 496, 1226, 538, 1218, 566, 1204, 573, 1128, 518, 1051, 576 }
    }
}

function normalizeShapesByUpperLip(shapes)
    local function getLipCenters(points)
        local upX, upY, downX, downY = 0, 0, 0, 0
        local half = #points / 2

        for i = 1, half, 2 do
            upX = upX + points[i]
            upY = upY + points[i + 1]
        end
        for i = half + 1, #points, 2 do
            downX = downX + points[i]
            downY = downY + points[i + 1]
        end

        local count = half / 2
        return upX / count, upY / count, downX / count, downY / count
    end

    local normalized = {}

    for j, shape in ipairs(shapes) do
        local upX, upY, downX, downY = getLipCenters(shape.points)

        -- Define anchor as upper lip center (we freeze this) and shift all points relative to it
        local anchorX = upX
        local anchorY = upY

        local newShape = { points = {} }
        for i = 1, #shape.points, 2 do
            local x = shape.points[i] - anchorX
            local y = shape.points[i + 1] - anchorY

            table.insert(newShape.points, x)
            table.insert(newShape.points, y)
        end
        if shape.data then
            newShape.data = shallowCopy(shape.data)
        end
        table.insert(normalized, newShape)
    end

    return normalized
end

function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

function normalizeShapesToCenter(shapes)
    local function getBBox(points)
        local minX, minY = points[1], points[2]
        local maxX, maxY = points[1], points[2]
        for i = 3, #points, 2 do
            local x, y = points[i], points[i + 1]
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
        end
        return minX, minY, maxX, maxY
    end

    -- Step 1: find largest bbox
    local maxW, maxH = 0, 0
    --local refCx, refCy = 0, 0

    for _, shape in ipairs(shapes) do
        local minX, minY, maxX, maxY = getBBox(shape.points)
        local w, h = maxX - minX, maxY - minY
        if w * h > maxW * maxH then
            maxW, maxH = w, h
            --refCx = (minX + maxX) / 2
            --refCy = (minY + maxY) / 2
        end
    end

    -- Step 2: create normalized copies
    local normalized = {}

    for _, shape in ipairs(shapes) do
        local minX, minY, maxX, maxY = getBBox(shape.points)
        local cx = (minX + maxX) / 2
        local cy = (minY + maxY) / 2
        --local w = maxX - minX
        --local h = maxY - minY


        local newShape = { points = {} }

        for i = 1, #shape.points, 2 do
            local x = (shape.points[i] - cx)     --+ refCx
            local y = (shape.points[i + 1] - cy) --+ refCy
            table.insert(newShape.points, x)
            table.insert(newShape.points, y)
        end

        table.insert(normalized, newShape)
    end
    print('largets bbox found', maxW, maxH)
    return normalized
end

return { raw = raw, normalized = normalizeShapesByUpperLip(raw) }
