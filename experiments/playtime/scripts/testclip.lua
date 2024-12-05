subjectPolygon = {
    { 50,  150 }, { 200, 50 }, { 350, 150 }, { 350, 300 },
    { 250, 300 }, { 200, 250 }, { 150, 350 }, { 100, 250 }, { 100, 200 }
}

clipPolygon = { { 100, 100 }, { 300, 100 }, { 300, 300 }, { 100, 300 } }



clipPolygon = { { -1673.0388007055, 1527.3891548546 }, { 1408.9717813051, 1520.3368606702 }, { 1444.2451499118, 149.08465608466 }, { -1320.3051146384, 149.08465608466 } }
subjectPolygon = { { -953.0329218107, -69.395061728395 }, { 479.0658436214, -102.31687242798 }, { 248.61316872428, -777.21399176955 }, { -846.03703703704, -760.75308641975 } }

clipPolygon = { { -1673.0388539902, 1527.3888947084 }, { 1408.9717280204, 1520.336600524 }, { 1444.2450966271, 149.08439593847 }, { -1320.3051679231, 149.08439593847 } }
subjectPolygon = { { -960.14231422083, 1496.5522231374 }, { 472.23336058953, 1513.6005598136 }, { 265.46061580761, 831.07613601758 }, { -829.09768268412, 809.34676462514 } }


function inside(p, cp1, cp2)
    return (cp2.x - cp1.x) * (p.y - cp1.y) > (cp2.y - cp1.y) * (p.x - cp1.x)
end

function intersection(cp1, cp2, s, e)
    local dcx, dcy = cp1.x - cp2.x, cp1.y - cp2.y
    local dpx, dpy = s.x - e.x, s.y - e.y
    local n1 = cp1.x * cp2.y - cp1.y * cp2.x
    local n2 = s.x * e.y - s.y * e.x
    local n3 = 1 / (dcx * dpy - dcy * dpx)
    local x = (n1 * dpx - n2 * dcx) * n3
    local y = (n1 * dpy - n2 * dcy) * n3
    return { x = x, y = y }
end

function clip(subjectPolygon, clipPolygon)
    local outputList = subjectPolygon
    local cp1 = clipPolygon[#clipPolygon]
    for _, cp2 in ipairs(clipPolygon) do -- WP clipEdge is cp1,cp2 here
        local inputList = outputList
        outputList = {}
        local s = inputList[#inputList]
        for _, e in ipairs(inputList) do
            if inside(e, cp1, cp2) then
                if not inside(s, cp1, cp2) then
                    outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
                end
                outputList[#outputList + 1] = e
            elseif inside(s, cp1, cp2) then
                outputList[#outputList + 1] = intersection(cp1, cp2, s, e)
            end
            s = e
        end
        cp1 = cp2
    end
    return outputList
end

function isCounterClockwise(polygon)
    local sum = 0
    for i = 1, #polygon do
        local p1 = polygon[i]
        local p2 = polygon[i % #polygon + 1]
        sum = sum + (p2.x - p1.x) * (p2.y + p1.y)
    end
    return sum < 0 -- Negative means counterclockwise
end

function reversePolygon(polygon)
    local reversed = {}
    for i = #polygon, 1, -1 do
        reversed[#reversed + 1] = polygon[i]
    end
    return reversed
end

function main()
    local function mkpoints(t)
        for i, p in ipairs(t) do
            p.x, p.y = p[1], p[2]
        end
    end
    mkpoints(subjectPolygon)
    mkpoints(clipPolygon)
    if not isCounterClockwise(subjectPolygon) then
        subjectPolygon = reversePolygon(subjectPolygon)
    end
    if not isCounterClockwise(clipPolygon) then
        clipPolygon = reversePolygon(clipPolygon)
    end
    print('ccw subject', isCounterClockwise(subjectPolygon))
    print('ccw clip', isCounterClockwise(clipPolygon))
    local outputList = clip(subjectPolygon, clipPolygon)

    for _, p in ipairs(outputList) do
        print(('{%f, %f},'):format(p.x, p.y))
    end
end

main()
